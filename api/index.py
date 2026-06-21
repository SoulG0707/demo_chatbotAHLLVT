from __future__ import annotations

import os
import shutil
import sys
import tempfile
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
TMP_ROOT = Path(tempfile.gettempdir()) / "chatbot_ahllvt"
RUNTIME_DB = TMP_ROOT / "ocr_qa.db"
RUNTIME_MEMORY_DB = TMP_ROOT / "memory.db"
BUNDLED_DB = PROJECT_ROOT / "data" / "ocr_qa.db"
BUNDLED_SQL = PROJECT_ROOT / "data" / "ocr_qa.sql"

if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

os.environ.setdefault("OCR_QA_DB", str(RUNTIME_DB))
os.environ.setdefault("OCR_QA_SQL", str(BUNDLED_SQL))
os.environ.setdefault("CHATBOT_MEMORY_DB", str(RUNTIME_MEMORY_DB))
os.environ.setdefault("CHATBOT_ENABLE_MCP", "0")

from app.database import ensure_database  # noqa: E402
from app.main import AppHandler  # noqa: E402


def _prepare_runtime_files() -> None:
    TMP_ROOT.mkdir(parents=True, exist_ok=True)
    if not RUNTIME_DB.exists() and BUNDLED_DB.exists():
        shutil.copyfile(BUNDLED_DB, RUNTIME_DB)
    ensure_database()


class handler(AppHandler):
    def __init__(self, *args, **kwargs):
        _prepare_runtime_files()
        super().__init__(*args, **kwargs)
