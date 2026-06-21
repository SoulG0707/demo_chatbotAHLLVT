from __future__ import annotations

import re
from dataclasses import dataclass

from app import legacy_backend
from app.utils.extract_utils import extract_file_number
from app.utils.text_utils import clean_answer_for_intent, detect_question_intent


@dataclass
class BenefitFacts:
    subject: str = ""
    receiver: str = ""
    relation: str = ""
    total_amount: str = ""
    paid_amount: str = ""
    remaining_amount: str = ""
    record_number: str = ""
    decision_number: str = ""
    decision_date: str = ""
    citation: str = ""
    primary_text: str = ""
    settlement_done: bool = False


class DeterministicAnswerService:
    def answer(
        self,
        question: str,
        rows: list[dict[str, object]],
        intent: str | None = None,
        resolved_subject: str = "",
        file_number: str = "",
    ) -> str | None:
        intent = intent or detect_question_intent(question)
        facts = self.extract_benefit_facts(question, rows, resolved_subject)
        requested_file_number = file_number or extract_file_number(question) or ""
        if requested_file_number:
            facts.record_number = requested_file_number

        answer = self._answer_by_intent(intent, facts)
        if not answer and intent == "general":
            answer = (
                legacy_backend.answer_family_adjustment_total(question, rows)
                or legacy_backend.answer_benefit_amount_detail(question, rows)
                or legacy_backend.answer_until_month_amount(question, rows)
                or legacy_backend.answer_amount_from_sql(question, rows)
            )
        if not answer and intent in {"total_amount", "paid_amount", "remaining_amount"}:
            answer = (
                legacy_backend.answer_family_adjustment_total(question, rows)
                or legacy_backend.answer_benefit_amount_detail(question, rows)
                or legacy_backend.answer_until_month_amount(question, rows)
                or legacy_backend.answer_amount_from_sql(question, rows)
            )
        return clean_answer_for_intent(answer, intent) if answer else None

    def extract_benefit_facts(
        self,
        question: str,
        rows: list[dict[str, object]],
        resolved_subject: str = "",
    ) -> BenefitFacts:
        if not rows:
            return BenefitFacts()

        asked_person = resolved_subject or legacy_backend.extract_question_person(rows, question) or ""
        best = BenefitFacts(subject=asked_person)
        best_score = -1
        for row in rows:
            content = legacy_backend.compact_text(row.get("content"))
            title = legacy_backend.compact_text(row.get("title"))
            text = f"{title}\n{content}"
            facts = self._extract_facts_from_text(text, rows, asked_person)
            score = self._score_facts(facts, question)
            if score > best_score:
                best = facts
                best_score = score

        if asked_person and not best.subject:
            best.subject = asked_person
        return best

    def _answer_by_intent(self, intent: str, facts: BenefitFacts) -> str | None:
        citation = self._citation_sentence(facts)
        if intent == "receiver":
            if not facts.receiver:
                return None
            relation = f", {facts.relation}" if facts.relation else ""
            return f"Người nhận trợ cấp là {facts.receiver}{relation}. {citation}"

        if intent == "total_amount":
            if not facts.total_amount:
                return None
            target = f" cho {facts.subject}" if facts.subject else ""
            answer = f"Tổng trợ cấp được cấp{target} là {facts.total_amount}."
            if facts.receiver:
                answer += f" Người nhận trợ cấp là {facts.receiver}."
            return f"{answer} {citation}"

        if intent == "file_number":
            if not facts.record_number:
                return None
            return f"Hồ sơ liên quan là hồ sơ số {facts.record_number}. {citation}"

        if intent == "file_lookup":
            return self._answer_file_lookup(facts)

        if intent == "decision":
            if not facts.decision_number:
                return None
            date_text = f" ngày {facts.decision_date}" if facts.decision_date else ""
            record_text = f", theo hồ sơ số {facts.record_number}" if facts.record_number else ""
            return f"Quyết định liên quan là Quyết định số {facts.decision_number}{date_text}{record_text}."

        if intent == "paid_amount":
            if not facts.paid_amount:
                return None
            target = f" của {facts.subject}" if facts.subject else ""
            return f"Khoản đã hưởng{target} là {facts.paid_amount}. {citation}"

        if intent == "remaining_amount":
            if not facts.remaining_amount:
                return None
            target = f" cho {facts.subject}" if facts.subject else ""
            return f"Khoản chênh lệch/còn lại cấp thêm{target} là {facts.remaining_amount}. {citation}"

        if intent == "settlement_status":
            return self._answer_settlement_status(facts)

        return None

    def _answer_file_lookup(self, facts: BenefitFacts) -> str | None:
        if not facts.record_number:
            return None
        person = facts.receiver or facts.subject
        citation = self._citation_sentence(facts)
        if person and facts.total_amount:
            return (
                f"Hồ sơ số {facts.record_number} là của {person}. "
                f"Tổng trợ cấp được cấp là {facts.total_amount}. {citation}"
            )
        if facts.total_amount:
            return (
                f"Hồ sơ số {facts.record_number} có tổng trợ cấp là {facts.total_amount}. "
                "Tuy nhiên, dữ liệu hiện chưa trích được rõ tên người trong hồ sơ này."
            )
        if person:
            return f"Hồ sơ số {facts.record_number} là của {person}. {citation}"
        return f"Hiện chưa có đủ dữ liệu trong hệ thống để xác định hồ sơ số {facts.record_number}."

    def _answer_settlement_status(self, facts: BenefitFacts) -> str | None:
        if facts.settlement_done:
            target = f"Đối với hồ sơ của {facts.subject}, " if facts.subject else ""
            return (
                f"{target}hồ sơ thể hiện đã quyết toán xong, không còn khoản nào cần chi trả "
                f"hoặc thu hồi thêm. {self._citation_sentence(facts)}"
            )
        if not any([facts.paid_amount, facts.remaining_amount]):
            return None
        target = f"Đối với hồ sơ của {facts.subject}, " if facts.subject else ""
        details = []
        if facts.paid_amount:
            details.append(f"khoản đã hưởng {facts.paid_amount}")
        if facts.remaining_amount:
            details.append(f"khoản chênh lệch cấp thêm {facts.remaining_amount}")
        if details:
            answer = f"{target}hồ sơ thể hiện " + " và ".join(details) + "."
        else:
            return None
        answer += f" {self._citation_sentence(facts)}"
        return answer

    def _extract_facts_from_text(self, text: str, rows: list[dict[str, object]], asked_person: str = "") -> BenefitFacts:
        normalized = legacy_backend.normalize_for_search(text)
        facts = BenefitFacts(primary_text=text)
        facts.record_number = legacy_backend.extract_record_number(text) or ""
        facts.decision_number = legacy_backend.extract_decision_number(text) or ""
        facts.decision_date = legacy_backend.extract_issued_date(text) or ""
        facts.citation = legacy_backend.build_citation(rows, text)
        facts.receiver = self._first_match(
            text,
            [
                r"Trợ cấp\s+(?:một|1|01)\s+lần\s+đối\s+với\s+(?:Ông|Bà)?\s*([^;.\n]+)",
                r"Nay trợ cấp cho:\s*(?:ông,\s*bà:|Ông\s*\(Bà\)\s*:|Ông|Bà)?\s*\**\s*([^*\n.-]+?)\s*\**\s*(?:-|;|\.)",
                r"Họ và tên:\s*\**\s*([^*\n-]+?)\s*\**\s*-",
                r"Nay trợ cấp cho:\s*(?:Ông\s*\(Bà\)\s*:)?\s*\**\s*([^*\n.-]+?)\s*\**\s*-",
                r"Họ tên người đứng nhận tiền[^.\n]*?\s+([A-ZÀ-Ỹ][A-ZÀ-Ỹa-zà-ỹ\s]+?)\s+Năm sinh",
            ],
        )
        facts.subject = asked_person or self._extract_subject(text)
        if facts.receiver and facts.subject:
            relation = self._extract_relation(text)
            facts.relation = f"{relation} của {facts.subject}" if relation else f"con của {facts.subject}"

        facts.total_amount = self._extract_family_total(text)
        facts.paid_amount = self._extract_family_paid(text)
        facts.remaining_amount = self._extract_family_remaining(text)
        facts.settlement_done = any(
            marker in normalized
            for marker in [
                "da quyet toan xong",
                "da quyet toan",
                "quyet toan xong",
                "tat toan xong",
                "khong con khoan",
                "khong phai chi tra",
                "khong phai thu hoi",
            ]
        )

        if not facts.total_amount:
            total_match = re.search(
                r"(?:tổng\s+cộng|mức\s+trợ\s+cấp\s*(?:1|01|một)\s*lần\s*(?:là)?|trợ\s+cấp\s*(?:01|1|một)\s*lần\s*số\s+tiền)\s*[:=]?\s*\**\s*(\d{1,3}(?:[.,]\d{3})+|\d{4,})\s*(?:đ|đồng)?",
                text,
                flags=re.IGNORECASE,
            )
            if total_match:
                facts.total_amount = legacy_backend.format_vnd(total_match.group(1))

        if not facts.paid_amount:
            facts.paid_amount = legacy_backend.extract_amount_after_marker(
                text,
                ["da huong", "da chi", "da nhan", "gia dinh da huong"],
            ) or ""

        if not facts.remaining_amount:
            facts.remaining_amount = legacy_backend.extract_amount_after_marker(
                text,
                ["chenh lech", "cap them", "con lai", "con thuc cap", "thuc cap"],
            ) or ""

        if not facts.subject and "nguoi huong" in normalized:
            facts.subject = legacy_backend.extract_person_name(text, "")
        return facts

    def _score_facts(self, facts: BenefitFacts, question: str) -> int:
        score = 0
        normalized_text = legacy_backend.normalize_for_search(facts.primary_text)
        normalized_question = legacy_backend.normalize_for_search(question)
        if facts.subject and legacy_backend.normalize_for_search(facts.subject) in normalized_question:
            score += 12
        if "tong cong ii" in normalized_text:
            score += 10
        for value, weight in [
            (facts.receiver, 4),
            (facts.total_amount, 4),
            (facts.record_number, 3),
            (facts.decision_number, 3),
            (facts.remaining_amount, 2),
            (facts.paid_amount, 2),
        ]:
            if value:
                score += weight
        return score

    def _citation_sentence(self, facts: BenefitFacts) -> str:
        if facts.citation:
            return f"Thông tin này căn cứ {facts.citation}."
        return "Thông tin này căn cứ dữ liệu trích từ tài liệu OCR."

    def _extract_family_total(self, text: str) -> str:
        return self._amount_from_pattern(
            r"Tổng cộng\s*II\s*=.*?=\s*(\d{1,3}(?:[.,]\d{3})+|\d{4,})\s*(?:đ|đồng)?",
            text,
        )

    def _extract_family_paid(self, text: str) -> str:
        return self._amount_from_pattern(
            r"Tổng cộng\s*I\s*=.*?=\s*(\d{1,3}(?:[.,]\d{3})+|\d{4,})\s*(?:đ|đồng)?",
            text,
        )

    def _extract_family_remaining(self, text: str) -> str:
        return self._amount_from_pattern(
            r"Số tiền chênh lệch cấp thêm[^=]*=\s*(\d{1,3}(?:[.,]\d{3})+|\d{4,})\s*(?:đ|đồng)?",
            text,
        )

    def _amount_from_pattern(self, pattern: str, text: str) -> str:
        match = re.search(pattern, text, flags=re.IGNORECASE | re.DOTALL)
        return legacy_backend.format_vnd(match.group(1)) if match else ""

    def _extract_subject(self, text: str) -> str:
        subject = self._first_match(
            text,
            [
                r"Là:\s*\**\s*(?:con|vợ|chồng|cha|mẹ)\s+của[^:]*:\s*([^*]+?)\s+(?:chết|từ trần|hy sinh)",
                r"Là:\s*\**\s*(?:con|vợ|chồng|cha|mẹ)\s+của\s+(?:ông|bà)?\s*([^*]+?)\s+(?:chết|từ trần|hy sinh)",
                r"thân nhân người có công\s*CM\s*:\s*([^;.\n]+)",
                r"Họ và tên người (?:có công|từ trần)\s*:?\s*([A-ZÀ-Ỹ][A-ZÀ-Ỹa-zà-ỹ\s]+)",
            ],
        )
        return re.sub(r"\s+", " ", subject).strip(" .,;:*")

    def _extract_relation(self, text: str) -> str:
        normalized = legacy_backend.normalize_for_search(text)
        for relation in ["con", "vo", "chong", "cha", "me"]:
            if f"la {relation} cua" in normalized or f"{relation} cua" in normalized:
                return {
                    "con": "con",
                    "vo": "vợ",
                    "chong": "chồng",
                    "cha": "cha",
                    "me": "mẹ",
                }[relation]
        return ""

    def _first_match(self, text: str, patterns: list[str]) -> str:
        for pattern in patterns:
            match = re.search(pattern, text, flags=re.IGNORECASE | re.DOTALL)
            if match:
                value = legacy_backend.compact_text(match.group(1).replace("*", ""))
                value = re.sub(r"\s+", " ", value).strip(" .,;:*")
                if value:
                    return value
        return ""
