from __future__ import annotations

import json
import uuid
from datetime import datetime, timezone

from app.database import get_connection


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def make_title(question: str) -> str:
    title = " ".join(str(question or "").strip().split())
    if not title:
        return "Cuộc trò chuyện mới"
    return title[:40] + ("..." if len(title) > 40 else "")


class ChatHistoryRepository:
    def create_session(self, title: str | None = None) -> dict[str, object]:
        session_id = str(uuid.uuid4())
        now = utc_now()
        with get_connection() as connection:
            connection.execute(
                """
                INSERT INTO chat_sessions(id, title, created_at, updated_at)
                VALUES (?, ?, ?, ?)
                """,
                (session_id, title or "Cuộc trò chuyện mới", now, now),
            )
        return {"id": session_id, "title": title or "Cuộc trò chuyện mới", "created_at": now, "updated_at": now}

    def ensure_session(self, session_id: str | None, first_question: str = "") -> str:
        if session_id and self.get_session(session_id):
            return session_id
        return str(self.create_session(make_title(first_question))["id"])

    def get_session(self, session_id: str) -> dict[str, object] | None:
        with get_connection() as connection:
            row = connection.execute(
                "SELECT id, title, created_at, updated_at FROM chat_sessions WHERE id = ?",
                (session_id,),
            ).fetchone()
        return dict(row) if row else None

    def list_sessions(self) -> list[dict[str, object]]:
        with get_connection() as connection:
            rows = connection.execute(
                """
                SELECT id, title, created_at, updated_at
                FROM chat_sessions
                ORDER BY updated_at DESC
                """
            ).fetchall()
        return [dict(row) for row in rows]

    def add_message(
        self,
        session_id: str,
        role: str,
        content: str,
        metadata: dict[str, object] | None = None,
    ) -> dict[str, object]:
        message_id = str(uuid.uuid4())
        now = utc_now()
        metadata_text = json.dumps(metadata or {}, ensure_ascii=False)
        with get_connection() as connection:
            connection.execute(
                """
                INSERT INTO chat_messages(id, session_id, role, content, created_at, metadata)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (message_id, session_id, role, content, now, metadata_text),
            )
            connection.execute(
                "UPDATE chat_sessions SET updated_at = ? WHERE id = ?",
                (now, session_id),
            )
        return {
            "id": message_id,
            "session_id": session_id,
            "role": role,
            "content": content,
            "created_at": now,
            "metadata": metadata or {},
        }

    def get_messages(self, session_id: str) -> list[dict[str, object]]:
        with get_connection() as connection:
            rows = connection.execute(
                """
                SELECT id, session_id, role, content, created_at, metadata
                FROM chat_messages
                WHERE session_id = ?
                ORDER BY created_at ASC
                """,
                (session_id,),
            ).fetchall()
        messages = []
        for row in rows:
            item = dict(row)
            try:
                item["metadata"] = json.loads(item.get("metadata") or "{}")
            except json.JSONDecodeError:
                item["metadata"] = {}
            messages.append(item)
        return messages

    def update_title_from_question(self, session_id: str, question: str) -> None:
        session = self.get_session(session_id)
        if not session or session.get("title") != "Cuộc trò chuyện mới":
            return
        with get_connection() as connection:
            connection.execute(
                "UPDATE chat_sessions SET title = ?, updated_at = ? WHERE id = ?",
                (make_title(question), utc_now(), session_id),
            )

    def delete_session(self, session_id: str) -> bool:
        with get_connection() as connection:
            cursor = connection.execute("DELETE FROM chat_sessions WHERE id = ?", (session_id,))
        try:
            from app.services.memory_service import MemoryService

            MemoryService().clear_session_memory(session_id)
        except Exception:
            pass
        return cursor.rowcount > 0

    def delete_all_sessions(self) -> None:
        with get_connection() as connection:
            connection.execute("DELETE FROM chat_sessions")
        try:
            from app.services.memory_service import MemoryService

            MemoryService().clear_all_memory()
        except Exception:
            pass
