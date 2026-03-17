FROM python:3.11-slim

WORKDIR /app

# Install Python dependencies (cached until requirements change)
RUN pip install --no-cache-dir "rembg[cpu]" fastapi uvicorn pillow numpy

# Pre-download the ML model at build time (best-effort)
COPY download_model.py /tmp/download_model.py
RUN python /tmp/download_model.py || true && rm -f /tmp/download_model.py

COPY server.py /app/server.py
EXPOSE 5000

CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "5000"]
