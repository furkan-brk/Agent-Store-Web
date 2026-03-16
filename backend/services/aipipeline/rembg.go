package aipipeline

import (
	"bytes"
	"encoding/base64"
	"fmt"
	"image"
	"image/draw"
	_ "image/jpeg"
	"image/png"
	"io"
	"log"
	"net/http"
	"strings"
	"time"
)

// BgRemover handles background removal via the rembg ML service with
// chroma key fallback.
type BgRemover struct {
	rembgURL string
}

// NewBgRemover creates a BgRemover pointing at the rembg sidecar service.
func NewBgRemover(rembgURL string) *BgRemover {
	return &BgRemover{rembgURL: rembgURL}
}

// RemoveBackground removes the background from a base64-encoded image and returns
// raw image bytes plus the format ("webp" from ML, "png" from chroma key).
func (r *BgRemover) RemoveBackground(base64Image string) ([]byte, string) {
	raw := base64Image
	if idx := strings.Index(raw, ","); idx != -1 {
		raw = raw[idx+1:]
	}

	imgBytes, err := base64.StdEncoding.DecodeString(raw)
	if err != nil {
		log.Printf("[BG-Remove] base64 decode failed: %v", err)
		return nil, ""
	}

	// Try ML removal via rembg
	if r.rembgURL != "" {
		client := &http.Client{Timeout: 10 * time.Second}
		resp, err := client.Post(r.rembgURL+"/api/remove", "application/octet-stream", bytes.NewReader(imgBytes))
		if err == nil {
			defer resp.Body.Close()
			if resp.StatusCode == 200 {
				webpBytes, readErr := io.ReadAll(resp.Body)
				if readErr == nil && len(webpBytes) > 0 {
					log.Printf("[BG-Remove] ML removal succeeded (%d bytes, webp)", len(webpBytes))
					return webpBytes, "webp"
				}
				log.Printf("[BG-Remove] ML response read failed: %v", readErr)
			} else {
				log.Printf("[BG-Remove] ML returned status %d", resp.StatusCode)
			}
		} else {
			log.Printf("[BG-Remove] ML service unreachable: %v", err)
		}
	} else {
		log.Printf("[BG-Remove] rembg URL not configured, skipping ML removal")
	}

	// Fallback: chroma key removal
	log.Printf("[BG-Remove] falling back to chroma key")
	if transparentB64, ckErr := chromaKey(raw); ckErr == nil {
		pngBytes, decErr := base64.StdEncoding.DecodeString(transparentB64)
		if decErr == nil && len(pngBytes) > 0 {
			log.Printf("[BG-Remove] chroma key succeeded (%d bytes, png)", len(pngBytes))
			return pngBytes, "png"
		}
	} else {
		log.Printf("[BG-Remove] chroma key failed: %v", ckErr)
	}

	log.Printf("[BG-Remove] all methods failed, returning original image")
	return imgBytes, "png"
}

func chromaKey(base64Image string) (string, error) {
	imgBytes, err := base64.StdEncoding.DecodeString(base64Image)
	if err != nil {
		return "", fmt.Errorf("base64 decode: %w", err)
	}

	img, _, err := image.Decode(bytes.NewReader(imgBytes))
	if err != nil {
		return "", fmt.Errorf("image decode: %w", err)
	}

	bounds := img.Bounds()
	w, h := bounds.Dx(), bounds.Dy()

	result := image.NewNRGBA(bounds)
	draw.Draw(result, bounds, img, bounds.Min, draw.Src)

	mask := make([]bool, w*h)

	// Pass 1: Hard classification — mark all magenta pixels transparent
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			idx := y*result.Stride + x*4
			r8 := int(result.Pix[idx])
			g8 := int(result.Pix[idx+1])
			b8 := int(result.Pix[idx+2])
			if isMagenta(r8, g8, b8) {
				result.Pix[idx] = 0
				result.Pix[idx+1] = 0
				result.Pix[idx+2] = 0
				result.Pix[idx+3] = 0
				mask[y*w+x] = true
			}
		}
	}

	// Pass 2: Edge soft alpha + despill
	dx := []int{-1, 0, 1, -1, 1, -1, 0, 1}
	dy := []int{-1, -1, -1, 0, 0, 1, 1, 1}

	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			if mask[y*w+x] {
				continue
			}
			isEdge := false
			for d := 0; d < 8; d++ {
				nx, ny := x+dx[d], y+dy[d]
				if nx >= 0 && nx < w && ny >= 0 && ny < h && mask[ny*w+nx] {
					isEdge = true
					break
				}
			}
			if !isEdge {
				continue
			}
			idx := y*result.Stride + x*4
			r8 := int(result.Pix[idx])
			g8 := int(result.Pix[idx+1])
			b8 := int(result.Pix[idx+2])
			contrib := magentaContribution(r8, g8, b8)
			alpha := 1.0 - contrib
			if alpha < 0.12 {
				result.Pix[idx] = 0
				result.Pix[idx+1] = 0
				result.Pix[idx+2] = 0
				result.Pix[idx+3] = 0
				mask[y*w+x] = true
				continue
			}
			dr, dg, db := despillMagenta(r8, g8, b8)
			result.Pix[idx] = uint8(dr)
			result.Pix[idx+1] = uint8(dg)
			result.Pix[idx+2] = uint8(db)
			result.Pix[idx+3] = uint8(alpha * 255)
		}
	}

	// Pass 3: 1-pixel erosion
	alphaSnap := make([]uint8, w*h)
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			alphaSnap[y*w+x] = result.Pix[y*result.Stride+x*4+3]
		}
	}
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			if alphaSnap[y*w+x] == 0 {
				continue
			}
			transparentCount := 0
			for d := 0; d < 8; d++ {
				nx, ny := x+dx[d], y+dy[d]
				if nx < 0 || nx >= w || ny < 0 || ny >= h {
					transparentCount++
					continue
				}
				if alphaSnap[ny*w+nx] == 0 {
					transparentCount++
				}
			}
			if transparentCount >= 6 {
				idx := y*result.Stride + x*4
				result.Pix[idx] = 0
				result.Pix[idx+1] = 0
				result.Pix[idx+2] = 0
				result.Pix[idx+3] = 0
			}
		}
	}

	// Pass 4: Encode as transparent PNG
	var buf bytes.Buffer
	if err := png.Encode(&buf, result); err != nil {
		return "", fmt.Errorf("png encode: %w", err)
	}
	return base64.StdEncoding.EncodeToString(buf.Bytes()), nil
}

func isMagenta(r8, g8, b8 int) bool {
	if r8 > 120 && b8 > 120 && r8 > g8+50 && b8 > g8+50 {
		maxRB := r8
		if b8 > maxRB {
			maxRB = b8
		}
		diff := r8 - b8
		if diff < 0 {
			diff = -diff
		}
		if float64(diff) < float64(maxRB)*0.35 {
			return true
		}
	}
	hue, sat, _ := rgbToHSV(uint8(r8), uint8(g8), uint8(b8))
	if hue >= 285 && hue <= 320 && sat > 0.35 {
		return true
	}
	return false
}

func magentaContribution(r8, g8, b8 int) float64 {
	avgRB := float64(r8+b8) / 2.0
	gf := float64(g8)
	if avgRB <= gf {
		return 0.0
	}
	excess := (avgRB - gf) / 255.0
	contrib := excess * excess
	if contrib < 0.02 {
		return 0.0
	}
	if contrib > 0.90 {
		return 1.0
	}
	return contrib
}

func despillMagenta(r8, g8, b8 int) (int, int, int) {
	avg := (r8 + g8 + b8) / 3
	limit := g8
	if avg > limit {
		limit = avg
	}
	if r8 > limit {
		r8 = limit
	}
	if b8 > limit {
		b8 = limit
	}
	return r8, g8, b8
}

func rgbToHSV(r, g, b uint8) (h float64, s float64, v float64) {
	rf := float64(r) / 255.0
	gf := float64(g) / 255.0
	bf := float64(b) / 255.0

	mx := rf
	if gf > mx {
		mx = gf
	}
	if bf > mx {
		mx = bf
	}
	mn := rf
	if gf < mn {
		mn = gf
	}
	if bf < mn {
		mn = bf
	}

	v = mx
	delta := mx - mn
	if mx == 0 {
		return 0, 0, 0
	}
	s = delta / mx
	if delta == 0 {
		return 0, 0, v
	}

	switch mx {
	case rf:
		h = 60.0 * (gf - bf) / delta
	case gf:
		h = 60.0*(bf-rf)/delta + 120.0
	case bf:
		h = 60.0*(rf-gf)/delta + 240.0
	}
	if h < 0 {
		h += 360.0
	}
	return h, s, v
}
