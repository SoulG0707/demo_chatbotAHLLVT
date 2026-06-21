# Chatbot AHLLTVT Long An

Đồ án xây dựng chatbot tra cứu hồ sơ Anh hùng lực lượng vũ trang nhân dân tỉnh Long An từ dữ liệu OCR đã lưu trong SQLite. Hệ thống có giao diện web đơn giản, lưu lịch sử hội thoại theo phiên, có trí nhớ ngữ cảnh ngắn hạn và có tích hợp thử nghiệm MCP Adaptive Graph of Thoughts để hỗ trợ sắp xếp ngữ cảnh trước khi gọi mô hình.

## Chức năng chính

- Tra cứu dữ liệu OCR trong `data/ocr_qa.db`.
- Trả lời theo dữ liệu hồ sơ, ưu tiên câu trả lời ngắn gọn và có căn cứ như số hồ sơ, số quyết định, ngày ban hành.
- Nhận diện một số câu hỏi xác định bằng logic deterministic trước khi gọi LLM.
- Gọi Ollama khi cần sinh câu trả lời từ ngữ cảnh tài liệu.
- Lưu lịch sử chat theo từng session.
- Lưu memory hội thoại trong `data/memory.db` để xử lý câu hỏi nối tiếp như "Ai là người nhận?".
- Tích hợp MCP ở mức an toàn: nếu MCP hoặc dependency chưa sẵn sàng thì hệ thống tự fallback về ngữ cảnh SQLite/OCR.
- Cung cấp API JSON cho giao diện web và kiểm thử.

## Công nghệ sử dụng

- Python 3.11
- SQLite
- Ollama, mặc định model `llama3:latest`
- HTML/CSS/JavaScript thuần cho giao diện
- MCP Adaptive Graph of Thoughts, bật bằng biến môi trường `CHATBOT_ENABLE_MCP=1`
- Memori-main được kiểm tra trạng thái SDK, nhưng runtime chính dùng SQLite memory riêng để ổn định khi chạy đồ án

## Cấu trúc thư mục

```text
app/
  main.py                         HTTP server, static server và API
  config.py                       Đường dẫn và biến môi trường cấu hình
  database.py                     Kết nối SQLite, khởi tạo bảng chat
  legacy_backend.py               Logic OCR/RAG/deterministic kế thừa
  prompts.py                      Prompt hệ thống cho chatbot
  models/
    schemas.py                    Dataclass kết quả chat
  repositories/
    ocr_repo.py                   Truy vấn dữ liệu OCR
    chat_history_repo.py          Lưu session và message
    memory_repo.py                Lưu memory hội thoại
  services/
    chat_service.py               Điều phối luồng hỏi đáp
    context_service.py            Tạo context và source metadata
    deterministic_answer_service.py
    ollama_service.py             Gọi Ollama
    memory_service.py             Xử lý trí nhớ hội thoại
    mcp_service.py                Tích hợp MCP có fallback
  utils/

static/
  chatbot.html                    Giao diện web chatbot

data/
  ocr_qa.db                       CSDL OCR chính
  ocr_qa.sql                      File SQL dữ liệu OCR
  memory.db                       CSDL memory hội thoại

tests/
  test_chatbot_backend.py         Unit test backend

Adaptive-Graph-of-Thoughts-MCP-server/
Memori-main/
run.py                            Entry chạy server hiện tại
chatbot_server.py                 Entry tương thích cũ
run_mcp.ps1                       Script chạy đồ án với MCP
install_mcp_deps.ps1              Script cài dependency MCP
requirements.txt                  Ghi chú dependency runtime chính
requirements-mcp.txt              Dependency cho MCP
```

## Yêu cầu trước khi chạy

1. Máy đã cài Python 3.11.
2. Đã có virtual environment `tfenv` trong thư mục dự án.
3. Đã cài Ollama và có model đang dùng, mặc định là:

```powershell
ollama pull llama3:latest
```

4. Nếu cần cài dependency MCP, chạy:

```powershell
.\tfenv\Scripts\Activate.ps1
.\install_mcp_deps.ps1
```

5. Cài dependency runtime chính, bao gồm dependency cần để probe Memori-main SDK:

```powershell
.\tfenv\Scripts\Activate.ps1
pip install -r requirements.txt
```

## Cách chạy

Mở PowerShell tại thư mục dự án:

```powershell
cd "D:\@_YenNgoc\Desktop\chatbot_AHLLTVT"
```

Active môi trường Python:

```powershell
.\tfenv\Scripts\Activate.ps1
```

Cài hoặc cập nhật dependency runtime:

```powershell
pip install -r requirements.txt
```

Chạy script khởi động đồ án:

```powershell
.\run_mcp.ps1
```

Script `run_mcp.ps1` sẽ:

- chuyển về đúng thư mục dự án;
- kiểm tra và active `tfenv`;
- dừng process cũ đang chiếm port `127.0.0.1:8000` nếu có;
- bật `CHATBOT_ENABLE_MCP=1`;
- chạy `python run.py`.

Sau khi server chạy, mở trình duyệt tại:

```text
http://127.0.0.1:8000/chatbot.html
```

Nếu PowerShell chặn chạy script, có thể mở quyền chạy script cho phiên hiện tại:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

## Cách chạy không bật MCP

Nếu chỉ muốn chạy chatbot với SQLite/OCR và memory, không bật MCP:

```powershell
.\tfenv\Scripts\Activate.ps1
python run.py
```

Hoặc entry cũ:

```powershell
python chatbot_server.py
```

## Biến môi trường cấu hình

| Biến | Mặc định | Ý nghĩa |
| --- | --- | --- |
| `CHATBOT_HOST` | `127.0.0.1` | Host chạy server |
| `CHATBOT_PORT` | `8000` | Port chạy server |
| `OLLAMA_MODEL` | `llama3:latest` | Model Ollama dùng để trả lời |
| `OCR_QA_DB` | `data/ocr_qa.db` | Đường dẫn SQLite OCR |
| `OCR_QA_SQL` | `data/ocr_qa.sql` | Đường dẫn file SQL OCR |
| `CHATBOT_ENABLE_MEMORY` | `1` | Bật/tắt memory hội thoại |
| `CHATBOT_MEMORY_DB` | `data/memory.db` | Đường dẫn SQLite memory |
| `CHATBOT_ENABLE_MCP` | `0` | Bật/tắt MCP |

Ví dụ đổi model:

```powershell
$env:OLLAMA_MODEL="llama3.1:8b"
.\run_mcp.ps1
```

Tắt memory:

```powershell
$env:CHATBOT_ENABLE_MEMORY="0"
python run.py
```

## API chính

- `GET /api/sessions`: danh sách phiên chat.
- `POST /api/sessions`: tạo phiên chat mới.
- `GET /api/sessions/{session_id}/messages`: lấy tin nhắn của một phiên.
- `DELETE /api/sessions/{session_id}`: xóa một phiên và memory liên quan.
- `DELETE /api/sessions`: xóa toàn bộ phiên và memory.
- `GET /api/sessions/{session_id}/memory`: xem memory của phiên.
- `DELETE /api/sessions/{session_id}/memory`: xóa memory của phiên.
- `GET /api/memory/status`: kiểm tra trạng thái memory.
- `GET /api/mcp/status`: kiểm tra trạng thái MCP.
- `POST /api/chat`: gửi câu hỏi cho chatbot.

Response trạng thái Memori-main khi thiếu dependency sẽ vẫn trả HTTP 200 để server không crash:

```json
{
  "available": false,
  "mode": "fallback",
  "error": "No module named 'aiohttp'",
  "suggestion": "Hãy chạy: pip install -r requirements.txt"
}
```

Request mẫu:

```json
{
  "question": "Tổng trợ cấp được cấp cho Cao Thị Mai là bao nhiêu?",
  "session_id": "optional-session-id",
  "model": "llama3:latest"
}
```

Response mẫu:

```json
{
  "answer": "...",
  "session_id": "...",
  "sources": [
    {
      "source_table": "raw_pages",
      "source_id": 10,
      "page_no": 10,
      "title": "Trang OCR 10",
      "record_number": "LA/AH: 59",
      "decision_number": "59/QĐ-SLĐTBXH",
      "issued_date": "19 tháng 10 năm 2010"
    }
  ]
}
```

## Luồng xử lý hỏi đáp

1. Giao diện gửi câu hỏi đến `POST /api/chat`.
2. `ChatService` tạo hoặc lấy session hiện tại.
3. Memory hội thoại được đọc để nhận diện câu hỏi nối tiếp.
4. Câu hỏi được dùng để tìm dữ liệu trong SQLite OCR.
5. Nếu có câu trả lời deterministic phù hợp, chatbot trả lời trực tiếp.
6. Nếu cần LLM, hệ thống build context tài liệu, enrich bằng MCP nếu khả dụng, rồi gọi Ollama.
7. Câu trả lời được làm sạch, lưu vào lịch sử chat và cập nhật memory.

## Kiểm thử

Chạy unit test:

```powershell
.\tfenv\Scripts\Activate.ps1
python -m unittest discover -s tests
```

Test hiện kiểm tra các phần chính:

- trích xuất số hồ sơ và citation;
- làm sạch nhãn trả lời không mong muốn;
- trả lời mẫu về trợ cấp của Cao Thị Mai;
- vòng đời session chat;
- lưu user message và assistant message;
- memory xử lý câu hỏi nối tiếp;
- không bịa khi memory không khớp tài liệu;
- xóa session đồng thời xóa memory;
- chatbot vẫn chạy khi memory không khả dụng.

## Ghi chú

- Dữ liệu chứng cứ chính luôn là SQLite/OCR trong `data/ocr_qa.db`.
- Memory chỉ dùng để hiểu ngữ cảnh hội thoại gần nhất, không thay thế dữ liệu hồ sơ.
- MCP đang được tích hợp theo hướng fallback an toàn để phù hợp môi trường đồ án. Khi MCP chưa import được hoặc thiếu dependency, chatbot vẫn hoạt động bằng SQLite/OCR và Ollama.
- File `chatbot_server.py` được giữ để tương thích với code/test cũ; entry nên dùng hiện tại là `run.py` hoặc script `run_mcp.ps1`.
