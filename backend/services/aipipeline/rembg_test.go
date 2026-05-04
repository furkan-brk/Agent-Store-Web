package aipipeline

import (
	"bytes"
	"encoding/base64"
	"image"
	"image/color"
	"image/png"
	"testing"
)

func TestRemoveBackground_SolidWhiteBackdrop(t *testing.T) {
	// 64x64 white background with a black square in the middle.
	img := newTestNRGBA(64, 64, color.NRGBA{R: 255, G: 255, B: 255, A: 255})
	for y := 20; y <= 44; y++ {
		for x := 20; x <= 44; x++ {
			img.SetNRGBA(x, y, color.NRGBA{R: 0, G: 0, B: 0, A: 255})
		}
	}

	// Internal white detail that should NOT be removed (not connected to border).
	img.SetNRGBA(32, 32, color.NRGBA{R: 255, G: 255, B: 255, A: 255})

	var in bytes.Buffer
	if err := png.Encode(&in, img); err != nil {
		t.Fatalf("png encode: %v", err)
	}
	b64 := base64.StdEncoding.EncodeToString(in.Bytes())

	remover := NewBgRemover("")
	out, format := remover.RemoveBackground(b64)
	if format != "png" {
		t.Fatalf("expected format=png, got %q", format)
	}
	if len(out) == 0 {
		t.Fatalf("expected non-empty output")
	}

	decoded, err := png.Decode(bytes.NewReader(out))
	if err != nil {
		t.Fatalf("decode output png: %v", err)
	}

	corner := color.NRGBAModel.Convert(decoded.At(0, 0)).(color.NRGBA)
	if corner.A != 0 {
		t.Fatalf("expected transparent corner alpha=0, got %d", corner.A)
	}

	centerBlack := color.NRGBAModel.Convert(decoded.At(25, 25)).(color.NRGBA)
	if centerBlack.A != 255 {
		t.Fatalf("expected opaque center alpha=255, got %d", centerBlack.A)
	}
	if centerBlack.R != 0 || centerBlack.G != 0 || centerBlack.B != 0 {
		t.Fatalf("expected black center pixel, got rgb=(%d,%d,%d)", centerBlack.R, centerBlack.G, centerBlack.B)
	}

	internalWhite := color.NRGBAModel.Convert(decoded.At(32, 32)).(color.NRGBA)
	if internalWhite.A != 255 {
		t.Fatalf("expected internal white detail to remain opaque alpha=255, got %d", internalWhite.A)
	}
}

// newTestNRGBA creates a small NRGBA image filled with a single colour.
func newTestNRGBA(w, h int, fill color.NRGBA) *image.NRGBA {
	img := image.NewNRGBA(image.Rect(0, 0, w, h))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			img.SetNRGBA(x, y, fill)
		}
	}
	return img
}
