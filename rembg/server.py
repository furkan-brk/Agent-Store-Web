from fastapi import FastAPI, Request, Response
from rembg import remove, new_session
from PIL import Image
from contextlib import asynccontextmanager
import io
import time

import numpy as np

session = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load the ML model at startup."""
    global session
    print("Loading isnet-anime model...")
    session = new_session("isnet-anime")
    print("Model loaded successfully.")
    yield


app = FastAPI(lifespan=lifespan)


# ---------------------------------------------------------------------------
# Chroma-key cleanup (matches Go backend chromaKey logic exactly)
# ---------------------------------------------------------------------------

def chroma_key_cleanup(img: Image.Image) -> Image.Image:
    """Post-process an RGBA image produced by rembg.remove().

    Pipeline:
      1. Composite the character onto solid magenta (#FF00FF).
      2. Pass 1 — hard magenta removal (alpha -> 0).
      3. Pass 2 — soft edge alpha + despill on border pixels.
      4. Pass 3 — fringe erosion (remove orphan pixels).

    Returns a new RGBA Image with cleaned transparency.
    """
    t0 = time.perf_counter()

    img = img.convert("RGBA")
    arr = np.array(img)  # shape (H, W, 4), dtype uint8
    h, w = arr.shape[:2]

    # -- Step 1: Composite onto magenta (#FF00FF) -------------------------
    # out = fg * (alpha/255) + magenta * (1 - alpha/255)
    alpha_f = arr[:, :, 3].astype(np.float32) / 255.0  # (H, W)
    magenta_bg = np.array([255, 0, 255], dtype=np.float32)

    composited = np.empty((h, w, 3), dtype=np.float32)
    for c in range(3):
        composited[:, :, c] = (
            arr[:, :, c].astype(np.float32) * alpha_f
            + magenta_bg[c] * (1.0 - alpha_f)
        )
    composited = np.clip(composited, 0, 255).astype(np.uint8)

    r = composited[:, :, 0].astype(np.int32)
    g = composited[:, :, 1].astype(np.int32)
    b = composited[:, :, 2].astype(np.int32)

    # Build output arrays — start from composited RGB + full alpha
    out_r = r.copy()
    out_g = g.copy()
    out_b = b.copy()
    out_a = np.full((h, w), 255, dtype=np.int32)

    # -- Step 2 (Pass 1): Hard magenta removal -----------------------------
    # isMagenta: R>120, B>120, R > G+50, B > G+50,
    #            abs(R-B) < max(R,B)*0.35
    cond_r120 = r > 120
    cond_b120 = b > 120
    cond_rg = r > (g + 50)
    cond_bg = b > (g + 50)
    max_rb = np.maximum(r, b)
    diff_rb = np.abs(r - b).astype(np.float64)
    cond_sym = diff_rb < (max_rb.astype(np.float64) * 0.35)

    magenta_mask = cond_r120 & cond_b120 & cond_rg & cond_bg & cond_sym
    out_a[magenta_mask] = 0

    pass1_count = int(np.count_nonzero(magenta_mask))
    print(f"  chroma_key pass1: {pass1_count} hard-magenta pixels removed")

    # -- Step 3 (Pass 2): Soft edge alpha + despill ------------------------
    # A pixel qualifies if it is NOT masked in pass 1 AND at least one of its
    # 8-connected neighbours IS masked (alpha==0 after pass 1).
    # We detect border pixels via a dilated version of the mask.

    # Pad out_a to handle boundary without branch
    padded_a = np.pad(out_a, pad_width=1, mode='constant', constant_values=255)

    # Check 8-connectivity: any neighbour has alpha==0 after pass 1
    neighbor_transparent = np.zeros((h, w), dtype=bool)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dy == 0 and dx == 0:
                continue
            neighbor_transparent |= (
                padded_a[1 + dy : 1 + dy + h, 1 + dx : 1 + dx + w] == 0
            )

    border_mask = (~magenta_mask) & neighbor_transparent

    # magentaContribution: ((avg(R,B) - G) / 255)^2, clamped
    avg_rb = (r.astype(np.float64) + b.astype(np.float64)) / 2.0
    gf = g.astype(np.float64)
    excess = np.where(avg_rb > gf, (avg_rb - gf) / 255.0, 0.0)
    contrib = excess * excess
    contrib = np.where(contrib < 0.02, 0.0, contrib)
    contrib = np.where(contrib > 0.90, 1.0, contrib)

    # Soft alpha: reduce alpha by contribution fraction
    soft_alpha = np.clip((1.0 - contrib) * 255.0, 0, 255).astype(np.int32)
    out_a = np.where(border_mask, np.minimum(out_a, soft_alpha), out_a)

    # despillMagenta on border pixels:
    #   limit = max(G, avg(R,G,B))
    #   R = min(R, limit); B = min(B, limit)
    avg_rgb = (r + g + b) // 3
    limit = np.maximum(g, avg_rgb)
    out_r = np.where(border_mask, np.minimum(out_r, limit), out_r)
    out_b = np.where(border_mask, np.minimum(out_b, limit), out_b)

    pass2_count = int(np.count_nonzero(border_mask))
    print(f"  chroma_key pass2: {pass2_count} border pixels softened/despilled")

    # -- Step 4 (Pass 3): Fringe erosion -----------------------------------
    # Remove orphan pixels where 6+ of 8 neighbours are transparent.
    padded_a2 = np.pad(out_a, pad_width=1, mode='constant', constant_values=0)

    transparent_neighbors = np.zeros((h, w), dtype=np.int32)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dy == 0 and dx == 0:
                continue
            transparent_neighbors += (
                padded_a2[1 + dy : 1 + dy + h, 1 + dx : 1 + dx + w] == 0
            ).astype(np.int32)

    fringe_mask = (out_a > 0) & (transparent_neighbors >= 6)
    out_a[fringe_mask] = 0

    pass3_count = int(np.count_nonzero(fringe_mask))
    print(f"  chroma_key pass3: {pass3_count} fringe pixels eroded")

    # -- Assemble output ---------------------------------------------------
    result = np.stack([
        out_r.astype(np.uint8),
        out_g.astype(np.uint8),
        out_b.astype(np.uint8),
        out_a.astype(np.uint8),
    ], axis=-1)

    elapsed = time.perf_counter() - t0
    print(f"  chroma_key total: {elapsed*1000:.1f}ms  ({w}x{h})")

    return Image.fromarray(result, "RGBA")


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.post("/api/remove")
async def remove_bg(request: Request):
    """Remove background and return WebP with transparency."""
    body = await request.body()
    if not body:
        return Response(
            content='{"error": "no image data received"}',
            status_code=400,
            media_type="application/json",
        )
    input_image = Image.open(io.BytesIO(body)).convert("RGBA")
    output = remove(input_image, session=session)

    # Post-process: chroma key cleanup to catch residual magenta fringe
    print("Running chroma key cleanup...")
    output = chroma_key_cleanup(output)

    buf = io.BytesIO()
    output.save(buf, format="WEBP", quality=85)
    buf.seek(0)
    return Response(content=buf.getvalue(), media_type="image/webp")


@app.get("/health")
def health():
    return {"status": "ok"}
