from __future__ import annotations

import re

from app.legacy_backend import clean_chat_answer, compact_text, normalize_for_search
from app.utils.extract_utils import extract_file_number


QUESTION_INTENTS = {
    "context_correction",
    "follow_up_expand",
    "file_lookup",
    "decision_people_lookup",
    "settlement_status",
    "receiver",
    "total_amount",
    "paid_amount",
    "remaining_amount",
    "file_number",
    "decision",
    "general",
}

INTENT_PRIORITY = [
    "context_correction",
    "follow_up_expand",
    "file_lookup",
    "decision_people_lookup",
    "settlement_status",
    "receiver",
    "total_amount",
    "paid_amount",
    "remaining_amount",
    "file_number",
    "decision",
]

SYNONYM_REPLACEMENTS = [
    (r"\bthu\s*chi\b", "chi tra hoac thu hoi"),
    (r"\bthu\s+nua\b", "thu hoi"),
    (r"\bthu\s+lai\b", "thu hoi"),
    (r"\bphai\s+thu\b", "phai thu hoi"),
    (r"\bcan\s+thu\b", "can thu hoi"),
    (r"\bcan\s+chi\s+tra\b", "chi tra"),
    (r"\bcon\s+phai\s+tra\b", "con phai chi tra"),
    (r"\bphai\s+tra\b", "phai chi tra"),
    (r"\bcon\s+khoan\s+nao\b", "con khoan"),
    (r"\bkhoan\s+nao\b", "khoan"),
    (r"\bquyet\s+toan\s+het\s+chua\b", "con khoan chi tra hoac thu hoi khong"),
    (r"\bda\s+quyet\s+toan\s+chua\b", "con khoan chi tra hoac thu hoi khong"),
    (r"\btat\s+toan\s+het\s+chua\b", "con khoan chi tra hoac thu hoi khong"),
]

INTENT_PATTERNS = {
    "context_correction": [
        "dang hoi ve",
        "dang hoi",
        "dang noi ho so",
        "dang noi ve",
        "y toi la",
        "toi hoi",
        "toi dang hoi",
        "khong phai",
        "khong dung nguoi",
        "nham nguoi",
        "nham ho so",
    ],
    "follow_up_expand": [
        "ghi du ra",
        "liet ke day du",
        "ghi het ra",
        "noi tiep",
        "tiep di",
        "day du",
        "cho toi danh sach day du",
        "ghi toan bo",
        "ke het",
    ],
    "file_lookup": [],
    "decision_people_lookup": [
        "lien quan den nhung ai",
        "lien quan den ai",
        "co nhung ai",
        "gom nhung ai",
        "danh sach nhung ai",
        "danh sach ca nhan",
        "danh sach nguoi",
        "liet ke nhung ai",
        "liet ke cac ca nhan",
        "nhung nguoi nao",
    ],
    "settlement_status": [
        "con khoan",
        "con khoan chi tra",
        "con khoan chi tra hoac thu hoi",
        "con khoan thu hoi",
        "con phai chi tra",
        "phai chi tra",
        "chi tra hay thu hoi",
        "chi tra hoac thu hoi",
        "can chi tra hay thu hoi",
        "thu hoi khong",
        "thu hoi nua khong",
        "con phai thu hoi",
        "phai thu hoi",
        "quyet toan",
        "tat toan",
        "thu chi",
    ],
    "receiver": [
        "ai la nguoi nhan",
        "nguoi nhan la ai",
        "ai nhan tro cap",
        "ai nhan",
        "nguoi thu huong la ai",
        "nguoi thu huong",
        "thu huong la ai",
    ],
    "total_amount": [
        "tong tro cap",
        "tong cong",
        "bao nhieu tien",
        "so tien tro cap",
        "tro cap bao nhieu",
        "duoc cap bao nhieu",
        "duoc huong bao nhieu",
    ],
    "paid_amount": [
        "da huong bao nhieu",
        "da nhan bao nhieu",
        "da chi bao nhieu",
        "khoan da huong",
        "khoan da chi",
        "da huong",
        "da chi",
    ],
    "remaining_amount": [
        "con lai bao nhieu",
        "khoan con lai",
        "chenh lech",
        "cap them",
        "thuc cap",
    ],
    "file_number": [
        "so ho so",
        "ho so so may",
        "ho so so",
        "ho so la gi",
        "ho so nao",
        "ma ho so",
    ],
    "decision": [
        "quyet dinh so may",
        "so quyet dinh",
        "quyet dinh lien quan",
        "quyet dinh nao",
        "quyet dinh la gi",
        "ngay quyet dinh",
    ],
}

ANSWER_INTENT_MARKERS = {
    "file_lookup": ["ho so so", "tong tro cap", "duoc cap", "duoc huong", "nguoi nhan", "thuoc ve"],
    "receiver": ["nguoi nhan", "nguoi thu huong", "nay tro cap cho"],
    "total_amount": ["tong tro cap", "tong cong", "duoc cap", "duoc huong", "tong so tien"],
    "paid_amount": ["da huong", "da chi", "da nhan", "khoan da"],
    "remaining_amount": ["con lai", "chenh lech", "cap them", "thuc cap"],
    "settlement_status": [
        "da huong",
        "da chi",
        "chenh lech",
        "cap them",
        "con phai",
        "thu hoi",
        "quyet toan",
        "tat toan",
        "ho so the hien",
        "khong con khoan",
    ],
    "file_number": ["ho so so", "so ho so", "ho so lien quan"],
    "decision": ["quyet dinh so", "so quyet dinh", "quyet dinh lien quan"],
    "decision_people_lookup": ["quyet dinh so", "lien quan den cac ca nhan", "ca nhan sau"],
}


def normalize_question(question: str) -> str:
    text = normalize_for_search(question)
    text = re.sub(r"[?？!！,，;；]+", " ", text)
    text = re.sub(r"\s+", " ", text).strip().lower()
    for pattern, replacement in SYNONYM_REPLACEMENTS:
        text = re.sub(pattern, replacement, text)
    return re.sub(r"\s+", " ", text).strip()


def detect_question_intent(question: str) -> str:
    normalized = normalize_question(question)
    lookup_markers = [
        "cua ai",
        "thuoc ve ai",
        "nguoi nhan",
        "tro cap",
        "bao nhieu",
        "so tien",
        "duoc cap",
        "duoc huong",
    ]
    if extract_file_number(question) and any(marker in normalized for marker in lookup_markers):
        return "file_lookup"
    if "ho so nay" in normalized and any(marker in normalized for marker in lookup_markers):
        return "file_lookup"
    if any(pattern in normalized for pattern in INTENT_PATTERNS["follow_up_expand"]):
        return "follow_up_expand"
    decision_markers = ["quyet dinh", "qd", "so quyet dinh"]
    people_markers = INTENT_PATTERNS["decision_people_lookup"]
    if any(marker in normalized for marker in decision_markers) and any(marker in normalized for marker in people_markers):
        return "decision_people_lookup"
    for intent in INTENT_PRIORITY:
        if any(pattern in normalized for pattern in INTENT_PATTERNS[intent]):
            return intent
    return "general"


def clean_answer_by_intent(answer: str, intent: str) -> str:
    text = clean_chat_answer(answer or "")
    if intent not in QUESTION_INTENTS or intent in {"general", "context_correction"} or not text:
        return text

    sentences = _split_sentences(text)
    if not sentences:
        return text

    keepers: list[str] = []
    citation_sentences = [
        sentence
        for sentence in sentences
        if any(marker in normalize_for_search(sentence) for marker in ["can cu", "theo ho so", "theo quyet dinh"])
    ]

    for sentence in sentences:
        normalized = normalize_for_search(sentence)
        if _sentence_matches_intent(normalized, intent):
            keepers.append(sentence)

    if intent == "total_amount":
        keepers = [
            sentence
            for sentence in keepers
            if not any(
                marker in normalize_for_search(sentence)
                for marker in ["da huong", "da chi", "chenh lech", "cap them"]
            )
        ]
    if intent == "settlement_status":
        keepers = [
            sentence
            for sentence in keepers
            if not any(
                marker in normalize_for_search(sentence)
                for marker in ["danh hieu", "phong tang", "truy tang", "que quan", "tieu su"]
            )
        ]

    for sentence in citation_sentences:
        if sentence not in keepers:
            keepers.append(sentence)

    return " ".join(keepers).strip() or text


def clean_answer_for_intent(answer: str, intent: str) -> str:
    return clean_answer_by_intent(answer, intent)


def _sentence_matches_intent(normalized_sentence: str, intent: str) -> bool:
    return any(marker in normalized_sentence for marker in ANSWER_INTENT_MARKERS.get(intent, []))


def _split_sentences(text: str) -> list[str]:
    normalized = re.sub(r"\s+", " ", str(text or "")).strip()
    if not normalized:
        return []
    parts = re.split(r"(?<=[.!?。])\s+", normalized)
    return [part.strip() for part in parts if part.strip()]
