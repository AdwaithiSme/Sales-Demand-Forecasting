# 🚀 Deployment Guide — 100% Free Tier

> **Goal**: Deploy the full-stack app to the internet for **$0/month**.  
> **Date**: 2026-05-28

---

## Deployment Stack (All Free, No Credit Card)

| Component | Platform | Free Tier | Why This? |
|-----------|----------|-----------|-----------|
| **Database** | [Supabase](https://supabase.com) | 500 MB PostgreSQL, 2 projects | Managed Postgres, web dashboard, easy CSV import |
| **Backend** | [Hugging Face Spaces](https://huggingface.co/spaces) | 2 vCPU, 16 GB RAM, Docker | Only free tier with enough RAM for Prophet + sentence-transformers |
| **Frontend** | [Vercel](https://vercel.com) | Unlimited static deploys | One-click React deploys from GitHub |

> ⚠️ **Why not Render?** Render free tier only gives 512 MB RAM. Prophet + sentence-transformers need ~1.5 GB at runtime. Your app would crash on startup. Hugging Face Spaces gives **16 GB RAM** for free — more than enough.

```
                 Internet Users
                      │
          ┌───────────┴───────────┐
          │                       │
    ┌─────▼─────┐          ┌─────▼──────────┐
    │  Vercel   │          │  HuggingFace   │
    │  (React)  │───REST──▶│  Spaces        │
    │  FREE     │          │  (FastAPI+Docker)
    └───────────┘          │  FREE          │
                           └─────┬──────────┘
                                 │
                    ┌────────────┼────────────┐
                    │            │            │
              ┌─────▼─────┐ ┌───▼───┐  ┌────▼────┐
              │ Supabase  │ │ChromaDB│  │ Model   │
              │ PostgreSQL│ │ (local)│  │Registry │
              │ FREE      │ │on disk │  │(on disk)│
              └───────────┘ └───────┘  └─────────┘
```

---

## Table of Contents

1. [Code Changes Required Before Deploying](#1-code-changes-required-before-deploying)
2. [Step 1: Deploy the Database (Supabase)](#2-step-1-deploy-the-database-supabase)
3. [Step 2: Deploy the Backend (Hugging Face Spaces)](#3-step-2-deploy-the-backend-hugging-face-spaces)
4. [Step 3: Deploy the Frontend (Vercel)](#4-step-3-deploy-the-frontend-vercel)
5. [Step 4: Connect Everything Together](#5-step-4-connect-everything-together)
6. [Post-Deployment Verification](#6-post-deployment-verification)
7. [Free Tier Limitations & Workarounds](#7-free-tier-limitations--workarounds)
8. [Production Hardening Checklist](#8-production-hardening-checklist)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Code Changes Required Before Deploying

> ⚠️ **These are MANDATORY** — the app will not work in production without them.

### 1A. 🐛 Fix the LangGraph Breaking Change (CRITICAL)

The `/chat` endpoint is currently broken due to a LangGraph API update.

**File**: `main.py` (around line 764)
```diff
- agent_executor = create_react_agent(llm, tools=langchain_tools, messages_modifier=system_content)
+ agent_executor = create_react_agent(llm, tools=langchain_tools, prompt=system_content)
```

---

### 1B. Backend: Bind to `0.0.0.0` and respect `PORT` env var (CRITICAL)

**File**: `main.py` (line 1271)
```diff
  if __name__ == "__main__":
      import uvicorn
-     uvicorn.run(app, host="127.0.0.1", port=8000)
+     port = int(os.environ.get("PORT", 7860))
+     uvicorn.run(app, host="0.0.0.0", port=port)
```

> HF Spaces expects port **7860** by default.

---

### 1C. Frontend: Replace ALL Hardcoded URLs (CRITICAL)

The frontend has `http://127.0.0.1:8000` and `'secret-token'` hardcoded across **6 files, ~35 occurrences**. Every one must use environment variables.

#### Step 1: Create `sales-dashboard/.env` for local dev
```env
REACT_APP_API_URL=http://127.0.0.1:8000
REACT_APP_API_KEY=your_local_admin_api_key
```

#### Step 2: Update each file

**Files that already have `const API` and `const H` — just change the values:**

`pages/Intelligence.js`, `pages/Orders.js`, `pages/Settings.js`:
```diff
- const API = 'http://127.0.0.1:8000';
- const H = { 'Content-Type': 'application/json', 'X-API-Key': 'secret-token' };
+ const API = process.env.REACT_APP_API_URL || 'http://127.0.0.1:8000';
+ const H = { 'Content-Type': 'application/json', 'X-API-Key': process.env.REACT_APP_API_KEY || 'secret-token' };
```

**Files that use inline URLs — add constants at the top and replace all occurrences:**

`pages/Dashboard.js`, `pages/Chatassistant.js`, `pages/Inventory.js`:
```javascript
// Add after imports:
const API = process.env.REACT_APP_API_URL || 'http://127.0.0.1:8000';
const API_KEY = process.env.REACT_APP_API_KEY || 'secret-token';
```

Then replace every `'http://127.0.0.1:8000/...'` with `` `${API}/...` `` and every `'secret-token'` with `API_KEY`.

**Full list of replacements needed:**

| File | Hardcoded URLs | Hardcoded Keys |
|------|---------------|----------------|
| `Dashboard.js` | Lines 143, 161, 162, 163, 186 | Lines 143, 159, 188 |
| `Chatassistant.js` | Lines 57, 163, 243 | Lines 59, 163, 245 |
| `Inventory.js` | Lines 84, 97 | Lines 84, 99 |
| `Intelligence.js` | Lines 14 (already `const API`) | Line 15 (already `const H`) |
| `Orders.js` | Lines 12 (already `const API`) | Line 13 (already `const H`) |
| `Settings.js` | Lines 9-10 (already `const API`), 22 | Lines 10, 21 |

---

## 2. Step 1: Deploy the Database (Supabase)

### 2.1 Create a Supabase project
1. Go to [supabase.com](https://supabase.com) → **Sign Up** (GitHub login works, no credit card)
2. Click **New Project**
3. **Name**: `sales-forecast`
4. **Region**: Choose the closest to your users
5. Set a **strong database password** — **save it somewhere safe**
6. Click **Create Project** (takes ~2 minutes)

### 2.2 Get your connection details
1. In your project → **Settings** → **Database**
2. Find the **Connection string** section → **URI** tab
3. Copy it. It looks like:
   ```
   postgresql://postgres.[REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres
   ```
4. **Save this** — you'll need it for the backend.

### 2.3 Create required tables
1. Go to **SQL Editor** in your Supabase dashboard
2. Paste and run this SQL:

```sql
-- Training data table (main data source for Prophet models)
CREATE TABLE IF NOT EXISTS training_data (
    date DATE,
    store_nbr INTEGER,
    family VARCHAR(255),
    y FLOAT,
    onpromotion INTEGER DEFAULT 0,
    oil_price FLOAT DEFAULT 90.0
);

-- Historical sales table (used by AI agent's text-to-SQL)
CREATE TABLE IF NOT EXISTS historical_sales (
    date DATE,
    store_id INTEGER,
    family VARCHAR(255),
    sales FLOAT,
    onpromotion INTEGER DEFAULT 0,
    oil_price FLOAT DEFAULT 90.0
);

-- API keys
CREATE TABLE IF NOT EXISTS api_keys (
    id SERIAL PRIMARY KEY,
    key VARCHAR(255) UNIQUE,
    user_id VARCHAR(50)
);

-- Chat history
CREATE TABLE IF NOT EXISTS chat_history (
    id SERIAL PRIMARY KEY,
    session_id VARCHAR(100),
    role VARCHAR(20),
    content TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Purchase orders
CREATE TABLE IF NOT EXISTS purchase_orders (
    id SERIAL PRIMARY KEY,
    tenant_id VARCHAR(50) DEFAULT 'admin_user',
    family VARCHAR(255),
    quantity INTEGER,
    estimated_cost FLOAT,
    status VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_training_store_family ON training_data (store_nbr, family);
CREATE INDEX IF NOT EXISTS idx_historical_store_family ON historical_sales (store_id, family);
```

### 2.4 Import your training data
**Option A — CSV Upload via Supabase Dashboard:**
1. Go to **Table Editor** → select `training_data`
2. Click **Import data** → upload your CSV

**Option B — From your local machine:**
```bash
# Temporarily point your .env at Supabase
# Then run your existing import scripts
set DB_HOST=aws-0-[REGION].pooler.supabase.com
set DB_PORT=6543
set DB_USER=postgres.[REF]
set DB_PASS=[YOUR_PASSWORD]
set DB_NAME=postgres

python train_batch.py
```

---

## 3. Step 2: Deploy the Backend (Hugging Face Spaces)

Hugging Face Spaces lets you run a Docker container with **2 vCPU + 16 GB RAM for free** — the only free platform that can handle Prophet + sentence-transformers comfortably.

### 3.1 Create a Hugging Face account
1. Go to [huggingface.co](https://huggingface.co) → Sign Up (free, no credit card)

### 3.2 Create a new Space
1. Click your profile → **New Space**
2. **Space name**: `sales-forecast-api`
3. **SDK**: Select **Docker**
4. **Visibility**: Public (required for free tier) or Private (if you have a Pro plan)
5. Click **Create Space**

### 3.3 Create a `Dockerfile` in your project root

Create this file at `ProphetBased/Dockerfile`:

```dockerfile
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
```

### 3.4 Create a `start.sh` startup script

Create `ProphetBased/start.sh`:

```bash
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
```

### 3.5 Create a `.dockerignore`

Create `ProphetBased/.dockerignore`:
```
.venv/
.git/
__pycache__/
*.pyc
.env
node_modules/
sales-dashboard/node_modules/
sales-dashboard/build/
v1_archive/
err.log
pip_list.txt
*.png
diagram_*.png
.vscode/
.pyre/
```

### 3.6 Set Secrets (Environment Variables)

In your HF Space → **Settings** → **Repository secrets**, add:

| Secret Name | Value |
|-------------|-------|
| `GITHUB_TOKEN` | Your GitHub PAT (for Azure OpenAI access) |
| `DATABASE_URL` | `postgresql://postgres.[REF]:[PASS]@aws-0-[REGION].pooler.supabase.com:6543/postgres` |
| `DB_HOST` | `aws-0-[REGION].pooler.supabase.com` |
| `DB_USER` | `postgres.[REF]` |
| `DB_PASS` | Your Supabase password |
| `DB_PORT` | `6543` |
| `DB_NAME` | `postgres` |
| `ADMIN_API_KEY` | Generate: `python -c "import secrets; print(secrets.token_hex(32))"` |
| `ALLOWED_ORIGINS` | `https://your-app.vercel.app` (update after frontend deploys) |

### 3.7 Push your code to the Space

```bash
# Add the HF Space as a git remote
git remote add hf https://huggingface.co/spaces/YOUR_USERNAME/sales-forecast-api

# Push your code
git push hf main
```

Or clone the Space repo and copy your files into it:
```bash
git clone https://huggingface.co/spaces/YOUR_USERNAME/sales-forecast-api
# Copy all your backend files into the cloned repo
# Commit and push
```

### 3.8 Wait for the build
- The Docker build takes **5–10 minutes** the first time (Prophet compilation is slow)
- Watch the build logs in the HF Space → **Logs** tab
- Once running, your API will be live at:
  ```
  https://YOUR_USERNAME-sales-forecast-api.hf.space
  ```

### 3.9 Verify
Open in browser:
```
https://YOUR_USERNAME-sales-forecast-api.hf.space/docs
```
You should see the Swagger UI.

---

## 4. Step 3: Deploy the Frontend (Vercel)

### 4.1 Push your code to GitHub
Make sure the full project (including `sales-dashboard/`) is pushed to GitHub.

### 4.2 Create a Vercel project
1. Go to [vercel.com](https://vercel.com) → **Sign Up** (GitHub login, no credit card)
2. Click **Add New** → **Project** → **Import** your GitHub repo
3. Configure:
   - **Root Directory**: Click **Edit** → set to `sales-dashboard`
   - **Framework Preset**: Create React App (auto-detected)
   - **Build Command**: `npm run build` (auto-detected)
   - **Output Directory**: `build` (auto-detected)

### 4.3 Set environment variables
Before clicking Deploy, add environment variables:

| Variable | Value |
|----------|-------|
| `REACT_APP_API_URL` | `https://YOUR_USERNAME-sales-forecast-api.hf.space` |
| `REACT_APP_API_KEY` | Same value as your `ADMIN_API_KEY` |

> ⚠️ Create React App bakes `REACT_APP_*` variables at **build time**. If you change them later, you must **redeploy**.

### 4.4 Deploy
Click **Deploy**. Vercel will build and deploy your React app.  
Your frontend will be live at:
```
https://your-app.vercel.app
```

---

## 5. Step 4: Connect Everything Together

After both frontend and backend are deployed, you need to update CORS:

### 5.1 Update `ALLOWED_ORIGINS` on the backend
Go to your HF Space → **Settings** → **Repository secrets** → update:
```
ALLOWED_ORIGINS=https://your-app.vercel.app
```

If you need multiple origins (e.g., localhost for dev + Vercel for prod):
```
ALLOWED_ORIGINS=http://localhost:3000,https://your-app.vercel.app
```

### 5.2 Restart the HF Space
After updating secrets, click **Restart** in the HF Space settings to apply them.

### 5.3 Test the full flow
1. Open `https://your-app.vercel.app`
2. Dashboard should load and show forecast charts
3. Chat assistant should respond to queries
4. Inventory page should calculate EOQ

---

## 6. Post-Deployment Verification

### Backend API Tests
```bash
# Set your variables
export API="https://YOUR_USERNAME-sales-forecast-api.hf.space"
export KEY="your_admin_api_key"

# 1. Swagger docs
curl $API/docs

# 2. Available categories
curl -H "X-API-Key: $KEY" "$API/available_categories?store_id=1"

# 3. Sales forecast
curl -X POST "$API/predict" \
  -H "X-API-Key: $KEY" \
  -H "Content-Type: application/json" \
  -d '{"store_id": 1, "family": "GROCERY I", "months": 3}'

# 4. Inventory optimization
curl -X POST "$API/inventory" \
  -H "X-API-Key: $KEY" \
  -H "Content-Type: application/json" \
  -d '{"store_id": 1, "family": "GROCERY I", "lead_time_days": 7, "current_stock": 500}'

# 5. AI chat (requires LangGraph fix from Section 1A)
curl -X POST "$API/chat" \
  -H "X-API-Key: $KEY" \
  -H "Content-Type: application/json" \
  -d '{"message": "What is the forecast for Grocery I?", "store_id": 1, "family": "GROCERY I", "current_stock": 100}'
```

### Frontend Checklist
- [ ] Dashboard loads with forecast charts
- [ ] Inventory page shows EOQ & stockout risk
- [ ] Chat assistant sends/receives messages
- [ ] Intelligence center shows anomalies
- [ ] Orders page loads
- [ ] Settings page can test backend connection

---

## 7. Free Tier Limitations & Workarounds

### Hugging Face Spaces (Backend)
| Limitation | Impact | Workaround |
|-----------|--------|------------|
| **Sleeps after ~48h of no traffic** | Cold start takes 30–60s | First request after sleep is slow; this is normal |
| **Ephemeral disk** | `model_registry/` and `chroma_db/` are wiped on restart | The `start.sh` script re-trains models and re-ingests docs on startup |
| **Public by default** | Anyone can see your Space code | API key auth protects endpoints; consider this acceptable for a portfolio project |
| **No custom domain** | URL is `username-spacename.hf.space` | Fine for demo/portfolio; upgrade to Pro for custom domains |

### Supabase (Database)
| Limitation | Impact | Workaround |
|-----------|--------|------------|
| **500 MB storage** | The full `train.csv` is 116 MB — you have room | Only import the store/family combos you need |
| **Pauses after 7 days of inactivity** | Database goes to sleep | Log into Supabase dashboard weekly, or the backend's first query will wake it |
| **2 projects max** | Can only have 2 free databases | Enough for this project |

### Vercel (Frontend)
| Limitation | Impact | Workaround |
|-----------|--------|------------|
| **100 GB bandwidth/month** | More than enough for a demo | Not a concern |
| **Serverless functions limited** | N/A — we use HF Spaces for backend | No impact |

### ⏱️ Expected Cold Start Timeline
When the app hasn't been used for a while:
1. **User visits frontend** → Vercel serves instantly (static files, always fast)
2. **Frontend calls backend** → HF Space wakes up (30–60s)
3. **Backend queries database** → Supabase wakes up (5–10s if paused)
4. **Total first-request time**: ~1–2 minutes (worst case, both sleeping)
5. **Subsequent requests**: Fast (< 2 seconds)

---

## 8. Production Hardening Checklist

### Security
- [ ] Replace all `'secret-token'` hardcoded values in frontend
- [ ] `ADMIN_API_KEY` is a strong 64-char hex string
- [ ] `ALLOWED_ORIGINS` only lists your Vercel domain
- [ ] HF Space secrets are used (not hardcoded in code)
- [ ] `.env` is NOT committed to GitHub
- [ ] `Dockerfile` does NOT copy `.env` (`.dockerignore` excludes it)

### Reliability
- [ ] Add a health check endpoint to `main.py`:
  ```python
  @app.get("/health")
  def health():
      return {"status": "ok"}
  ```
- [ ] `start.sh` handles missing models gracefully (already built in)
- [ ] Frontend shows loading states during cold starts

### Performance
- [ ] Pin exact versions in `requirements.txt` for reproducible Docker builds
- [ ] Consider lazy-loading Prophet (only import when a forecast endpoint is called) to reduce startup memory

---

## 9. Troubleshooting

### "Application error" on HF Spaces
- **Check Logs**: HF Space → **Logs** tab for error details
- **Common cause**: Missing environment secrets. Verify all secrets are set.
- **Memory**: Unlikely with 16 GB RAM, but check if you're loading too many models at once

### CORS errors in browser console
```
Access to fetch has been blocked by CORS policy
```
- **Fix**: Update `ALLOWED_ORIGINS` secret in HF Space to include your Vercel URL exactly (including `https://`)
- **Restart** the HF Space after changing secrets

### "Model not found" (404 on /predict)
- **Cause**: Models haven't been trained yet (ephemeral disk was wiped)
- **Fix**: The `start.sh` script should auto-train on startup. Check HF Logs for training output. If it failed, you may need to ensure the database has data.

### ChromaDB "collection not found"
- **Cause**: `ingest_docs.py` hasn't run yet
- **Fix**: `start.sh` handles this. Make sure `knowledge_base/*.txt` files are included in the Docker image.

### Frontend shows old backend URL after env change
- **Cause**: CRA bakes env vars at build time
- **Fix**: Go to Vercel → **Deployments** → **Redeploy** (not just restart)

### Supabase database is paused
- **Cause**: No queries for 7+ days
- **Fix**: Log into Supabase dashboard → your project → click **Restore**
- **Prevention**: The backend's regular API calls keep it awake

### Docker build fails on HF Spaces
- **Cause**: Usually a missing system dependency for Prophet/psycopg2
- **Fix**: Ensure `build-essential`, `gcc`, `g++`, and `libpq-dev` are in the Dockerfile's builder stage

### `sentence-transformers` download is slow on startup
- **Cause**: Model downloads from HF Hub on every cold start (~90 MB)
- **Fix**: Add `HF_TOKEN` as a secret for faster, authenticated downloads. Or add this to Dockerfile to pre-download:
  ```dockerfile
  RUN python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('all-MiniLM-L6-v2')"
  ```

---

## Quick Reference: All Environment Variables

### Backend (Hugging Face Spaces Secrets)
| Variable | Required | Example |
|----------|----------|---------|
| `GITHUB_TOKEN` | ✅ | `ghp_xxxxxxxxxxxx` |
| `DATABASE_URL` | ✅ | `postgresql://postgres.[REF]:[PASS]@aws-0-[REGION].pooler.supabase.com:6543/postgres` |
| `DB_HOST` | ✅ | `aws-0-[REGION].pooler.supabase.com` |
| `DB_USER` | ✅ | `postgres.[REF]` |
| `DB_PASS` | ✅ | Your Supabase DB password |
| `DB_PORT` | ✅ | `6543` |
| `DB_NAME` | ✅ | `postgres` |
| `ADMIN_API_KEY` | ✅ | 64-char hex string |
| `ALLOWED_ORIGINS` | ✅ | `https://your-app.vercel.app` |
| `HF_TOKEN` | Optional | `hf_xxxxxxxxxxxx` |

### Frontend (Vercel Environment Variables)
| Variable | Required | Example |
|----------|----------|---------|
| `REACT_APP_API_URL` | ✅ | `https://username-sales-forecast-api.hf.space` |
| `REACT_APP_API_KEY` | ✅ | Same as `ADMIN_API_KEY` |

---

## Files to Create Before Deploying

| File | Location | Purpose |
|------|----------|---------|
| `Dockerfile` | Project root | Docker config for HF Spaces |
| `start.sh` | Project root | Startup script (train + ingest + serve) |
| `.dockerignore` | Project root | Exclude unnecessary files from Docker image |
| `sales-dashboard/.env` | Frontend root | Local dev env vars (gitignored) |
