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
	"mime/multipart"
	"net/http"
	"strings"
	"time"
)

// BgRemover performs background removal on images generated with a solid,
// uniform backdrop. This is a pure-Go implementation that requires no external
// Python service or ML model.
//
// Expected input:
//   - The avatar generator requests a flat, uniform backdrop that reaches every
//     pixel of the image edges (e.g. pure white #FFFFFF).
//   - The character silhouette is clearly separated from the backdrop.
//
// Strategy:
// - Detect the backdrop colour by sampling the image corners.
// - Flood-fill from the borders to mark only background connected to the edges.
// - Apply soft-edge alpha for anti-aliased boundary pixels.
type BgRemover struct {
	clipDropAPIKey string
}

// NewBgRemover creates a BgRemover.  When clipDropAPIKey is non-empty the
// ClipDrop background-removal API is tried first; on failure (or when the
// key is empty) the built-in solid-background remover is used as a fallback.
func NewBgRemover(clipDropAPIKey string) *BgRemover {
	if clipDropAPIKey != "" {
		log.Println("[BG-Remove] ClipDrop API key configured — will use ClipDrop with solid-bg fallback")
	} else {
		log.Println("[BG-Remove] No ClipDrop API key — using solid-bg algorithm only")
	}
	return &BgRemover{clipDropAPIKey: clipDropAPIKey}
}

// RemoveBackground decodes a base64-encoded image, removes a solid background,
// and returns the processed image bytes together with the output format string
// ("png").
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

	// --- Try ClipDrop API first if configured ---
	if r.clipDropAPIKey != "" {
		clipResult, clipErr := r.clipDropRemoveBackground(imgBytes)
		if clipErr == nil {
			elapsed := time.Since(start)
			log.Printf("[BG-Remove] ClipDrop API succeeded | input=%d bytes | output=%d bytes (%.1f%% of original) | elapsed=%s",
				len(imgBytes), len(clipResult),
				float64(len(clipResult))/float64(len(imgBytes))*100,
				elapsed.Round(time.Millisecond))
			return clipResult, "png"
		}
		log.Printf("[BG-Remove] ClipDrop API failed: %v — falling back to solid-bg", clipErr)
	}

	// --- Fallback: solid-background removal (pure Go) ---
	processed, format, err := solidBackgroundRemove(imgBytes)
	if err != nil {
		log.Printf("[BG-Remove] solid-bg failed: %v — returning original image", err)
		return imgBytes, "png"
	}

	elapsed := time.Since(start)
	log.Printf("[BG-Remove] solid-bg succeeded | format=%s | input=%d bytes | output=%d bytes (%.1f%% of original) | elapsed=%s",
		format, len(imgBytes), len(processed),
		float64(len(processed))/float64(len(imgBytes))*100,
		elapsed.Round(time.Millisecond))

	return processed, format
}

// clipDropRemoveBackground calls the ClipDrop remove-background API and
// returns the processed image bytes (PNG with transparent background).
func (r *BgRemover) clipDropRemoveBackground(imgBytes []byte) ([]byte, error) {
	var body bytes.Buffer
	writer := multipart.NewWriter(&body)

	part, err := writer.CreateFormFile("image_file", "image.png")
	if err != nil {
		return nil, fmt.Errorf("create form file: %w", err)
	}
	if _, err := part.Write(imgBytes); err != nil {
		return nil, fmt.Errorf("write image data: %w", err)
	}
	if err := writer.Close(); err != nil {
		return nil, fmt.Errorf("close multipart writer: %w", err)
	}

	req, err := http.NewRequest(http.MethodPost, "https://clipdrop-api.co/remove-background/v1", &body)
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("x-api-key", r.clipDropAPIKey)
	req.Header.Set("Content-Type", writer.FormDataContentType())

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("clipdrop request: %w", err)
	}
	defer resp.Body.Close()

	respBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read response body: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("clipdrop returned HTTP %d: %s", resp.StatusCode, string(respBytes))
	}

	return respBytes, nil
}

// ---------------------------------------------------------------------------
// Core algorithm
// ---------------------------------------------------------------------------

// solidBackgroundRemove takes raw image bytes (PNG/JPEG), removes a flat
// background colour by flood-filling from the borders, and returns PNG bytes
// with an alpha channel.
func solidBackgroundRemove(imgBytes []byte) ([]byte, string, error) {
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

	bgR, bgG, bgB := sampleCornerBackground(result, w, h)

	// Tuned for uniform backdrops (white preferred). Hard tolerance is used for
	// flood-fill; soft tolerance is used only for edge alpha smoothing.
	hardTol := 12
	softTol := 45

	// mask[i] == true means pixel is background (connected to border).
	mask := make([]bool, totalPixels)
	queue := make([]int, 0, w*2+h*2)

	push := func(x, y int) {
		if x < 0 || x >= w || y < 0 || y >= h {
			return
		}
		pos := y*w + x
		if mask[pos] {
			return
		}
		idx := y*result.Stride + x*4
		r8 := int(result.Pix[idx])
		g8 := int(result.Pix[idx+1])
		b8 := int(result.Pix[idx+2])
		if maxAbsDiff(r8, g8, b8, int(bgR), int(bgG), int(bgB)) <= hardTol {
			mask[pos] = true
			queue = append(queue, pos)
		}
	}

	// Seed flood-fill from all border pixels.
	for x := 0; x < w; x++ {
		push(x, 0)
		push(x, h-1)
	}
	for y := 0; y < h; y++ {
		push(0, y)
		push(w-1, y)
	}

	// BFS flood-fill (4-connected).
	for head := 0; head < len(queue); head++ {
		pos := queue[head]
		x := pos % w
		y := pos / w
		push(x-1, y)
		push(x+1, y)
		push(x, y-1)
		push(x, y+1)
	}

	removedPixels := 0
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			if !mask[y*w+x] {
				continue
			}
			idx := y*result.Stride + x*4
			result.Pix[idx] = 0
			result.Pix[idx+1] = 0
			result.Pix[idx+2] = 0
			result.Pix[idx+3] = 0
			removedPixels++
		}
	}

	// Soft edge alpha: for foreground pixels adjacent to background, compute a
	// partial alpha based on distance-to-background colour.
	dx8 := [8]int{-1, 0, 1, -1, 1, -1, 0, 1}
	dy8 := [8]int{-1, -1, -1, 0, 0, 1, 1, 1}

	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			if mask[y*w+x] {
				continue
			}

			// Check adjacency to background.
			isEdge := false
			for d := 0; d < 8; d++ {
				nx, ny := x+dx8[d], y+dy8[d]
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
			d := maxAbsDiff(r8, g8, b8, int(bgR), int(bgG), int(bgB))

			if d <= hardTol {
				result.Pix[idx] = 0
				result.Pix[idx+1] = 0
				result.Pix[idx+2] = 0
				result.Pix[idx+3] = 0
				removedPixels++
				continue
			}
			if d >= softTol {
				continue
			}

			alpha := float64(d-hardTol) / float64(softTol-hardTol)
			if alpha < 0 {
				alpha = 0
			}
			if alpha > 1 {
				alpha = 1
			}
			result.Pix[idx+3] = uint8(alpha * 255)
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
	log.Printf("[BG-Remove] quality metrics | bg_rgb=(%d,%d,%d) | image=%dx%d | total_pixels=%d | removed=%d (%.1f%%) | retained=%.1f%%",
		bgR, bgG, bgB,
		w, h, totalPixels, removedPixels, pctRemoved, 100-pctRemoved)

	return buf.Bytes(), "png", nil
}

// ---------------------------------------------------------------------------
// Helper functions
// ---------------------------------------------------------------------------

func sampleCornerBackground(img *image.NRGBA, w, h int) (uint8, uint8, uint8) {
	// Sample four corners and average. The prompt enforces a uniform backdrop,
	// so corners are a reliable background reference.
	if w == 0 || h == 0 {
		return 255, 255, 255
	}
	points := [][2]int{{0, 0}, {w - 1, 0}, {0, h - 1}, {w - 1, h - 1}}
	var rSum, gSum, bSum int
	for _, p := range points {
		x, y := p[0], p[1]
		idx := y*img.Stride + x*4
		rSum += int(img.Pix[idx])
		gSum += int(img.Pix[idx+1])
		bSum += int(img.Pix[idx+2])
	}
	return uint8(rSum / len(points)), uint8(gSum / len(points)), uint8(bSum / len(points))
}

func maxAbsDiff(r8, g8, b8, br8, bg8, bb8 int) int {
	dr := r8 - br8
	if dr < 0 {
		dr = -dr
	}
	dg := g8 - bg8
	if dg < 0 {
		dg = -dg
	}
	db := b8 - bb8
	if db < 0 {
		db = -db
	}
	max := dr
	if dg > max {
		max = dg
	}
	if db > max {
		max = db
	}
	return max
}
