from __future__ import annotations

import json
import os
import re
import sqlite3
import subprocess
import sys
import unicodedata
import urllib.error
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parent
DB_PATH = Path(os.environ.get("OCR_QA_DB", ROOT / "data" / "ocr_qa.db"))
SQL_PATH = Path(os.environ.get("OCR_QA_SQL", ROOT / "data" / "ocr_qa.sql"))
OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", "llama3:latest")
MAX_SQL_ROWS = 15


def configure_console() -> None:
    for stream_name in ("stdout", "stderr", "stdin"):
        stream = getattr(sys, stream_name, None)
        if stream and hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")


def ensure_database() -> None:
    if DB_PATH.exists():
        return
    if not SQL_PATH.exists():
        raise FileNotFoundError(f"Không tìm thấy file SQL để tạo database: {SQL_PATH}")
    connection = sqlite3.connect(DB_PATH)
    try:
        connection.executescript(SQL_PATH.read_text(encoding="utf-8"))
        connection.commit()
    finally:
        connection.close()


def ensure_ollama_model() -> None:
    subprocess.run(["ollama", "show", OLLAMA_MODEL], check=True, capture_output=True, text=True)


def call_ollama(prompt: str) -> str:
    payload = json.dumps(
        {"model": OLLAMA_MODEL, "prompt": prompt, "stream": False},
        ensure_ascii=False,
    ).encode("utf-8")
    request = urllib.request.Request(
        "http://127.0.0.1:11434/api/generate",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=240) as response:
            raw = response.read().decode("utf-8")
    except urllib.error.URLError:
        result = subprocess.run(
            ["ollama", "run", OLLAMA_MODEL],
            input=prompt,
            capture_output=True,
            text=True,
            encoding="utf-8",
            cwd=ROOT,
            check=True,
        )
        raw = result.stdout

    try:
        data = json.loads(raw)
        text = data.get("response", "")
    except json.JSONDecodeError:
        text = raw
    return strip_ansi(text).strip()


def strip_ansi(text: str) -> str:
    return re.sub(r"\x1b\[[0-9;?]*[A-Za-z]", "", text)


def normalize_text(text: str) -> str:
    lowered = text.lower().strip()
    return "".join(
        ch for ch in unicodedata.normalize("NFD", lowered) if unicodedata.category(ch) != "Mn"
    ).replace("đ", "d")


def get_schema_context(conn: sqlite3.Connection) -> str:
    tables = [
        "persons",
        "organizations",
        "decisions",
        "honors",
        "relationships",
        "benefit_cases",
        "payment_periods",
        "raw_pages",
    ]
    chunks = []
    for table in tables:
        columns = conn.execute(f"PRAGMA table_info({table})").fetchall()
        formatted_columns = ", ".join(f"{col[1]} {col[2]}" for col in columns)
        chunks.append(f"- {table}({formatted_columns})")
    return "\n".join(chunks)


def get_domain_context() -> str:
    return """
Quy ước nghiệp vụ:
- persons chứa người được phong/truy tặng hoặc thân nhân hưởng trợ cấp.
- honors nối người được phong/truy tặng với quyết định danh hiệu.
- benefit_cases chứa hồ sơ trợ cấp; beneficiary_person_id là người hưởng, honored_person_id là người được phong/truy tặng/liên quan.
- payment_periods chứa các giai đoạn truy lãnh hoặc truy thu.
- relationships chứa quan hệ thân nhân như cha, mẹ, con.
- raw_pages chứa OCR toàn văn theo từng trang để tìm kiếm bổ sung khi dữ liệu chuẩn hóa chưa đủ.
- Khi người dùng hỏi "nói về X", ưu tiên trả tóm tắt hồ sơ của X: thông tin cá nhân, quan hệ, quyết định, trợ cấp.
- decision_kind hợp lệ: benefit_decision, honor_decision, benefit_adjustment.
- benefit_type hiện có: tro_cap_mot_lan_va_truy_lanh, tro_cap_mot_lan_than_nhan, mai_tang_phi_va_tro_cap_mot_lan, di_chuyen_tro_cap_hang_thang.
""".strip()


def list_known_people(conn: sqlite3.Connection) -> str:
    rows = conn.execute("SELECT full_name, COALESCE(alias, '') FROM persons ORDER BY full_name").fetchall()
    names = []
    for full_name, alias in rows:
        names.append(full_name if not alias else f"{full_name} (alias: {alias})")
    return "; ".join(names)


def build_intent_prompt(question: str, conn: sqlite3.Connection, schema_context: str) -> str:
    return f"""
Bạn là trợ lý phân tích câu hỏi tiếng Việt cho hệ hỏi đáp SQLite.

Nhiệm vụ:
- Phân loại câu hỏi vào một trong các intent:
  1. person_summary
  2. benefit_info
  3. payment_detail
  4. relationship_info
  5. decision_info
  6. raw_search
- Tìm person_name gần đúng nhất từ danh sách người đã biết nếu có.
- Nếu câu hỏi kiểu "nói về", "hồ sơ của", "thông tin về" thì intent là person_summary.
- Nếu hỏi quyết định nào thì intent là decision_info.
- Nếu hỏi trợ cấp bao nhiêu, hưởng gì thì intent là benefit_info.
- Nếu hỏi truy lãnh, giai đoạn thanh toán thì intent là payment_detail.
- Nếu hỏi cha/mẹ/con/thân nhân là ai thì intent là relationship_info.
- Nếu không chắc hoặc không có người phù hợp thì chọn raw_search.
- Trả về DUY NHẤT một JSON trên 1 dòng theo mẫu:
  {{"intent":"person_summary","person_name":"Trần Thị Nuôi","keywords":["trần thị nuôi"]}}

Schema:
{schema_context}

{get_domain_context()}

Danh sách người đã biết:
{list_known_people(conn)}

Câu hỏi của người dùng:
{question}
""".strip()


def parse_json_object(text: str) -> dict[str, object]:
    match = re.search(r"\{.*\}", text, flags=re.DOTALL)
    if match:
        return json.loads(match.group(0))

    fallback: dict[str, object] = {"intent": "raw_search", "person_name": None, "keywords": []}
    intent_match = re.search(r"intent\s*[:*]*\s*([a-z_]+)", text, flags=re.IGNORECASE)
    if intent_match:
        fallback["intent"] = intent_match.group(1).lower()

    person_match = re.search(r"person\s*name\s*[:*]*\s*(.+)", text, flags=re.IGNORECASE)
    if person_match:
        fallback["person_name"] = person_match.group(1).strip().strip('"')

    keywords_match = re.search(r"keywords\s*[:*]*\s*(\[[^\]]*\])", text, flags=re.IGNORECASE)
    if keywords_match:
        try:
            fallback["keywords"] = json.loads(keywords_match.group(1))
        except json.JSONDecodeError:
            pass

    return fallback


def detect_intent(conn: sqlite3.Connection, question: str) -> dict[str, object]:
    prompt = build_intent_prompt(question, conn, get_schema_context(conn))
    raw = call_ollama(prompt)
    payload = parse_json_object(raw)
    return {
        "intent": payload.get("intent", "raw_search"),
        "person_name": payload.get("person_name"),
        "keywords": payload.get("keywords", []),
    }


def lookup_person(conn: sqlite3.Connection, candidate: str | None) -> str | None:
    if not candidate:
        return None
    row = conn.execute(
        """
        SELECT full_name
        FROM persons
        WHERE lower(full_name) = lower(?)
           OR lower(COALESCE(alias, '')) = lower(?)
        LIMIT 1
        """,
        (candidate, candidate),
    ).fetchone()
    return row[0] if row else None


def resolve_person_name(
    conn: sqlite3.Connection,
    person_name: str | None,
    question: str,
    keywords: list[str] | None = None,
) -> str | None:
    simplified = normalize_text(question)
    ranked: list[tuple[int, str]] = []
    for full_name, alias in conn.execute("SELECT full_name, COALESCE(alias, '') FROM persons"):
        variants = [normalize_text(full_name)]
        if alias:
            variants.append(normalize_text(alias))
        if any(variant and variant in simplified for variant in variants):
            ranked.append((len(full_name), full_name))
    if ranked:
        ranked.sort(reverse=True)
        return ranked[0][1]

    if keywords:
        for keyword in keywords:
            matched = lookup_person(conn, keyword)
            if matched:
                return matched

    matched = lookup_person(conn, person_name)
    if matched:
        return matched
    return None


def is_difference_payment_question(question: str) -> bool:
    simplified = normalize_text(question)
    return "chenh lech" in simplified or "cap them" in simplified


def is_benefit_amount_question(question: str) -> bool:
    simplified = normalize_text(question)
    asks_benefit_amount = "tro cap" in simplified and (
        "so tien" in simplified or "bao nhieu" in simplified
    )
    asks_payment_period = any(
        marker in simplified
        for marker in ["truy lanh", "giai doan", "truy thu", "chenh lech", "cap them"]
    )
    return asks_benefit_amount and not asks_payment_period


def build_difference_payment_sql() -> str:
    return """
    SELECT
        pb.full_name AS beneficiary_name,
        ph.full_name AS honored_name,
        d.decision_number,
        d.title AS decision_title,
        rp.page_no AS source_page_no,
        pp.from_date,
        pp.to_date,
        pp.months_count,
        pp.monthly_amount,
        pp.total_amount,
        pp.description,
        (
            SELECT page_no
            FROM raw_pages
            WHERE raw_text LIKE '%' || pb.full_name || '%'
              AND (raw_text LIKE '%chênh lệch%' OR raw_text LIKE '%cấp thêm%')
            LIMIT 1
        ) AS raw_match_page_no
    FROM payment_periods pp
    JOIN benefit_cases bc ON bc.case_id = pp.case_id
    JOIN persons pb ON pb.person_id = bc.beneficiary_person_id
    LEFT JOIN persons ph ON ph.person_id = bc.honored_person_id
    LEFT JOIN decisions d ON d.decision_id = bc.decision_id
    LEFT JOIN raw_pages rp ON rp.raw_page_id = d.source_page_id
    WHERE (pb.full_name = ? OR ph.full_name = ?)
      AND (pp.description LIKE '%chênh lệch%' OR pp.description LIKE '%cấp thêm%')
    ORDER BY pp.payment_period_id
    LIMIT 15;
    """


def build_sql_from_intent(intent: str, person_name: str | None) -> str:
    if intent == "person_summary" and person_name:
        return """
        SELECT
            p.full_name,
            p.alias,
            p.gender,
            p.birth_year,
            p.hometown,
            p.residence,
            p.person_type,
            GROUP_CONCAT(DISTINCT r.relation_type || ': ' || COALESCE(pr.full_name, r.related_person_name)) AS relationships,
            GROUP_CONCAT(DISTINCT h.honor_title || ' (' || h.action_type || ')') AS honors,
            GROUP_CONCAT(DISTINCT d.decision_number || ' - ' || d.title) AS decisions,
            GROUP_CONCAT(DISTINCT
                CASE
                    WHEN bc.one_time_amount IS NOT NULL THEN 'trợ cấp một lần ' || bc.one_time_amount || ' đồng'
                    WHEN bc.monthly_amount IS NOT NULL THEN 'trợ cấp hàng tháng ' || bc.monthly_amount || ' đồng'
                    ELSE bc.benefit_type
                END
            ) AS benefits
        FROM persons p
        LEFT JOIN relationships r ON r.person_id = p.person_id
        LEFT JOIN persons pr ON pr.person_id = r.related_person_id
        LEFT JOIN honors h ON h.honored_person_id = p.person_id
        LEFT JOIN decisions d
            ON d.decision_id = h.decision_id
            OR d.decision_id IN (
                SELECT decision_id
                FROM benefit_cases
                WHERE beneficiary_person_id = p.person_id OR honored_person_id = p.person_id
            )
        LEFT JOIN benefit_cases bc
            ON bc.beneficiary_person_id = p.person_id
            OR bc.honored_person_id = p.person_id
        WHERE p.full_name = ?
        GROUP BY p.person_id
        LIMIT 1;
        """
    if intent == "benefit_info" and person_name:
        return """
        SELECT
            pb.full_name AS beneficiary_name,
            ph.full_name AS honored_name,
            bc.benefit_type,
            bc.start_date,
            bc.one_time_amount,
            bc.monthly_amount,
            bc.status,
            d.decision_number,
            d.title,
            d.issued_date,
            bc.notes
        FROM benefit_cases bc
        JOIN persons pb ON pb.person_id = bc.beneficiary_person_id
        LEFT JOIN persons ph ON ph.person_id = bc.honored_person_id
        LEFT JOIN decisions d ON d.decision_id = bc.decision_id
        WHERE pb.full_name = ? OR ph.full_name = ?
        LIMIT 15;
        """
    if intent == "payment_detail" and person_name:
        return """
        SELECT
            pb.full_name AS beneficiary_name,
            ph.full_name AS honored_name,
            pp.from_date,
            pp.to_date,
            pp.months_count,
            pp.monthly_amount,
            pp.total_amount,
            pp.description
        FROM payment_periods pp
        JOIN benefit_cases bc ON bc.case_id = pp.case_id
        JOIN persons pb ON pb.person_id = bc.beneficiary_person_id
        LEFT JOIN persons ph ON ph.person_id = bc.honored_person_id
        WHERE pb.full_name = ? OR ph.full_name = ?
        ORDER BY pp.from_date
        LIMIT 15;
        """
    if intent == "relationship_info" and person_name:
        return """
        SELECT
            p.full_name AS person,
            r.relation_type,
            COALESCE(pr.full_name, r.related_person_name) AS related_person
        FROM relationships r
        JOIN persons p ON p.person_id = r.person_id
        LEFT JOIN persons pr ON pr.person_id = r.related_person_id
        WHERE p.full_name = ? OR pr.full_name = ?
        LIMIT 15;
        """
    if intent == "decision_info" and person_name:
        return """
        SELECT DISTINCT
            p.full_name,
            d.decision_number,
            d.title,
            d.issued_date,
            d.decision_kind,
            d.summary
        FROM persons p
        LEFT JOIN honors h ON h.honored_person_id = p.person_id
        LEFT JOIN benefit_cases bc
            ON bc.beneficiary_person_id = p.person_id
            OR bc.honored_person_id = p.person_id
        LEFT JOIN decisions d
            ON d.decision_id = h.decision_id
            OR d.decision_id = bc.decision_id
        WHERE p.full_name = ?
        LIMIT 15;
        """
    return """
    SELECT
        page_no,
        substr(raw_text, 1, 800) AS excerpt
    FROM raw_pages
    WHERE raw_text LIKE '%' || ? || '%'
    LIMIT 5;
    """


def execute_sql(conn: sqlite3.Connection, sql: str) -> list[sqlite3.Row]:
    return list(conn.execute(sql))


def rows_to_json(rows: list[sqlite3.Row]) -> str:
    payload = [{key: row[key] for key in row.keys()} for row in rows]
    return json.dumps(payload, ensure_ascii=False, indent=2)


def format_vnd_amounts(text: str) -> str:
    def replace_amount(match: re.Match[str]) -> str:
        raw_number = match.group("amount")
        digits = re.sub(r"\D", "", raw_number)
        if not digits:
            return match.group(0)
        formatted = f"{int(digits):,}".replace(",", ".")
        return f"{formatted} đồng"

    return re.sub(
        r"(?P<amount>\d{4,}(?:[.,]\d{3})*)\s*(?:đồng|đ)\b",
        replace_amount,
        text,
        flags=re.IGNORECASE,
    )


def format_vnd(value: object) -> str:
    if value is None:
        return ""
    digits = re.sub(r"\D", "", str(value))
    if not digits:
        return str(value)
    return f"{int(digits):,}".replace(",", ".") + " đồng"


def answer_difference_payment(question: str, rows: list[sqlite3.Row]) -> str | None:
    if not rows or not is_difference_payment_question(question):
        return None
    row = rows[0]
    amount = row["total_amount"] if "total_amount" in row.keys() else None
    beneficiary_name = row["beneficiary_name"] if "beneficiary_name" in row.keys() else "người hưởng"
    decision_number = row["decision_number"] if "decision_number" in row.keys() else None
    if amount is None:
        return None
    citation = f" theo Quyết định số {decision_number}" if decision_number else ""
    return f"Số tiền chênh lệch cấp thêm cho gia đình của {beneficiary_name} là {format_vnd(amount)}{citation}."


def first_amount_from_text(text: str | None) -> str | None:
    if not text:
        return None
    match = re.search(r"\d{1,3}(?:[.,]\d{3})+|\d{4,}", text)
    if not match:
        return None
    return format_vnd(match.group(0))


def answer_benefit_amount(question: str, rows: list[sqlite3.Row]) -> str | None:
    if not rows:
        return None

    simplified = normalize_text(question)
    asks_amount = any(token in simplified for token in ["bao nhieu", "so tien", "tro cap"])
    if not asks_amount:
        return None

    row = rows[0]
    keys = row.keys()
    if "beneficiary_name" not in keys or "one_time_amount" not in keys:
        return None

    beneficiary_name = row["beneficiary_name"]
    decision_number = row["decision_number"] if "decision_number" in keys else None
    notes = row["notes"] if "notes" in keys else None
    one_time_amount = row["one_time_amount"]
    monthly_amount = row["monthly_amount"] if "monthly_amount" in keys else None

    notes_simplified = normalize_text(notes or "")
    actual_amount = first_amount_from_text(notes) if any(
        marker in notes_simplified
        for marker in ["thuc cap", "con thuc cap", "con lai", "sau khi tru"]
    ) else None

    issued_date = row["issued_date"] if "issued_date" in keys else None
    if decision_number and issued_date:
        citation = f" Thông tin này căn cứ theo Quyết định số {decision_number} ngày {issued_date}."
    elif decision_number:
        citation = f" Thông tin này căn cứ theo Quyết định số {decision_number}."
    else:
        citation = ""
    if actual_amount and one_time_amount:
        return (
            f"Số tiền còn lại thực cấp cho {beneficiary_name} là {actual_amount}. "
            f"Mức trợ cấp một lần trong quyết định là {format_vnd(one_time_amount)}, "
            f"nhưng ghi chú hồ sơ nêu: {notes}.{citation}"
        )
    if one_time_amount:
        return f"Số tiền trợ cấp một lần cho {beneficiary_name} là {format_vnd(one_time_amount)}.{citation}"
    if monthly_amount:
        return f"Số tiền trợ cấp hàng tháng cho {beneficiary_name} là {format_vnd(monthly_amount)}.{citation}"
    return None


def fallback_search(conn: sqlite3.Connection, question: str) -> tuple[str, list[sqlite3.Row]]:
    sql = """
    SELECT
        p.full_name,
        p.alias,
        p.birth_year,
        p.hometown,
        p.residence,
        d.decision_number,
        d.issued_date,
        bc.one_time_amount,
        bc.monthly_amount,
        bc.notes
    FROM persons p
    LEFT JOIN honors h ON h.honored_person_id = p.person_id
    LEFT JOIN decisions d ON d.decision_id = h.decision_id
    LEFT JOIN benefit_cases bc
        ON bc.beneficiary_person_id = p.person_id
        OR bc.honored_person_id = p.person_id
    WHERE lower(p.full_name) LIKE '%' || lower(?) || '%'
       OR lower(COALESCE(p.alias, '')) LIKE '%' || lower(?) || '%'
    LIMIT 10;
    """
    simple_name = question.replace("nói về", "").replace("thông tin", "").replace("hồ sơ của", "").strip()
    rows = list(conn.execute(sql, (simple_name, simple_name)))
    return sql, rows


def synthesize_answer(question: str, sql: str, rows: list[sqlite3.Row]) -> str:
    if not rows:
        return "Không tìm thấy dữ liệu phù hợp trong các bảng hiện có."
    prompt = f"""
Bạn là trợ lý hỏi đáp hồ sơ hành chính.

Yêu cầu:
- Trả lời bằng tiếng Việt tự nhiên, ngắn gọn, trực tiếp theo câu hỏi.
- Chỉ dùng dữ liệu trong kết quả SQL.
- Nếu dữ liệu chưa đủ chắc chắn, nói rõ là hồ sơ hiện có chỉ thể hiện như vậy.
- Nếu có tiền, ghi theo đơn vị đồng và phân tách hàng nghìn bằng dấu chấm, ví dụ 13.700.000 đồng.
- Không lặp lại câu hỏi của người dùng.
- Không dùng các nhãn “Câu hỏi:”, “Trả lời:”, “Lời giải:”, “Đáp án:”, “Dẫn chứng:”, “Lưu ý:”.
- Không nhắc đến việc bạn là AI, không giải thích prompt.

Câu hỏi của người dùng:
{question}

SQL đã chạy:
{sql}

Kết quả SQL (JSON):
{rows_to_json(rows)}
""".strip()
    answer = call_ollama(prompt)
    answer = re.sub(
        r"(?im)^\s*(?:Câu hỏi|Trả lời|Lời giải|Đáp án|Dẫn chứng|Lưu ý)\s*[:：]\s*",
        "",
        answer,
    )
    answer = re.sub(
        r"(?i)\b(?:Câu hỏi|Trả lời|Lời giải|Đáp án|Dẫn chứng|Lưu ý)\s*[:：]\s*",
        "",
        answer,
    )
    answer = re.sub(r"(?i)\bBased on the documents provided\b[:,]?\s*", "", answer)
    return format_vnd_amounts(answer.strip())


def ask_database(conn: sqlite3.Connection, question: str) -> tuple[str, str, list[sqlite3.Row], str]:
    try:
        intent_payload = detect_intent(conn, question)
        person_name = resolve_person_name(
            conn,
            intent_payload.get("person_name"),
            question,
            keywords=list(intent_payload.get("keywords", [])),
        )
        intent = str(intent_payload.get("intent", "raw_search"))
        if person_name and is_difference_payment_question(question):
            sql = build_difference_payment_sql()
            intent = "difference_payment"
        elif person_name and is_benefit_amount_question(question):
            sql = build_sql_from_intent("benefit_info", person_name)
            intent = "benefit_amount"
        else:
            sql = build_sql_from_intent(intent, person_name)
        if intent == "raw_search" or not person_name:
            search_term = person_name or question
            rows = list(conn.execute(sql, (search_term,)))
        elif intent in {"benefit_info", "benefit_amount", "payment_detail", "relationship_info", "difference_payment"}:
            rows = list(conn.execute(sql, (person_name, person_name)))
        else:
            rows = list(conn.execute(sql, (person_name,)))

        if not rows:
            fallback_sql, fallback_rows = fallback_search(conn, question)
            if fallback_rows:
                answer = synthesize_answer(question, fallback_sql, fallback_rows)
                return f"Llama intent `{intent}` fallback", fallback_sql, fallback_rows, answer
        answer = (
            answer_difference_payment(question, rows)
            or answer_benefit_amount(question, rows)
            or synthesize_answer(question, sql, rows)
        )
        return f"Llama intent `{intent}`", sql, rows, answer
    except Exception as exc:
        fallback_sql, fallback_rows = fallback_search(conn, question)
        if fallback_rows:
            answer = synthesize_answer(question, fallback_sql, fallback_rows)
            return f"Fallback sau lỗi: {exc}", fallback_sql, fallback_rows, answer
        return f"Lỗi", "", [], f"Không xử lý được câu hỏi. Chi tiết: {exc}"


def print_examples() -> None:
    print("Ví dụ câu hỏi tự nhiên:")
    print("  - nói về trần thị nuôi")
    print("  - hồ sơ của nguyễn văn chiếu có gì")
    print("  - ai là thân nhân của nguyễn thị bé")
    print("  - trần thị nuôi được hưởng theo quyết định nào")
    print("  - nguyễn văn chiếu được truy lãnh mấy giai đoạn")


def main() -> None:
    configure_console()
    ensure_database()
    ensure_ollama_model()
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row

    try:
        print(f"Terminal QA dùng Ollama model `{OLLAMA_MODEL}` trên SQLite. Gõ 'exit' để thoát.")
        print_examples()
        while True:
            question = input("\nHỏi> ").strip()
            if not question:
                continue
            if question.lower() in {"exit", "quit"}:
                break

            mode, sql, rows, answer = ask_database(conn, question)
            print(f"\n[{mode}]")
            if sql:
                print("SQL:")
                print(sql)
            print("\nPhản hồi:")
            print(answer)

            if rows:
                print("\nDữ liệu SQL:")
                print(rows_to_json(rows))
    finally:
        conn.close()


if __name__ == "__main__":
    main()
