# Deploy on Vercel

Use this `vercel` folder as the Vercel project root.

Included runtime files:

- `server.py`: Flask/Vercel Python entrypoint.
- `app/`: chatbot backend logic.
- `public/chatbot.html`: web UI served by Vercel.
- `data/ocr_qa.db` and `data/ocr_qa.sql`: OCR seed data.
- `demo_terminal_qa.py`: legacy helper module used by the backend.
- `vercel.json`, `.python-version`, `requirements.txt`: Vercel configuration.

The function copies `data/ocr_qa.db` into the runtime temp directory before use,
so chat history and memory writes do not modify the bundled database. On Vercel,
that writable temp storage is ephemeral and can reset between cold starts.

Note: local Ollama is not available inside Vercel by default. Deterministic
answers from SQLite can work, but questions that require the LLM need an Ollama
endpoint reachable from the deployment or another hosted model integration.
