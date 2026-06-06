# 📋 TODO — Local Deployment Checklist

> **Project**: Sales Forecasting & Inventory Decision System  
> **Date Created**: 2026-05-28  
> **Status**: 🔴 Not Started

---

## 1. Prerequisites

- [ ] **Python 3.10+** installed and on PATH
- [ ] **Node.js 18+** and npm installed
- [ ] **PostgreSQL 14+** installed and running locally
- [ ] **Git** — repository cloned to local machine

---

## 2. Environment & Secrets

- [ ] Copy `.env.example` → `.env`
  ```bash
  cp .env.example .env
  ```
- [ ] Fill in **all** required values in `.env`:
  | Variable | What to set |
  |---|---|
  | `GITHUB_TOKEN` | GitHub PAT with model inference access (Azure-hosted OpenAI) |
  | `DB_USER` | Your local PostgreSQL username (default: `postgres`) |
  | `DB_PASS` | Your local PostgreSQL password |
  | `DB_HOST` | `localhost` |
  | `DB_PORT` | `5432` |
  | `DB_NAME` | `SalesForecast` |
  | `ADMIN_API_KEY` | Generate with: `python -c "import secrets; print(secrets.token_hex(32))"` |
  | `ALLOWED_ORIGINS` | `http://localhost:3000` |
- [ ] Verify `.env` is in `.gitignore` (it is — already configured)

---

## 3. Python Backend Setup

- [ ] Create and activate virtual environment:
  ```bash
  python -m venv .venv
  .venv\Scripts\activate        # Windows
  # source .venv/bin/activate   # macOS/Linux
  ```
- [ ] Install backend dependencies:
  ```bash
  pip install -r requirements.txt
  ```
- [ ] Verify key packages installed:
  ```bash
  python -c "import fastapi, prophet, langchain_openai, chromadb; print('All good ✅')"
  ```

---

## 4. Database Setup

- [ ] Create the PostgreSQL database:
  ```bash
  createdb SalesForecast
  ```
- [ ] Load `train.csv` into the database  
  > ⚠️ `train.csv` (116 MB) is **not in the repo** — you must source it separately  
  > (Kaggle "Store Sales — Time Series Forecasting" dataset)
- [ ] Ensure the `historical_sales` table exists with columns:  
  `date`, `store_id`, `family`, `sales`, `onpromotion`, `oil_price`
- [ ] Ensure the `training_data` table exists (used by `/retrain` endpoint) with columns:  
  `date (as ds)`, `store_nbr`, `family`, `y`, `onpromotion`, `oil_price`
- [ ] Verify DB connection:
  ```bash
  python check_env.py
  ```

---

## 5. RAG Knowledge Base (ChromaDB)

- [ ] Verify `knowledge_base/` folder has source documents:
  - `marketing_brief_beverages.txt`
  - `news_port_strike.txt`
  - `supplier_notice_grocery.txt`
- [ ] Ingest documents into ChromaDB:
  ```bash
  python ingest_docs.py
  ```
- [ ] Confirm `chroma_db/` directory is created and populated
- [ ] Verify ChromaDB loads on startup (look for `✅ Connected to local ChromaDB knowledge base.` in console)

---

## 6. Prophet Model Training

- [ ] Train batch models from database:
  ```bash
  python train_batch.py
  ```
- [ ] Verify `model_registry/` is populated with JSON models.  
  Expected files per store/family combination:
  - `s{store_id}_{FAMILY}.json` (serialized Prophet model)
  - `s{store_id}_{FAMILY}_metrics.json` (MAE, RMSE, MAPE, last_trained)
- [ ] Currently trained models in registry:
  - [x] `s1_AUTOMOTIVE`
  - [x] `s1_BEVERAGES`
  - [x] `s1_GROCERY I`
  - [x] `s1_PRODUCE`

---

## 7. 🐛 Known Bug Fix — LangGraph `create_react_agent` Breaking Change

> **This is a CRITICAL blocker** — the `/chat` endpoint is currently broken.

The error log (`err.log`) shows:
```
TypeError: create_react_agent() got unexpected keyword arguments: {'messages_modifier': ...}
```

**Root Cause**: The `langgraph` package updated its API. The `messages_modifier` parameter was renamed to `prompt` (or `state_modifier`) in newer versions of `langgraph>=0.1.x`.

- [ ] **Fix in `main.py`** (around line 764):
  ```python
  # BEFORE (broken):
  agent_executor = create_react_agent(llm, tools=langchain_tools, messages_modifier=system_content)
  
  # AFTER (fix — use the new parameter name):
  agent_executor = create_react_agent(llm, tools=langchain_tools, prompt=system_content)
  ```
- [ ] Test the `/chat` endpoint after fixing:
  ```bash
  curl -X POST http://localhost:8000/chat \
    -H "X-API-Key: YOUR_KEY" \
    -H "Content-Type: application/json" \
    -d '{"message": "What is the forecast for Grocery I?", "store_id": 1, "family": "GROCERY I", "current_stock": 100}'
  ```

---

## 8. Start the Backend

- [ ] Launch FastAPI server:
  ```bash
  uvicorn main:app --reload --port 8000
  ```
- [ ] Verify startup messages:
  - `✅ Connected to local ChromaDB knowledge base.`
  - No import errors or crashes
- [ ] Verify Swagger docs load at: [http://localhost:8000/docs](http://localhost:8000/docs)

---

## 9. Frontend (React Dashboard) Setup

- [ ] Navigate to the frontend directory:
  ```bash
  cd sales-dashboard
  ```
- [ ] Install npm dependencies:
  ```bash
  npm install
  ```
- [ ] Start the React dev server:
  ```bash
  npm start
  ```
- [ ] Verify the app opens at: [http://localhost:3000](http://localhost:3000)
- [ ] Verify the frontend pages load:
  - [ ] **Dashboard** — forecast charts render
  - [ ] **Inventory** — EOQ & stockout widgets load
  - [ ] **Chat Assistant** — multi-agent chat works (requires bug fix from Step 7)
  - [ ] **Intelligence Center** — anomaly detection loads
  - [ ] **Orders** — order management page loads
  - [ ] **Settings** — settings page loads

---

## 10. API Endpoint Verification

Test each endpoint (replace `YOUR_KEY` with your `ADMIN_API_KEY`):

- [ ] `POST /predict` — Sales forecast
  ```bash
  curl -X POST http://localhost:8000/predict \
    -H "X-API-Key: YOUR_KEY" \
    -H "Content-Type: application/json" \
    -d '{"store_id": 1, "family": "GROCERY I", "months": 3}'
  ```
- [ ] `POST /inventory` — Inventory optimization
  ```bash
  curl -X POST http://localhost:8000/inventory \
    -H "X-API-Key: YOUR_KEY" \
    -H "Content-Type: application/json" \
    -d '{"store_id": 1, "family": "GROCERY I", "lead_time_days": 7, "current_stock": 500}'
  ```
- [ ] `POST /analyze_history` — Anomaly detection
- [ ] `POST /retrain` — Model retraining (requires DB `training_data` table)
- [ ] `POST /chat` — AI chat assistant (requires bug fix)
- [ ] `GET /available_categories` — List store/family combos
- [ ] `GET /docs` — Swagger UI

---

## 11. External API Dependencies

These are called at runtime and require internet access:

- [ ] **YFinance** — Live crude oil prices (`CL=F` ticker)  
  Verify: `python -c "import yfinance as yf; print(yf.Ticker('CL=F').history(period='1d'))"`
- [ ] **Open-Meteo API** — Weather data for Seattle port area  
  Verify: `curl "https://api.open-meteo.com/v1/forecast?latitude=47.6062&longitude=-122.3321&current=temperature_2m"`
- [ ] **GitHub Models (Azure OpenAI)** — LLM inference for chat & text-to-SQL  
  Requires valid `GITHUB_TOKEN` in `.env`

---

## 12. Security Checklist

- [ ] `.env` file is **NOT** committed to git
- [ ] `ADMIN_API_KEY` is a strong random hex string (64 chars recommended)
- [ ] `ALLOWED_ORIGINS` only includes `http://localhost:3000` for local dev
- [ ] API key validation is active on all endpoints (via `verify_api_key` dependency)
- [ ] SQL injection protection is active (family name validator rejects `'";=` characters)

---

## 13. Optional Improvements for Local Dev

- [ ] Add `HF_TOKEN` to `.env` to avoid Hugging Face rate-limit warnings on `sentence-transformers`
- [ ] Pin exact dependency versions in `requirements.txt` for reproducibility
- [ ] Add more documents to `knowledge_base/` for richer RAG responses
- [ ] Train models for additional store/family combinations beyond Store 1
- [ ] Clear `err.log` after resolving the LangGraph bug

---

## 14. Quick-Start Summary (After All Setup)

```bash
# Terminal 1 — Backend
cd ProphetBased
.venv\Scripts\activate
uvicorn main:app --reload --port 8000

# Terminal 2 — Frontend
cd ProphetBased\sales-dashboard
npm start
```

**Backend**: http://localhost:8000  
**Frontend**: http://localhost:3000  
**API Docs**: http://localhost:8000/docs
