from __future__ import annotations

import logging
import os
import shutil
import sys
import tempfile
from pathlib import Path

from flask import Flask, jsonify, request, send_from_directory


PROJECT_ROOT = Path(__file__).resolve().parent
TMP_ROOT = Path(tempfile.gettempdir()) / "chatbot_ahllvt"
RUNTIME_DB = TMP_ROOT / "ocr_qa.db"
RUNTIME_MEMORY_DB = TMP_ROOT / "memory.db"
BUNDLED_DB = PROJECT_ROOT / "data" / "ocr_qa.db"
BUNDLED_SQL = PROJECT_ROOT / "data" / "ocr_qa.sql"
PUBLIC_DIR = PROJECT_ROOT / "public"

if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

os.environ.setdefault("OCR_QA_DB", str(RUNTIME_DB))
os.environ.setdefault("OCR_QA_SQL", str(BUNDLED_SQL))
os.environ.setdefault("CHATBOT_MEMORY_DB", str(RUNTIME_MEMORY_DB))
os.environ.setdefault("CHATBOT_ENABLE_MCP", "0")

import demo_terminal_qa as qa  # noqa: E402
from app.database import ensure_database  # noqa: E402
from app.repositories.chat_history_repo import ChatHistoryRepository  # noqa: E402
from app.services.chat_service import ChatService  # noqa: E402
from app.services.memory_service import MemoryService  # noqa: E402
from app.services.mcp_service import MCPService  # noqa: E402


logger = logging.getLogger(__name__)
CHAT_ENDPOINTS = {"/api/chat", "/chat", "/ask"}

app = Flask(__name__)
app.json.ensure_ascii = False


def _prepare_runtime_files() -> None:
    TMP_ROOT.mkdir(parents=True, exist_ok=True)
    if not RUNTIME_DB.exists() and BUNDLED_DB.exists():
        shutil.copyfile(BUNDLED_DB, RUNTIME_DB)
    ensure_database()


@app.before_request
def before_request() -> None:
    _prepare_runtime_files()


@app.get("/")
@app.get("/chatbot.html")
def chatbot_page():
    return send_from_directory(PUBLIC_DIR, "chatbot.html")


@app.get("/favicon.ico")
def favicon():
    return "", 204


@app.get("/api/sessions")
def list_sessions():
    return jsonify(ChatHistoryRepository().list_sessions())


@app.post("/api/sessions")
def create_session():
    payload = request.get_json(silent=True) or {}
    title = str(payload.get("title", "")).strip() or None
    return jsonify(ChatHistoryRepository().create_session(title)), 201


@app.get("/api/sessions/<session_id>/messages")
def get_session_messages(session_id: str):
    return jsonify(ChatHistoryRepository().get_messages(session_id))


@app.get("/api/sessions/<session_id>/memory")
def get_session_memory(session_id: str):
    return jsonify(MemoryService().get_session_memory(session_id))


@app.delete("/api/sessions/<session_id>/memory")
def delete_session_memory(session_id: str):
    MemoryService().clear_session_memory(session_id)
    return jsonify({"ok": True})


@app.delete("/api/sessions/<session_id>")
def delete_session(session_id: str):
    deleted = ChatHistoryRepository().delete_session(session_id)
    MemoryService().clear_session_memory(session_id)
    return jsonify({"ok": deleted})


@app.delete("/api/sessions")
def delete_all_sessions():
    ChatHistoryRepository().delete_all_sessions()
    MemoryService().clear_all_memory()
    return jsonify({"ok": True})


@app.get("/api/mcp/status")
def mcp_status():
    return jsonify(MCPService().status())


@app.get("/api/memory/status")
def memory_status():
    return jsonify(MemoryService().status())


@app.post("/api/chat")
@app.post("/chat")
@app.post("/ask")
def chat():
    try:
        payload = request.get_json(silent=True) or {}
        question = str(payload.get("question", "")).strip()
        session_id = str(payload.get("session_id", "")).strip() or None
        model = str(payload.get("model", "")).strip() or qa.OLLAMA_MODEL
        if not question:
            return jsonify({"error": "Câu hỏi đang trống."}), 400
        result = ChatService().ask(question, model=model, session_id=session_id)
        return jsonify(
            {
                "answer": result.answer,
                "session_id": result.session_id,
                "sources": result.sources,
                "requested_model": result.requested_model,
                "actual_model": result.actual_model,
                "mode": result.mode,
                "mcp_used": result.mcp_used,
                "tools_used": result.tools_used,
            }
        )
    except Exception as exc:
        logger.exception("chat failed: %s", exc)
        return jsonify({"error": str(exc)}), 500


@app.errorhandler(404)
def not_found(_error):
    return jsonify({"error": "Not found"}), 404
