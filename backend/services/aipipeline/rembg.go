package aipipeline

import (
	"bytes"
	"encoding/base64"
	"fmt"
	"image"
	"image/draw"
	_ "image/jpeg"
	"image/png"
	"log"
	"strings"
	"time"
)

// BgRemover performs chroma-key background removal on images generated with a
// magenta (#FF00FF) backdrop.  This is a pure-Go implementation that requires
// no external Python service or ML model.
//
// The Imagen avatar prompt always requests a solid magenta background, so a
// well-tuned chroma-key algorithm is sufficient for clean extraction.
type BgRemover struct{}

// NewBgRemover creates a BgRemover.  No configuration is required because
// the pipeline no longer depends on an external rembg service.
func NewBgRemover() *BgRemover {
	return &BgRemover{}
}

// RemoveBackground decodes a base64-encoded image, removes the magenta
// background via a 4-pass chroma-key algorithm, and returns the processed
// image bytes together with the output format string ("png").
//
// The returned format is always "png" because the Docker build uses
// CGO_ENABLED=0 which precludes CGo-based WebP encoders.  PNG is the only
// stdlib format that supports an alpha channel.
//
// On failure the original (undecoded) image bytes are returned so callers
// always receive a usable image.
func (r *BgRemover) RemoveBackground(base64Image string) ([]byte, string) {
	start := time.Now()

	// Strip optional data-URI prefix (e.g. "data:image/png;base64,…").
	raw := base64Image
	if strings.HasPrefix(raw, "data:") {
		if idx := strings.Index(raw, ","); idx != -1 {
			raw = raw[idx+1:]
		}
	}

	imgBytes, err := base64.StdEncoding.DecodeString(raw)
	if err != nil {
		log.Printf("[BG-Remove] base64 decode failed: %v", err)
		return nil, ""
	}

	processed, format, err := chromaKeyRemove(imgBytes)
	if err != nil {
		log.Printf("[BG-Remove] chroma-key failed: %v — returning original image", err)
		return imgBytes, "png"
	}

	elapsed := time.Since(start)
	log.Printf("[BG-Remove] chroma-key succeeded | format=%s | input=%d bytes | output=%d bytes (%.1f%% of original) | elapsed=%s",
		format, len(imgBytes), len(processed),
		float64(len(processed))/float64(len(imgBytes))*100,
		elapsed.Round(time.Millisecond))

	return processed, format
}

// ---------------------------------------------------------------------------
// Core algorithm
// ---------------------------------------------------------------------------

// chromaKeyRemove takes raw image bytes (PNG/JPEG), removes the magenta
// background using a 4-pass algorithm, and returns the processed image bytes
// plus the output format ("png").
func chromaKeyRemove(imgBytes []byte) ([]byte, string, error) {
	img, _, err := image.Decode(bytes.NewReader(imgBytes))
	if err != nil {
		return nil, "", fmt.Errorf("image decode: %w", err)
	}

	bounds := img.Bounds()
	w, h := bounds.Dx(), bounds.Dy()
	if w == 0 || h == 0 {
		return nil, "", fmt.Errorf("degenerate image: %dx%d", w, h)
	}
	totalPixels := w * h

	result := image.NewNRGBA(bounds)
	draw.Draw(result, bounds, img, bounds.Min, draw.Src)

	// mask[i] == true means the pixel has been classified as background.
	mask := make([]bool, totalPixels)
	removedPixels := 0

	// 8-connected neighbour offsets
	dx := [8]int{-1, 0, 1, -1, 1, -1, 0, 1}
	dy := [8]int{-1, -1, -1, 0, 0, 1, 1, 1}

	// ------------------------------------------------------------------
	// Pass 1: Hard classification — mark all clearly-magenta pixels as
	// transparent.
	// ------------------------------------------------------------------
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
				removedPixels++
			}
		}
	}

	// ------------------------------------------------------------------
	// Pass 2: Soft edge alpha + despill — for foreground pixels that
	// border a transparent region, compute a partial alpha based on
	// magenta contribution and neutralise the magenta colour spill.
	// ------------------------------------------------------------------
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			if mask[y*w+x] {
				continue
			}

			// Check whether this pixel is adjacent to a transparent one.
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
				// Almost entirely magenta — treat as background.
				result.Pix[idx] = 0
				result.Pix[idx+1] = 0
				result.Pix[idx+2] = 0
				result.Pix[idx+3] = 0
				mask[y*w+x] = true
				removedPixels++
				continue
			}

			dr, dg, db := despillMagenta(r8, g8, b8)
			result.Pix[idx] = uint8(dr)
			result.Pix[idx+1] = uint8(dg)
			result.Pix[idx+2] = uint8(db)
			result.Pix[idx+3] = uint8(alpha * 255)
		}
	}

	// ------------------------------------------------------------------
	// Pass 3: 1-pixel fringe erosion — remove isolated foreground pixels
	// that are almost entirely surrounded by transparent neighbours
	// (6 out of 8 neighbours transparent).
	// ------------------------------------------------------------------
	alphaSnap := make([]uint8, totalPixels)
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
				removedPixels++
			}
		}
	}

	// ------------------------------------------------------------------
	// Pass 4: Encode as PNG with best compression.
	// ------------------------------------------------------------------
	var buf bytes.Buffer
	encoder := &png.Encoder{CompressionLevel: png.DefaultCompression}
	if err := encoder.Encode(&buf, result); err != nil {
		return nil, "", fmt.Errorf("png encode: %w", err)
	}

	pctRemoved := float64(removedPixels) / float64(totalPixels) * 100
	log.Printf("[BG-Remove] quality metrics | image=%dx%d | total_pixels=%d | removed=%d (%.1f%%) | retained=%.1f%%",
		w, h, totalPixels, removedPixels, pctRemoved, 100-pctRemoved)

	return buf.Bytes(), "png", nil
}

// ---------------------------------------------------------------------------
// Helper functions
// ---------------------------------------------------------------------------

// isMagenta returns true when the pixel colour is within the magenta/fuchsia
// range.  Two tests are applied:
//   - RGB heuristic: R and B both bright, G is significantly lower, R≈B.
//   - HSV heuristic: hue 285-320 with saturation > 0.35.
func isMagenta(r8, g8, b8 int) bool {
	// Fast RGB heuristic
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

	// Slower but wider HSV heuristic for borderline shades
	hue, sat, _ := rgbToHSV(uint8(r8), uint8(g8), uint8(b8))
	if hue >= 280 && hue <= 335 && sat > 0.30 {
		return true
	}
	return false
}

// magentaContribution estimates how much of a pixel's colour comes from
// magenta.  Returns a value in [0, 1] where 1 means pure magenta.
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

// despillMagenta neutralises magenta colour contamination on edge pixels by
// clamping R and B channels so they do not exceed the maximum of the green
// channel and the pixel's luminance average.
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

// rgbToHSV converts an RGB triplet to hue (0-360), saturation (0-1), value (0-1).
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
