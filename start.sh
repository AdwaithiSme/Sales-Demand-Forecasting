#!/bin/bash
set -e

echo "🚀 Starting Sales Forecast API..."

# Ingest RAG documents if ChromaDB is empty
if [ ! -d "chroma_db/chroma.sqlite3" ] && [ -d "knowledge_base" ]; then
    echo "📚 Ingesting knowledge base documents..."
    python ingest_docs.py || echo "⚠️ Ingest failed, continuing..."
fi

# Train models if model_registry is empty
if [ -z "$(ls -A model_registry 2>/dev/null)" ]; then
    echo "🧠 Training Prophet models (first run)..."
    python train_batch.py || echo "⚠️ Training failed, continuing..."
fi

echo "✅ Starting FastAPI server on port ${PORT:-7860}"
exec uvicorn main:app --host 0.0.0.0 --port ${PORT:-7860}
