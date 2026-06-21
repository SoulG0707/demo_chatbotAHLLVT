from __future__ import annotations

import logging
import re
import sys
from pathlib import Path

from app import legacy_backend
from app.config import CHATBOT_ENABLE_MEMORY, DB_PATH, MEMORI_DIR
from app.repositories.memory_repo import MemoryRepository
from app.utils.extract_utils import extract_decision_number
from app.utils.text_utils import detect_question_intent


logger = logging.getLogger(__name__)


class MemoryService:
    def __init__(self, memori_dir: Path = MEMORI_DIR) -> None:
        self.enabled = CHATBOT_ENABLE_MEMORY
        self.memori_dir = Path(memori_dir)
        self.repo = MemoryRepository()
        self._memori_checked = False
        self._memori_available = False
        self._memori_mode = "fallback"
        self._memori_error: str | None = None
        self._memori_reason = ""
        self._memori_suggestion: str | None = None

    def is_available(self) -> bool:
        if not self.enabled:
            return False
        try:
            self.repo.ensure_tables()
            return True
        except Exception as exc:
            logger.exception("Memory database is not available: %s", exc)
            return False

    def memori_sdk_status(self) -> dict[str, object]:
        if not self._memori_checked:
            self._probe_memori_sdk()
        return {
            "available": self._memori_available,
            "mode": self._memori_mode,
            "error": self._memori_error,
            "reason": self._memori_reason,
            "suggestion": self._memori_suggestion,
            "path": str(self.memori_dir),
        }

    def load_memory_context(self, session_id: str, question: str) -> str:
        if not self.is_available():
            return ""
        try:
            values = self.repo.latest_by_key(session_id)
            if not values:
                return ""
            lines = ["[TRÍ NHỚ HỘI THOẠI]"]
            if values.get("current_person"):
                lines.append(f"Người đang được hỏi gần nhất: {values['current_person']}")
            topic = values.get("current_topic") or values.get("topic")
            if topic:
                lines.append(f"Chủ đề gần nhất: {topic}")
            record_number = values.get("current_file_number") or values.get("file_number") or values.get("record_number")
            if record_number:
                lines.append(f"Số hồ sơ liên quan: {record_number}")
            decision_number = values.get("current_decision_number") or values.get("decision_number")
            if decision_number:
                lines.append(f"Số quyết định liên quan: {decision_number}")
            last_decision_number = values.get("last_decision_number")
            if last_decision_number and last_decision_number != decision_number:
                lines.append(f"Số quyết định câu hỏi gần nhất: {last_decision_number}")
            if values.get("decision_date"):
                lines.append(f"Ngày quyết định liên quan: {values['decision_date']}")
            if values.get("last_user_intent"):
                lines.append(f"Ý định câu hỏi gần nhất: {values['last_user_intent']}")
            if values.get("last_user_question"):
                lines.append(f"Câu hỏi gần nhất cần giữ ngữ cảnh: {values['last_user_question']}")
            return "\n".join(lines) if len(lines) > 1 else ""
        except Exception as exc:
            logger.exception("load_memory_context failed: %s", exc)
            return ""

    def resolve_question_subject(
        self,
        session_id: str,
        question: str,
        memory_context: str = "",
        history: list[dict[str, object]] | None = None,
    ) -> str:
        asked_name = self._find_known_person_name(question)
        if asked_name:
            return asked_name
        values: dict[str, str] = {}
        if self.is_available():
            try:
                values = self.repo.latest_by_key(session_id)
            except Exception as exc:
                logger.exception("resolve_question_subject failed: %s", exc)
        if values.get("current_person"):
            return values["current_person"]

        context_match = re.search(r"Người đang được hỏi gần nhất:\s*([^\n]+)", memory_context or "")
        if context_match:
            return legacy_backend.compact_text(context_match.group(1))

        for message in reversed(history or []):
            if message.get("role") != "user":
                continue
            content = str(message.get("content") or "")
            name = self._find_known_person_name(content)
            if name:
                return name
        return ""

    def resolve_question_file_number(
        self,
        session_id: str,
        question: str,
        memory_context: str = "",
    ) -> str:
        record_number = self.extract_question_file_number(question)
        if record_number:
            return record_number
        values: dict[str, str] = {}
        if self.is_available():
            try:
                values = self.repo.latest_by_key(session_id)
            except Exception as exc:
                logger.exception("resolve_question_file_number failed: %s", exc)
        record_number = values.get("current_file_number") or values.get("file_number") or values.get("record_number") or ""
        if record_number:
            return record_number
        context_match = re.search(r"Số hồ sơ liên quan:\s*([^\n]+)", memory_context or "")
        return legacy_backend.compact_text(context_match.group(1)) if context_match else ""

    def extract_question_file_number(self, question: str) -> str:
        record_number = self._extract_record_number(question)
        if record_number:
            return record_number
        terms = legacy_backend.extract_record_terms(question)
        return terms[0] if terms else ""

    def get_last_user_question(self, session_id: str, history: list[dict[str, object]] | None = None) -> str:
        values: dict[str, str] = {}
        if self.is_available():
            try:
                values = self.repo.latest_by_key(session_id)
            except Exception as exc:
                logger.exception("get_last_user_question failed: %s", exc)
        memory_question = str(values.get("last_user_question") or "").strip()
        if memory_question:
            return memory_question
        for message in reversed(history or []):
            if message.get("role") != "user":
                continue
            content = legacy_backend.compact_text(message.get("content"))
            if content and detect_question_intent(content) != "context_correction":
                return content
        return ""

    def get_last_user_intent(self, session_id: str, history: list[dict[str, object]] | None = None) -> str:
        values: dict[str, str] = {}
        if self.is_available():
            try:
                values = self.repo.latest_by_key(session_id)
            except Exception as exc:
                logger.exception("get_last_user_intent failed: %s", exc)
        memory_intent = str(values.get("last_user_intent") or "").strip()
        if memory_intent:
            return memory_intent
        question = self.get_last_user_question(session_id, history)
        return detect_question_intent(question) if question else ""

    def get_last_decision_number(self, session_id: str) -> str:
        values: dict[str, str] = {}
        if self.is_available():
            try:
                values = self.repo.latest_by_key(session_id)
            except Exception as exc:
                logger.exception("get_last_decision_number failed: %s", exc)
        return str(
            values.get("last_decision_number")
            or values.get("current_decision_number")
            or values.get("decision_number")
            or ""
        ).strip()

    def get_last_file_number(self, session_id: str) -> str:
        values: dict[str, str] = {}
        if self.is_available():
            try:
                values = self.repo.latest_by_key(session_id)
            except Exception as exc:
                logger.exception("get_last_file_number failed: %s", exc)
        return str(
            values.get("last_file_number")
            or values.get("current_file_number")
            or values.get("file_number")
            or values.get("record_number")
            or ""
        ).strip()

    def resolve_question_for_search(
        self,
        session_id: str,
        question: str,
        intent: str | None = None,
        subject: str | None = None,
        history: list[dict[str, object]] | None = None,
    ) -> str:
        if not self.is_available():
            return question
        try:
            values = self.repo.latest_by_key(session_id)
        except Exception as exc:
            logger.exception("resolve_question_for_search failed: %s", exc)
            return question
        if not values:
            return question

        intent = intent or detect_question_intent(question)
        subject = subject or self.resolve_question_subject(session_id, question, history=history)
        normalized = legacy_backend.normalize_for_search(question)
        has_known_anchor = any(
            legacy_backend.normalize_for_search(value) in normalized
            for key, value in values.items()
            if key in {"current_person", "record_number", "file_number", "decision_number"} and value
        )
        if has_known_anchor:
            return question

        follow_up_markers = [
            "ai la nguoi nhan",
            "nguoi nhan",
            "ho la ai",
            "la ai",
            "bao nhieu",
            "so tien",
            "quyet dinh nao",
            "quyet dinh so may",
            "ho so nao",
            "so ho so",
            "duoc huong",
            "da huong",
            "da chi",
            "chenh lech",
            "con lai",
        ]
        is_follow_up = (
            intent != "general"
            or len(normalized.split()) <= 8
            or any(marker in normalized for marker in follow_up_markers)
        )
        if not is_follow_up:
            return question

        additions = []
        if subject:
            additions.append(f"liên quan đến {subject}")
        elif values.get("current_person"):
            additions.append(f"liên quan đến {values['current_person']}")
        record_number = values.get("current_file_number") or values.get("file_number") or values.get("record_number")
        if record_number:
            additions.append(f"hồ sơ {record_number}")
        decision_number = values.get("current_decision_number") or values.get("decision_number")
        if decision_number:
            additions.append(f"quyết định {decision_number}")
        topic = values.get("current_topic") or values.get("topic")
        if topic and legacy_backend.normalize_for_search(topic) not in normalized:
            additions.append(topic)
        if intent in {"receiver", "total_amount", "paid_amount", "remaining_amount", "settlement_status"} and "tro cap" not in normalized:
            additions.append("trợ cấp")
        if not additions:
            return question
        return f"{question} ({'; '.join(additions)})"

    def search_anchor_values(self, session_id: str) -> list[str]:
        if not self.is_available():
            return []
        try:
            values = self.repo.latest_by_key(session_id)
        except Exception as exc:
            logger.exception("search_anchor_values failed: %s", exc)
            return []
        anchors = []
        for key in ("current_person", "current_file_number", "record_number", "file_number", "current_decision_number", "decision_number"):
            value = str(values.get(key) or "").strip()
            if value:
                anchors.append(value)
        return anchors

    def rows_match_anchors(self, rows: list[dict[str, object]], anchors: list[str]) -> bool:
        if not anchors:
            return True
        joined = legacy_backend.normalize_for_search(
            "\n".join(f"{row.get('title', '')}\n{row.get('content', '')}" for row in rows)
        )
        return any(legacy_backend.normalize_for_search(anchor) in joined for anchor in anchors)

    def save_interaction(
        self,
        session_id: str,
        user_message: str,
        assistant_message: str,
        metadata: dict | None = None,
    ) -> None:
        if not self.is_available():
            return
        try:
            candidates = {}
            if metadata and isinstance(metadata.get("memory"), dict):
                candidates.update(metadata["memory"])
            extracted = self.extract_memory_candidates(user_message, assistant_message)
            for key, value in extracted.items():
                candidates.setdefault(key, value)
            if not candidates:
                return
            for key, value in candidates.items():
                if value in (None, "", []):
                    continue
                if isinstance(value, list):
                    value_text = ", ".join(str(item).strip() for item in value if str(item).strip())
                else:
                    value_text = str(value).strip()
                if not value_text:
                    continue
                self.repo.upsert_memory(
                    session_id=session_id,
                    memory_type="conversation_context",
                    key=key,
                    value=value_text,
                    confidence=0.9,
                    metadata=metadata or {},
                )
        except Exception as exc:
            logger.exception("save_interaction failed: %s", exc)

    def extract_memory_candidates(self, user_message: str, assistant_message: str) -> dict:
        combined = f"{user_message}\n{assistant_message}"
        candidates: dict[str, object] = {}

        asked_name = self._find_known_person_name(user_message)
        answer_names = self._find_known_person_names(assistant_message)
        if asked_name:
            candidates["current_person"] = asked_name
        if answer_names:
            candidates["related_entities"] = answer_names[:5]

        record_number = self._extract_record_number(combined)
        if record_number:
            candidates["record_number"] = record_number
            candidates["file_number"] = record_number
            candidates["current_file_number"] = record_number

        decision_number = extract_decision_number(combined)
        if decision_number:
            candidates["decision_number"] = decision_number
            candidates["current_decision_number"] = decision_number

        decision_date = legacy_backend.extract_issued_date(combined)
        if decision_date:
            candidates["decision_date"] = decision_date

        recipient = self._extract_recipient(combined)
        if recipient:
            candidates["recipient"] = recipient

        topic = self._extract_topic(user_message, assistant_message)
        if topic:
            candidates["topic"] = topic
            candidates["current_topic"] = topic
        return candidates

    def build_memory_snapshot(
        self,
        user_message: str,
        assistant_message: str,
        rows: list[dict[str, object]],
        sources: list[dict[str, object]],
        subject: str = "",
        intent: str = "general",
        decision_number: str = "",
        file_number: str = "",
        result_items: list[object] | None = None,
    ) -> dict[str, object]:
        candidates = self.extract_memory_candidates(user_message, assistant_message)
        if subject:
            candidates["current_person"] = subject
            candidates["last_subject"] = subject
        if file_number:
            candidates["current_file_number"] = file_number
            candidates["file_number"] = file_number
            candidates["last_file_number"] = file_number
        if decision_number:
            candidates["current_decision_number"] = decision_number
            candidates["decision_number"] = decision_number
            candidates["last_decision_number"] = decision_number
        elif candidates.get("decision_number"):
            candidates["last_decision_number"] = candidates["decision_number"]
        candidates["last_user_intent"] = intent
        if user_message and intent != "context_correction":
            candidates["last_user_question"] = user_message
        if result_items:
            candidates["last_result_items"] = [
                item.get("display_name") if isinstance(item, dict) else str(item)
                for item in result_items
            ]
        joined_rows = "\n".join(f"{row.get('title', '')}\n{row.get('content', '')}" for row in rows)
        if joined_rows:
            row_person = self._find_known_person_name(joined_rows)
            if row_person and not candidates.get("current_person"):
                candidates["current_person"] = row_person
            record_number = self._extract_record_number(joined_rows)
            if record_number:
                candidates.setdefault("record_number", record_number)
                candidates.setdefault("file_number", record_number)
                candidates.setdefault("current_file_number", record_number)
            row_decision_number = extract_decision_number(joined_rows)
            if row_decision_number:
                candidates.setdefault("decision_number", row_decision_number)
                candidates.setdefault("current_decision_number", row_decision_number)
                candidates.setdefault("last_decision_number", row_decision_number)
            decision_date = legacy_backend.extract_issued_date(joined_rows)
            if decision_date:
                candidates.setdefault("decision_date", decision_date)

        for source in sources:
            if source.get("record_number"):
                candidates.setdefault("record_number", source["record_number"])
                candidates.setdefault("file_number", source["record_number"])
                candidates.setdefault("current_file_number", source["record_number"])
            if source.get("decision_number"):
                candidates.setdefault("decision_number", source["decision_number"])
                candidates.setdefault("current_decision_number", source["decision_number"])
            if source.get("issued_date"):
                candidates.setdefault("decision_date", source["issued_date"])

        if intent in {"receiver", "total_amount", "paid_amount", "remaining_amount", "settlement_status"}:
            candidates["current_topic"] = "trợ cấp"
            candidates["topic"] = "trợ cấp"
        elif intent == "decision":
            candidates["current_topic"] = "quyết định"
            candidates["topic"] = "quyết định"
        elif intent == "file_number":
            candidates["current_topic"] = "hồ sơ"
            candidates["topic"] = "hồ sơ"
        return candidates

    def clear_session_memory(self, session_id: str) -> None:
        if not self.is_available():
            return
        try:
            self.repo.clear_session_memory(session_id)
        except Exception as exc:
            logger.exception("clear_session_memory failed: %s", exc)

    def get_session_memory(self, session_id: str) -> list[dict[str, object]]:
        if not self.is_available():
            return []
        try:
            return self.repo.list_session_memory(session_id)
        except Exception as exc:
            logger.exception("get_session_memory failed: %s", exc)
            return []

    def clear_all_memory(self) -> None:
        if not self.is_available():
            return
        try:
            self.repo.clear_all_memory()
        except Exception as exc:
            logger.exception("clear_all_memory failed: %s", exc)

    def status(self) -> dict[str, object]:
        memori_sdk = self.memori_sdk_status()
        return {
            "enabled": self.enabled,
            "available": memori_sdk["available"],
            "mode": memori_sdk["mode"],
            "error": memori_sdk["error"],
            "suggestion": memori_sdk["suggestion"],
            "local_memory_available": self.is_available(),
            "memori_sdk": memori_sdk,
        }

    def _probe_memori_sdk(self) -> None:
        self._memori_checked = True
        if not self.memori_dir.exists():
            self._memori_mode = "fallback"
            self._memori_error = f"Không tìm thấy đường dẫn Memori-main: {self.memori_dir}"
            self._memori_reason = "Không tìm thấy thư mục Memori-main."
            self._memori_suggestion = "Kiểm tra lại thư mục Memori-main trong project."
            logger.warning("Memori-main SDK fallback: %s", self._memori_error)
            return
        if str(self.memori_dir) not in sys.path:
            sys.path.insert(0, str(self.memori_dir))
        try:
            import memori  # noqa: F401
        except ModuleNotFoundError as exc:
            missing_module = exc.name or str(exc)
            self._memori_mode = "fallback"
            self._memori_error = str(exc)
            self._memori_reason = f"Thiếu dependency khi import Memori-main: {missing_module}"
            self._memori_suggestion = "Hãy chạy: pip install -r requirements.txt"
            if missing_module == "aiohttp":
                logger.warning(
                    "Memori-main SDK fallback: thiếu dependency aiohttp. "
                    "Hãy chạy: pip install -r requirements.txt"
                )
            else:
                logger.warning(
                    "Memori-main SDK fallback: thiếu dependency %s khi import Memori-main. "
                    "Hãy chạy: pip install -r requirements.txt",
                    missing_module,
                )
            return
        except ImportError as exc:
            self._memori_mode = "fallback"
            self._memori_error = str(exc)
            self._memori_reason = f"Lỗi import Memori-main: {exc}"
            self._memori_suggestion = "Kiểm tra dependency Memori-main và chạy: pip install -r requirements.txt"
            logger.warning("Memori-main SDK fallback: lỗi import Memori-main: %s", exc)
            return
        except Exception as exc:
            self._memori_mode = "fallback"
            self._memori_error = str(exc)
            self._memori_reason = f"Memori-main import lỗi do code/runtime: {exc}"
            self._memori_suggestion = "Xem traceback trong log để sửa lỗi Memori-main."
            logger.exception("Memori-main SDK fallback: import lỗi do code/runtime: %s", exc)
            return
        self._memori_available = True
        self._memori_mode = "memori-main"
        self._memori_error = None
        self._memori_reason = "Memori-main import thành công; chatbot vẫn giữ SQLite memory làm fallback an toàn."
        self._memori_suggestion = None
        logger.info("Memori-main SDK import thành công.")

    def _find_known_person_name(self, text: str) -> str:
        names = self._find_known_person_names(text)
        return names[0] if names else ""

    def _find_known_person_names(self, text: str) -> list[str]:
        normalized = legacy_backend.normalize_for_search(text)
        if not normalized:
            return []
        try:
            import sqlite3

            with sqlite3.connect(DB_PATH) as connection:
                connection.row_factory = sqlite3.Row
                rows = connection.execute(
                    "SELECT full_name FROM persons ORDER BY LENGTH(full_name) DESC"
                ).fetchall()
        except Exception as exc:
            logger.exception("Cannot read known person names from OCR DB: %s", exc)
            return []

        names = []
        for row in rows:
            name = str(row["full_name"] or "").strip()
            if not name:
                continue
            if legacy_backend.normalize_for_search(name) in normalized and name not in names:
                names.append(name)
        return names

    def _extract_recipient(self, text: str) -> str:
        patterns = [
            r"Người nhận trợ cấp là\s+([^.,\n]+)",
            r"Người nhận\s+(?:trợ cấp\s+)?(?:là\s+)?([^.,\n]+)",
            r"Họ và tên:\s*\**\s*([^*\n-]+?)\s*\**\s*-",
        ]
        for pattern in patterns:
            match = re.search(pattern, text, flags=re.IGNORECASE)
            if match:
                value = legacy_backend.compact_text(match.group(1))
                value = re.sub(r"\s+con của.*$", "", value, flags=re.IGNORECASE).strip()
                if value:
                    return value
        return ""

    def _extract_record_number(self, text: str) -> str:
        record_number = legacy_backend.extract_record_number(text)
        if record_number:
            return record_number
        match = re.search(
            r"hồ\s*sơ\s*số\s+([0-9A-ZĐđ./:-]+(?:\s*[:：]\s*\d+)?)",
            text,
            flags=re.IGNORECASE,
        )
        if not match:
            return ""
        value = legacy_backend.compact_text(match.group(1)).strip(".,;")
        value = re.sub(r"\s*[:：]\s*", ": ", value)
        return value if legacy_backend.is_plausible_record_number(value) else ""

    def _extract_topic(self, user_message: str, assistant_message: str) -> str:
        normalized = legacy_backend.normalize_for_search(f"{user_message}\n{assistant_message}")
        topics = []
        if any(marker in normalized for marker in ["tro cap", "so tien", "bao nhieu", "nguoi nhan"]):
            topics.append("trợ cấp")
        if "nguoi nhan" in normalized:
            topics.append("người nhận trợ cấp")
        if any(marker in normalized for marker in ["quyet dinh", "qd"]):
            topics.append("quyết định")
        if any(marker in normalized for marker in ["ho so", "la/"]):
            topics.append("hồ sơ")
        if any(marker in normalized for marker in ["danh hieu", "truy tang", "phong tang"]):
            topics.append("danh hiệu")
        return " và ".join(dict.fromkeys(topics))
