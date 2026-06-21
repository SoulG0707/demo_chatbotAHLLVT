from __future__ import annotations

import re

from app import legacy_backend
from app.utils.extract_utils import contains_decision_number, validate_context_matches_file_number


class ContextService:
    def build_context(self, rows: list[dict[str, object]], question: str, file_number: str = "") -> str:
        context = legacy_backend.build_context(rows, question)
        if not rows or not file_number:
            return context

        name = self._extract_person_name(rows)
        decision_number = self._first_metadata(rows, legacy_backend.extract_decision_number)
        decision_date = self._first_metadata(rows, legacy_backend.extract_issued_date)
        source_lines = ["[THÔNG TIN NGUỒN ƯU TIÊN]"]
        source_lines.append(f"Số hồ sơ: {file_number}")
        if name:
            source_lines.append(f"Tên người: {name}")
        if decision_number:
            source_lines.append(f"Số quyết định: {decision_number}")
        if decision_date:
            source_lines.append(f"Ngày quyết định: {decision_date}")
        return "\n".join(source_lines) + "\n\n" + context

    def validate_context_matches_file_number(self, context: str, file_number: str) -> bool:
        if not file_number:
            return True
        return validate_context_matches_file_number(context, file_number)

    def validate_context_matches_decision_number(self, context: str, decision_number: str) -> bool:
        if not decision_number:
            return True
        return contains_decision_number(context, decision_number)

    def build_sources(self, rows: list[dict[str, object]]) -> list[dict[str, object]]:
        sources = []
        for row in rows:
            text = f"{row.get('title', '')}\n{row.get('content', '')}"
            sources.append(
                {
                    "source_table": row.get("source_table"),
                    "source_id": row.get("source_id"),
                    "page_no": row.get("page_no"),
                    "title": row.get("title"),
                    "record_number": legacy_backend.extract_record_number(text) or "",
                    "decision_number": legacy_backend.extract_decision_number(text) or "",
                    "issued_date": legacy_backend.extract_issued_date(text) or "",
                }
            )
        return sources

    def _extract_person_name(self, rows: list[dict[str, object]]) -> str:
        for row in rows:
            text = f"{row.get('title', '')}\n{row.get('content', '')}"
            for pattern in [
                r"Trợ cấp\s+(?:một|1|01)\s+lần\s+đối\s+với\s+(?:Ông|Bà)?\s*([^;.\n]+)",
                r"Nay\s+trợ\s+cấp\s+cho\s*(?:ông,\s*bà:|Ông\s*\(Bà\)\s*:|Ông|Bà)?\s*([^;.\n-]+)",
                r"Người hưởng:\s*([^\n]+)",
                r"Họ và tên:\s*\**\s*([^*\n-]+?)\s*\**\s*-",
            ]:
                match = re.search(pattern, text, flags=re.IGNORECASE)
                if match:
                    value = legacy_backend.compact_text(match.group(1))
                    value = re.sub(r"^(?:ông|bà)\s+", "", value, flags=re.IGNORECASE).strip(" .,;:*")
                    if value:
                        return value
        return ""

    def _first_metadata(self, rows: list[dict[str, object]], extractor) -> str:
        for row in rows:
            text = f"{row.get('title', '')}\n{row.get('content', '')}"
            value = extractor(text)
            if value:
                return value
        return ""
