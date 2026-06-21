from __future__ import annotations

import logging
import sys
from pathlib import Path

from app.config import CHATBOT_ENABLE_MCP, MCP_SERVER_DIR


logger = logging.getLogger(__name__)


class MCPService:
    """Safe wrapper for Adaptive Graph of Thoughts MCP integration.

    The bundled MCP server requires Python 3.11+, Poetry/FastAPI dependencies,
    and usually Neo4j. This wrapper detects availability and gracefully returns
    the original context when the MCP stack is not ready.
    """

    def __init__(self, server_dir: Path = MCP_SERVER_DIR) -> None:
        self.server_dir = server_dir
        self.enabled = CHATBOT_ENABLE_MCP
        self._reason = ""

    def is_available(self) -> bool:
        if not self.enabled:
            self._reason = "CHATBOT_ENABLE_MCP chưa bật."
            return False
        if not self.server_dir.exists():
            self._reason = f"Không tìm thấy MCP server: {self.server_dir}"
            return False
        if sys.version_info < (3, 11):
            self._reason = "Adaptive GoT MCP yêu cầu Python 3.11+."
            return False
        src_dir = self.server_dir / "src"
        if str(src_dir) not in sys.path:
            sys.path.insert(0, str(src_dir))
        try:
            import adaptive_graph_of_thoughts  # noqa: F401
        except Exception as exc:
            self._reason = f"Chưa import được adaptive_graph_of_thoughts: {exc}"
            return False
        return True

    def enrich_context(self, question: str, context: str, history: list[dict[str, object]]) -> str:
        if not self.is_available():
            logger.info("MCP fallback: %s", self._reason)
            return context
        try:
            # A full MCP tool call needs the server runtime and Neo4j. For this
            # chatbot, keep SQLite/OCR authoritative and only add lightweight
            # organization hints when the package is importable.
            recent = " | ".join(str(item.get("content", ""))[:120] for item in history[-4:])
            return (
                "[GỢI Ý SẮP XẾP NGỮ CẢNH TỪ MCP]\n"
                "Ưu tiên căn cứ có số hồ sơ, số quyết định, ngày ban hành; "
                "giữ câu trả lời ngắn gọn theo dữ liệu OCR.\n"
                f"Câu hỏi hiện tại: {question}\n"
                f"Lịch sử gần nhất: {recent}\n\n"
                f"{context}"
            )
        except Exception as exc:
            logger.exception("MCP enrich_context failed: %s", exc)
            return context

    def run_mcp_mode(
        self,
        question: str,
        context: str,
        history: list[dict[str, object]],
        sources: list[dict[str, object]] | None = None,
        actual_model: str = "",
    ) -> tuple[str, dict[str, object]]:
        metadata: dict[str, object] = {
            "mcp_requested": True,
            "mcp_available": False,
            "tools_used": [],
            "actual_model": actual_model,
        }
        try:
            if not self.is_available():
                logger.info("MCP mode fallback: %s", self._reason)
                return context, metadata

            recent = " | ".join(str(item.get("content", ""))[:120] for item in history[-4:])
            source_count = len(sources or [])
            enriched_context = (
                "[MCP MODE]\n"
                "- Ưu tiên dữ liệu SQLite/OCR đã tìm được.\n"
                "- Ưu tiên trả lời đúng intent câu hỏi.\n"
                "- Không lặp lại toàn bộ context.\n"
                "- Không suy đoán ngoài nguồn.\n"
                "- Nếu câu hỏi hỏi người thụ hưởng thì chỉ trả người thụ hưởng.\n"
                "- Nếu câu hỏi hỏi tổng tiền thì chỉ trả tổng tiền.\n"
                "- Nếu câu hỏi hỏi số quyết định thì chỉ trả số quyết định.\n"
                f"- Câu hỏi hiện tại: {question}\n"
                f"- Số nguồn OCR/SQLite: {source_count}\n"
                f"- Lịch sử gần nhất: {recent}\n\n"
                f"{context}"
            )
            metadata["mcp_available"] = True
            metadata["tools_used"] = ["mcp_context_enrich"]
            return enriched_context, metadata
        except Exception as exc:
            logger.exception("MCP run_mcp_mode failed: %s", exc)
            return context, metadata

    def status(self) -> dict[str, object]:
        available = self.is_available()
        return {"enabled": self.enabled, "available": available, "reason": self._reason}
