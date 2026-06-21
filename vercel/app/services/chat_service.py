from __future__ import annotations

import json
import logging
import re
import subprocess
import urllib.error

from app import legacy_backend
from app.config import MCP_BASE_MODEL, OLLAMA_MODEL, VIRTUAL_MCP_MODEL
from app.models.schemas import ChatResult
from app.repositories.chat_history_repo import ChatHistoryRepository
from app.repositories.ocr_repo import OCRRepository
from app.services.context_service import ContextService
from app.services.deterministic_answer_service import DeterministicAnswerService
from app.services.memory_service import MemoryService
from app.services.mcp_service import MCPService
from app.services.ollama_service import OllamaService
from app.utils.extract_utils import contains_decision_number, extract_decision_number, extract_file_number, normalize_decision_number
from app.utils.text_utils import clean_answer_for_intent, detect_question_intent, normalize_question


logger = logging.getLogger(__name__)


class ChatService:
    def __init__(self) -> None:
        self.history_repo = ChatHistoryRepository()
        self.ocr_repo = OCRRepository()
        self.context_service = ContextService()
        self.deterministic_service = DeterministicAnswerService()
        self.ollama_service = OllamaService()
        self.mcp_service = MCPService()
        self.memory_service = MemoryService()

    def ask(self, question: str, model: str | None = None, session_id: str | None = None) -> ChatResult:
        requested_model = (model or OLLAMA_MODEL).strip() or OLLAMA_MODEL
        use_mcp_mode = requested_model == VIRTUAL_MCP_MODEL
        actual_ollama_model = MCP_BASE_MODEL if use_mcp_mode else requested_model
        mcp_used = False
        tools_used: list[str] = []
        deterministic_used = False
        logger.info(
            "requested_model=%s actual_ollama_model=%s use_mcp_mode=%s",
            requested_model,
            actual_ollama_model,
            use_mcp_mode,
        )
        session_id = self.history_repo.ensure_session(session_id, question)
        self.history_repo.update_title_from_question(session_id, question)
        previous_history = self.history_repo.get_messages(session_id)
        normalized_question = normalize_question(question)
        original_intent = detect_question_intent(normalized_question)
        memory_context = self.memory_service.load_memory_context(session_id, question)
        explicit_file_number = extract_file_number(question)
        explicit_decision_number = extract_decision_number(question) or ""
        if explicit_decision_number and original_intent == "follow_up_expand":
            original_intent = "decision_people_lookup"
        last_decision_number = self._last_decision_number(session_id)
        logger.info(
            "detected_intent=%s extracted_decision_number=%s last_decision_number_from_memory=%s",
            original_intent,
            explicit_decision_number,
            last_decision_number,
        )
        question_person = self._extract_question_person(question)
        subject = (
            ""
            if explicit_file_number
            else question_person or self._resolve_subject(session_id, question, memory_context, previous_history)
        )
        file_number = explicit_file_number or ("" if question_person else self._resolve_file_number(session_id, question, memory_context))
        logger.info(
            "extracted_file_number=%s detected_intent=%s resolved_subject=%s resolved_file_number=%s",
            explicit_file_number or "",
            original_intent,
            subject,
            file_number,
        )
        if original_intent == "context_correction" and subject and not self._explicit_file_number(question):
            file_number = ""
        effective_question = question
        intent = original_intent
        if original_intent == "follow_up_expand":
            last_intent = self._last_user_intent(session_id, previous_history)
            decision_number = last_decision_number
            if decision_number and last_intent in {"decision_people_lookup", "decision", "general", "follow_up_expand"}:
                self.history_repo.add_message(session_id, "user", question)
                sql, rows, people, answer = self._decision_people_lookup_answer(decision_number, expand=True)
                sources = self.context_service.build_sources(rows)
                self.history_repo.add_message(session_id, "assistant", answer, {"sources": sources, "sql": sql})
                self._save_memory(
                    session_id,
                    question,
                    answer,
                    sources,
                    sql,
                    question,
                    "follow_up_expand",
                    original_intent,
                    subject,
                    file_number,
                    decision_number,
                    people,
                    rows,
                )
                logger.info(
                    "search_mode=exact_decision_number context_matched_decision_number=%s number_of_people_found=%s",
                    bool(rows),
                    len(people),
                )
                logger.info(
                    "deterministic_used=%s mcp_used=%s ocr_rows=%s",
                    True,
                    mcp_used,
                    len(rows),
                )
                return self._chat_result(
                    answer,
                    session_id,
                    sources,
                    requested_model,
                    actual_ollama_model,
                    use_mcp_mode,
                    mcp_used=mcp_used,
                    tools_used=tools_used,
                )

            answer = "Bạn muốn tôi ghi đầy đủ nội dung nào? Vui lòng cho biết số hồ sơ hoặc số quyết định cần tra cứu."
            self.history_repo.add_message(session_id, "user", question)
            self.history_repo.add_message(session_id, "assistant", answer, {"sources": [], "sql": ""})
            self.memory_service.save_interaction(
                session_id,
                question,
                answer,
                {
                    "sources": [],
                    "sql": "",
                    "search_question": question,
                    "intent": "follow_up_expand",
                    "original_intent": original_intent,
                    "resolved_subject": subject,
                    "resolved_file_number": file_number,
                    "memory": {
                        "last_user_intent": "follow_up_expand",
                        "last_user_question": question,
                    },
                },
            )
            logger.info(
                "search_mode=follow_up_no_context context_matched_decision_number= number_of_people_found=0"
            )
            logger.info(
                "deterministic_used=%s mcp_used=%s ocr_rows=%s",
                True,
                mcp_used,
                0,
            )
            return self._chat_result(
                answer,
                session_id,
                [],
                requested_model,
                actual_ollama_model,
                use_mcp_mode,
                mcp_used=mcp_used,
                tools_used=tools_used,
            )
        if original_intent == "context_correction":
            last_question = self._last_user_question(session_id, previous_history)
            last_intent = self._last_user_intent(session_id, previous_history)
            if last_question:
                effective_question = last_question
                intent = last_intent or detect_question_intent(normalize_question(last_question))
            else:
                answer = self._context_correction_confirmation(subject, file_number)
                self.history_repo.add_message(session_id, "user", question)
                self.history_repo.add_message(session_id, "assistant", answer, {"sources": [], "sql": ""})
                self.memory_service.save_interaction(
                    session_id,
                    question,
                    answer,
                    {
                        "sources": [],
                        "sql": "",
                        "search_question": question,
                        "intent": original_intent,
                        "resolved_subject": subject,
                        "memory": {
                            "current_person": subject,
                            "current_file_number": file_number,
                            "current_topic": "",
                            "last_user_intent": "",
                            "last_user_question": "",
                        },
                    },
                )
                logger.info(
                    "deterministic_used=%s mcp_used=%s ocr_rows=%s",
                    True,
                    mcp_used,
                    0,
                )
                return self._chat_result(
                    answer,
                    session_id,
                    [],
                    requested_model,
                    actual_ollama_model,
                    use_mcp_mode,
                    mcp_used=mcp_used,
                    tools_used=tools_used,
                )

        self.history_repo.add_message(session_id, "user", question)
        history = self.history_repo.get_messages(session_id)

        if intent == "decision_people_lookup" and explicit_decision_number:
            sql, rows, people, answer = self._decision_people_lookup_answer(explicit_decision_number, expand=False)
            sources = self.context_service.build_sources(rows)
            self.history_repo.add_message(session_id, "assistant", answer, {"sources": sources, "sql": sql})
            self._save_memory(
                session_id,
                question,
                answer,
                sources,
                sql,
                question,
                intent,
                original_intent,
                subject,
                file_number,
                explicit_decision_number,
                people,
                rows,
            )
            logger.info(
                "search_mode=exact_decision_number context_matched_decision_number=%s number_of_people_found=%s",
                bool(rows),
                len(people),
            )
            logger.info(
                "deterministic_used=%s mcp_used=%s ocr_rows=%s",
                True,
                mcp_used,
                len(rows),
            )
            return self._chat_result(
                answer,
                session_id,
                sources,
                requested_model,
                actual_ollama_model,
                use_mcp_mode,
                mcp_used=mcp_used,
                tools_used=tools_used,
            )

        search_question = (
            effective_question
            if explicit_file_number or explicit_decision_number
            else self._resolve_search_question(session_id, effective_question, intent, subject, history)
        )
        if original_intent == "context_correction" and subject:
            search_question = f"{effective_question} (liên quan đến {subject})"
            if file_number:
                search_question += f" (hồ sơ {file_number})"
        if intent == "settlement_status" and subject:
            search_question = (
                f"{effective_question} {subject} "
                "phiếu điều chỉnh trợ cấp Tổng cộng II chênh lệch cấp thêm đã hưởng"
            )
            if file_number:
                search_question += f" hồ sơ {file_number}"

        search_mode = "general_search"
        if file_number:
            search_mode = "exact_file_number"
            sql, rows = self.ocr_repo.search_by_file_number(file_number)
        elif explicit_decision_number:
            search_mode = "exact_decision_number"
            sql, rows = self.ocr_repo.search_by_decision_number(explicit_decision_number)
        else:
            sql, rows = self.ocr_repo.search(search_question)
        logger.info("search_mode=%s", search_mode)
        logger.info("ocr_rows=%s", len(rows))
        logger.debug(
            "selected_sources=%s",
            [
                {
                    "source_table": row.get("source_table"),
                    "source_id": row.get("source_id"),
                    "page_no": row.get("page_no"),
                }
                for row in rows
            ],
        )
        rows = self._filter_rows_for_subject(rows, subject, file_number)
        if explicit_decision_number:
            rows = self._filter_rows_for_decision_number(rows, explicit_decision_number)
        if search_question != question and not (subject or file_number):
            anchors = self.memory_service.search_anchor_values(session_id)
            if anchors and not self.memory_service.rows_match_anchors(rows, anchors):
                rows = []
        document_context = self.context_service.build_context(rows, search_question, file_number=file_number)
        if not self.validate_context_matches_subject(document_context, subject, file_number):
            rows = []
            document_context = ""
        if explicit_decision_number and not self.validate_context_matches_decision_number(document_context, explicit_decision_number):
            rows = []
            document_context = ""
        logger.info(
            "context_matched_file_number=%s",
            self.context_service.validate_context_matches_file_number(document_context, file_number)
            if file_number
            else "",
        )
        logger.info(
            "context_matched_decision_number=%s",
            self.validate_context_matches_decision_number(document_context, explicit_decision_number)
            if explicit_decision_number
            else "",
        )
        sources = self.context_service.build_sources(rows)

        if not document_context:
            answer = self._fallback_for_intent(intent, file_number)
        else:
            answer = self.deterministic_service.answer(
                search_question,
                rows,
                intent,
                resolved_subject=subject,
                file_number=file_number,
            )
            deterministic_used = bool(answer)
            if not answer:
                context = self._compose_context(
                    intent,
                    memory_context,
                    history,
                    document_context,
                    subject,
                    file_number,
                    effective_question,
                )
                prompt_history = self._prompt_history(history)
                enriched_context = context
                if use_mcp_mode:
                    enriched_context, mcp_metadata = self.mcp_service.run_mcp_mode(
                        effective_question,
                        context,
                        prompt_history,
                        sources=sources,
                        actual_model=actual_ollama_model,
                    )
                    mcp_used = bool(mcp_metadata.get("mcp_available"))
                    tools_used = list(mcp_metadata.get("tools_used") or [])
                try:
                    answer = self.ollama_service.ask(effective_question, enriched_context, actual_ollama_model)
                except (TimeoutError, urllib.error.URLError, subprocess.TimeoutExpired, json.JSONDecodeError) as exc:
                    answer = f"Không xử lý được câu hỏi lúc này. Vui lòng kiểm tra Ollama. Chi tiết: {exc}"
        answer = clean_answer_for_intent(answer or legacy_backend.FALLBACK_ANSWER, intent)
        memory_snapshot_builder = getattr(self.memory_service, "build_memory_snapshot", None)
        memory_snapshot = (
            memory_snapshot_builder(
                effective_question,
                answer,
                rows,
                sources,
                subject=subject,
                intent=intent,
                decision_number=explicit_decision_number,
                file_number=file_number,
            )
            if memory_snapshot_builder
            else {}
        )
        self.history_repo.add_message(session_id, "assistant", answer, {"sources": sources, "sql": sql})
        self.memory_service.save_interaction(
            session_id,
            question,
            answer,
            {
                "sources": sources,
                "sql": sql,
                "search_question": search_question,
                "intent": intent,
                "original_intent": original_intent,
                "resolved_subject": subject,
                "resolved_file_number": file_number,
                "memory": memory_snapshot,
            },
        )
        logger.info(
            "deterministic_used=%s mcp_used=%s ocr_rows=%s",
            deterministic_used,
            mcp_used,
            len(rows),
        )
        return self._chat_result(
            answer,
            session_id,
            sources,
            requested_model,
            actual_ollama_model,
            use_mcp_mode,
            mcp_used=mcp_used,
            tools_used=tools_used,
        )

    def _chat_result(
        self,
        answer: str,
        session_id: str,
        sources: list[dict[str, object]],
        requested_model: str,
        actual_model: str,
        use_mcp_mode: bool,
        mcp_used: bool = False,
        tools_used: list[str] | None = None,
    ) -> ChatResult:
        return ChatResult(
            answer=answer,
            session_id=session_id,
            sources=sources,
            requested_model=requested_model,
            actual_model=actual_model,
            mode="mcp" if use_mcp_mode else "normal",
            mcp_used=mcp_used,
            tools_used=tools_used or [],
        )

    def _decision_people_lookup_answer(
        self,
        decision_number: str,
        expand: bool = False,
    ) -> tuple[str, list[dict[str, object]], list[dict[str, str]], str]:
        normalized = normalize_decision_number(decision_number)
        sql, rows = self.ocr_repo.search_by_decision_number(normalized)
        rows = self._filter_rows_for_decision_number(rows, normalized)
        people = self.ocr_repo.get_people_by_decision_number(normalized) if rows else []
        if not rows or not people:
            answer = (
                "Hiện chưa có đủ dữ liệu trong hệ thống để liệt kê đầy đủ các cá nhân liên quan đến "
                f"Quyết định số {normalized}."
            )
            return sql, rows, [], answer

        heading = f"Quyết định số {normalized} liên quan đến các cá nhân sau:"
        lines = [heading]
        if expand:
            for index, person in enumerate(people, start=1):
                item_text = str(
                    person.get("detail")
                    or person.get("display_name")
                    or person.get("name")
                    or ""
                ).strip()
                if item_text:
                    lines.append(f"{index}. {item_text}")
            return sql, rows, people, "\n".join(lines)
        if len(people) > 5:
            preview_people = people[:3] + people[-1:]
            for index, person in enumerate(preview_people, start=1):
                if index == 4:
                    lines.append("...")
                    actual_index = len(people)
                else:
                    actual_index = index
                display_name = str(person.get("display_name") or person.get("name") or "").strip()
                if display_name:
                    lines.append(f"{actual_index}. {display_name}")
            lines.append("")
            lines.append(
                "Tất cả những người này đã được Chủ tịch nước truy tặng danh hiệu Anh hùng "
                "Lực lượng vũ trang nhân dân."
            )
            return sql, rows, people, "\n".join(lines)
        for index, person in enumerate(people, start=1):
            display_name = str(person.get("display_name") or person.get("name") or "").strip()
            if display_name:
                lines.append(f"{index}. {display_name}")
        return sql, rows, people, "\n".join(lines)

    def _save_memory(
        self,
        session_id: str,
        question: str,
        answer: str,
        sources: list[dict[str, object]],
        sql: str,
        search_question: str,
        intent: str,
        original_intent: str,
        subject: str,
        file_number: str,
        decision_number: str,
        result_items: list[object],
        rows: list[dict[str, object]],
    ) -> None:
        memory_snapshot_builder = getattr(self.memory_service, "build_memory_snapshot", None)
        memory_snapshot = (
            memory_snapshot_builder(
                search_question,
                answer,
                rows,
                sources,
                subject=subject,
                intent=intent,
                decision_number=decision_number,
                file_number=file_number,
                result_items=result_items,
            )
            if memory_snapshot_builder
            else {}
        )
        self.memory_service.save_interaction(
            session_id,
            question,
            answer,
            {
                "sources": sources,
                "sql": sql,
                "search_question": search_question,
                "intent": intent,
                "original_intent": original_intent,
                "resolved_subject": subject,
                "resolved_file_number": file_number,
                "resolved_decision_number": decision_number,
                "memory": memory_snapshot,
            },
        )

    def _compose_context(
        self,
        intent: str,
        memory_context: str,
        history: list[dict[str, object]],
        document_context: str,
        subject: str = "",
        file_number: str = "",
        question: str = "",
    ) -> str:
        parts = [f"[Ý ĐỊNH CÂU HỎI]\n{intent}"]
        if file_number:
            parts.append(f"[SỐ HỒ SƠ NGƯỜI DÙNG HỎI]\n{file_number}")
        if subject or file_number:
            subject_lines = ["[CHỦ THỂ ĐANG HỎI]"]
            if subject:
                subject_lines.append(subject)
            if file_number:
                subject_lines.append(f"Hồ sơ số: {file_number}")
            subject_lines.append("Chỉ dùng context tài liệu khớp chủ thể này để trả lời.")
            parts.append("\n".join(subject_lines))
        if memory_context:
            parts.append(memory_context)
        history_lines = []
        for message in history[:-1][-4:]:
            if message.get("role") != "user":
                continue
            content = legacy_backend.compact_text(message.get("content"), 180)
            if content:
                history_lines.append(f"Người dùng từng hỏi: {content}")
        if history_lines:
            parts.append("[LỊCH SỬ CHAT GẦN NHẤT - TÓM TẮT NGẮN]\n" + "\n".join(history_lines))
        parts.append("[CONTEXT TÀI LIỆU]\n" + document_context)
        if question:
            parts.append("[CÂU HỎI NGƯỜI DÙNG]\n" + question)
        parts.append(
            "[YÊU CẦU TRẢ LỜI]\n"
            f"Trả lời đúng intent {intent}. Không lặp lại thông tin không được hỏi. "
            "Không copy nguyên câu trả lời cũ trong lịch sử. "
            "Không dùng thông tin ngoài context tài liệu. Không lấy thông tin của người khác. "
            "Nếu context tài liệu không khớp chủ thể đã resolve, hãy báo chưa đủ dữ liệu. "
            "Nếu người dùng hỏi số hồ sơ cụ thể, chỉ trả lời khi context chứa đúng số hồ sơ đó; "
            "không dùng memory để thay thế số hồ sơ trong câu hỏi và không lấy dữ liệu hồ sơ khác. "
            "Nếu người dùng hỏi 'ghi đủ ra', 'nói tiếp', 'liệt kê đầy đủ', phải mở rộng câu trả lời trước đó "
            "và không tự chuyển sang quyết định khác. Nếu câu hỏi có số quyết định cụ thể, ưu tiên số đó tuyệt đối. "
            "Không dùng dữ liệu của quyết định khác; nếu context không khớp số quyết định, hãy báo chưa đủ dữ liệu. "
            "Nếu intent là settlement_status, chỉ trả lời tình trạng khoản chi trả/thu hồi/quyết toán; "
            "không trả lời sang danh hiệu, tiểu sử hoặc thông tin tổng quan."
        )
        return "\n\n".join(parts)

    def _resolve_subject(
        self,
        session_id: str,
        question: str,
        memory_context: str,
        history: list[dict[str, object]],
    ) -> str:
        resolver = getattr(self.memory_service, "resolve_question_subject", None)
        if not resolver:
            return ""
        return resolver(session_id, question, memory_context, history)

    def _extract_question_person(self, question: str) -> str:
        extractor = getattr(self.memory_service, "_find_known_person_name", None)
        if not extractor:
            return ""
        return extractor(question)

    def _resolve_file_number(self, session_id: str, question: str, memory_context: str) -> str:
        resolver = getattr(self.memory_service, "resolve_question_file_number", None)
        if not resolver:
            return ""
        return resolver(session_id, question, memory_context)

    def _resolve_search_question(
        self,
        session_id: str,
        question: str,
        intent: str,
        subject: str,
        history: list[dict[str, object]],
    ) -> str:
        try:
            return self.memory_service.resolve_question_for_search(
                session_id,
                question,
                intent=intent,
                subject=subject,
                history=history,
            )
        except TypeError:
            return self.memory_service.resolve_question_for_search(session_id, question)

    def _last_user_question(self, session_id: str, previous_history: list[dict[str, object]]) -> str:
        getter = getattr(self.memory_service, "get_last_user_question", None)
        if getter:
            return getter(session_id, previous_history)
        for message in reversed(previous_history):
            if message.get("role") == "user":
                content = legacy_backend.compact_text(message.get("content"))
                if content and detect_question_intent(normalize_question(content)) != "context_correction":
                    return content
        return ""

    def _last_user_intent(self, session_id: str, previous_history: list[dict[str, object]]) -> str:
        getter = getattr(self.memory_service, "get_last_user_intent", None)
        if getter:
            return getter(session_id, previous_history)
        question = self._last_user_question(session_id, previous_history)
        return detect_question_intent(normalize_question(question)) if question else ""

    def _last_decision_number(self, session_id: str) -> str:
        getter = getattr(self.memory_service, "get_last_decision_number", None)
        if getter:
            return getter(session_id)
        return ""

    def validate_context_matches_subject(
        self,
        context: str,
        resolved_subject: str = "",
        file_number: str = "",
    ) -> bool:
        if not context:
            return False
        if file_number:
            return self.context_service.validate_context_matches_file_number(context, file_number)
        normalized_context = legacy_backend.normalize_for_search(context)
        subject_norm = legacy_backend.normalize_for_search(resolved_subject)
        if subject_norm:
            return subject_norm in normalized_context
        return True

    def validate_context_matches_decision_number(self, context: str, decision_number: str = "") -> bool:
        if not decision_number:
            return True
        if not context:
            return False
        target = normalize_decision_number(decision_number)
        if not contains_decision_number(context, target):
            return False
        found = self._extract_all_decision_numbers(context)
        return not found or all(item == target for item in found)

    def _filter_rows_for_subject(
        self,
        rows: list[dict[str, object]],
        subject: str = "",
        file_number: str = "",
    ) -> list[dict[str, object]]:
        subject_norm = legacy_backend.normalize_for_search(subject)
        if not subject_norm and not file_number:
            return rows

        matched = []
        for row in rows:
            text = legacy_backend.normalize_for_search(f"{row.get('title', '')}\n{row.get('content', '')}")
            raw_text = f"{row.get('title', '')}\n{row.get('content', '')}"
            if file_number:
                if self.context_service.validate_context_matches_file_number(raw_text, file_number):
                    matched.append(row)
                continue
            if subject_norm:
                if subject_norm in text:
                    matched.append(row)
                continue
        return matched

    def _filter_rows_for_decision_number(
        self,
        rows: list[dict[str, object]],
        decision_number: str = "",
    ) -> list[dict[str, object]]:
        target = normalize_decision_number(decision_number)
        if not target:
            return rows
        matched = []
        for row in rows:
            text = f"{row.get('title', '')}\n{row.get('content', '')}"
            if not contains_decision_number(text, target):
                continue
            row_decisions = self._extract_all_decision_numbers(text)
            if row_decisions and any(item != target for item in row_decisions):
                continue
            matched.append(row)
        return matched

    def _extract_all_decision_numbers(self, text: str) -> list[str]:
        pattern = (
            r"(?:Quyết\s*định|Quyet\s*dinh|Q[ĐD]|Số|So)?\s*(?:số|so)?\s*[:：]?\s*"
            r"([0-9]{1,5}\s*/\s*(?:QĐ|QD|UBND|LĐTBXH|LDTBXH|SLĐTBXH|SLDTBXH|CTN)[0-9A-ZĐa-zđ./-]*)"
        )
        values = []
        for match in re.finditer(pattern, text or "", flags=re.IGNORECASE):
            value = normalize_decision_number(match.group(1))
            if value and value not in values:
                values.append(value)
        return values

    def _explicit_file_number(self, question: str) -> str:
        extractor = getattr(self.memory_service, "extract_question_file_number", None)
        if extractor:
            return extractor(question)
        terms = legacy_backend.extract_record_terms(question)
        return terms[0] if terms else ""

    def _fallback_for_intent(self, intent: str, file_number: str = "") -> str:
        if file_number:
            return f"Hiện chưa có đủ dữ liệu trong hệ thống để xác định hồ sơ số {file_number}."
        if intent == "settlement_status":
            return "Hiện chưa có đủ dữ liệu trong hệ thống để xác định khoản còn phải chi trả hoặc thu hồi đối với hồ sơ này."
        return legacy_backend.FALLBACK_ANSWER

    def _context_correction_confirmation(self, subject: str, file_number: str) -> str:
        if subject and file_number:
            return f"Tôi đã chuyển ngữ cảnh sang {subject}, hồ sơ số {file_number}. Bạn muốn tra cứu thông tin nào trong hồ sơ này?"
        if subject:
            return f"Tôi đã chuyển ngữ cảnh sang {subject}. Bạn muốn tra cứu thông tin nào trong hồ sơ này?"
        if file_number:
            return f"Tôi đã chuyển ngữ cảnh sang hồ sơ số {file_number}. Bạn muốn tra cứu thông tin nào trong hồ sơ này?"
        return "Tôi đã ghi nhận bạn đang sửa ngữ cảnh, nhưng chưa xác định được người hoặc số hồ sơ cần tra cứu."

    def _prompt_history(self, history: list[dict[str, object]]) -> list[dict[str, object]]:
        prompt_history = []
        for message in history[:-1][-4:]:
            if message.get("role") != "user":
                continue
            prompt_history.append({**message, "content": legacy_backend.compact_text(message.get("content"), 180)})
        return prompt_history
