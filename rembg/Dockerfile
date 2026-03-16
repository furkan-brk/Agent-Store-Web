FROM python:3.11-slim
RUN pip install --no-cache-dir "rembg[cpu]"
# Pre-download the model at build time (not at runtime)
RUN python -c "from rembg import new_session; new_session('isnet-general-use')"
EXPOSE 5000
CMD ["rembg", "s", "--host", "0.0.0.0", "--port", "5000", "--model", "isnet-general-use"]
