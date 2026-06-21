from __future__ import annotations

import logging
import re
import sqlite3
from html import unescape

from app import legacy_backend
from app.config import DB_PATH
from app.utils.extract_utils import (
    contains_decision_number,
    decision_number_variants,
    file_number_variants,
    normalize_decision_number,
    split_file_number,
)


logger = logging.getLogger(__name__)


class OCRRepository:
    def search(self, question: str) -> tuple[str, list[dict[str, object]]]:
        return legacy_backend.search_database(question)

    def search_by_file_number(self, file_number: str, limit: int = 10) -> tuple[str, list[dict[str, object]]]:
        parsed = split_file_number(file_number)
        if not parsed:
            return "", []

        prefix, number = parsed
        variants = file_number_variants(file_number)
        where_parts = []
        params: list[object] = []

        for variant in variants:
            where_parts.append("rp.raw_text LIKE ? COLLATE NOCASE")
            params.append(f"%{variant}%")

        compact_targets = [
            variant.replace(" ", "")
            for variant in variants
            if ":" in variant or "-" in variant
        ]
        for target in compact_targets:
            where_parts.append("REPLACE(rp.raw_text, ' ', '') LIKE ? COLLATE NOCASE")
            params.append(f"%{target}%")

        if number:
            where_parts.append("(rp.raw_text LIKE ? COLLATE NOCASE AND rp.raw_text LIKE ? COLLATE NOCASE)")
            params.extend([f"%{prefix}%", f"%{number}%"])

        if not where_parts:
            return "", []

        sql = f"""
        SELECT
            'raw_pages' AS source_table,
            rp.raw_page_id AS source_id,
            'Trang OCR ' || rp.page_no AS title,
            rp.page_no AS page_no,
            rp.raw_text AS content,
            100 AS score
        FROM raw_pages rp
        WHERE {" OR ".join(where_parts)}
        ORDER BY rp.page_no
        LIMIT ?;
        """
        params.append(limit)

        try:
            with sqlite3.connect(DB_PATH) as connection:
                connection.row_factory = sqlite3.Row
                rows = [
                    {key: row[key] for key in row.keys()}
                    for row in connection.execute(sql, params).fetchall()
                ]
        except Exception as exc:
            logger.exception("search_by_file_number failed for %s: %s", file_number, exc)
            return sql, []

        return sql, rows

    def search_by_decision_number(self, decision_number: str, limit: int = 30) -> tuple[str, list[dict[str, object]]]:
        normalized = normalize_decision_number(decision_number)
        if not normalized:
            return "", []

        sql_label = f"-- exact decision number search: {normalized}"
        rows: list[dict[str, object]] = []
        seen: set[tuple[object, object]] = set()
        try:
            with sqlite3.connect(DB_PATH) as connection:
                connection.row_factory = sqlite3.Row
                self._append_structured_decision_rows(connection, normalized, rows, seen)
                self._append_raw_page_decision_rows(connection, normalized, rows, seen, limit)
        except Exception as exc:
            logger.exception("search_by_decision_number failed for %s: %s", decision_number, exc)
            return sql_label, []
        return sql_label, rows[:limit]

    def get_people_by_decision_number(self, decision_number: str) -> list[dict[str, str]]:
        normalized = normalize_decision_number(decision_number)
        if not normalized:
            return []

        try:
            with sqlite3.connect(DB_PATH) as connection:
                connection.row_factory = sqlite3.Row
                structured_people = self._structured_people_by_decision_number(connection, normalized)
                ocr_people = self._ocr_people_by_decision_number(connection, normalized)
        except Exception as exc:
            logger.exception("get_people_by_decision_number failed for %s: %s", decision_number, exc)
            return []

        people = ocr_people if len(ocr_people) > len(structured_people) else structured_people
        return self._dedupe_people(people)

    def _append_structured_decision_rows(
        self,
        connection: sqlite3.Connection,
        normalized: str,
        rows: list[dict[str, object]],
        seen: set[tuple[object, object]],
    ) -> None:
        decision_ids = self._decision_ids_by_number(connection, normalized)
        if not decision_ids:
            return
        placeholders = ",".join("?" for _ in decision_ids)

        for row in connection.execute(
            f"""
            SELECT
                'decisions' AS source_table,
                d.decision_id AS source_id,
                d.decision_number || ' - ' || d.title AS title,
                rp.page_no AS page_no,
                TRIM(
                    'Số quyết định: ' || COALESCE(d.decision_number, '') || char(10) ||
                    'Tiêu đề: ' || COALESCE(d.title, '') || char(10) ||
                    'Ngày ban hành: ' || COALESCE(d.issued_date, '') || char(10) ||
                    'Loại quyết định: ' || COALESCE(d.decision_kind, '') || char(10) ||
                    'Tóm tắt: ' || COALESCE(d.summary, '')
                ) AS content,
                100 AS score
            FROM decisions d
            LEFT JOIN raw_pages rp ON rp.raw_page_id = d.source_page_id
            WHERE d.decision_id IN ({placeholders})
            ORDER BY d.decision_id
            """,
            decision_ids,
        ):
            self._append_row(rows, seen, row)

        for row in connection.execute(
            f"""
            SELECT
                'honors' AS source_table,
                h.honor_id AS source_id,
                p.full_name || ' - ' || h.honor_title AS title,
                rp.page_no AS page_no,
                TRIM(
                    'Người được phong/truy tặng: ' || COALESCE(p.full_name, '') || char(10) ||
                    'Danh hiệu: ' || COALESCE(h.honor_title, '') || char(10) ||
                    'Hình thức: ' || COALESCE(h.action_type, '') || char(10) ||
                    'Chiến dịch: ' || COALESCE(h.campaign, '') || char(10) ||
                    'Quyết định: ' || COALESCE(d.decision_number, '') || ' - ' || COALESCE(d.title, '') || char(10) ||
                    'Ngày ban hành: ' || COALESCE(d.issued_date, '')
                ) AS content,
                95 AS score
            FROM honors h
            JOIN persons p ON p.person_id = h.honored_person_id
            JOIN decisions d ON d.decision_id = h.decision_id
            LEFT JOIN raw_pages rp ON rp.raw_page_id = d.source_page_id
            WHERE h.decision_id IN ({placeholders})
            ORDER BY h.honor_id
            """,
            decision_ids,
        ):
            self._append_row(rows, seen, row)

    def _append_raw_page_decision_rows(
        self,
        connection: sqlite3.Connection,
        normalized: str,
        rows: list[dict[str, object]],
        seen: set[tuple[object, object]],
        limit: int,
    ) -> None:
        variants = decision_number_variants(normalized)
        where_parts = []
        params: list[object] = []
        for variant in variants:
            where_parts.append("rp.raw_text LIKE ? COLLATE NOCASE")
            params.append(f"%{variant}%")
            compact_variant = variant.replace(" ", "")
            where_parts.append("REPLACE(rp.raw_text, ' ', '') LIKE ? COLLATE NOCASE")
            params.append(f"%{compact_variant}%")
        if not where_parts:
            return
        params.append(max(limit * 3, 30))
        for row in connection.execute(
            f"""
            SELECT
                'raw_pages' AS source_table,
                rp.raw_page_id AS source_id,
                'Trang OCR ' || rp.page_no AS title,
                rp.page_no AS page_no,
                rp.raw_text AS content,
                CASE
                    WHEN rp.raw_text LIKE '%DANH SÁCH%' COLLATE NOCASE THEN 100
                    WHEN rp.raw_text LIKE '%DANH SACH%' COLLATE NOCASE THEN 100
                    ELSE 80
                END AS score
            FROM raw_pages rp
            WHERE {" OR ".join(where_parts)}
            ORDER BY score DESC, rp.page_no
            LIMIT ?;
            """,
            params,
        ):
            if contains_decision_number(row["content"], normalized):
                self._append_row(rows, seen, row)

    def _decision_ids_by_number(self, connection: sqlite3.Connection, normalized: str) -> list[int]:
        decision_ids = []
        for row in connection.execute("SELECT decision_id, decision_number FROM decisions ORDER BY decision_id"):
            if normalize_decision_number(row["decision_number"]) == normalized:
                decision_ids.append(int(row["decision_id"]))
        return decision_ids

    def _structured_people_by_decision_number(
        self,
        connection: sqlite3.Connection,
        normalized: str,
    ) -> list[dict[str, str]]:
        decision_ids = self._decision_ids_by_number(connection, normalized)
        if not decision_ids:
            return []
        placeholders = ",".join("?" for _ in decision_ids)
        people = []
        for row in connection.execute(
            f"""
            SELECT p.full_name, COALESCE(h.honor_title, '') AS honor_title, COALESCE(h.action_type, '') AS action_type
            FROM honors h
            JOIN persons p ON p.person_id = h.honored_person_id
            WHERE h.decision_id IN ({placeholders})
            ORDER BY h.honor_id
            """,
            decision_ids,
        ):
            title = self._display_title(row["action_type"], row["full_name"])
            people.append(
                {
                    "name": str(row["full_name"] or "").strip(),
                    "display_name": title,
                    "honor_title": str(row["honor_title"] or "").strip(),
                }
            )
        return people

    def _ocr_people_by_decision_number(
        self,
        connection: sqlite3.Connection,
        normalized: str,
    ) -> list[dict[str, str]]:
        candidates = []
        for row in connection.execute("SELECT raw_page_id, page_no, raw_text FROM raw_pages ORDER BY page_no"):
            text = str(row["raw_text"] or "")
            normalized_text = legacy_backend.normalize_for_search(text)
            if not contains_decision_number(text, normalized):
                continue
            if not any(marker in normalized_text for marker in ["danh sach", "anh hung luc luong vu trang"]):
                continue
            people = self._extract_people_from_list_text(text)
            if people:
                candidates.append((len(people), int(row["page_no"] or 0), people))
        if not candidates:
            return []
        candidates.sort(key=lambda item: (-item[0], item[1]))
        return candidates[0][2]

    def _extract_people_from_list_text(self, text: str) -> list[dict[str, str]]:
        people = []
        row_matches = re.findall(
            r"<tr>\s*<td[^>]*>\s*(?:\d+|R\s*<br\s*/?>\s*\d+)\)?\s*</td>\s*<td[^>]*>\s*(.*?)\s*</td>\s*</tr>",
            text,
            flags=re.IGNORECASE | re.DOTALL,
        )
        if not row_matches:
            row_matches = re.findall(
                r"(?:^|\n)\s*\d+\)?[.)]?\s+((?:Liệt\s*s[ĩỹy]|Ông|Bà)\s+[^\n]+)",
                text,
                flags=re.IGNORECASE,
            )
        for raw_item in row_matches:
            item = self._html_to_text(raw_item)
            display_name = self._extract_display_name(item)
            if not display_name:
                continue
            detail = self._normalize_list_item(item)
            people.append(
                {
                    "name": self._strip_title(display_name),
                    "display_name": display_name,
                    "detail": detail or display_name,
                    "honor_title": "Anh hùng Lực lượng vũ trang nhân dân",
                }
            )
        return people

    def _append_row(
        self,
        rows: list[dict[str, object]],
        seen: set[tuple[object, object]],
        row: sqlite3.Row,
    ) -> None:
        row_key = (row["source_table"], row["source_id"])
        if row_key in seen:
            return
        seen.add(row_key)
        rows.append({key: row[key] for key in row.keys()})

    def _dedupe_people(self, people: list[dict[str, str]]) -> list[dict[str, str]]:
        deduped = []
        seen = set()
        for person in people:
            key = legacy_backend.normalize_for_search(person.get("name") or person.get("display_name") or "")
            if not key or key in seen:
                continue
            seen.add(key)
            deduped.append(person)
        return deduped

    def _html_to_text(self, value: str) -> str:
        text = re.sub(r"<[^>]+>", " ", value or "")
        text = unescape(text)
        return legacy_backend.compact_text(text).strip(" .,;")

    def _extract_display_name(self, item: str) -> str:
        text = legacy_backend.compact_text(item)
        match = re.match(
            r"((?:Liệt\s*s[ĩỹy]|Ông|Bà)\s+.+?)(?:,\s*(?:nguyên|quê|tỉnh|huyện)|\.|$)",
            text,
            flags=re.IGNORECASE,
        )
        if not match:
            return ""
        display_name = legacy_backend.compact_text(match.group(1)).strip(" .,;")
        display_name = re.sub(r"^Liệt\s*s[ỹy]\b", "Liệt sĩ", display_name, flags=re.IGNORECASE)
        display_name = re.sub(r"^Ong\b", "Ông", display_name, flags=re.IGNORECASE)
        return display_name

    def _normalize_list_item(self, item: str) -> str:
        text = legacy_backend.compact_text(item).strip(" .,;")
        if not text:
            return ""
        text = re.sub(r"^Liệt\s*s[ỹy]\b", "Liệt sĩ", text, flags=re.IGNORECASE)
        text = re.sub(r"\bLợi\s+sỹ\b", "Liệt sĩ", text, flags=re.IGNORECASE)
        text = re.sub(r"^Ong\b", "Ông", text, flags=re.IGNORECASE)
        return text

    def _strip_title(self, display_name: str) -> str:
        return re.sub(r"^(?:Liệt\s*sĩ|Liệt\s*sỹ|Ông|Bà)\s+", "", display_name or "", flags=re.IGNORECASE).strip()

    def _display_title(self, action_type: str, full_name: str) -> str:
        name = str(full_name or "").strip()
        if not name:
            return ""
        if legacy_backend.normalize_for_search(action_type) == "truy_tang":
            return f"Liệt sĩ {name}"
        return name
