# ── Stage 1: Build ──────────────────────────────────────────────
FROM python:3.11-slim AS builder

# Install system dependencies needed by Prophet (cmdstan) and psycopg2
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    g++ \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2: Runtime ───────────────────────────────────────────
FROM python:3.11-slim

# Install runtime-only system libs
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Copy installed Python packages from builder
COPY --from=builder /install /usr/local

# HF Spaces runs as user 1000 — create the user and workspace
RUN useradd -m -u 1000 appuser
WORKDIR /home/appuser/app

# Copy application code
COPY --chown=appuser:appuser . .

# Create writable directories for runtime data
RUN mkdir -p model_registry chroma_db knowledge_base \
    && chown -R appuser:appuser model_registry chroma_db knowledge_base

USER appuser

# HF Spaces expects port 7860
ENV PORT=7860
EXPOSE 7860

# Startup script: ingest docs + train models (if empty) + start server
COPY --chown=appuser:appuser start.sh .
RUN chmod +x start.sh

CMD ["./start.sh"]
