from fastapi import FastAPI, Request, Response
from rembg import remove, new_session
from PIL import Image
import io

app = FastAPI()
session = new_session("isnet-general-use")


@app.post("/api/remove")
async def remove_bg(request: Request):
    """Remove background and return WebP with transparency."""
    body = await request.body()
    input_image = Image.open(io.BytesIO(body)).convert("RGBA")
    output = remove(input_image, session=session)

    buf = io.BytesIO()
    output.save(buf, format="WEBP", quality=85)
    buf.seek(0)
    return Response(content=buf.getvalue(), media_type="image/webp")


@app.get("/health")
def health():
    return {"status": "ok"}
