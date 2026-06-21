# Deploy Files For Vercel

## Ket qua phan tich

- Framework frontend: khong dung Next.js, React hay Vite. Ung dung web hien tai la HTML/CSS/JavaScript thuan.
- Entry point frontend goc: `static/chatbot.html`.
- Entry point backend goc: `run.py` -> `app.main.run_server()` -> phuc vu `static/chatbot.html` va cac API JSON.
- Frontend khong import module JavaScript/CSS rieng. Toan bo CSS va JavaScript nam inline trong `chatbot.html`.
- Frontend goi cac API runtime:
  - `GET /api/sessions`
  - `POST /api/sessions`
  - `GET /api/sessions/{session_id}/messages`
  - `DELETE /api/sessions/{session_id}`
  - `DELETE /api/sessions`
  - `GET /api/memory/status`
  - `POST /api/chat`

## File/thu muc duoc dua vao `deploy-vercel/`

- `src/index.html`: ban copy cua `static/chatbot.html`, co them `API_BASE_URL` de frontend co the goi backend rieng khi deploy tren Vercel.
- `scripts/build.mjs`: build script toi thieu, doc `src/index.html`, inject `API_BASE_URL`, ghi ra `public/index.html`.
- `package.json`: khai bao static project va lenh `npm run build`.
- `package-lock.json`: lockfile duoc tao bang `npm install --package-lock-only`.
- `vercel.json`: cau hinh Vercel dung build command `npm run build`, output directory `public`.
- `.env.example`: vi du bien `API_BASE_URL`.
- `.gitignore`: loai tru `node_modules`, `.vercel`, `.env`, log va output build.
- `public/index.html`: output da build tai local de kiem tra; Vercel se tao lai file nay khi chay build.
- `DEPLOY_FILES.md`: tai lieu nay.

## File/thu muc bi loai bo

- `node_modules/`, `.git/`, `.venv/`, `tfenv/`, `__pycache__/`: dependency/cache local, khong deploy len Vercel.
- `.next/`, `dist/`, `build/`: build output neu co, khong thay trong runtime frontend can giu.
- `chatbot_server.err.log`, `chatbot_server.out.log`: log local.
- `docs/`, `README.md`, `markdown_file.md`, `html_file.html`: tai lieu/bao cao, khong can cho runtime frontend.
- `tests/`: unit test backend, khong can trong source frontend deploy.
- `data/ocr_qa.db`, `data/memory.db`, `data/ocr_qa.sql`: database SQLite local. Khong phu hop de frontend static tren Vercel doc truc tiep.
- `app/`, `run.py`, `chatbot_server.py`, `demo_terminal_qa.py`, `requirements.txt`, `requirements-mcp.txt`, `run_mcp.ps1`, `install_mcp_deps.ps1`: backend Python/local scripts, khong phu hop voi static frontend deploy.
- `Adaptive-Graph-of-Thoughts-MCP-server/`: MCP server local, khong can cho frontend Vercel.
- `Memori-main/`: SDK/vendor/test/docs rat lon, backend hien chi probe/fallback; khong can cho frontend Vercel.

## Bien moi truong tren Vercel

- `API_BASE_URL`: URL backend da deploy rieng, vi du `https://chatbot-api.example.com`.
- Co the dung `NEXT_PUBLIC_API_BASE_URL` thay the; build script uu tien `API_BASE_URL`, sau do moi den `NEXT_PUBLIC_API_BASE_URL`.

Neu `API_BASE_URL` de trong, frontend se goi cung origin `/api/...`. Cach nay chi hoat dong neu ban tu bo sung API route/proxy tren Vercel.

## Lenh build va output

- Install command: `npm install`
- Build command: `npm run build`
- Output directory: `public`

Neu deploy tu root repository thay vi chon Root Directory la `deploy-vercel`, root repo da co them:

- `../vercel.json`: ep Vercel install/build trong `deploy-vercel` va output `deploy-vercel/public`.
- `../package.json`: khai bao project Node toi thieu de tranh Vercel tu nhan repo goc la Flask do co `requirements.txt`.

Trong Vercel Project Settings nen dat:

- Framework Preset: `Other`
- Root Directory: `deploy-vercel`
- Install Command: `npm install`
- Build Command: `npm run build`
- Output Directory: `public`

## Canh bao ve backend

Backend hien tai khong nen dua truc tiep vao Vercel static deployment vi:

- Dung Python `http.server` chay dai han thay vi Vercel serverless function.
- Phu thuoc SQLite file local trong `data/`.
- Phu thuoc Ollama local tai `http://127.0.0.1:11434`.
- Co MCP/Memori local va virtual environment `tfenv`.
- Chat history/memory ghi vao file DB local, khong ben vung tren Vercel serverless.

Huong tach de deploy dung:

1. Deploy frontend trong `deploy-vercel/` len Vercel.
2. Deploy backend Python rieng tren VPS, Render, Railway hoac Fly.io.
3. Backend rieng can expose cac endpoint `/api/chat`, `/api/sessions`, `/api/memory/status` nhu hien tai.
4. Backend can bat CORS cho domain Vercel cua frontend.
5. Dat `API_BASE_URL` tren Vercel tro den backend rieng.

## Kiem tra da thuc hien

- Da chay `npm install --package-lock-only` trong `deploy-vercel/`.
- Da chay `npm run build` thanh cong.
- Build sinh `public/index.html`.
