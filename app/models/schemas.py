from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class ChatResult:
    answer: str
    session_id: str
    sources: list[dict[str, object]] = field(default_factory=list)
    requested_model: str = ""
    actual_model: str = ""
    mode: str = "normal"
    mcp_used: bool = False
    tools_used: list[str] = field(default_factory=list)
