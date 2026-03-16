FROM python:3.11-slim

RUN pip install --no-cache-dir "rembg[cpu]" fastapi uvicorn pillow

# Pre-download the model at build time
RUN python -c "from rembg import new_session; new_session('isnet-general-use')"

COPY server.py /app/server.py
WORKDIR /app
EXPOSE 5000

CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "5000"]
