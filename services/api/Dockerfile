FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    CROP_SAATHI_DB=/app/data/crop_saathi.db \
    CROP_SAATHI_IMAGE_DIR=/app/data/images

WORKDIR /app
COPY pyproject.toml ./
COPY app ./app
RUN pip install --no-cache-dir .

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
