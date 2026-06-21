import json
import sys
import tempfile
import threading
import unittest
import urllib.request
from http.server import ThreadingHTTPServer
from pathlib import Path
from unittest.mock import patch

import chatbot_server as chatbot
import app.main as app_main
from app.database import ensure_database
from app.repositories.chat_history_repo import ChatHistoryRepository
from app.repositories.memory_repo import MemoryRepository
from app.services.chat_service import ChatService
from app.services.memory_service import MemoryService
from app.utils.extract_utils import extract_decision_number, extract_file_number
from app.utils.text_utils import detect_question_intent, normalize_question


FORBIDDEN_LABELS = ("Câu hỏi:", "Trả lời:", "Lời giải:", "Đáp án:")


class MinimalMemoryService:
    def load_memory_context(self, session_id, question):
        return ""

    def resolve_question_for_search(self, session_id, question, **kwargs):
        return question

    def search_anchor_values(self, session_id):
        return []

    def rows_match_anchors(self, rows, anchors):
        return True

    def build_memory_snapshot(self, *args, **kwargs):
        return {}

    def save_interaction(self, session_id, user_message, assistant_message, metadata=None):
        return None


class NonDeterministicOCR:
    def search(self, question):
        return (
            "fake sql",
            [
                {
                    "source_table": "raw_pages",
                    "source_id": 999,
                    "page_no": 1,
                    "title": "Trang OCR test",
                    "content": "Nội dung thử nghiệm không có mẫu trả lời deterministic.",
                }
            ],
        )


class TrackingOllama:
    def __init__(self, answer="Câu trả lời từ Ollama test."):
        self.calls = []
        self.answer = answer

    def ask(self, question, context, model=None):
        self.calls.append({"question": question, "context": context, "model": model})
        return self.answer


class NullDeterministic:
    def answer(self, *args, **kwargs):
        return None


def clear_memori_modules() -> None:
    for name in list(sys.modules):
        if name == "memori" or name.startswith("memori."):
            del sys.modules[name]


class ChatbotBackendTests(unittest.TestCase):
    def setUp(self) -> None:
        ensure_database()

    def test_extract_file_number_and_citation(self) -> None:
        ocr_text = (
            "Số: 59 /QĐ-SLĐTBXH Tân An, ngày 19 tháng 10 năm 2010 "
            "Số hồ sơ: LA/AH: 59"
        )
        self.assertEqual(chatbot.extract_file_number(ocr_text), "LA/AH: 59")
        rows = [
            {
                "source_table": "raw_pages",
                "source_id": 10,
                "page_no": 10,
                "title": "Trang OCR 10",
                "content": ocr_text,
            }
        ]
        self.assertIn("theo hồ sơ số LA/AH: 59", chatbot.build_citation(rows, ocr_text))

    def test_file_number_variants_extract_to_same_value(self) -> None:
        variants = [
            "LA/AH: 59",
            "LA/AH 59",
            "LA/AH:59",
            "Số hồ sơ: LA/AH: 59",
        ]
        for variant in variants:
            self.assertEqual(extract_file_number(variant), "LA/AH: 59")

    def test_file_lookup_uses_exact_file_number_search(self) -> None:
        class TrackingOCR:
            def __init__(self):
                self.called_with = []

            def search_by_file_number(self, file_number):
                self.called_with.append(file_number)
                return (
                    "exact sql",
                    [
                        {
                            "source_table": "raw_pages",
                            "source_id": 10,
                            "page_no": 10,
                            "title": "Trang OCR 10",
                            "content": (
                                "Số: 59 /QĐ-SLĐTBXH Tân An, ngày 19 tháng 10 năm 2010 "
                                "Số hồ sơ: LA/AH: 59. Trợ cấp một lần đối với Bà Trần Thị Nuôi; "
                                "Mức trợ cấp 1 lần là: 13.700.000 đ"
                            ),
                        }
                    ],
                )

            def search(self, question):
                raise AssertionError("general search must not be used when question has a file number")

        repo = ChatHistoryRepository()
        session = repo.create_session("Exact file lookup")
        session_id = str(session["id"])
        try:
            service = ChatService()
            tracking_ocr = TrackingOCR()
            service.ocr_repo = tracking_ocr
            result = service.ask("Hồ sơ LA/AH: 59 là của ai và được trợ cấp bao nhiêu?", session_id=session_id)
            self.assertEqual(tracking_ocr.called_with, ["LA/AH: 59"])
            self.assertIn("Hồ sơ số LA/AH: 59", result.answer)
            self.assertIn("Trần Thị Nuôi", result.answer)
            self.assertIn("13.700.000 đồng", result.answer)
            for label in FORBIDDEN_LABELS:
                self.assertNotIn(label, result.answer)
        finally:
            repo.delete_session(session_id)

    def test_file_lookup_ignores_memory_person_when_file_number_is_explicit(self) -> None:
        repo = ChatHistoryRepository()
        session = repo.create_session("Explicit file beats memory")
        session_id = str(session["id"])
        try:
            MemoryRepository().upsert_memory(
                session_id,
                "conversation_context",
                "current_person",
                "Nguyễn Văn Chiếu",
            )
            MemoryRepository().upsert_memory(
                session_id,
                "conversation_context",
                "current_file_number",
                "57/QĐ-LĐTBXH",
            )
            result = ChatService().ask("Hồ sơ LA/AH: 59 là của ai và được trợ cấp bao nhiêu?", session_id=session_id)
            self.assertIn("Hồ sơ số LA/AH: 59", result.answer)
            self.assertIn("Trần Thị Nuôi", result.answer)
            self.assertNotIn("Nguyễn Văn Chiếu", result.answer)
            self.assertNotIn("Nguyễn Văn Chiêu", result.answer)
            self.assertNotIn("57/QĐ-LĐTBXH", result.answer)
        finally:
            repo.delete_session(session_id)

    def test_file_lookup_context_mismatch_returns_insufficient_data(self) -> None:
        class MismatchedOCR:
            def search_by_file_number(self, file_number):
                return (
                    "fake exact sql",
                    [
                        {
                            "source_table": "raw_pages",
                            "source_id": 1,
                            "page_no": 1,
                            "title": "Trang OCR 1",
                            "content": (
                                "Nay trợ cấp cho ông, bà: Nguyễn Văn Chiếu. "
                                "Số: 57 /QĐ-LĐTBXH. Tổng cộng: 5.800.000 đồng."
                            ),
                        }
                    ],
                )

        repo = ChatHistoryRepository()
        session = repo.create_session("File mismatch")
        session_id = str(session["id"])
        try:
            service = ChatService()
            service.ocr_repo = MismatchedOCR()
            result = service.ask("Hồ sơ LA/AH: 59 là của ai và được trợ cấp bao nhiêu?", session_id=session_id)
            self.assertIn("chưa có đủ dữ liệu", result.answer)
            self.assertIn("hồ sơ số LA/AH: 59", result.answer)
            self.assertNotIn("Nguyễn Văn Chiếu", result.answer)
            self.assertNotIn("57/QĐ-LĐTBXH", result.answer)
        finally:
            repo.delete_session(session_id)

    def test_clean_chat_answer_removes_forbidden_labels_and_english(self) -> None:
        answer = chatbot.clean_chat_answer(
            "Based on the documents provided, Trả lời: Tổng cộng 900000 đồng."
        )
        for label in FORBIDDEN_LABELS:
            self.assertNotIn(label, answer)
        self.assertNotIn("Based on the documents provided", answer)
        self.assertIn("900.000 đồng", answer)

    def test_cao_thi_mai_total_answer_is_short_and_cited(self) -> None:
        question = "Tổng trợ cấp được cấp cho Cao Thị Mai là bao nhiêu, ai là người nhận?"
        _, rows = chatbot.search_database(question)
        answer = chatbot.answer_family_adjustment_total(question, rows)
        self.assertIsNotNone(answer)
        assert answer is not None
        self.assertIn("900.000 đồng", answer)
        self.assertIn("Nguyễn Thị Quận", answer)
        self.assertIn("theo hồ sơ số LA/08", answer)
        for label in FORBIDDEN_LABELS:
            self.assertNotIn(label, answer)

    def test_chat_history_session_lifecycle(self) -> None:
        repo = ChatHistoryRepository()
        session = repo.create_session("Test session")
        session_id = str(session["id"])
        try:
            repo.add_message(session_id, "user", "Xin chào")
            repo.add_message(session_id, "assistant", "Chào bạn")
            messages = repo.get_messages(session_id)
            self.assertEqual([item["role"] for item in messages], ["user", "assistant"])
        finally:
            self.assertTrue(repo.delete_session(session_id))
        self.assertIsNone(repo.get_session(session_id))

    def test_chat_service_saves_user_and_assistant_messages(self) -> None:
        repo = ChatHistoryRepository()
        session = repo.create_session("Cuộc trò chuyện mới")
        session_id = str(session["id"])
        try:
            result = ChatService().ask(
                "Tổng trợ cấp được cấp cho Cao Thị Mai là bao nhiêu, ai là người nhận?",
                session_id=session_id,
            )
            self.assertEqual(result.session_id, session_id)
            self.assertIn("Nguyễn Thị Quận", result.answer)
            self.assertIn("theo hồ sơ số LA/08", result.answer)
            for label in FORBIDDEN_LABELS:
                self.assertNotIn(label, result.answer)

            messages = repo.get_messages(session_id)
            self.assertEqual(len(messages), 2)
            self.assertEqual(messages[0]["role"], "user")
            self.assertEqual(messages[1]["role"], "assistant")
        finally:
            repo.delete_session(session_id)

    def test_memory_resolves_follow_up_recipient_question(self) -> None:
        repo = ChatHistoryRepository()
        session = repo.create_session("Cuộc trò chuyện mới")
        session_id = str(session["id"])
        try:
            service = ChatService()
            first = service.ask(
                "Tổng trợ cấp được cấp cho Cao Thị Mai là bao nhiêu?",
                session_id=session_id,
            )
            self.assertIn("900.000 đồng", first.answer)

            memory_context = MemoryService().load_memory_context(session_id, "Ai là người nhận?")
            self.assertIn("Cao Thị Mai", memory_context)
            self.assertIn("LA/08", memory_context)

            follow_up = service.ask("Ai là người nhận?", session_id=session_id)
            self.assertIn("Nguyễn Thị Quận", follow_up.answer)
            self.assertIn("Cao Thị Mai", follow_up.answer)
            self.assertNotIn("Tổng trợ cấp được cấp", follow_up.answer)
            self.assertNotIn("900.000 đồng", follow_up.answer)
            for label in FORBIDDEN_LABELS:
                self.assertNotIn(label, follow_up.answer)
        finally:
            repo.delete_session(session_id)

    def test_intent_classifier_basic_cases(self) -> None:
        self.assertEqual(detect_question_intent("Ai là người nhận?"), "receiver")
        self.assertEqual(detect_question_intent("Tổng trợ cấp là bao nhiêu?"), "total_amount")
        self.assertEqual(detect_question_intent("Số hồ sơ là gì?"), "file_number")
        self.assertEqual(detect_question_intent("Quyết định số mấy?"), "decision")
        self.assertEqual(detect_question_intent("Khoản chênh lệch là bao nhiêu?"), "remaining_amount")
        self.assertEqual(detect_question_intent("Đã hưởng bao nhiêu?"), "paid_amount")
        self.assertEqual(detect_question_intent("Hồ sơ LA/AH: 59 là của ai?"), "file_lookup")
        self.assertEqual(detect_question_intent("đang hỏi về Cao Thị Mai mà"), "context_correction")
        self.assertEqual(detect_question_intent("còn khoản nào cần chi trả hay thu nữa không"), "settlement_status")
        self.assertEqual(detect_question_intent("còn khoản thu chi nào nữa không"), "settlement_status")
        self.assertEqual(detect_question_intent("quyết toán hết chưa"), "settlement_status")
        self.assertEqual(detect_question_intent("ghi đủ ra"), "follow_up_expand")
        self.assertEqual(
            detect_question_intent("Quyết định số 212/QĐ-CTN liên quan đến những ai?"),
            "decision_people_lookup",
        )
        self.assertIn("chi tra hoac thu hoi", normalize_question("còn khoản thu chi nào nữa không"))

    def test_decision_number_variants_extract_to_same_value(self) -> None:
        variants = [
            "212/QĐ-CTN",
            "212/QD-CTN",
            "Quyết định số 212/QĐ-CTN",
            "số 212/QĐ-CTN",
            "QD 212/QD-CTN",
        ]
        for variant in variants:
            self.assertEqual(extract_decision_number(variant), "212/QĐ-CTN")

    def test_decision_people_direct_uses_exact_decision_number(self) -> None:
        class TrackingOCR:
            def __init__(self):
                self.called_with = []

            def search_by_decision_number(self, decision_number):
                self.called_with.append(decision_number)
                return (
                    "exact decision sql",
                    [
                        {
                            "source_table": "raw_pages",
                            "source_id": 9,
                            "page_no": 9,
                            "title": "Trang OCR 9",
                            "content": (
                                "DANH SÁCH TRUY TẶNG ANH HÙNG LỰC LƯỢNG VŨ TRANG NHÂN DÂN "
                                "(Kèm theo Quyết định số 212/QĐ-CTN ngày 23/2/2010). "
                                "1) Liệt sỹ Đỗ Công Thương. 2) Liệt sỹ Lê Văn Khuê."
                            ),
                        }
                    ],
                )

            def get_people_by_decision_number(self, decision_number):
                self.called_with.append(f"people:{decision_number}")
                return [
                    {"display_name": "Liệt sĩ Đỗ Công Thương", "name": "Đỗ Công Thương"},
                    {"display_name": "Liệt sĩ Lê Văn Khuê", "name": "Lê Văn Khuê"},
                ]

        repo = ChatHistoryRepository()
        session = repo.create_session("Decision people direct")
        session_id = str(session["id"])
        try:
            service = ChatService()
            tracking_ocr = TrackingOCR()
            service.ocr_repo = tracking_ocr
            result = service.ask("Quyết định số 212/QĐ-CTN liên quan đến những ai?", session_id=session_id)
            self.assertEqual(tracking_ocr.called_with, ["212/QĐ-CTN", "people:212/QĐ-CTN"])
            self.assertIn("Quyết định số 212/QĐ-CTN", result.answer)
            self.assertIn("Liệt sĩ Đỗ Công Thương", result.answer)
            self.assertIn("Liệt sĩ Lê Văn Khuê", result.answer)
            self.assertNotIn("...", result.answer)
        finally:
            repo.delete_session(session_id)

    def test_follow_up_expand_reuses_previous_decision_number(self) -> None:
        repo = ChatHistoryRepository()
        session = repo.create_session("Decision follow-up expand")
        session_id = str(session["id"])
        try:
            service = ChatService()
            first = service.ask("Quyết định số 212/QĐ-CTN liên quan đến những ai?", session_id=session_id)
            self.assertIn("Quyết định số 212/QĐ-CTN", first.answer)
            self.assertIn("...", first.answer)

            follow_up = service.ask("ghi đủ ra", session_id=session_id)
            self.assertEqual(detect_question_intent("ghi đủ ra"), "follow_up_expand")
            self.assertIn("Quyết định số 212/QĐ-CTN", follow_up.answer)
            self.assertIn("Liệt sĩ Đỗ Công Thương", follow_up.answer)
            self.assertIn("nguyên Ủy viên quân sự", follow_up.answer)
            self.assertIn("Ông Hồ Ngọc", follow_up.answer)
            self.assertNotIn("Quyết định số 58/QĐ-SLĐTBXH", follow_up.answer)
            self.assertNotIn("Nguyễn Văn Báo", follow_up.answer)
            self.assertNotIn("...", follow_up.answer)

            repeated_follow_up = service.ask("ghi đủ ra", session_id=session_id)
            self.assertIn("Quyết định số 212/QĐ-CTN", repeated_follow_up.answer)
            self.assertIn("nguyên Ủy viên quân sự", repeated_follow_up.answer)
            self.assertNotIn("Quyết định số 58/QĐ-SLĐTBXH", repeated_follow_up.answer)
            self.assertNotIn("Nguyễn Văn Báo", repeated_follow_up.answer)
        finally:
            repo.delete_session(session_id)

    def test_decision_people_context_mismatch_returns_insufficient_data(self) -> None:
        class MismatchedOCR:
            def search_by_decision_number(self, decision_number):
                return (
                    "fake exact decision sql",
                    [
                        {
                            "source_table": "raw_pages",
                            "source_id": 4,
                            "page_no": 4,
                            "title": "Trang OCR 4",
                            "content": (
                                "Số: 58 /QĐ-SLĐTBXH. Điều 1. Trợ cấp một lần đối với Ông Nguyễn Văn Báo. "
                                "Căn cứ Quyết định số 212/QĐ-CTN ngày 23 tháng 02 năm 2010."
                            ),
                        }
                    ],
                )

            def get_people_by_decision_number(self, decision_number):
                return [{"display_name": "Ông Nguyễn Văn Báo", "name": "Nguyễn Văn Báo"}]

        repo = ChatHistoryRepository()
        session = repo.create_session("Decision mismatch")
        session_id = str(session["id"])
        try:
            service = ChatService()
            service.ocr_repo = MismatchedOCR()
            result = service.ask("Quyết định số 212/QĐ-CTN liên quan đến những ai?", session_id=session_id)
            self.assertIn("chưa có đủ dữ liệu", result.answer)
            self.assertIn("Quyết định số 212/QĐ-CTN", result.answer)
            self.assertNotIn("Nguyễn Văn Báo", result.answer)
            self.assertNotIn("58/QĐ-SLĐTBXH", result.answer)
        finally:
            repo.delete_session(session_id)

    def test_follow_up_file_number_answer_is_focused(self) -> None:
        repo = ChatHistoryRepository()
        session = repo.create_session("File follow-up")
        session_id = str(session["id"])
        try:
            service = ChatService()
            first = service.ask(
                "Tổng trợ cấp được cấp cho Cao Thị Mai là bao nhiêu?",
                session_id=session_id,
            )
            self.assertIn("900.000 đồng", first.answer)

            follow_up = service.ask("Số hồ sơ là gì?", session_id=session_id)
            self.assertIn("hồ sơ số LA/08", follow_up.answer)
            self.assertNotIn("Tổng trợ cấp được cấp", follow_up.answer)
            self.assertNotIn("900.000 đồng", follow_up.answer)
            for label in FORBIDDEN_LABELS:
                self.assertNotIn(label, follow_up.answer)
        finally:
            repo.delete_session(session_id)

    def test_follow_up_decision_answer_is_focused(self) -> None:
        repo = ChatHistoryRepository()
        session = repo.create_session("Decision follow-up")
        session_id = str(session["id"])
        try:
            service = ChatService()
            first = service.ask(
                "Tổng trợ cấp được cấp cho Cao Thị Mai là bao nhiêu?",
                session_id=session_id,
            )
            self.assertIn("900.000 đồng", first.answer)

            follow_up = service.ask("Quyết định số mấy?", session_id=session_id)
            self.assertIn("Quyết định số 08/LĐTBXH.BC", follow_up.answer)
            self.assertIn("20/04/2006", follow_up.answer)
            self.assertNotIn("Tổng trợ cấp được cấp", follow_up.answer)
            self.assertNotIn("900.000 đồng", follow_up.answer)
            for label in FORBIDDEN_LABELS:
                self.assertNotIn(label, follow_up.answer)
        finally:
            repo.delete_session(session_id)

    def test_memory_only_subject_resolves_follow_up_without_name(self) -> None:
        repo = ChatHistoryRepository()
        session = repo.create_session("Memory subject")
        session_id = str(session["id"])
        try:
            MemoryRepository().upsert_memory(
                session_id,
                "conversation_context",
                "current_person",
                "Cao Thị Mai",
            )
            MemoryRepository().upsert_memory(
                session_id,
                "conversation_context",
                "record_number",
                "LA/08",
            )
            result = ChatService().ask("Ai là người nhận?", session_id=session_id)
            self.assertIn("Nguyễn Thị Quận", result.answer)
            self.assertNotIn("900.000 đồng", result.answer)
        finally:
            repo.delete_session(session_id)

    def test_settlement_follow_up_stays_on_cao_thi_mai(self) -> None:
        repo = ChatHistoryRepository()
        session = repo.create_session("Settlement follow-up")
        session_id = str(session["id"])
        try:
            service = ChatService()
            first = service.ask(
                "Tổng trợ cấp được cấp cho Cao Thị Mai là bao nhiêu?",
                session_id=session_id,
            )
            self.assertIn("Cao Thị Mai", first.answer)
            follow_up = service.ask("còn khoản nào cần chi trả hay thu nữa không", session_id=session_id)
            self.assertIn("Cao Thị Mai", follow_up.answer)
            self.assertIn("750.000 đồng", follow_up.answer)
            self.assertIn("150.000 đồng", follow_up.answer)
            self.assertNotIn("Nguyễn Văn Chiếu", follow_up.answer)
            self.assertNotIn("57/QĐ-LĐTBXH", follow_up.answer)
        finally:
            repo.delete_session(session_id)

    def test_equivalent_settlement_questions_return_same_business_facts(self) -> None:
        repo = ChatHistoryRepository()
        session = repo.create_session("Equivalent settlement")
        session_id = str(session["id"])
        try:
            service = ChatService()
            first = service.ask(
                "Tổng trợ cấp được cấp cho Cao Thị Mai là bao nhiêu?",
                session_id=session_id,
            )
            self.assertIn("Cao Thị Mai", first.answer)

            variants = [
                service.ask("còn khoản thu chi nào nữa không", session_id=session_id).answer,
                service.ask("còn khoản nào cần chi trả hay thu nữa không", session_id=session_id).answer,
            ]
            for answer in variants:
                self.assertIn("Cao Thị Mai", answer)
                self.assertIn("750.000 đồng", answer)
                self.assertIn("150.000 đồng", answer)
                self.assertNotIn("Nguyễn Văn Chiếu", answer)
                self.assertNotIn("57/QĐ-LĐTBXH", answer)
            self.assertEqual(
                ("750.000 đồng" in variants[0], "150.000 đồng" in variants[0]),
                ("750.000 đồng" in variants[1], "150.000 đồng" in variants[1]),
            )
        finally:
            repo.delete_session(session_id)

    def test_context_correction_replays_last_question_with_new_subject(self) -> None:
        repo = ChatHistoryRepository()
        session = repo.create_session("Correction")
        session_id = str(session["id"])
        try:
            repo.add_message(session_id, "user", "còn khoản nào cần chi trả hay thu nữa không")
            repo.add_message(session_id, "assistant", "Thông tin nhầm theo Nguyễn Văn Chiếu.")
            memory_repo = MemoryRepository()
            memory_repo.upsert_memory(
                session_id,
                "conversation_context",
                "current_person",
                "Nguyễn Văn Chiếu",
            )
            memory_repo.upsert_memory(
                session_id,
                "conversation_context",
                "current_file_number",
                "57/QĐ-LĐTBXH",
            )
            memory_repo.upsert_memory(
                session_id,
                "conversation_context",
                "last_user_question",
                "còn khoản nào cần chi trả hay thu nữa không",
            )
            memory_repo.upsert_memory(
                session_id,
                "conversation_context",
                "last_user_intent",
                "settlement_status",
            )

            result = ChatService().ask("đang hỏi về Cao Thị Mai mà", session_id=session_id)
            self.assertIn("Cao Thị Mai", result.answer)
            self.assertIn("750.000 đồng", result.answer)
            self.assertIn("150.000 đồng", result.answer)
            self.assertNotIn("Nguyễn Văn Chiếu", result.answer)
            self.assertNotIn("57/QĐ-LĐTBXH", result.answer)
        finally:
            repo.delete_session(session_id)

    def test_subject_mismatch_context_returns_insufficient_data(self) -> None:
        class MismatchedOCR:
            def search(self, question):
                return (
                    "fake sql",
                    [
                        {
                            "source_table": "benefit_cases",
                            "source_id": 57,
                            "page_no": 1,
                            "title": "Nguyễn Văn Chiếu - tro_cap_mot_lan_va_truy_lanh",
                            "content": (
                                "Người hưởng: Nguyễn Văn Chiếu "
                                "Quyết định: 57/QĐ-LĐTBXH "
                                "Tổng tiền: 3.000.000 đồng"
                            ),
                        }
                    ],
                )

        repo = ChatHistoryRepository()
        session = repo.create_session("Mismatch")
        session_id = str(session["id"])
        try:
            MemoryRepository().upsert_memory(
                session_id,
                "conversation_context",
                "current_person",
                "Cao Thị Mai",
            )
            service = ChatService()
            service.ocr_repo = MismatchedOCR()
            result = service.ask("còn khoản nào cần chi trả hay thu nữa không", session_id=session_id)
            self.assertIn("chưa có đủ dữ liệu", result.answer)
            self.assertNotIn("Nguyễn Văn Chiếu", result.answer)
            self.assertNotIn("57/QĐ-LĐTBXH", result.answer)
        finally:
            repo.delete_session(session_id)

    def test_memory_anchor_without_document_context_does_not_fabricate(self) -> None:
        repo = ChatHistoryRepository()
        session = repo.create_session("Memory mismatch")
        session_id = str(session["id"])
        try:
            MemoryRepository().upsert_memory(
                session_id,
                "conversation_context",
                "current_person",
                "Người Không Có Trong Dữ Liệu",
            )
            result = ChatService().ask("Ai là người nhận?", session_id=session_id)
            self.assertEqual(result.answer, chatbot.FALLBACK_ANSWER)
        finally:
            repo.delete_session(session_id)

    def test_delete_session_clears_chat_history_and_memory(self) -> None:
        repo = ChatHistoryRepository()
        session = repo.create_session("Delete memory")
        session_id = str(session["id"])
        repo.add_message(session_id, "user", "Xin chào")
        MemoryRepository().upsert_memory(
            session_id,
            "conversation_context",
            "current_person",
            "Cao Thị Mai",
        )

        self.assertTrue(MemoryService().get_session_memory(session_id))
        self.assertTrue(repo.delete_session(session_id))
        self.assertIsNone(repo.get_session(session_id))
        self.assertEqual(MemoryService().get_session_memory(session_id), [])

    def test_chat_service_works_when_memory_unavailable(self) -> None:
        class DisabledMemory:
            def load_memory_context(self, session_id, question):
                return ""

            def resolve_question_for_search(self, session_id, question):
                return question

            def search_anchor_values(self, session_id):
                return []

            def rows_match_anchors(self, rows, anchors):
                return True

            def save_interaction(self, session_id, user_message, assistant_message, metadata=None):
                return None

        repo = ChatHistoryRepository()
        session = repo.create_session("Memory disabled")
        session_id = str(session["id"])
        try:
            service = ChatService()
            service.memory_service = DisabledMemory()
            result = service.ask(
                "Tổng trợ cấp được cấp cho Cao Thị Mai là bao nhiêu, ai là người nhận?",
                session_id=session_id,
            )
            self.assertIn("Nguyễn Thị Quận", result.answer)
        finally:
            repo.delete_session(session_id)

    def test_normal_model_is_passed_to_ollama(self) -> None:
        repo = ChatHistoryRepository()
        session = repo.create_session("Normal model")
        session_id = str(session["id"])
        try:
            service = ChatService()
            service.memory_service = MinimalMemoryService()
            service.ocr_repo = NonDeterministicOCR()
            service.deterministic_service = NullDeterministic()
            service.ollama_service = TrackingOllama()

            result = service.ask("Tóm tắt nội dung thử nghiệm này.", model="llama3:latest", session_id=session_id)

            self.assertEqual(service.ollama_service.calls[0]["model"], "llama3:latest")
            self.assertEqual(result.requested_model, "llama3:latest")
            self.assertEqual(result.actual_model, "llama3:latest")
            self.assertEqual(result.mode, "normal")
        finally:
            repo.delete_session(session_id)

    def test_virtual_mcp_model_uses_base_model_for_ollama(self) -> None:
        repo = ChatHistoryRepository()
        session = repo.create_session("MCP model")
        session_id = str(session["id"])
        try:
            service = ChatService()
            service.memory_service = MinimalMemoryService()
            service.ocr_repo = NonDeterministicOCR()
            service.deterministic_service = NullDeterministic()
            service.ollama_service = TrackingOllama()

            result = service.ask(
                "Tóm tắt nội dung thử nghiệm này.",
                model="ollama-mcp:latest",
                session_id=session_id,
            )

            self.assertEqual(service.ollama_service.calls[0]["model"], "llama3:latest")
            self.assertNotEqual(service.ollama_service.calls[0]["model"], "ollama-mcp:latest")
            self.assertEqual(result.requested_model, "ollama-mcp:latest")
            self.assertEqual(result.actual_model, "llama3:latest")
            self.assertEqual(result.mode, "mcp")
        finally:
            repo.delete_session(session_id)

    def test_mcp_unavailable_falls_back_without_crashing(self) -> None:
        repo = ChatHistoryRepository()
        session = repo.create_session("MCP unavailable")
        session_id = str(session["id"])
        try:
            service = ChatService()
            service.memory_service = MinimalMemoryService()
            service.ocr_repo = NonDeterministicOCR()
            service.deterministic_service = NullDeterministic()
            service.ollama_service = TrackingOllama("Fallback qua Ollama vẫn hoạt động.")

            result = service.ask(
                "Tóm tắt nội dung thử nghiệm này.",
                model="ollama-mcp:latest",
                session_id=session_id,
            )

            self.assertIn("Fallback qua Ollama", result.answer)
            self.assertFalse(result.mcp_used)
            self.assertEqual(result.tools_used, [])
            self.assertEqual(service.ollama_service.calls[0]["model"], "llama3:latest")
        finally:
            repo.delete_session(session_id)

    def test_deterministic_answer_is_prioritized_before_ollama_in_normal_and_mcp_modes(self) -> None:
        class FixedDeterministic:
            def __init__(self):
                self.calls = 0

            def answer(self, *args, **kwargs):
                self.calls += 1
                return "Câu trả lời deterministic."

        class FailingOllama:
            calls = []

            def ask(self, question, context, model=None):
                self.calls.append({"question": question, "context": context, "model": model})
                raise AssertionError("Ollama must not be called when deterministic answer exists")

        for model, expected_mode in [("llama3:latest", "normal"), ("ollama-mcp:latest", "mcp")]:
            repo = ChatHistoryRepository()
            session = repo.create_session(f"Deterministic {model}")
            session_id = str(session["id"])
            try:
                service = ChatService()
                service.memory_service = MinimalMemoryService()
                service.ocr_repo = NonDeterministicOCR()
                service.deterministic_service = FixedDeterministic()
                service.ollama_service = FailingOllama()

                result = service.ask("Tóm tắt nội dung thử nghiệm này.", model=model, session_id=session_id)

                self.assertEqual(result.answer, "Câu trả lời deterministic.")
                self.assertEqual(result.mode, expected_mode)
                self.assertFalse(result.mcp_used)
                self.assertEqual(service.ollama_service.calls, [])
                self.assertEqual(service.deterministic_service.calls, 1)
            finally:
                repo.delete_session(session_id)

    def test_memori_status_reports_missing_dependency_fallback(self) -> None:
        clear_memori_modules()
        with tempfile.TemporaryDirectory() as temp_dir:
            package_dir = Path(temp_dir) / "memori"
            package_dir.mkdir()
            (package_dir / "__init__.py").write_text(
                "import definitely_missing_memori_dependency\n",
                encoding="utf-8",
            )

            status = MemoryService(memori_dir=Path(temp_dir)).status()
            if temp_dir in sys.path:
                sys.path.remove(temp_dir)

        clear_memori_modules()
        self.assertFalse(status["available"])
        self.assertEqual(status["mode"], "fallback")
        self.assertIn("definitely_missing_memori_dependency", str(status["error"]))
        self.assertIn("pip install -r requirements.txt", str(status["suggestion"]))

    def test_memori_status_reports_available_when_import_succeeds(self) -> None:
        clear_memori_modules()
        with tempfile.TemporaryDirectory() as temp_dir:
            package_dir = Path(temp_dir) / "memori"
            package_dir.mkdir()
            (package_dir / "__init__.py").write_text("", encoding="utf-8")

            status = MemoryService(memori_dir=Path(temp_dir)).status()
            if temp_dir in sys.path:
                sys.path.remove(temp_dir)

        clear_memori_modules()
        self.assertTrue(status["available"])
        self.assertEqual(status["mode"], "memori-main")
        self.assertIsNone(status["error"])

    def test_memory_status_endpoint_returns_200_when_fallback(self) -> None:
        class FallbackMemoryService:
            def status(self):
                return {
                    "available": False,
                    "mode": "fallback",
                    "error": "No module named 'aiohttp'",
                    "suggestion": "Hãy chạy: pip install -r requirements.txt",
                }

        with patch.object(app_main, "MemoryService", FallbackMemoryService):
            server = ThreadingHTTPServer(("127.0.0.1", 0), app_main.AppHandler)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                url = f"http://127.0.0.1:{server.server_port}/api/memory/status"
                with urllib.request.urlopen(url, timeout=5) as response:
                    payload = json.loads(response.read().decode("utf-8"))
                    self.assertEqual(response.status, 200)
            finally:
                server.shutdown()
                server.server_close()
                thread.join(timeout=5)

        self.assertFalse(payload["available"])
        self.assertEqual(payload["mode"], "fallback")

    def test_chat_service_response_has_no_forbidden_labels(self) -> None:
        repo = ChatHistoryRepository()
        session = repo.create_session("No labels")
        session_id = str(session["id"])
        try:
            result = ChatService().ask(
                "Tổng trợ cấp được cấp cho Cao Thị Mai là bao nhiêu?",
                session_id=session_id,
            )
            for label in FORBIDDEN_LABELS:
                self.assertNotIn(label, result.answer)
        finally:
            repo.delete_session(session_id)


if __name__ == "__main__":
    unittest.main()
