// testbg — Local background removal testing tool.
//
// Drop agent images (PNG/JPG) into the "input" folder next to this binary,
// then run the tool. It processes every image through the same magenta
// chroma-key pipeline used in production and writes transparent PNGs
// to the "output" folder.
//
// Usage:
//
//	cd backend && go run ./cmd/testbg
//	cd backend && go run ./cmd/testbg -in ./my_images -out ./my_results
//	cd backend && go run ./cmd/testbg -in ../some/path/single_image.png
package main

import (
	"bytes"
	"encoding/base64"
	"flag"
	"fmt"
	"image"
	"image/draw"
	_ "image/jpeg"
	"image/png"
	"os"
	"path/filepath"
	"strings"
	"time"
)

func main() {
	defaultIn := filepath.Join("cmd", "testbg", "input")
	defaultOut := filepath.Join("cmd", "testbg", "output")

	inPath := flag.String("in", defaultIn, "Input directory or single image file (PNG/JPG)")
	outPath := flag.String("out", defaultOut, "Output directory for transparent PNGs")
	flag.Parse()

	// Ensure output directory exists
	if err := os.MkdirAll(*outPath, 0o755); err != nil {
		fatal("create output dir: %v", err)
	}

	// Determine if input is a single file or a directory
	info, err := os.Stat(*inPath)
	if err != nil {
		fatal("cannot access input path %q: %v", *inPath, err)
	}

	var files []string
	if info.IsDir() {
		entries, err := os.ReadDir(*inPath)
		if err != nil {
			fatal("read input dir: %v", err)
		}
		for _, e := range entries {
			if e.IsDir() {
				continue
			}
			ext := strings.ToLower(filepath.Ext(e.Name()))
			if ext == ".png" || ext == ".jpg" || ext == ".jpeg" {
				files = append(files, filepath.Join(*inPath, e.Name()))
			}
		}
		if len(files) == 0 {
			fmt.Printf("No PNG/JPG files found in %s\n", *inPath)
			fmt.Println("Drop some agent images into the input folder and run again.")
			return
		}
	} else {
		files = []string{*inPath}
	}

	fmt.Printf("🎨 Magenta ChromaKey Background Removal Test\n")
	fmt.Printf("   Input:  %s\n", *inPath)
	fmt.Printf("   Output: %s\n", *outPath)
	fmt.Printf("   Files:  %d\n\n", len(files))

	success, failed := 0, 0
	for i, f := range files {
		name := filepath.Base(f)
		fmt.Printf("[%d/%d] Processing %s ...", i+1, len(files), name)

		start := time.Now()
		err := processImage(f, *outPath)
		elapsed := time.Since(start)

		if err != nil {
			fmt.Printf(" FAILED (%v)\n", err)
			failed++
		} else {
			fmt.Printf(" OK (%dms)\n", elapsed.Milliseconds())
			success++
		}
	}

	fmt.Printf("\nDone: %d succeeded, %d failed\n", success, failed)
}

func processImage(inputPath, outDir string) error {
	// Read input file
	data, err := os.ReadFile(inputPath)
	if err != nil {
		return fmt.Errorf("read file: %w", err)
	}

	// Decode image
	img, format, err := image.Decode(bytes.NewReader(data))
	if err != nil {
		return fmt.Errorf("decode %s: %w", format, err)
	}

	bounds := img.Bounds()
	w, h := bounds.Dx(), bounds.Dy()

	// Convert to NRGBA for direct pixel access
	result := image.NewNRGBA(bounds)
	draw.Draw(result, bounds, img, bounds.Min, draw.Src)

	mask := make([]bool, w*h)

	// ── Pass 1: Hard classification — mark all magenta pixels transparent ──
	magentaCount := 0
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
				magentaCount++
			}
		}
	}

	totalPixels := w * h
	pct := float64(magentaCount) / float64(totalPixels) * 100

	// ── Pass 2: Edge soft alpha + despill ──
	dx := []int{-1, 0, 1, -1, 1, -1, 0, 1}
	dy := []int{-1, -1, -1, 0, 0, 1, 1, 1}
	edgeCount := 0

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
			edgeCount++

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

	// ── Pass 3: 1-pixel erosion ──
	alphaSnap := make([]uint8, w*h)
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			alphaSnap[y*w+x] = result.Pix[y*result.Stride+x*4+3]
		}
	}
	erosionCount := 0
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
				erosionCount++
			}
		}
	}

	// Write output PNG
	baseName := strings.TrimSuffix(filepath.Base(inputPath), filepath.Ext(inputPath))
	outFile := filepath.Join(outDir, baseName+"_transparent.png")

	f, err := os.Create(outFile)
	if err != nil {
		return fmt.Errorf("create output: %w", err)
	}
	defer f.Close()

	if err := png.Encode(f, result); err != nil {
		return fmt.Errorf("encode png: %w", err)
	}

	fmt.Printf(" [%dx%d, magenta:%.1f%%, edges:%d, eroded:%d]", w, h, pct, edgeCount, erosionCount)

	// Also write a base64 version for easy pasting into API testing
	var buf bytes.Buffer
	if err := png.Encode(&buf, result); err == nil {
		b64 := base64.StdEncoding.EncodeToString(buf.Bytes())
		b64File := filepath.Join(outDir, baseName+"_base64.txt")
		os.WriteFile(b64File, []byte(b64), 0o644)
	}

	return nil
}

// ─── Magenta Detection (exact copy of production algorithm) ──────────────────

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

	max := rf
	if gf > max {
		max = gf
	}
	if bf > max {
		max = bf
	}
	min := rf
	if gf < min {
		min = gf
	}
	if bf < min {
		min = bf
	}

	v = max
	delta := max - min

	if max == 0 {
		return 0, 0, 0
	}
	s = delta / max

	if delta == 0 {
		return 0, 0, v
	}

	switch max {
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

func fatal(format string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, "ERROR: "+format+"\n", args...)
	os.Exit(1)
}
