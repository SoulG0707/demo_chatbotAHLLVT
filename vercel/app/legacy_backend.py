from __future__ import annotations

import json
import os
import re
import sqlite3
import subprocess
import urllib.error
import urllib.request
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

import demo_terminal_qa as qa
from app.prompts import SYSTEM_PROMPT as APP_SYSTEM_PROMPT


ROOT = Path(__file__).resolve().parent.parent
HOST = "127.0.0.1"
PORT = 8000
CHAT_ENDPOINTS = {"/api/chat", "/chat", "/ask"}
FALLBACK_ANSWER = "Hiện chưa có đủ dữ liệu trong hệ thống để trả lời chính xác câu hỏi này."
MAX_SEARCH_ROWS = 10
MAX_CONTEXT_CHARS = 12000
MAX_ROW_CONTEXT_CHARS = 2600
MAX_RAW_EXCERPT_CHARS = 3200
LLAMA_TIMEOUT_SECONDS = 90
LLAMA_KEEP_ALIVE = "30m"
LLAMA_OPTIONS = {
    "temperature": 0.1,
    "top_p": 0.8,
    "num_predict": 900,
}
SYSTEM_PROMPT = """
Bạn là chatbot hỗ trợ tra cứu thông tin về Anh hùng lực lượng vũ trang nhân dân tỉnh Long An.

QUY TẮC BẮT BUỘC:

1. Luôn trả lời hoàn toàn bằng tiếng Việt.
- Nếu tài liệu, ngữ cảnh hoặc kết quả truy xuất có tiếng Anh, hãy dịch sang tiếng Việt tự nhiên.
- Không được trả lời bằng tiếng Anh.
- Chỉ giữ nguyên tên riêng, số hồ sơ, số quyết định, ngày tháng, đơn vị tiền tệ và thuật ngữ pháp lý khi cần.

2. Trả lời như một chatbot hỗ trợ đang trò chuyện với người dùng.
- Không lặp lại câu hỏi của người dùng.
- Không dùng các nhãn như: “Câu hỏi:”, “Trả lời:”, “Lời giải:”, “Đáp án:”, “Dẫn chứng:”, “Lưu ý:”.
- Trả lời ngắn gọn, tự nhiên, đi thẳng vào ý chính.
- Không viết theo kiểu bài giải hoặc văn bản học thuật dài dòng.
- Nếu người dùng hỏi một thông tin cụ thể, chỉ trả lời đúng thông tin đó và căn cứ liên quan.
- Không lặp lại toàn bộ câu trả lời trước đó.
- Không liệt kê lại các khoản tiền nếu câu hỏi chỉ hỏi người nhận.
- Không nêu lại tiểu sử hoặc thông tin tổng hợp nếu người dùng chỉ hỏi một trường dữ liệu cụ thể.
- Nếu hỏi “Ai là người nhận?” thì chỉ trả lời người nhận và căn cứ.
- Nếu hỏi “Tổng trợ cấp bao nhiêu?” thì trả lời tổng trợ cấp và có thể kèm người nhận nếu cần.
- Nếu hỏi “Số hồ sơ là gì?” thì chỉ trả lời số hồ sơ và căn cứ.
- Nếu hỏi “Quyết định số mấy?” thì chỉ trả lời số quyết định, ngày quyết định và căn cứ.
- Nếu người dùng sửa ngữ cảnh, ví dụ “đang hỏi về ... mà”, phải cập nhật chủ thể đang hỏi và trả lời lại câu hỏi gần nhất theo chủ thể mới nếu có.
- Không trả lời thông tin tổng quan khi người dùng chỉ đang sửa ngữ cảnh.
- Không dùng thông tin của người/hồ sơ khác để trả lời nếu câu hỏi đã xác định rõ chủ thể.
- Nếu context tài liệu không khớp với chủ thể người dùng hỏi, phải báo chưa đủ dữ liệu thay vì trả lời sai người.
- Nếu câu hỏi có số hồ sơ cụ thể, phải ưu tiên số hồ sơ đó tuyệt đối.
- Không được dùng người/hồ sơ trong trí nhớ để thay thế số hồ sơ người dùng vừa hỏi.
- Không được lấy dữ liệu từ hồ sơ khác để trả lời câu hỏi có số hồ sơ cụ thể.
- Nếu context không chứa đúng số hồ sơ được hỏi, phải báo chưa đủ dữ liệu.
- Khi trả lời câu hỏi có số hồ sơ, phải nêu rõ “hồ sơ số ...”.
- Nếu người dùng hỏi “ghi đủ ra”, “nói tiếp”, “liệt kê đầy đủ”, “ghi hết ra”, “tiếp đi”, phải hiểu đây là yêu cầu mở rộng câu trả lời trước đó.
- Không được tự chuyển sang hồ sơ hoặc quyết định khác khi xử lý câu hỏi nối tiếp.
- Nếu câu trước đang hỏi về một số quyết định, phải tiếp tục dùng đúng số quyết định đó.
- Nếu câu hỏi có số quyết định cụ thể, phải ưu tiên số quyết định đó tuyệt đối.
- Không được dùng dữ liệu của quyết định khác để trả lời.
- Nếu context không khớp số quyết định được hỏi, phải báo chưa đủ dữ liệu.
- Nếu người dùng đổi cách diễn đạt nhưng cùng ý nghĩa, phải hiểu theo cùng một ý định nghiệp vụ.
- Các câu “còn khoản thu chi nào nữa không”, “còn khoản nào cần chi trả hay thu nữa không”, “đã quyết toán hết chưa”, “còn phải chi trả hoặc thu hồi không” đều là câu hỏi về tình trạng quyết toán/khoản phải chi trả hoặc thu hồi.
- Với nhóm câu hỏi này, chỉ trả lời tình trạng còn khoản chi trả/thu hồi/quyết toán; không trả lời sang danh hiệu, tiểu sử hoặc thông tin tổng quan.

3. Chỉ trả lời dựa trên dữ liệu được cung cấp trong CONTEXT.
- Không tự suy đoán.
- Không bịa thêm thông tin ngoài tài liệu.
- Nếu không đủ dữ liệu để kết luận, hãy trả lời: “Hiện chưa có đủ dữ liệu trong hệ thống để trả lời chính xác câu hỏi này.”

4. Luôn kèm căn cứ trong câu trả lời.
- Nếu CONTEXT có “Số hồ sơ”, bắt buộc phải nêu theo dạng: “theo hồ sơ số ...”.
- Nếu CONTEXT có “Số quyết định” và ngày ban hành, bắt buộc phải nêu theo dạng: “theo Quyết định số ... ngày ...”.
- Không được ghi chung chung như “theo hồ sơ đọc 5”, “theo hồ sơ đọc 9”, “theo tài liệu” nếu có số hồ sơ cụ thể.
- Ưu tiên căn cứ theo thứ tự: số hồ sơ → số quyết định → ngày ban hành → nguồn OCR/trang/tờ.

5. Nếu câu hỏi liên quan đến tiền trợ cấp, phải phân biệt rõ nếu dữ liệu có:
- Tổng số tiền được trợ cấp.
- Khoản đã chi.
- Khoản còn lại.
- Người nhận trợ cấp.
- Thời gian hoặc số tháng được hưởng.

6. Nếu dữ liệu mâu thuẫn hoặc thiếu rõ ràng, không tự chọn đại một kết quả.
Hãy nói rõ dữ liệu hiện chưa thống nhất hoặc chưa đủ rõ, rồi nêu các thông tin đang có.
""".strip()

STOPWORDS = {
    "anh",
    "ai",
    "ba",
    "ba",
    "bao",
    "biet",
    "cac",
    "cho",
    "co",
    "cua",
    "da",
    "dang",
    "dua",
    "duoc",
    "du",
    "duoi",
    "gi",
    "hay",
    "ho",
    "hoi",
    "khong",
    "la",
    "luc",
    "luong",
    "may",
    "mot",
    "nao",
    "neu",
    "noi",
    "ong",
    "qua",
    "quan",
    "so",
    "su",
    "ten",
    "the",
    "theo",
    "thong",
    "tin",
    "tinh",
    "toi",
    "tra",
    "trong",
    "tu",
    "va",
    "ve",
    "vu",
}


def normalize_for_search(value: object) -> str:
    normalized = qa.normalize_text(str(value or ""))
    return re.sub(r"\s*/\s*", "/", normalized)


def compact_text(value: object, limit: int | None = None) -> str:
    text = re.sub(r"\s+", " ", str(value or "")).strip()
    if limit and len(text) > limit:
        return text[: limit - 3].rstrip() + "..."
    return text


def format_vnd(value: object) -> str:
    digits = re.sub(r"\D", "", str(value or ""))
    if not digits:
        return ""
    return f"{int(digits):,}".replace(",", ".") + " đồng"


def format_amount_text(value: str) -> str:
    return format_vnd(value)


def summarize_list_page(content: str) -> str | None:
    people = []
    pattern = re.compile(
        r"Đồng chí:\s*(?P<name>.+?)\s+Sinh năm\s*(?P<birth>\d{4}).*?"
        r"Quê quán:\s*(?P<hometown>.+?)\.\s*"
        r"(?:(?:Nhập ngũ|Tham gia cách mạng):\s*(?P<joined>[^;.\n]+)[;.]?\s*)?"
        r"Đảng viên\s+"
        r"Chức vụ, đơn vị trong kháng chiến chống Mỹ:\s*(?P<role>.+?)(?=(?:\s+\d+\.\s*\d+-\s*Đồng chí:)|$)",
        flags=re.IGNORECASE | re.DOTALL,
    )
    for match in pattern.finditer(content):
        name = compact_text(match.group("name"), 80)
        birth = compact_text(match.group("birth"))
        hometown = compact_text(match.group("hometown"), 120)
        joined = compact_text(match.group("joined") or "", 60)
        role = compact_text(match.group("role"), 180).rstrip(".")
        line = f"{len(people) + 1}. {name}, sinh năm {birth}, quê quán {hometown}"
        if joined:
            line += f", tham gia/nhập ngũ {joined}"
        if role:
            line += f", chức vụ/đơn vị: {role}"
        people.append(line + ".")
    if not people:
        return None
    return "Kết luận danh sách trong hồ sơ: " + " ".join(people)


def extract_keywords(question: str) -> list[str]:
    normalized = normalize_for_search(question)
    tokens = re.findall(r"[\w]+", normalized, flags=re.UNICODE)
    keywords: list[str] = []
    for token in tokens:
        if len(token) < 2 or token in STOPWORDS:
            continue
        if token not in keywords:
            keywords.append(token)
    return keywords[:24]


def extract_record_terms(question: str) -> list[str]:
    terms: list[str] = []
    patterns = [
        r"(?:hồ\s*sơ|ho\s*so|số\s*hồ\s*sơ|so\s*ho\s*so|số|so)\s*(?:số|so)?\s*[:#]?\s*([0-9]{1,4}\s*/\s*[A-Za-zÀ-ỹĐđ.-]+)",
        r"\b([0-9]{1,4}\s*/\s*(?:qđ|qd|ubnd|lđtbxh|ldtbxh|ctn|sldtbxh)[A-Za-zÀ-ỹĐđ./-]*)\b",
        r"\b(LA\s*/\s*[0-9]{1,4})\b",
    ]
    for pattern in patterns:
        for match in re.finditer(pattern, question, flags=re.IGNORECASE):
            value = re.sub(r"\s+", "", match.group(1)).strip(".,;:()[]{}")
            if value and value not in terms:
                terms.append(value)

    normalized = normalize_for_search(question)
    number_match = re.search(r"(?:ho so|so ho so)\s*(?:so)?\s*([0-9]{1,4})\b", normalized)
    if number_match and not terms:
        number = number_match.group(1)
        for value in (number, f"LA/{number}"):
            if value not in terms:
                terms.append(value)
    return terms[:4]


def extract_context_terms(question: str) -> list[str]:
    normalized = normalize_for_search(question)
    tokens = re.findall(r"[\w]+", normalized, flags=re.UNICODE)
    if not tokens:
        return []

    stop_at = {
        "bao",
        "che",
        "do",
        "duoc",
        "huong",
        "la",
        "muc",
        "nguoi",
        "nhieu",
        "so",
        "tien",
        "tro",
        "cap",
    }
    skip = STOPWORDS | {
        "chi",
        "day",
        "du",
        "ke",
        "liet",
        "neu",
        "noi",
        "ro",
        "tiet",
        "va",
        "ve",
    }

    candidates: list[list[str]] = []
    for start_index, token in enumerate(tokens):
        if token in skip or token in stop_at:
            continue
        phrase = []
        for token in tokens[start_index:]:
            if token in stop_at:
                break
            if token in skip:
                if phrase:
                    break
                continue
            phrase.append(token)
            if len(phrase) == 4:
                break
        if len(phrase) >= 2:
            candidates.append(phrase)

    if not candidates:
        return []

    candidates.sort(key=len, reverse=True)
    phrase = " ".join(candidates[0])
    return [phrase]


def is_list_question(question: str) -> bool:
    normalized = normalize_for_search(question)
    return any(marker in normalized for marker in ["danh sach", "anh sach", "liet ke", "neu danh", "04 ca nhan"])


def inspect_schema(conn: sqlite3.Connection) -> dict[str, set[str]]:
    schema: dict[str, set[str]] = {}
    tables = conn.execute(
        "SELECT name FROM sqlite_master WHERE type IN ('table', 'view')"
    ).fetchall()
    for row in tables:
        table = row["name"]
        if table.startswith("sqlite_") or table.startswith("raw_page_fts_"):
            continue
        columns = conn.execute(f"PRAGMA table_info({table})").fetchall()
        schema[table] = {column["name"] for column in columns}
    return schema


def resolve_known_names(conn: sqlite3.Connection, question: str) -> list[str]:
    normalized_question = normalize_for_search(question)
    matches: list[tuple[int, str]] = []
    if "persons" not in inspect_schema(conn):
        return []
    for row in conn.execute("SELECT full_name, COALESCE(alias, '') AS alias FROM persons"):
        variants = [row["full_name"], row["alias"]]
        for variant in variants:
            normalized_variant = normalize_for_search(variant)
            if normalized_variant and normalized_variant in normalized_question:
                matches.append((len(normalized_variant), row["full_name"]))
                break
    matches.sort(reverse=True)
    names = []
    for _, name in matches:
        if name not in names:
            names.append(name)
    return names[:3]


def build_search_sql(
    schema: dict[str, set[str]],
    keywords: list[str],
    limit: int,
    required_terms: list[str] | None = None,
) -> tuple[str, list[object]]:
    select_blocks = []
    if "persons" in schema:
        select_blocks.append(
            """
            SELECT
                'persons' AS source_table,
                p.person_id AS source_id,
                p.full_name AS title,
                NULL AS page_no,
                90 AS priority,
                TRIM(
                    'Họ tên: ' || COALESCE(p.full_name, '') || char(10) ||
                    'Bí danh: ' || COALESCE(p.alias, '') || char(10) ||
                    'Giới tính: ' || COALESCE(p.gender, '') || char(10) ||
                    'Năm sinh: ' || COALESCE(CAST(p.birth_year AS TEXT), '') || char(10) ||
                    'Quê quán: ' || COALESCE(p.hometown, '') || char(10) ||
                    'Nơi ở: ' || COALESCE(p.residence, '') || char(10) ||
                    'Loại hồ sơ: ' || COALESCE(p.person_type, '') || char(10) ||
                    'Ghi chú: ' || COALESCE(p.notes, '')
                ) AS content
            FROM persons p
            """
        )
    if {"decisions", "organizations"}.issubset(schema):
        select_blocks.append(
            """
            SELECT
                'decisions' AS source_table,
                d.decision_id AS source_id,
                d.decision_number || ' - ' || d.title AS title,
                rp.page_no AS page_no,
                80 AS priority,
                TRIM(
                    'Số quyết định: ' || COALESCE(d.decision_number, '') || char(10) ||
                    'Tiêu đề: ' || COALESCE(d.title, '') || char(10) ||
                    'Ngày ban hành: ' || COALESCE(d.issued_date, '') || char(10) ||
                    'Loại quyết định: ' || COALESCE(d.decision_kind, '') || char(10) ||
                    'Cơ quan ban hành: ' || COALESCE(o.organization_name, '') || char(10) ||
                    'Tóm tắt: ' || COALESCE(d.summary, '')
                ) AS content
            FROM decisions d
            LEFT JOIN organizations o ON o.organization_id = d.issuer_org_id
            LEFT JOIN raw_pages rp ON rp.raw_page_id = d.source_page_id
            """
        )
    if {"honors", "persons", "decisions"}.issubset(schema):
        select_blocks.append(
            """
            SELECT
                'honors' AS source_table,
                h.honor_id AS source_id,
                p.full_name || ' - ' || h.honor_title AS title,
                rp.page_no AS page_no,
                95 AS priority,
                TRIM(
                    'Người được phong/truy tặng: ' || COALESCE(p.full_name, '') || char(10) ||
                    'Danh hiệu: ' || COALESCE(h.honor_title, '') || char(10) ||
                    'Hình thức: ' || COALESCE(h.action_type, '') || char(10) ||
                    'Chiến dịch: ' || COALESCE(h.campaign, '') || char(10) ||
                    'Quyết định: ' || COALESCE(d.decision_number, '') || ' - ' || COALESCE(d.title, '') || char(10) ||
                    'Ngày ban hành: ' || COALESCE(d.issued_date, '') || char(10) ||
                    'Ghi chú: ' || COALESCE(h.notes, '')
                ) AS content
            FROM honors h
            JOIN persons p ON p.person_id = h.honored_person_id
            JOIN decisions d ON d.decision_id = h.decision_id
            LEFT JOIN raw_pages rp ON rp.raw_page_id = d.source_page_id
            """
        )
    if {"benefit_cases", "persons", "decisions"}.issubset(schema):
        select_blocks.append(
            """
            SELECT
                'benefit_cases' AS source_table,
                bc.case_id AS source_id,
                pb.full_name || ' - ' || bc.benefit_type AS title,
                rp.page_no AS page_no,
                85 AS priority,
                TRIM(
                    'Người hưởng: ' || COALESCE(pb.full_name, '') || char(10) ||
                    'Người được phong/truy tặng liên quan: ' || COALESCE(ph.full_name, '') || char(10) ||
                    'Loại trợ cấp: ' || COALESCE(bc.benefit_type, '') || char(10) ||
                    'Ngày bắt đầu: ' || COALESCE(bc.start_date, '') || char(10) ||
                    'Mức trợ cấp một lần trước khấu trừ: ' || COALESCE(CAST(bc.one_time_amount AS TEXT), '') || char(10) ||
                    'Trợ cấp hàng tháng: ' || COALESCE(CAST(bc.monthly_amount AS TEXT), '') || char(10) ||
                    'Trạng thái: ' || COALESCE(bc.status, '') || char(10) ||
                    'Quyết định: ' || COALESCE(d.decision_number, '') || ' - ' || COALESCE(d.title, '') || char(10) ||
                    'Ngày ban hành: ' || COALESCE(d.issued_date, '') || char(10) ||
                    'Ghi chú: ' || COALESCE(bc.notes, '')
                ) AS content
            FROM benefit_cases bc
            JOIN persons pb ON pb.person_id = bc.beneficiary_person_id
            LEFT JOIN persons ph ON ph.person_id = bc.honored_person_id
            LEFT JOIN decisions d ON d.decision_id = bc.decision_id
            LEFT JOIN raw_pages rp ON rp.raw_page_id = d.source_page_id
            """
        )
    if {"payment_periods", "benefit_cases", "persons"}.issubset(schema):
        select_blocks.append(
            """
            SELECT
                'payment_periods' AS source_table,
                pp.payment_period_id AS source_id,
                pb.full_name || ' - giai đoạn thanh toán' AS title,
                rp.page_no AS page_no,
                75 AS priority,
                TRIM(
                    'Người hưởng: ' || COALESCE(pb.full_name, '') || char(10) ||
                    'Người được phong/truy tặng liên quan: ' || COALESCE(ph.full_name, '') || char(10) ||
                    'Quyết định: ' || COALESCE(d.decision_number, '') || ' - ' || COALESCE(d.title, '') || char(10) ||
                    'Ngày ban hành: ' || COALESCE(d.issued_date, '') || char(10) ||
                    'Từ ngày: ' || COALESCE(pp.from_date, '') || char(10) ||
                    'Đến ngày: ' || COALESCE(pp.to_date, '') || char(10) ||
                    'Số tháng: ' || COALESCE(CAST(pp.months_count AS TEXT), '') || char(10) ||
                    'Mức hàng tháng: ' || COALESCE(CAST(pp.monthly_amount AS TEXT), '') || char(10) ||
                    'Tổng tiền: ' || COALESCE(CAST(pp.total_amount AS TEXT), '') || char(10) ||
                    'Mô tả: ' || COALESCE(pp.description, '')
                ) AS content
            FROM payment_periods pp
            JOIN benefit_cases bc ON bc.case_id = pp.case_id
            JOIN persons pb ON pb.person_id = bc.beneficiary_person_id
            LEFT JOIN persons ph ON ph.person_id = bc.honored_person_id
            LEFT JOIN decisions d ON d.decision_id = bc.decision_id
            LEFT JOIN raw_pages rp ON rp.raw_page_id = d.source_page_id
            """
        )
    if {"relationships", "persons"}.issubset(schema):
        select_blocks.append(
            """
            SELECT
                'relationships' AS source_table,
                r.relationship_id AS source_id,
                p.full_name || ' - quan hệ thân nhân' AS title,
                NULL AS page_no,
                70 AS priority,
                TRIM(
                    'Người trong hồ sơ: ' || COALESCE(p.full_name, '') || char(10) ||
                    'Quan hệ: ' || COALESCE(r.relation_type, '') || char(10) ||
                    'Người liên quan: ' || COALESCE(pr.full_name, r.related_person_name, '') || char(10) ||
                    'Ghi chú: ' || COALESCE(r.notes, '')
                ) AS content
            FROM relationships r
            JOIN persons p ON p.person_id = r.person_id
            LEFT JOIN persons pr ON pr.person_id = r.related_person_id
            """
        )
    if "raw_pages" in schema:
        select_blocks.append(
            """
            SELECT
                'raw_pages' AS source_table,
                rp.raw_page_id AS source_id,
                'Trang OCR ' || rp.page_no AS title,
                rp.page_no AS page_no,
                40 AS priority,
                rp.raw_text AS content
            FROM raw_pages rp
            """
        )

    if not select_blocks:
        return "SELECT 1 WHERE 0", []

    score_parts = []
    params: list[object] = []
    for keyword in keywords:
        pattern = f"%{keyword}%"
        score_parts.append("CASE WHEN normalize_for_search(title) LIKE ? THEN 8 ELSE 0 END")
        params.append(pattern)
        score_parts.append("CASE WHEN normalize_for_search(content) LIKE ? THEN 2 ELSE 0 END")
        params.append(pattern)

    score_sql = " + ".join(score_parts) if score_parts else "0"
    required_sql = ""
    for term in required_terms or []:
        pattern = f"%{normalize_for_search(term)}%"
        required_sql += " AND (normalize_for_search(title) LIKE ? OR normalize_for_search(content) LIKE ?)"
        params.extend([pattern, pattern])

    sql = f"""
    WITH searchable AS (
        {" UNION ALL ".join(select_blocks)}
    )
    SELECT source_table, source_id, title, page_no, content, score
    FROM (
        SELECT
            source_table,
            source_id,
            title,
            page_no,
            content,
            priority,
            ({score_sql}) AS score
        FROM searchable
    )
    WHERE score > 0
      {required_sql}
    ORDER BY score DESC, priority DESC, source_table, source_id
    LIMIT ?;
    """
    params.append(limit)
    return sql, params


def excerpt_for_keywords(
    text: str,
    keywords: list[str],
    question: str = "",
    limit: int = MAX_RAW_EXCERPT_CHARS,
) -> str:
    compact = compact_text(text)
    normalized = normalize_for_search(compact)
    first_index: int | None = None
    normalized_question = normalize_for_search(question)
    priority_phrases = [
        "so tien con lai",
        "con thuc cap",
        "thuc cap",
        "sau khi tru",
        "muc tro cap",
        "den het thang",
        "truy lanh",
        "tong cong",
        "so tien",
        "chenh lech",
        "truy thu",
    ]
    for phrase in priority_phrases:
        if phrase not in normalized_question:
            continue
        index = normalized.find(phrase)
        if index >= 0:
            first_index = index
            break
    for keyword in keywords:
        if first_index is not None:
            break
        index = normalized.find(keyword)
        if index >= 0 and (first_index is None or index < first_index):
            first_index = index
    if first_index is None or len(compact) <= limit:
        return compact_text(compact, limit)

    start = max(0, first_index - limit // 3)
    end = min(len(compact), start + limit)
    excerpt = compact[start:end].strip()
    if start > 0:
        excerpt = "..." + excerpt
    if end < len(compact):
        excerpt += "..."
    return excerpt


def rerank_rows(
    rows: list[dict[str, object]],
    question: str,
    record_terms: list[str],
) -> list[dict[str, object]]:
    normalized_question = normalize_for_search(question)
    list_question = is_list_question(question)
    amount_question = any(
        marker in normalized_question
        for marker in ["bao nhieu", "so tien", "muc tro cap", "tro cap bao nhieu"]
    )
    list_question = list_question and not amount_question
    phrase_boosts = [
        ("muc tro cap", 40),
        ("den het thang", 40),
        ("so tien tro cap", 40),
        ("huong tro cap", 32),
        ("cat tro cap", 30),
        ("so tien con lai", 30),
        ("con thuc cap", 30),
        ("sau khi tru", 20),
        ("truy thu", 16),
        ("chenh lech", 16),
    ]
    list_phrase_boosts = [
        ("04 ca nhan", 80),
        ("phong tang", 40),
        ("thanh chieu", 36),
        ("kháng chien chong my", 36),
        ("khang chien chong my", 36),
        ("cuu nuoc", 28),
        ("dong chi", 24),
    ]

    def rank(index_and_row: tuple[int, dict[str, object]]) -> tuple[int, int, int]:
        index, row = index_and_row
        text = normalize_for_search(f"{row.get('title', '')} {row.get('content', '')}")
        boost = 0
        for term in record_terms:
            normalized_term = normalize_for_search(term)
            if normalized_term and normalized_term in text:
                boost += 160 if "/" in term else 50
        for phrase, weight in phrase_boosts:
            if phrase in normalized_question and phrase in text:
                boost += weight
        if amount_question and re.search(r"\d{1,3}(?:[.,]\d{3})+|\d{4,}", str(row.get("content", ""))):
            boost += 18
        if amount_question and row.get("source_table") == "raw_pages":
            boost += 10
        if list_question and row.get("source_table") == "raw_pages":
            boost += 45
            for phrase, weight in list_phrase_boosts:
                if phrase in text:
                    boost += weight
        if row.get("source_table") == "raw_pages" and any(
            phrase in normalized_question and phrase in text
            for phrase, _ in phrase_boosts
        ):
            boost += 20
        score = int(row.get("score") or 0)
        return boost, score, -index

    ranked = sorted(enumerate(rows), key=rank, reverse=True)
    return [row for _, row in ranked]


def search_database(question: str, limit: int = MAX_SEARCH_ROWS) -> tuple[str, list[dict[str, object]]]:
    keywords = extract_keywords(question)
    record_terms = extract_record_terms(question)
    context_terms = extract_context_terms(question)
    if not keywords and not record_terms and not context_terms:
        return "", []

    conn = sqlite3.connect(qa.DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.create_function("normalize_for_search", 1, normalize_for_search)
    try:
        schema = inspect_schema(conn)
        sql_parts = []
        rows = []
        seen: set[tuple[object, object]] = set()
        pool_limit = max(limit * 3, 24)

        searches: list[tuple[str, list[str], list[str] | None, int]] = []
        if record_terms:
            searches.append(("record-priority", record_terms + keywords, record_terms, pool_limit))
        elif context_terms and (not is_list_question(question) or is_amount_question(question)):
            searches.append(("context-priority", context_terms + keywords, context_terms, pool_limit))

        for label, search_terms, required_terms, search_limit in searches:
            sql, params = build_search_sql(schema, search_terms, search_limit, required_terms)
            sql_parts.append(f"-- {label}: terms={search_terms}, required={required_terms or []}\n{sql.strip()}")
            for row in conn.execute(sql, params).fetchall():
                row_key = (row["source_table"], row["source_id"])
                if row_key in seen:
                    continue
                seen.add(row_key)
                item = {key: row[key] for key in row.keys()}
                if item.get("source_table") == "raw_pages":
                    item["content"] = excerpt_for_keywords(
                        str(item.get("content") or ""),
                        search_terms,
                        question,
                    )
                else:
                    item["content"] = compact_text(item.get("content"), MAX_ROW_CONTEXT_CHARS)
                rows.append(item)
                if len(rows) >= pool_limit:
                    break
            if len(rows) >= pool_limit:
                break

        if not rows:
            sql, params = build_search_sql(schema, keywords or record_terms or context_terms, pool_limit, None)
            sql_parts.append(f"-- keyword-search: terms={keywords or record_terms or context_terms}, required=[]\n{sql.strip()}")
            for row in conn.execute(sql, params).fetchall():
                row_key = (row["source_table"], row["source_id"])
                if row_key in seen:
                    continue
                seen.add(row_key)
                item = {key: row[key] for key in row.keys()}
                if item.get("source_table") == "raw_pages":
                    item["content"] = excerpt_for_keywords(
                        str(item.get("content") or ""),
                        keywords or record_terms or context_terms,
                        question,
                    )
                else:
                    item["content"] = compact_text(item.get("content"), MAX_ROW_CONTEXT_CHARS)
                rows.append(item)
                if len(rows) >= pool_limit:
                    break

        rows = rerank_rows(rows, question, record_terms)
        return "\n\n".join(sql_parts), rows[:limit]
    finally:
        conn.close()


def build_context(rows: list[dict[str, object]], question: str = "") -> str:
    chunks = []
    used = 0
    source_summary = build_source_summary(rows)
    if source_summary:
        intro = f"[TÓM TẮT NGUỒN]\n{source_summary}."
        chunks.append(intro)
        used += len(intro) + 2
    asked_person = extract_question_person(rows, question)
    normalized_question = normalize_for_search(question)
    asks_amount = any(
        marker in normalized_question
        for marker in ["bao nhieu", "so tien", "muc tro cap", "tro cap bao nhieu"]
    )
    asks_detail = any(
        marker in normalized_question
        for marker in ["liet ke", "chi tiet", "ke ro", "ro", "gom nhung", "nhung khoan"]
    )
    for index, row in enumerate(rows, start=1):
        source = row.get("source_table") or "database"
        source_id = row.get("source_id") or ""
        page_no = row.get("page_no")
        title = compact_text(row.get("title"), 160)
        content = compact_text(row.get("content"), MAX_ROW_CONTEXT_CHARS)
        if is_list_question(question) and row.get("source_table") == "raw_pages":
            list_summary = summarize_list_page(content)
            if list_summary:
                content = f"{list_summary} {content}"
        source_text = f"{title}\n{content}"
        record_number = extract_record_number(source_text)
        normalized_content = normalize_for_search(content)
        beneficiary_name = extract_person_name(content, title)
        related_only_to_asked_person = (
            bool(asked_person)
            and not question_mentions_name(beneficiary_name, asked_person)
            and question_mentions_name(content, asked_person)
            and "nguoi duoc phong/truy tang lien quan" in normalized_content
        )
        if related_only_to_asked_person:
            content = (
                f"Lưu ý quan hệ dữ liệu: đây là hồ sơ của người hưởng {beneficiary_name}; "
                f"{asked_person} chỉ là người được phong/truy tặng liên quan, không phải người bị khấu trừ trong dòng này. "
                f"{content}"
            )
        elif asks_detail and any(marker in normalized_content for marker in ["truy lanh", "tong cong", "tro cap 01 lan", "tro cap mot lan"]):
            amount_lines = []
            structured_period = re.search(
                r"Từ ngày:\s*([0-9-]+).*?Đến ngày:\s*([0-9-]+).*?Số tháng:\s*(\d+).*?Mức hàng tháng:\s*(\d+).*?Tổng tiền:\s*(\d+)",
                content,
                flags=re.IGNORECASE,
            )
            if structured_period:
                date_from, date_to, months, monthly, total = structured_period.groups()
                amount_lines.append(
                    f"Truy lãnh {date_from} đến {date_to}: {months} tháng x {format_amount_text(monthly)} = {format_amount_text(total)}"
                )
            for date_from, date_to, months, monthly, total in re.findall(
                r"(\d{2}/\d{2}/\d{4})\s*đến\s*(\d{2}/\d{2}/\d{4}),\s*(\d+)\s*tháng\s*x\s*([\d.]+)\s*đ\s*=\s*([\d.]+)\s*đồng",
                content,
                flags=re.IGNORECASE,
            ):
                amount_lines.append(
                    f"Truy lãnh {date_from} đến {date_to}: {months} tháng x {format_amount_text(monthly)} = {format_amount_text(total)}"
                )
            one_time_match = re.search(
                r"Trợ cấp\s*(?:01|1|một)\s*lần\s*(?:số tiền)?\s*:?\s*([\d.]+)\s*đồng",
                content,
                flags=re.IGNORECASE,
            )
            total_match = re.search(r"Tổng cộng\s*:?\s*\**\s*([\d.]+)\s*đồng", content, flags=re.IGNORECASE)
            summary_parts = []
            if one_time_match:
                summary_parts.append(f"trợ cấp một lần {format_amount_text(one_time_match.group(1))}")
            summary_parts.extend(amount_lines)
            if total_match:
                summary_parts.append(f"tổng cộng {format_amount_text(total_match.group(1))}")
            if summary_parts:
                content = "Kết luận các khoản tiền trong hồ sơ: " + "; ".join(summary_parts) + ". " + content
        elif "sau khi tru" in normalized_content and "con thuc cap" in normalized_content:
            actual_amount = extract_amount_after_marker(
                content,
                ["con thuc cap", "con lai cap", "so tien con lai", "sau khi tru", "thuc cap"],
            )
            if actual_amount:
                content = (
                    f"Kết luận từ ghi chú hồ sơ: số tiền trợ cấp thực cấp/còn lại là {actual_amount}. "
                    f"Mức trợ cấp một lần trước khấu trừ không phải là số thực cấp cuối cùng. "
                    f"{content}"
                )
        elif asks_amount and any(marker in normalized_content for marker in ["so tien tro cap", "muc tro cap"]):
            amount_match = re.search(
                r"(?:Số tiền trợ cấp|Mức trợ cấp[^:]*Số tiền)\s*:?\s*(\d{1,3}(?:[.,]\d{3})+|\d{4,})",
                content,
                flags=re.IGNORECASE,
            )
            if amount_match:
                content = (
                    f"Kết luận từ đoạn OCR: số tiền trợ cấp là {format_vnd(amount_match.group(1))}. "
                    f"{content}"
                )
        decision_number = extract_decision_number(source_text)
        issued_date = extract_issued_date(source_text)
        source_label = build_source_label(source, source_id, page_no)
        metadata_lines = ["[THÔNG TIN NGUỒN]"]
        if record_number:
            metadata_lines.append(f"Số hồ sơ: {record_number}")
        if decision_number:
            metadata_lines.append(f"Số quyết định: {decision_number}")
        if issued_date:
            metadata_lines.append(f"Ngày ban hành: {issued_date}")
        if source_label:
            metadata_lines.append(f"Nguồn OCR/trang/tờ: {source_label}")
        chunk = (
            "\n".join(metadata_lines) + "\n\n"
            f"[NỘI DUNG LIÊN QUAN]\n"
            f"Tiêu đề: {title}\n"
            f"Nội dung: {content}"
        )
        if used + len(chunk) + 2 > MAX_CONTEXT_CHARS:
            break
        chunks.append(chunk)
        used += len(chunk) + 2
    return "\n\n".join(chunks)


def is_amount_question(question: str) -> bool:
    normalized = normalize_for_search(question)
    return "so tien" in normalized or "bao nhieu" in normalized or "tro cap" in normalized


def extract_amount_after_marker(content: str, markers: list[str]) -> str | None:
    normalized = normalize_for_search(content)
    amount_pattern = re.compile(r"\d{1,3}(?:[.,]\d{3})+|\d{4,}")
    for marker in markers:
        marker_index = normalized.find(marker)
        if marker_index < 0:
            continue
        nearby = content[marker_index : marker_index + 180]
        amounts = amount_pattern.findall(nearby)
        if amounts:
            return format_vnd(amounts[-1])
    return None


def extract_first_labeled_amount(content: str, label: str) -> str | None:
    match = re.search(
        rf"{re.escape(label)}\s*:?\s*(\d{{1,3}}(?:[.,]\d{{3}})+|\d{{4,}})",
        content,
        flags=re.IGNORECASE,
    )
    return format_vnd(match.group(1)) if match else None


def extract_person_name(content: str, title: object) -> str:
    match = re.search(r"Người hưởng:\s*(.*?)\s+Người được", content)
    if match:
        return match.group(1).strip()
    return str(title or "").split(" - ")[0].strip() or "người hưởng"


def question_mentions_name(question: str, name: str | None) -> bool:
    normalized_name = normalize_for_search(name)
    return bool(normalized_name and normalized_name in normalize_for_search(question))


def extract_question_person(rows: list[dict[str, object]], question: str) -> str | None:
    for row in rows:
        if row.get("source_table") != "persons":
            continue
        title = str(row.get("title") or "")
        if question_mentions_name(question, title):
            return title
    return None


def extract_decision_number(content: str) -> str | None:
    number = r"([0-9]{1,5}\s*/\s*(?:QĐ|QD|UBND|LĐTBXH|LDTBXH|SLĐTBXH|SLDTBXH|CTN)[0-9A-ZĐa-zđ./-]*)"
    patterns = (
        rf"(?:Quyết\s*định|Quyet\s*dinh|Q[ĐD])\s*(?:số|so)?\s*[:：]?\s*{number}",
        rf"(?:Số|So)\s*[:：]?\s*{number}",
        rf"\b{number}",
    )
    for pattern in patterns:
        match = re.search(pattern, content, flags=re.IGNORECASE)
        if match:
            value = re.sub(r"\s+", "", match.group(1).strip()).upper()
            value = value.replace("QD-", "QĐ-").replace("/QD", "/QĐ")
            value = value.replace("LDTBXH", "LĐTBXH").replace("SLDTBXH", "SLĐTBXH")
            return value.strip(".,;:()[]{}")
    return None


def extract_record_number(content: str, page_no: object = None) -> str | None:
    file_number = extract_file_number(content)
    if file_number:
        return file_number
    match = re.search(r"Số\s+hồ\s+sơ\s*[:：]?\s*([0-9A-Za-zĐđ./-]+)", content, flags=re.IGNORECASE)
    if match and is_plausible_record_number(match.group(1)):
        return match.group(1).strip()
    return None


def is_plausible_record_number(value: object) -> bool:
    text = compact_text(value)
    return bool(text and re.search(r"\d", text) and not re.fullmatch(r"[.\-_/]+", text))


def extract_file_number(text: str) -> str | None:
    patterns = [
        r"(?:Số\s+hồ\s+sơ|Hồ\s+sơ\s+số|Hồ\s+sơ)?\s*[:：]?\s*\b([A-ZĐ]{1,8}\s*/\s*[A-ZĐ]{1,12})\s*[:：\-]?\s*(\d{1,5})\b",
        r"(?:Số\s+hồ\s+sơ|Hồ\s+sơ\s+số|Hồ\s+sơ)?\s*[:：]?\s*\b([A-ZĐ]{1,8}\s*/\s*\d{1,5})\b",
        r"Số\s+hồ\s+sơ\s*[:：]\s*([A-ZĐ/.\-]+)\s*[:：]\s*(\d+)",
        r"Số\s+hồ\s+sơ\s*[:：]\s*([A-ZĐ/.\-]+\s*[:：]\s*\d+)",
    ]
    for pattern in patterns:
        match = re.search(pattern, text, flags=re.IGNORECASE)
        if not match:
            continue
        if len(match.groups()) == 2:
            prefix = re.sub(r"\s+", "", match.group(1).strip())
            value = f"{prefix}: {match.group(2).strip()}"
            return value if is_plausible_record_number(value) else None
        value = re.sub(r"\s*[:：]\s*", ": ", match.group(1).strip())
        value = re.sub(r"\s+", "", value)
        return value if is_plausible_record_number(value) else None
    return None


def extract_issued_date(content: str) -> str | None:
    patterns = (
        r"Ngày ban hành:\s*([0-9]{4}-[0-9]{2}-[0-9]{2}|[0-9]{1,2}/[0-9]{1,2}/[0-9]{4})",
        r"ngày\s+([0-9]{1,2})\s+tháng\s+([0-9]{1,2})\s+năm\s+([0-9]{4})",
        r"ngày\s+([0-9]{1,2}/[0-9]{1,2}/[0-9]{4})",
    )
    for pattern in patterns:
        match = re.search(pattern, content, flags=re.IGNORECASE)
        if not match:
            continue
        if len(match.groups()) == 3:
            day, month, year = match.groups()
            return f"{int(day):02d}/{int(month):02d}/{year}"
        return format_date_text(match.group(1))
    return None


def build_source_label(source_table: object, source_id: object, page_no: object) -> str:
    if page_no is not None and str(page_no).strip():
        return f"trang OCR {str(page_no).strip()}"
    if source_table and source_id:
        return f"{source_table} #{source_id}"
    return ""


def find_source_metadata(rows: list[dict[str, object]], primary_text: str = "") -> dict[str, str]:
    texts = [primary_text]
    for row in rows:
        texts.append(f"{row.get('title', '')}\n{row.get('content', '')}")
    joined = "\n".join(texts)
    metadata = {
        "record_number": extract_record_number(primary_text) or extract_record_number(joined) or "",
        "decision_number": extract_decision_number(primary_text) or extract_decision_number(joined) or "",
        "issued_date": extract_issued_date(primary_text) or extract_issued_date(joined) or "",
        "source_label": "",
    }
    for row in rows:
        label = build_source_label(row.get("source_table"), row.get("source_id"), row.get("page_no"))
        if label:
            metadata["source_label"] = label
            break
    return metadata


def build_citation(rows: list[dict[str, object]], primary_text: str = "") -> str:
    metadata = find_source_metadata(rows, primary_text)
    parts = []
    if metadata["record_number"]:
        parts.append(f"theo hồ sơ số {metadata['record_number']}")
    else:
        parts.append("hiện dữ liệu chưa trích được số hồ sơ cụ thể")
    if metadata["decision_number"] and metadata["issued_date"]:
        parts.append(f"theo Quyết định số {metadata['decision_number']} ngày {metadata['issued_date']}")
    elif metadata["decision_number"]:
        parts.append(f"theo Quyết định số {metadata['decision_number']}")
    elif metadata["issued_date"]:
        parts.append(f"ngày ban hành {metadata['issued_date']}")
    elif metadata["source_label"]:
        parts.append(f"nguồn {metadata['source_label']}")
    return ", ".join(parts)


def clean_chat_answer(answer: str) -> str:
    text = qa.strip_ansi(str(answer or "")).strip()
    text = re.sub(
        r"(?im)^\s*(?:Câu hỏi|Trả lời|Lời giải|Đáp án|Dẫn chứng|Lưu ý)\s*[:：]\s*",
        "",
        text,
    )
    text = re.sub(
        r"(?i)\b(?:Câu hỏi|Trả lời|Lời giải|Đáp án|Dẫn chứng|Lưu ý)\s*[:：]\s*",
        "",
        text,
    )
    text = re.sub(
        r"(?i)\bBased on the documents provided\b[:,]?\s*",
        "",
        text,
    ).strip()
    return qa.format_vnd_amounts(text)


def build_source_summary(rows: list[dict[str, object]]) -> str:
    record_numbers: list[str] = []
    decision_numbers: list[str] = []
    for row in rows:
        content = compact_text(row.get("content"), MAX_ROW_CONTEXT_CHARS)
        title = compact_text(row.get("title"), 240)
        record_number = extract_record_number(f"{title}\n{content}", row.get("page_no"))
        if record_number and record_number not in record_numbers:
            record_numbers.append(record_number)
        decision_number = extract_decision_number(f"{title}\n{content}")
        if decision_number and decision_number not in decision_numbers:
            decision_numbers.append(decision_number)

    parts = []
    if record_numbers:
        parts.append("Số hồ sơ liên quan: " + ", ".join(record_numbers[:10]))
    if decision_numbers:
        parts.append("Số quyết định liên quan: " + ", ".join(decision_numbers[:8]))
    return "; ".join(parts)


def first_regex_group(pattern: str, text: str, flags: int = re.IGNORECASE | re.DOTALL) -> str:
    match = re.search(pattern, text, flags=flags)
    return compact_text(match.group(1).replace("*", "")) if match else ""


def answer_family_adjustment_total(question: str, rows: list[dict[str, object]]) -> str | None:
    normalized_question = normalize_for_search(question)
    if not (
        is_amount_question(question)
        and any(marker in normalized_question for marker in ["tong", "nguoi nhan", "ai la nguoi nhan"])
    ):
        return None

    for row in rows:
        content = compact_text(row.get("content"))
        normalized_content = normalize_for_search(content)
        if "tong cong ii" not in normalized_content:
            continue

        total_amount = first_regex_group(
            r"Tổng cộng\s*II\s*=.*?=\s*(\d{1,3}(?:[.,]\d{3})+|\d{4,})\s*(?:đ|đồng)?",
            content,
        )
        if not total_amount:
            continue
        total_amount = format_vnd(total_amount)
        paid_amount = first_regex_group(
            r"Tổng cộng\s*I\s*=.*?=\s*(\d{1,3}(?:[.,]\d{3})+|\d{4,})\s*(?:đ|đồng)?",
            content,
        )
        difference_amount = first_regex_group(
            r"Số tiền chênh lệch cấp thêm[^=]*=\s*(\d{1,3}(?:[.,]\d{3})+|\d{4,})\s*(?:đ|đồng)?",
            content,
        )
        recipient = first_regex_group(
            r"Họ và tên:\s*\**\s*([^*\n-]+?)\s*\**\s*-",
            content,
        )
        honored_person = first_regex_group(
            r"Là:\s*\**\s*con của[^:]*:\s*([^*]+?)\s+chết",
            content,
        )
        if not honored_person:
            honored_person = first_regex_group(r"Là:\s*\**\s*con của\s+(?:ông|bà)?\s*([^*]+?)\s+chết", content)

        parts = []
        if honored_person:
            parts.append(f"Tổng trợ cấp được cấp cho {honored_person} là {total_amount}.")
        else:
            parts.append(f"Tổng trợ cấp được cấp là {total_amount}.")
        if recipient:
            relation = f", con của {honored_person}" if honored_person else ""
            parts.append(f"Người nhận trợ cấp là {recipient}{relation}.")
        detail_parts = []
        if paid_amount:
            detail_parts.append(f"khoản đã hưởng {format_vnd(paid_amount)}")
        if difference_amount:
            detail_parts.append(f"khoản chênh lệch cấp thêm {format_vnd(difference_amount)}")
        if detail_parts:
            parts.append("Hồ sơ cũng thể hiện " + " và ".join(detail_parts) + ".")
        parts.append(f"Thông tin này căn cứ {build_citation(rows, content)}.")
        return " ".join(parts)
    return None


def answer_until_month_amount(question: str, rows: list[dict[str, object]]) -> str | None:
    normalized_question = normalize_for_search(question)
    if not any(marker in normalized_question for marker in ["den het thang", "muc tro cap", "cat tro cap"]):
        return None

    asked_person = extract_question_person(rows, question)
    amount_pattern = re.compile(
        r"Mức trợ cấp[^.:\n]*?(?:của\s+(?:Bà|Ông)\s+)?(?P<name>[A-ZÀ-Ỹa-zà-ỹ\s]+?)?\s*Số tiền\s*:?\s*(?P<amount>\d{1,3}(?:[.,]\d{3})+|\d{4,})\s*(?:đ|đồng)?",
        flags=re.IGNORECASE,
    )
    for row in rows:
        if row.get("source_table") != "raw_pages":
            continue
        content = compact_text(row.get("content"))
        match = amount_pattern.search(content)
        if not match:
            continue
        row_person = compact_text(match.group("name"))
        person_name = asked_person or row_person or extract_person_name(content, row.get("title"))
        if asked_person and not question_mentions_name(content, asked_person):
            continue
        amount = format_vnd(match.group("amount"))
        if not amount:
            continue
        citation = build_citation(rows, content)
        return f"Mức trợ cấp của {person_name} hưởng đến hết tháng 02/2006 là {amount}. Thông tin này căn cứ {citation}."
    return None


def answer_amount_from_sql(question: str, rows: list[dict[str, object]]) -> str | None:
    if not rows or not is_amount_question(question):
        return None

    adjustment_markers = [
        "con thuc cap",
        "con lai cap",
        "so tien con lai",
        "sau khi tru",
        "thuc cap",
    ]
    for row in rows:
        if row.get("source_table") != "benefit_cases":
            continue
        content = compact_text(row.get("content"))
        beneficiary_name = extract_person_name(content, row.get("title"))
        if not question_mentions_name(question, beneficiary_name):
            continue
        normalized = normalize_for_search(content)
        if not any(marker in normalized for marker in adjustment_markers):
            continue

        actual_amount = extract_amount_after_marker(content, adjustment_markers)
        if not actual_amount:
            continue

        decision_number = extract_decision_number(content)
        base_amount = extract_first_labeled_amount(
            content,
            "Mức trợ cấp một lần trước khấu trừ",
        )

        citation = build_citation(rows, content)
        answer = f"Số tiền còn lại thực cấp cho {beneficiary_name} là {actual_amount}."
        if base_amount and base_amount != actual_amount:
            answer += f" Mức trợ cấp một lần trước khấu trừ là {base_amount}, nhưng hồ sơ ghi sau khi trừ truy thu còn thực cấp {actual_amount}."
        answer += f" Thông tin này căn cứ {citation}."
        return answer

    return None


def format_date_text(value: str) -> str:
    value = compact_text(value)
    match = re.fullmatch(r"(\d{4})-(\d{2})-(\d{2})", value)
    if match:
        year, month, day = match.groups()
        return f"{day}/{month}/{year}"
    return value


def parse_payment_period_line(content: str) -> tuple[str, int] | None:
    structured_period = re.search(
        r"Từ ngày:\s*([0-9-]+).*?Đến ngày:\s*([0-9-]+).*?Số tháng:\s*(\d+).*?Mức hàng tháng:\s*(\d+).*?Tổng tiền:\s*(\d+)",
        content,
        flags=re.IGNORECASE,
    )
    if not structured_period:
        return None
    date_from, date_to, months, monthly, total = structured_period.groups()
    line = (
        f"truy lãnh từ {format_date_text(date_from)} đến {format_date_text(date_to)}: "
        f"{months} tháng x {format_amount_text(monthly)} = {format_amount_text(total)}"
    )
    return line, int(total)


def answer_benefit_amount_detail(question: str, rows: list[dict[str, object]]) -> str | None:
    if not rows or not is_amount_question(question):
        return None

    asked_person = extract_question_person(rows, question)
    case_row = None
    for row in rows:
        if row.get("source_table") != "benefit_cases":
            continue
        content = compact_text(row.get("content"))
        beneficiary_name = extract_person_name(content, row.get("title"))
        if asked_person and not question_mentions_name(beneficiary_name, asked_person):
            continue
        if not question_mentions_name(question, beneficiary_name) and asked_person:
            continue
        case_row = row
        break
    if case_row is None:
        return None

    case_content = compact_text(case_row.get("content"))
    beneficiary_name = extract_person_name(case_content, case_row.get("title"))
    decision_number = extract_decision_number(case_content)
    record_number = extract_record_number(case_content, case_row.get("page_no"))
    start_match = re.search(r"Ngày bắt đầu:\s*([0-9-]+)", case_content, flags=re.IGNORECASE)
    base_amount = extract_first_labeled_amount(case_content, "Mức trợ cấp một lần trước khấu trừ")
    monthly_amount = extract_first_labeled_amount(case_content, "Trợ cấp hàng tháng")

    detail_lines: list[str] = []
    total_value = 0
    if base_amount:
        detail_lines.append(f"trợ cấp 01 lần: {base_amount}")
        total_value += int(re.sub(r"\D", "", base_amount))

    for row in rows:
        if row.get("source_table") != "payment_periods":
            continue
        content = compact_text(row.get("content"))
        if not question_mentions_name(content, beneficiary_name):
            continue
        if decision_number and decision_number not in content:
            continue
        period = parse_payment_period_line(content)
        if period:
            line, amount = period
            detail_lines.append(line)
            total_value += amount

    total_match = re.search(r"tổng cộng\s*[: ]\s*(\d{1,3}(?:[.,]\d{3})+|\d{4,})", case_content, flags=re.IGNORECASE)
    total_amount = format_vnd(total_match.group(1)) if total_match else (format_vnd(total_value) if total_value else "")
    if not total_amount and not detail_lines:
        return None

    citation = build_citation(rows, case_content)
    intro = f"{beneficiary_name} được hưởng"
    if total_amount:
        intro += f" tổng cộng {total_amount}"
    intro += "."

    answer_parts = [intro]
    if detail_lines:
        answer_parts.append("Cụ thể gồm:\n- " + "\n- ".join(detail_lines) + ".")
    if start_match:
        answer_parts.append(f"Thời điểm bắt đầu hưởng trợ cấp: {format_date_text(start_match.group(1))}.")
    if monthly_amount:
        answer_parts.append(f"Mức trợ cấp hàng tháng ghi trong dữ liệu hồ sơ: {monthly_amount}.")
    answer_parts.append(f"Thông tin này căn cứ {citation}.")
    return "\n\n".join(answer_parts)


def call_local_llama(question: str, context: str, model: str | None = None) -> str:
    selected_model = model or qa.OLLAMA_MODEL
    user_prompt = f"""
CONTEXT:
{context}

Câu hỏi của người dùng:
{question}

Hãy trả lời như một chatbot hỗ trợ đang trò chuyện.
Không lặp lại câu hỏi.
Không dùng các nhãn “Câu hỏi”, “Trả lời”, “Lời giải”, “Dẫn chứng”.
Trả lời ngắn gọn, đúng dữ liệu và có căn cứ từ CONTEXT.
""".strip()
    payload = json.dumps(
        {
            "model": selected_model,
            "messages": [
                {
                    "role": "system",
                    "content": APP_SYSTEM_PROMPT,
                },
                {
                    "role": "user",
                    "content": user_prompt,
                },
            ],
            "stream": False,
            "keep_alive": LLAMA_KEEP_ALIVE,
            "options": LLAMA_OPTIONS,
        },
        ensure_ascii=False,
    ).encode("utf-8")
    request = urllib.request.Request(
        "http://127.0.0.1:11434/api/chat",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=LLAMA_TIMEOUT_SECONDS) as response:
        raw = response.read().decode("utf-8")
    data = json.loads(raw)
    message = data.get("message") if isinstance(data, dict) else {}
    content = message.get("content", "") if isinstance(message, dict) else ""
    return clean_chat_answer(str(content))


def warm_up_local_llama(model: str) -> None:
    payload = json.dumps(
        {
            "model": model,
            "prompt": "Sẵn sàng.",
            "stream": False,
            "keep_alive": LLAMA_KEEP_ALIVE,
            "options": {"num_predict": 1, "temperature": 0},
        },
        ensure_ascii=False,
    ).encode("utf-8")
    request = urllib.request.Request(
        "http://127.0.0.1:11434/api/generate",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=LLAMA_TIMEOUT_SECONDS) as response:
        response.read()


class ChatbotHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def do_GET(self) -> None:
        if self.path == "/":
            self.path = "/chatbot.html"
        if urlparse(self.path).path == "/favicon.ico":
            self.send_response(204)
            self.end_headers()
            return
        super().do_GET()

    def do_POST(self) -> None:
        if urlparse(self.path).path not in CHAT_ENDPOINTS:
            self.send_error(404, "Not found")
            return

        try:
            payload = self.read_json()
            question = str(payload.get("question", "")).strip()
            model = str(payload.get("model", "")).strip() or qa.OLLAMA_MODEL
            if not question:
                self.send_json({"error": "Câu hỏi đang trống."}, status=400)
                return

            mode, sql, rows, answer = self.answer_question(question, model)
            self.log_qa_trace(question, model, mode, sql, rows, answer)
            self.send_json({"answer": answer})
        except Exception as exc:
            self.send_json({"error": str(exc)}, status=500)

    def read_json(self) -> dict[str, object]:
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length).decode("utf-8")
        return json.loads(raw or "{}")

    def send_json(self, payload: dict[str, object], status: int = 200) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def answer_question(
        self,
        question: str,
        model: str,
    ) -> tuple[str, str, list[dict[str, object]], str]:
        sql, rows = search_database(question)
        context = build_context(rows, question)
        if not context:
            return "SQL-first no match", sql, rows, FALLBACK_ANSWER

        direct_answer = (
            answer_family_adjustment_total(question, rows)
            or answer_benefit_amount_detail(question, rows)
            or answer_until_month_amount(question, rows)
            or answer_amount_from_sql(question, rows)
        )
        if direct_answer:
            return "SQL-first + deterministic", sql, rows, clean_chat_answer(direct_answer)

        try:
            answer = call_local_llama(question, context, model)
        except (TimeoutError, urllib.error.URLError, subprocess.TimeoutExpired, json.JSONDecodeError) as exc:
            answer = f"Không xử lý được câu hỏi lúc này. Vui lòng kiểm tra Llama 3 local/Ollama. Chi tiết: {exc}"
        return "SQL-first + local Llama", sql, rows, answer or FALLBACK_ANSWER

    def log_qa_trace(
        self,
        question: str,
        model: str,
        mode: str,
        sql: str,
        rows: list[dict[str, object]],
        answer: str,
    ) -> None:
        print("\n========== QA TRACE ==========")
        print(f"Question: {question}")
        print(f"Model: {model}")
        print(f"DB: {qa.DB_PATH}")
        print(f"Mode: {mode}")
        if sql:
            print("SQL:")
            print(compact_text(sql, 3000))
        print(f"Rows returned: {len(rows)}")
        if rows:
            print("Rows JSON:")
            print(compact_text(json.dumps(rows, ensure_ascii=False, indent=2), 5000))
            source_pages = []
            for row in rows:
                for key in ("source_page_no", "raw_match_page_no", "page_no"):
                    if key in row and row[key] is not None:
                        source_pages.append(f"{key}={row[key]}")
            if source_pages:
                print("Source pages:", ", ".join(dict.fromkeys(source_pages)))
        print(f"Answer: {answer}")
        print("======== END QA TRACE ========\n")

    def log_message(self, format: str, *args) -> None:
        print(f"{self.address_string()} - {format % args}")


def main() -> None:
    qa.configure_console()
    qa.ensure_database()
    if "OLLAMA_MODEL" not in os.environ:
        os.environ["OLLAMA_MODEL"] = qa.OLLAMA_MODEL
    qa.ensure_ollama_model()
    print(f"Đang nạp sẵn Llama local qua Ollama: {qa.OLLAMA_MODEL}")
    warm_up_local_llama(qa.OLLAMA_MODEL)

    server = ThreadingHTTPServer((HOST, PORT), ChatbotHandler)
    print(f"Chatbot server đang chạy: http://{HOST}:{PORT}/chatbot.html")
    print(f"Dùng Ollama model mặc định: {qa.OLLAMA_MODEL}")
    print("Nhấn Ctrl+C để dừng.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nĐã dừng server.")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
