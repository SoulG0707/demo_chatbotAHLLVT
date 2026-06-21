from __future__ import annotations

import os
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent.parent
APP_DIR = BASE_DIR / "app"
STATIC_DIR = BASE_DIR / "static"
DATA_DIR = BASE_DIR / "data"
DB_PATH = Path(os.environ.get("OCR_QA_DB", DATA_DIR / "ocr_qa.db"))
SQL_PATH = Path(os.environ.get("OCR_QA_SQL", DATA_DIR / "ocr_qa.sql"))
MCP_SERVER_DIR = BASE_DIR / "Adaptive-Graph-of-Thoughts-MCP-server"
MEMORI_DIR = BASE_DIR / "Memori-main"
MEMORY_DB_PATH = Path(os.environ.get("CHATBOT_MEMORY_DB", DATA_DIR / "memory.db"))
CHATBOT_ENABLE_MEMORY = os.environ.get("CHATBOT_ENABLE_MEMORY", "1").lower() in {"1", "true", "yes"}
CHATBOT_ENABLE_MCP = os.environ.get("CHATBOT_ENABLE_MCP", "0").lower() in {"1", "true", "yes"}

HOST = os.environ.get("CHATBOT_HOST", "127.0.0.1")
PORT = int(os.environ.get("CHATBOT_PORT", "8000"))
OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", "llama3:latest")
VIRTUAL_MCP_MODEL = "ollama-mcp:latest"
MCP_BASE_MODEL = os.environ.get("MCP_BASE_MODEL", "llama3:latest")
