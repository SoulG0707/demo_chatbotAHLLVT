from __future__ import annotations

import sqlite3

from app.config import DB_PATH, SQL_PATH


def get_connection() -> sqlite3.Connection:
    connection = sqlite3.connect(DB_PATH)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys = ON")
    return connection


def ensure_database() -> None:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    if not DB_PATH.exists():
        if not SQL_PATH.exists():
            raise FileNotFoundError(f"Không tìm thấy file SQL để tạo database: {SQL_PATH}")
        connection = sqlite3.connect(DB_PATH)
        try:
            connection.executescript(SQL_PATH.read_text(encoding="utf-8"))
            connection.commit()
        finally:
            connection.close()
    ensure_chat_history_tables()


def ensure_chat_history_tables() -> None:
    with get_connection() as connection:
        connection.executescript(
            """
            CREATE TABLE IF NOT EXISTS chat_sessions (
                id TEXT PRIMARY KEY,
                title TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS chat_messages (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                role TEXT NOT NULL,
                content TEXT NOT NULL,
                created_at TEXT NOT NULL,
                metadata TEXT,
                FOREIGN KEY(session_id) REFERENCES chat_sessions(id) ON DELETE CASCADE
            );

            CREATE INDEX IF NOT EXISTS idx_chat_sessions_updated_at
                ON chat_sessions(updated_at);

            CREATE INDEX IF NOT EXISTS idx_chat_messages_session_created
                ON chat_messages(session_id, created_at);
            """
        )
