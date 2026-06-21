from __future__ import annotations

from app import legacy_backend


class OllamaService:
    def ask(self, question: str, context: str, model: str | None = None) -> str:
        return legacy_backend.call_local_llama(question, context, model)
