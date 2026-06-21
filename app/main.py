from __future__ import annotations

import json
import logging
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

import demo_terminal_qa as qa
from app.config import HOST, PORT, STATIC_DIR
from app.database import ensure_database
from app.repositories.chat_history_repo import ChatHistoryRepository
from app.services.chat_service import ChatService
from app.services.memory_service import MemoryService
from app.services.mcp_service import MCPService


logger = logging.getLogger(__name__)
CHAT_ENDPOINTS = {"/api/chat", "/chat", "/ask"}


class AppHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(STATIC_DIR), **kwargs)

    def do_GET(self) -> None:
        path = urlparse(self.path).path
        if path == "/":
            self.path = "/chatbot.html"
            return super().do_GET()
        if path == "/favicon.ico":
            self.send_response(204)
            self.end_headers()
            return
        if path == "/api/sessions":
            return self.send_json(ChatHistoryRepository().list_sessions())
        if path.startswith("/api/sessions/") and path.endswith("/messages"):
            parts = path.strip("/").split("/")
            if len(parts) == 4:
                return self.send_json(ChatHistoryRepository().get_messages(parts[2]))
        if path.startswith("/api/sessions/") and path.endswith("/memory"):
            parts = path.strip("/").split("/")
            if len(parts) == 4:
                return self.send_json(MemoryService().get_session_memory(parts[2]))
        if path == "/api/mcp/status":
            return self.send_json(MCPService().status())
        if path == "/api/memory/status":
            return self.send_json(MemoryService().status())
        return super().do_GET()

    def do_POST(self) -> None:
        path = urlparse(self.path).path
        try:
            if path == "/api/sessions":
                payload = self.read_json()
                title = str(payload.get("title", "")).strip() or None
                return self.send_json(ChatHistoryRepository().create_session(title), status=201)
            if path in CHAT_ENDPOINTS:
                payload = self.read_json()
                question = str(payload.get("question", "")).strip()
                session_id = str(payload.get("session_id", "")).strip() or None
                model = str(payload.get("model", "")).strip() or qa.OLLAMA_MODEL
                if not question:
                    return self.send_json({"error": "Câu hỏi đang trống."}, status=400)
                result = ChatService().ask(question, model=model, session_id=session_id)
                return self.send_json(
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
            return self.send_json({"error": "Not found"}, status=404)
        except Exception as exc:
            logger.exception("POST failed: %s", exc)
            return self.send_json({"error": str(exc)}, status=500)

    def do_DELETE(self) -> None:
        path = urlparse(self.path).path
        repo = ChatHistoryRepository()
        try:
            if path == "/api/sessions":
                repo.delete_all_sessions()
                MemoryService().clear_all_memory()
                return self.send_json({"ok": True})
            if path.startswith("/api/sessions/"):
                parts = path.strip("/").split("/")
                if len(parts) == 4 and parts[3] == "memory":
                    MemoryService().clear_session_memory(parts[2])
                    return self.send_json({"ok": True})
                if len(parts) == 3:
                    deleted = repo.delete_session(parts[2])
                    MemoryService().clear_session_memory(parts[2])
                    return self.send_json({"ok": deleted})
            return self.send_json({"error": "Not found"}, status=404)
        except Exception as exc:
            logger.exception("DELETE failed: %s", exc)
            return self.send_json({"error": str(exc)}, status=500)

    def read_json(self) -> dict[str, object]:
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length).decode("utf-8")
        return json.loads(raw or "{}")

    def send_json(self, payload: object, status: int = 200) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format: str, *args) -> None:
        print(f"{self.address_string()} - {format % args}")


def run_server(host: str = HOST, port: int = PORT) -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    qa.configure_console()
    ensure_database()
    try:
        qa.ensure_ollama_model()
        print(f"Dùng Ollama model mặc định: {qa.OLLAMA_MODEL}")
    except Exception as exc:
        print(f"Cảnh báo: chưa kiểm tra được Ollama model {qa.OLLAMA_MODEL}: {exc}")
    server = ThreadingHTTPServer((host, port), AppHandler)
    print(f"Chatbot server đang chạy: http://{host}:{port}/chatbot.html")
    server.serve_forever()


if __name__ == "__main__":
    run_server()
