from __future__ import annotations

import json
import sqlite3
import uuid
from datetime import datetime, timezone
from pathlib import Path

from app.config import MEMORY_DB_PATH


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


class MemoryRepository:
    def __init__(self, db_path: Path = MEMORY_DB_PATH) -> None:
        self.db_path = Path(db_path)
        self.ensure_tables()

    def get_connection(self) -> sqlite3.Connection:
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        connection = sqlite3.connect(self.db_path)
        connection.row_factory = sqlite3.Row
        return connection

    def ensure_tables(self) -> None:
        with self.get_connection() as connection:
            connection.executescript(
                """
                CREATE TABLE IF NOT EXISTS conversation_memory (
                    id TEXT PRIMARY KEY,
                    session_id TEXT NOT NULL,
                    memory_type TEXT NOT NULL,
                    key TEXT NOT NULL,
                    value TEXT NOT NULL,
                    confidence REAL NOT NULL DEFAULT 1.0,
                    source_message_id TEXT,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    metadata TEXT
                );

                CREATE UNIQUE INDEX IF NOT EXISTS idx_conversation_memory_session_key
                    ON conversation_memory(session_id, memory_type, key);

                CREATE INDEX IF NOT EXISTS idx_conversation_memory_session_updated
                    ON conversation_memory(session_id, updated_at);
                """
            )

    def upsert_memory(
        self,
        session_id: str,
        memory_type: str,
        key: str,
        value: str,
        confidence: float = 1.0,
        source_message_id: str | None = None,
        metadata: dict[str, object] | None = None,
    ) -> None:
        now = utc_now()
        metadata_text = json.dumps(metadata or {}, ensure_ascii=False)
        with self.get_connection() as connection:
            existing = connection.execute(
                """
                SELECT id, created_at
                FROM conversation_memory
                WHERE session_id = ? AND memory_type = ? AND key = ?
                """,
                (session_id, memory_type, key),
            ).fetchone()
            if existing:
                connection.execute(
                    """
                    UPDATE conversation_memory
                    SET value = ?, confidence = ?, source_message_id = ?,
                        updated_at = ?, metadata = ?
                    WHERE id = ?
                    """,
                    (
                        value,
                        confidence,
                        source_message_id,
                        now,
                        metadata_text,
                        existing["id"],
                    ),
                )
                return
            connection.execute(
                """
                INSERT INTO conversation_memory(
                    id, session_id, memory_type, key, value, confidence,
                    source_message_id, created_at, updated_at, metadata
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    str(uuid.uuid4()),
                    session_id,
                    memory_type,
                    key,
                    value,
                    confidence,
                    source_message_id,
                    now,
                    now,
                    metadata_text,
                ),
            )

    def list_session_memory(self, session_id: str) -> list[dict[str, object]]:
        with self.get_connection() as connection:
            rows = connection.execute(
                """
                SELECT id, session_id, memory_type, key, value, confidence,
                       source_message_id, created_at, updated_at, metadata
                FROM conversation_memory
                WHERE session_id = ?
                ORDER BY updated_at DESC
                """,
                (session_id,),
            ).fetchall()
        memories = []
        for row in rows:
            item = dict(row)
            try:
                item["metadata"] = json.loads(item.get("metadata") or "{}")
            except json.JSONDecodeError:
                item["metadata"] = {}
            memories.append(item)
        return memories

    def latest_by_key(self, session_id: str) -> dict[str, str]:
        values: dict[str, str] = {}
        for item in self.list_session_memory(session_id):
            key = str(item.get("key") or "")
            value = str(item.get("value") or "").strip()
            if key and value and key not in values:
                values[key] = value
        return values

    def clear_session_memory(self, session_id: str) -> int:
        with self.get_connection() as connection:
            cursor = connection.execute(
                "DELETE FROM conversation_memory WHERE session_id = ?",
                (session_id,),
            )
        return cursor.rowcount

    def clear_all_memory(self) -> None:
        with self.get_connection() as connection:
            connection.execute("DELETE FROM conversation_memory")
