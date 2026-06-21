from __future__ import annotations

import re
from html import unescape


_FILE_PREFIX = r"[A-ZĐ]{1,8}\s*/\s*[A-ZĐ]{1,12}"
_LETTER_DIGIT_FILE = r"[A-ZĐ]{1,8}\s*/\s*\d{1,5}"


def extract_file_number(text: str) -> str | None:
    if not text:
        return None

    patterns = [
        rf"(?:số\s+hồ\s+sơ|hồ\s+sơ\s+số|hồ\s+sơ)?\s*[:：]?\s*\b({_FILE_PREFIX})\s*[:：\-]?\s*(\d{{1,5}})\b",
        rf"(?:số\s+hồ\s+sơ|hồ\s+sơ\s+số|hồ\s+sơ)?\s*[:：]?\s*\b({_LETTER_DIGIT_FILE})\b",
    ]

    for pattern in patterns:
        match = re.search(pattern, text, flags=re.IGNORECASE)
        if not match:
            continue
        groups = match.groups()
        if len(groups) == 2:
            prefix = _normalize_file_prefix(groups[0])
            return f"{prefix}: {groups[1]}"
        return _normalize_file_prefix(groups[0])
    return None


def normalize_decision_number(value: str) -> str:
    text = str(value or "").strip()
    if not text:
        return ""
    text = unescape(text)
    text = re.sub(r"\s+", "", text).upper()
    text = text.replace("QD-", "QĐ-")
    text = text.replace("/QD", "/QĐ")
    text = text.replace("LDTBXH", "LĐTBXH")
    text = text.replace("SLDTBXH", "SLĐTBXH")
    text = text.strip(".,;:()[]{}")
    return text


def extract_decision_number(text: str) -> str | None:
    if not text:
        return None

    prefix = r"(?:quyết\s*định|quyet\s*dinh|q[đd])"
    number = r"(\d{1,5}\s*/\s*(?:QĐ|QD|UBND|LĐTBXH|LDTBXH|SLĐTBXH|SLDTBXH|CTN)[0-9A-ZĐa-zđ./-]*)"
    patterns = [
        rf"{prefix}\s*(?:số|so)?\s*[:：]?\s*{number}",
        rf"(?:số|so)\s*[:：]?\s*{number}",
        rf"\b{number}",
    ]
    for pattern in patterns:
        match = re.search(pattern, text, flags=re.IGNORECASE)
        if match:
            normalized = normalize_decision_number(match.group(1))
            return normalized or None
    return None


def decision_number_variants(decision_number: str) -> list[str]:
    normalized = normalize_decision_number(decision_number)
    if not normalized or "/" not in normalized:
        return []

    slash_index = normalized.find("/")
    number = normalized[:slash_index]
    suffix = normalized[slash_index + 1 :]
    ascii_suffix = suffix.replace("QĐ", "QD").replace("LĐTBXH", "LDTBXH").replace("SLĐTBXH", "SLDTBXH")
    suffixes = list(dict.fromkeys([suffix, ascii_suffix]))
    variants = []
    for item in suffixes:
        variants.extend(
            [
                f"{number}/{item}",
                f"{number} /{item}",
                f"{number}/ {item}",
                f"{number} / {item}",
                f"Quyết định số {number}/{item}",
                f"Quyết định số {number} / {item}",
                f"QD {number}/{item}",
                f"QĐ {number}/{item}",
                f"số {number}/{item}",
            ]
        )
    return list(dict.fromkeys(variants))


def contains_decision_number(text: str, decision_number: str) -> bool:
    if not text or not decision_number:
        return False
    target = normalize_decision_number(decision_number)
    if not target or "/" not in target:
        return False
    compact = normalize_decision_number(text)
    return target in compact


def file_number_variants(file_number: str) -> list[str]:
    parsed = split_file_number(file_number)
    if not parsed:
        return []

    prefix, number = parsed
    if number:
        return list(
            dict.fromkeys(
                [
                    f"{prefix}: {number}",
                    f"{prefix}:{number}",
                    f"{prefix} {number}",
                    f"{prefix}-{number}",
                    f"Số hồ sơ: {prefix}: {number}",
                    f"Số hồ sơ {prefix}: {number}",
                ]
            )
        )
    return [prefix]


def validate_context_matches_file_number(context: str, file_number: str) -> bool:
    return contains_file_number(context, file_number)


def contains_file_number(text: str, file_number: str) -> bool:
    if not text or not file_number:
        return False

    parsed = split_file_number(file_number)
    if not parsed:
        return False

    prefix, number = parsed
    prefix_pattern = r"\s*/\s*".join(re.escape(part) for part in prefix.split("/"))
    if number:
        pattern = rf"(?<![A-ZĐ0-9/]){prefix_pattern}(?![A-ZĐ])\s*(?:[:：\-]|\s)\s*{re.escape(number)}(?!\d)"
    else:
        pattern = rf"(?<![A-ZĐ0-9/]){prefix_pattern}(?![A-ZĐ0-9/])"
    return bool(re.search(pattern, text, flags=re.IGNORECASE))


def split_file_number(file_number: str) -> tuple[str, str] | None:
    value = str(file_number or "").strip()
    if not value:
        return None

    match = re.fullmatch(rf"\s*({_FILE_PREFIX})\s*[:：\- ]\s*(\d{{1,5}})\s*", value, flags=re.IGNORECASE)
    if match:
        return _normalize_file_prefix(match.group(1)), match.group(2)

    match = re.fullmatch(rf"\s*({_LETTER_DIGIT_FILE})\s*", value, flags=re.IGNORECASE)
    if match:
        return _normalize_file_prefix(match.group(1)), ""
    return None


def _normalize_file_prefix(value: str) -> str:
    return re.sub(r"\s+", "", value or "").upper()


from app.legacy_backend import extract_issued_date, extract_record_number  # noqa: E402
