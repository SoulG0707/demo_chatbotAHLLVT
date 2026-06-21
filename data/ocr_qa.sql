PRAGMA foreign_keys = OFF;

DROP TABLE IF EXISTS source_files;
DROP TABLE IF EXISTS raw_pages;
DROP TABLE IF EXISTS persons;
DROP TABLE IF EXISTS organizations;
DROP TABLE IF EXISTS decisions;
DROP TABLE IF EXISTS honors;
DROP TABLE IF EXISTS relationships;
DROP TABLE IF EXISTS benefit_cases;
DROP TABLE IF EXISTS payment_periods;
DROP TABLE IF EXISTS raw_page_fts;

CREATE TABLE source_files (
    source_file_id INTEGER PRIMARY KEY,
    file_name TEXT NOT NULL,
    description TEXT
);

CREATE TABLE raw_pages (
    raw_page_id INTEGER PRIMARY KEY,
    source_file_id INTEGER NOT NULL,
    page_no INTEGER NOT NULL,
    page_marker TEXT,
    raw_text TEXT NOT NULL,
    FOREIGN KEY (source_file_id) REFERENCES source_files(source_file_id)
);

CREATE VIRTUAL TABLE raw_page_fts USING fts5(
    raw_text,
    content='raw_pages',
    content_rowid='raw_page_id'
);

CREATE TABLE persons (
    person_id INTEGER PRIMARY KEY,
    full_name TEXT NOT NULL,
    alias TEXT,
    gender TEXT,
    birth_year INTEGER,
    hometown TEXT,
    residence TEXT,
    person_type TEXT NOT NULL,
    notes TEXT
);

CREATE TABLE organizations (
    organization_id INTEGER PRIMARY KEY,
    organization_name TEXT NOT NULL,
    organization_type TEXT,
    location_text TEXT
);

CREATE TABLE decisions (
    decision_id INTEGER PRIMARY KEY,
    decision_number TEXT NOT NULL,
    title TEXT NOT NULL,
    issuer_org_id INTEGER,
    issued_date TEXT,
    decision_kind TEXT,
    source_page_id INTEGER,
    summary TEXT,
    FOREIGN KEY (issuer_org_id) REFERENCES organizations(organization_id),
    FOREIGN KEY (source_page_id) REFERENCES raw_pages(raw_page_id)
);

CREATE TABLE honors (
    honor_id INTEGER PRIMARY KEY,
    honored_person_id INTEGER NOT NULL,
    decision_id INTEGER NOT NULL,
    honor_title TEXT NOT NULL,
    action_type TEXT NOT NULL,
    campaign TEXT,
    notes TEXT,
    FOREIGN KEY (honored_person_id) REFERENCES persons(person_id),
    FOREIGN KEY (decision_id) REFERENCES decisions(decision_id)
);

CREATE TABLE relationships (
    relationship_id INTEGER PRIMARY KEY,
    person_id INTEGER NOT NULL,
    related_person_id INTEGER,
    related_person_name TEXT,
    relation_type TEXT NOT NULL,
    notes TEXT,
    FOREIGN KEY (person_id) REFERENCES persons(person_id),
    FOREIGN KEY (related_person_id) REFERENCES persons(person_id)
);

CREATE TABLE benefit_cases (
    case_id INTEGER PRIMARY KEY,
    beneficiary_person_id INTEGER NOT NULL,
    honored_person_id INTEGER,
    decision_id INTEGER NOT NULL,
    benefit_type TEXT NOT NULL,
    start_date TEXT,
    one_time_amount INTEGER,
    monthly_amount INTEGER,
    currency TEXT DEFAULT 'VND',
    status TEXT,
    notes TEXT,
    FOREIGN KEY (beneficiary_person_id) REFERENCES persons(person_id),
    FOREIGN KEY (honored_person_id) REFERENCES persons(person_id),
    FOREIGN KEY (decision_id) REFERENCES decisions(decision_id)
);

CREATE TABLE payment_periods (
    payment_period_id INTEGER PRIMARY KEY,
    case_id INTEGER NOT NULL,
    from_date TEXT,
    to_date TEXT,
    months_count INTEGER,
    monthly_amount INTEGER,
    total_amount INTEGER,
    description TEXT,
    FOREIGN KEY (case_id) REFERENCES benefit_cases(case_id)
);

BEGIN TRANSACTION;
INSERT INTO source_files (source_file_id, file_name, description) VALUES (1, 'markdown_file.md', 'OCR markdown source from image_cut.');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (1, 1, 1, '1', 'UBND TỈNH LONG AN  
SỞ LAO ĐỘNG THƯƠNG BINH  
VÀ XÃ HỘI

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

Tân An, ngày 20 tháng 02 năm 2006

Số: 57 /QĐ-LĐTBXH

### QUYẾT ĐỊNH

V/v trợ cấp Anh hùng Lực lượng vũ trang nhân dân

### GIÁM ĐỐC SỞ LAO ĐỘNG THƯƠNG BINH VÀ XÃ HỘI

Căn cứ Nghị định số 28/CP ngày 29 tháng 4 năm 1995 của Chính phủ hướng dẫn thi hành Pháp lệnh ưu đãi người hoạt động cách mạng, liệt sĩ và gia đình liệt sĩ, thương binh, bệnh binh, người hoạt động kháng chiến, người có công giúp đỡ cách mạng;

Căn cứ Quyết định số 5438/UB.QĐ ngày 28 tháng 11 năm 1995 của UBND tỉnh Long An, ủy quyền cho Sở Lao động-Thương binh và Xã hội tỉnh Long An, ký các quyết định thuộc lĩnh vực chính sách người có công;

Xét đề nghị của Ông Trưởng Phòng Chính sách TBLS,

### QUYẾT ĐỊNH:

**Điều 1.** Nay trợ cấp cho ông, bà: Nguyễn Văn Chiếu - Sinh năm: 1930  
Nguyễn quán: Mỹ Thành, Cai Lậy, Tiền Giang.

Chỗ ở hiện nay: Phường 6, thị xã Tân An, tỉnh Long An

Là Anh hùng Lực lượng vũ trang đã được Nhà nước Phong tặng danh hiệu  
Anh hùng Lực lượng vũ trang nhân dân, theo Quyết định số 634-24/06/2005.

Được hưởng trợ cấp kể từ ngày 01 tháng 06 năm 2005

Trợ cấp 01 lần số tiền: 3.000.000 đồng.

Truy lãnh trợ cấp từ:

- 01/06/2005 đến 30/09/2005, 4 tháng x 250.000 đ = 1.000.000 đồng.

- 01/10/2005 đến 31/03/2006, 6 tháng x 300.000 đ = 1.800.000 đồng.

Tổng cộng: **5.800.000 đồng (Năm triệu tám trăm ngàn đồng).**

**Điều 2.** Quyết định này có hiệu lực kể từ ngày ký.

**Điều 3.** Trưởng phòng Chính sách Thương binh Liệt sỹ, Trưởng phòng kế hoạch Tài vụ, Trưởng phòng Nội vụ Lao động TBXH thị xã Tân An và UBND Phường 6 và Ông Nguyễn Văn Chiếu thi hành quyết định này.

**Nơi nhận:**

- Như điều 3;

- Lưu VT.VPCS.

ĐQDahl - Nguye VanChie');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (2, 1, 2, '2', '**CHỦ TỊCH NƯỚC**

Số: 634 / 2005/QĐ/CTN

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM

Độc lập - Tự do - Hạnh phúc

Hà Nội, ngày 27 tháng 6 năm 2005

**QUYẾT ĐỊNH CỦA CHỦ TỊCH NƯỚC**

**Về việc Phong tặng danh hiệu Anh hùng Lực lượng vũ trang nhân dân**

**CHỦ TỊCH**

**NƯỚC CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM**

Căn cứ Điều 103 của Hiến pháp nước Cộng hòa xã hội chủ nghĩa Việt Nam năm 1992 đã được sửa đổi, bổ sung theo Nghị quyết số 51/2001/QH10 ngày 25 tháng 12 năm 2001 của Quốc hội khóa X, kỳ họp thứ 10;

Theo đề nghị của Thủ tướng Chính phủ tại Tờ trình số 737/TTg-TCCB ngày 06 tháng 6 năm 2005;

**QUYẾT ĐỊNH**

**Điều 1.** Phong tặng danh hiệu **Anh hùng Lực lượng vũ trang nhân dân** cho 12 huyện (thị xã); 143 xã (phường, thị trấn); 26 đơn vị và 04 cá nhân (có danh sách kèm theo).

Đã có thành tích đặc biệt xuất sắc trong cuộc kháng chiến chống Mỹ, cứu nước.

**Điều 2.** Quyết định này có hiệu lực thi hành từ ngày ký.

Thủ tướng Chính phủ, Chủ nhiệm Văn phòng Chủ tịch nước, các tập thể và cá nhân có tên trong danh sách chịu trách nhiệm thi hành Quyết định này.

**CHỦ TỊCH  
NƯỚC CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM**

*Trần Đức Lương*

Nơi nhận:

- Chính phủ,
- Văn phòng Chủ tịch nước,
- Ban Thị đưa - Khen thưởng TW,
- Lưu VT, Vụ ĐTKT-KTXH

Sep. 13 2005 03:48AM P2

FAX NO. : 08043170

FROM : BAN ĐTKT TU');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (3, 1, 3, '3', 'FROM : BINH THUYET TU

FILE NO. : 05043170

Sep. 13 2005 03:49 PM P1

**ANH SÁCH 04 CÁ NHÂN ĐƯỢC PHONG TẶNG  
THÀNH CHIẾU ANH HÙNG LƯỢC LƯỢNG VŨ TRANG NHÂN DÂN  
CÓ THÀNH TÍCH ĐẶC BIỆT XUẤT SẮC  
TRONG CUỘC KHÁNG CHIẾN CHỐNG MỸ, CỨU NƯỚC**  
(Kèm theo Quyết định số: 63\*/2005/QĐ/CTN ngày 29 tháng 6 năm 2005)

1. 1- Đồng chí: Nguyễn Văn Chiếu Sinh năm 1930. Dân tộc: Kinh  
   Quê quán: Mỹ Thành, Cai Lậy, Tiền Giang.  
   Nhập ngũ: 1950; Đảng viên  
   Chức vụ, đơn vị trong kháng chiến chống Mỹ: Tỉnh đội trưởng tỉnh đội  
   Long An.
2. 2- Đồng chí: Đoàn Tấn Khoa Sinh năm 1937 Dân tộc: Kinh  
   Quê quán: Ninh Quới, Hồng Dân, Bạc Liêu.  
   Tham gia cách mạng: 03/1956 ; Đảng viên  
   Chức vụ, đơn vị trong kháng chiến chống Mỹ: Bí thư huyện ủy huyện Mỹ  
   Xuyên, tỉnh Sóc Trăng.
3. 3- Đồng chí: Lưu Nguyệt Hồng Sinh năm 1950 Dân tộc: Kinh  
   Quê quán: Vĩnh Quới, Thanh Trì, Sóc Trăng.  
   Tham gia cách mạng: 1965; Đảng viên  
   Chức vụ, đơn vị trong kháng chiến chống Mỹ: Hội trưởng Hội Phụ nữ huyện  
   Thanh Trì, tỉnh Sóc Trăng.
4. 4- Đồng chí: Lê Văn Chữ (Nam Lôi) Sinh năm 1923 Dân tộc: Kinh  
   Quê quán: An Lạc Thôn, Kế Sách, Sóc Trăng.  
   Tham gia cách mạng: 7/1947; Đảng viên  
   Chức vụ, đơn vị trong kháng chiến chống Mỹ: Tỉnh đội trưởng Tỉnh đội  
   Trà Vinh.');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (4, 1, 4, '4', '584

UBND TỈNH LONG AN  
SỞ LAO ĐỘNG - THƯƠNG BINH  
VÀ XÃ HỘI

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

Số: 58 /QĐ-SLDTBXH

Tân An, ngày 25 tháng 5 năm 2010

Số hồ sơ: 58

**QUYẾT ĐỊNH**

**Về việc trợ cấp ưu đãi Anh hùng lực lượng vũ trang nhân dân**

**GIÁM ĐỐC SỞ LAO ĐỘNG THƯƠNG BINH VÀ XÃ HỘI**

Căn cứ Nghị định số 54/2006/NĐ-CP ngày 26 tháng 5 năm 2006 của Chính phủ hướng dẫn thi hành một số điều Pháp lệnh ưu đãi người có công với cách mạng;

Căn cứ Quyết định số 212/QĐ-CTN ngày 23 tháng 02 năm 2010 của Chủ tịch nước;

Căn cứ Nghị định số 38/2009/NĐ-CP ngày 23 tháng 4 năm 2009 của Chính phủ quy định về mức trợ cấp, phụ cấp ưu đãi đối với người có công với cách mạng;

Xét đề nghị của Trưởng Phòng Người có công;

**QUYẾT ĐỊNH:**

**Điều 1.** Trợ cấp một lần đối với Ông: Nguyễn Văn Báo Sinh năm: 1932 .

Nguyên quán: xã Đức Tân, huyện Tân Trù, tỉnh Long An.

Trú quán: xã Đức Tân, huyện Tân Trù, tỉnh Long An.

Là cha của Liệt sỹ Nguyễn Thị Bé (Nguyễn Hoàng Anh).

Nguyên quán: xã Đức Tân, huyện Tân Trù, tỉnh Long An.

Trú quán: xã Đức Tân, huyện Tân Trù, tỉnh Long An.

đã được truy tặng danh hiệu Anh hùng lực lượng vũ trang nhân dân, theo Quyết định số 212 /QĐ-CTN ngày 23 tháng 02 năm 2010 của Chủ tịch nước.

Mức trợ cấp 1 lần là: 13.700.000 đ

(Bằng chữ: Mười ba triệu bảy trăm ngàn đồng)

**Điều 2.** Trưởng Phòng Người có công, Trưởng Phòng Kế hoạch - Tài chính, Trưởng Phòng Lao động Thương binh Xã hội huyện Tân Trù và Ông Nguyễn Văn Báo có trách nhiệm thi hành quyết định này. *Lv*

**Nơi nhận:**

- - Như điều 2;
- - Lưu VT.

**KT. GIÁM ĐỐC**

PHÓ GIÁM ĐỐC

Nguyễn Văn Ghim');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (5, 1, 5, '5', '**UBND HUYỆN TÂN TRỤ  
PHÒNG LAO ĐỘNG- TB&XH**

**CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập – Tự do – hạnh phúc**

Số: 423/LĐ-TB&XH

Tân Trụ, ngày 17 tháng 5 năm 2010

V/v giải quyết chế độ tư đãi  
đối với Anh hùng LLVT nhân dân

**Kính gửi:** Sở Lao động TBXH tỉnh Long An

Căn cứ công văn số 630/CV SLĐTB&XH ngày 27/4/2010 của Sở Lao động Thương binh và Xã hội về việc giải quyết chế độ cho thân nhân Anh hùng Lực lượng vũ trang.

Phòng LĐTB&XH kính đề nghị Sở Lao động- TB&XH tỉnh Long An giải quyết chế độ trợ cấp cho thân nhân liệt sĩ Nguyễn Thị Bé (Nguyễn Hoàng Anh), nguyên Tiểu đội phó, Đội 198 Thanh niên xung phong, Tổng Đội Thanh niên xung phong Giải phóng miền Nam, quê quán xã Đức Tân, huyện Tân Trụ. Được truy tặng danh hiệu AHLLVTND theo Quyết định số 212/QĐ-CTN ngày 23 tháng 02 năm 2010 của Chủ tịch nước. (Kèm theo hồ sơ)

Kính đề nghị Sở LĐTB&XH xem xét giải quyết.

**Nơi nhận:**

- - Như trên;
- - UBND huyện;
- - Lưu

**Nguyễn Văn Thuận**');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (6, 1, 6, '6', '**ỦY BAN NHÂN DÂN  
XÃ ĐỨC TÂN**

\*\*\*

Số : *44* DN-UBND

*"Vv chế độ trợ cấp ưu đãi  
đối với Anh hùng LLVT nhân dân"*

**CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc.**

*Đức Tân, ngày 14 tháng 5 năm 2010*

**Kính gửi:** Ủy ban nhân dân huyện Tân Trụ  
Phòng lao động TB&XH huyện Tân Trụ.

Căn cứ quyết định số 212/QĐ-CTN ngày 23/02/2010 của Chủ tịch nước về việc truy tặng danh hiệu Anh hùng lực lượng vũ trang nhân dân.

Lợi sỹ Nguyễn Thị Bé (Nguyễn Hoàng Anh) nguyên tiểu đội phó, Đội 198 Thanh niên xung phong, Tổng đội Thanh niên xung phong giải phóng miền Nam huyện Đức Huệ, đã có thành tích đặc biệt xuất sắc trong cuộc kháng chiến chống Mỹ cứu nước, được Chủ tịch nước truy tặng danh hiệu Anh hùng Lực lượng vũ trang nhân dân ngày 23/02/2010

Nay UBND xã Đức Tân đề nghị UBND huyện, Phòng LĐTB &XH huyện xem xét giải quyết chế độ trợ cấp ưu đãi đối với Anh hùng Lực lượng vũ trang nhân dân Nguyễn Thị Bé. Người được hưởng chế độ trợ cấp là ông Nguyễn Văn Báo cha của Anh hùng Lực lượng vũ trang nhân dân

Rất mong UBND huyện, Phòng LĐTB &XH huyện sớm xem xét giải quyết chế độ cho thân nhân Anh hùng, giúp xã hoàn thành thốt nhiệm vụ./.

**Nơi nhận:**

- - UBND/huyện;
- - Phòng LĐTB&XH/h;
- - Lưu.

**TM.UBND XÃ ĐỨC TÂN  
CHỦ TỊCH**

**TRƯỞNG HIỆN ĐOÀN**');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (7, 1, 7, '7', '4

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc.

BẢNG KHAI VỀ NGƯỜI CÓ CÔNG

1. Phần khai về người có công:

Họ và tên: Nguyễn Thị Bích ... Nam (nữ) ... Năm sinh: 1958  
Nguyễn quán: ... ấp Bình Lợi ... Xã Tân ... Phường ... Long An  
Cơ quan, đơn vị công tác: ... Đại Thanh ... xã ... phường ...  
Nơi đăng ký hộ khẩu: ... ấp Bình Lợi ... Xã Tân ... Phường ... Long An  
Đã được tặng danh hiệu (Anh hùng LLVT, Anh hùng LD trong kháng chiến):  
... Anh hùng ... chiến ... chống ... xâm lược ...

Theo Quyết định số: 2212 ngày 23 tháng 02 năm 2010 của Chủ tịch nước.

2. Phần khai về thân nhân (người đứng khai):

Họ và tên: Nguyễn Văn Bá ... Năm sinh: 1932  
Nguyễn quán: ... ấp Bình Lợi ... Xã Tân ... Phường ... Long An  
Trú quán: ...  
Quang hệ với Anh hùng LLVT, Anh hùng LD trong kháng chiến: (vợ, chồng, cha, mẹ, con, ...) ... Cha ...  
Đã từ trần ngày ... tháng ... năm ...

Tôi xin cam đoan lời khai trên là đúng, nếu sai tôi xin hoàn toàn chịu trách nhiệm trước pháp luật./

Ông (bà) Nguyễn Văn Bá ...  
Hiện cư trú tại: ... ấp Bình Lợi ...  
... Xã Tân ... Phường ...  
chưa hưởng trợ cấp ưu đãi đối với  
Anh hùng LLVT, Anh hùng LD trong  
kháng chiến.

Ngày 14 tháng 5 năm 2010  
Người khai  
(Ký, ghi rõ họ tên)  
Bá Bá

Nguyễn Văn Bá

Đức Tân Ngày 14 tháng 5 năm 2010

TM. UBND XÃ  
CHỦ TỊCH

Trương Thiên Đôn');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (8, 1, 8, '8', 'BẢN SƠ

2010

22

CHỦ TỊCH  
CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM

Ngày 22 tháng 2 năm 2010

Quyết định số 23/2010/QĐ-TTg  
Ngày 22 tháng 2 năm 2010

QUYẾT ĐỊNH

Về việc truy tặng danh hiệu Anh hùng Lực lượng vũ trang nhân dân

CHỦ TỊCH

NUỐC CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM

Căn cứ Điều 103 của Hiến pháp nước Cộng hòa xã hội chủ nghĩa Việt Nam năm 1992;

Căn cứ Luật thi đua, khen thưởng;

Kết đề nghị của Thủ tướng Chính phủ tại Tờ trình số 295/TTrg-TCCV ngày 11 tháng 02 năm 2010.

QUYẾT ĐỊNH

**Điều 1.** Truy tặng danh hiệu Anh hùng Lực lượng vũ trang nhân dân cho:

1- 29 cá nhân (có danh sách kèm theo);

*Đã có thành tích đặc biệt xuất sắc trong cuộc kháng chiến chống thực dân Pháp xâm lược.*

2- 156 cá nhân (có danh sách kèm theo);

*Đã có thành tích đặc biệt xuất sắc trong cuộc kháng chiến chống Mỹ, cứu nước.*

**Điều 2.** Quyết định này có hiệu lực thi hành từ ngày ký.

Thủ tướng Chính phủ, Chủ nhiệm Văn phòng Chủ tịch nước chịu trách nhiệm thi hành Quyết định này.

Chứng trực tiến xem đúng với bản chính  
(Số: 22/2010/QĐ-TTg)

Đức Tân, ngày 11 tháng 5 năm 2010  
(CHỦ TỊCH CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM)

Nơi nhận:

- Chính phủ;
- Văn phòng Chủ tịch nước;
- Bản Tờ đưa - Kiến nghị;
- Lưu MT, Văn thư;

CHỦ TỊCH

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM

2. Minh

Nguyễn Minh Triết

Quang Thi Phương');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (9, 1, 9, '9', 'UBND TỈNH LONG AN  
SỞ LAO ĐỘNG THƯƠNG BINH  
VÀ XÃ HỘI

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

**DANH SÁCH TRUY TẠNG  
ANH HƯNG LỰC LƯỢNG VŨ TRANG NHÂN DÂN**  
(Kèm theo Quyết định số 212/QĐ-CTN ngày 23/2/2010 của Chủ tịch nước )

<table border="1"><tbody><tr><td>1)</td><td>Liệt sỹ Đỗ Công Thương, nguyên Ủy viên quân sự xã Phú Ngãi Trị huyện Châu Thành, tỉnh Long An</td></tr><tr><td>2)</td><td>Liệt sỹ Lê Văn Khuê, nguyên Chủ tịch Ủy ban hành chính kháng chiến xã Phước Tân Hưng, huyện Châu Thành</td></tr><tr><td>3)</td><td>Liệt sỹ Trương Văn Nhường, nguyên Giao liên xã Đức Lập Hạ, huyện Đức Hòa, tỉnh Long An.</td></tr><tr><td>4)</td><td>Liệt sỹ Nguyễn Thái Bình, nguyên sinh viên Việt Nam du học tại Mỹ . Quê xã Tân Kim, huyện Cần Giuộc, tỉnh Long An.</td></tr><tr><td>5)</td><td>Liệt sỹ Lê Văn Giao (Lê Hùng Minh), nguyên Trung Đội trưởng , Đội 198 Thanh niên xung phong, Tổng đội Thanh niên xung phong Giải phóng miền Nam huyện Đức Huệ</td></tr><tr><td>6)</td><td>Liệt sỹ Hồ Văn Ngà, nguyên Đội trưởng Đội công binh huyện Châu Thành, tỉnh Long An.</td></tr><tr><td>7)</td><td>Liệt sỹ Nguyễn Thị Bé (Nguyễn Hoàng Anh), nguyên Tiểu đội phó, Đội 198 Thanh niên xung phong, Tổng Đội Thanh niên xung phong Giải phóng miền Nam xã Đức Tân, huyện Tân Trụ.</td></tr><tr><td>8)</td><td>Liệt sỹ Nguyễn Thị Lê (Nấm Châu), nguyên Bí thư xã Mỹ Thạnh Bắc, huyện Đức Huệ, tỉnh Long An</td></tr><tr><td>9)</td><td>Liệt sỹ Nguyễn Thành Toàn , nguyên xã Đội trưởng xã Mỹ Thạnh Bắc, huyện Đức Huệ, tỉnh Long An</td></tr><tr><td>10)</td><td>Liệt sỹ Nguyễn Văn Trại, nguyên xã Đội phó xã Mỹ Hạnh (nay là xã Mỹ Hạnh Bắc), huyện Đức Hòa, tỉnh Long An</td></tr><tr><td>11)</td><td>Liệt sỹ Võ Văn Thần, nguyên Du kích xã Mỹ Hạnh ( nay là xã Mỹ Hạnh Bắc) huyện Đức Hòa tỉnh Long An.</td></tr><tr><td>12)</td><td>Liệt sỹ Nguyễn Văn Liên (Bảy Liên), nguyên Bí thư, kiêm xã Đội trưởng xã Hòa Khánh huyện Đức Hòa tỉnh Long An.</td></tr><tr><td>13)</td><td>Liệt sỹ Nguyễn Văn Bực, nguyên Tiểu đội phó, Đại đội 313, huyện đội Châu Thành, tỉnh Long An.</td></tr><tr><td>14)</td><td>Liệt sỹ Võ Văn Nô, nguyên Du kích xã Thanh Phú Long , huyện Châu Thành, tỉnh Long An</td></tr><tr><td>15)</td><td>Liệt sỹ Trần Công Vịnh, nguyên Phó Bí thư Huyện Đoàn Mộc Hóa, tỉnh Tân An ( nay là tỉnh Long An)</td></tr><tr><td>16)</td><td>Ông Hồ Ngọc Dần (Dương Tân Mào), nguyên Tỉnh Đội trưởng tỉnh Kiên Tường ( nay là tỉnh Long An) thành phố Tân An</td></tr></tbody></table>');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (10, 1, 10, '10', '59

①

**UBND TỈNH LONG AN  
SỞ LAO ĐỘNG - THƯƠNG BINH  
VÀ XÃ HỘI**

**CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc**

Số: 59 /QĐ-SLETBXH

Tân An, ngày 19 tháng 10 năm 2010

Số hồ sơ: LA/AH: 59

**QUYẾT ĐỊNH**

**Về việc trợ cấp ưu đãi Anh hùng lực lượng vũ trang nhân dân**

**GIÁM ĐỐC SỞ LAO ĐỘNG THƯƠNG BINH VÀ XÃ HỘI**

Căn cứ Nghị định số 54/2006/NĐ-CP ngày 26 tháng 5 năm 2006 của Chính phủ hướng dẫn thi hành một số điều Pháp lệnh ưu đãi người có công với cách mạng;

Căn cứ Quyết định số 212/QĐ-CTN ngày 23 tháng 02 năm 2010 của Chủ tịch nước;

Căn cứ Nghị định số 38//2009/NĐ-CP ngày 23 tháng 4 năm 2009 của Chính phủ quy định về mức trợ cấp, phụ cấp ưu đãi đối với người có công với cách mạng;

Xét đề nghị của Trường Phòng Người có công;

**QUYẾT ĐỊNH:**

**Điều 1.** Trợ cấp một lần đối với Bà Trần Thị Nuôi; Sinh năm: 1956 .

Nguyên quán: Xã Nhơn Hoà Lập, huyện Tân Thạnh, tỉnh Long An.

Trú quán: Xã Tân Ninh, huyện Tân Thạnh, tỉnh Long An.

Là con của Liệt sỹ Trần Công Vinh.

Nguyên quán: Xã Nhơn Hoà Lập, huyện Tân Thạnh, tỉnh Long An.

Trú quán: Xã Tân Ninh, huyện Tân Thạnh, tỉnh Long An.

đã được truy tặng danh hiệu Anh hùng lực lượng vũ trang nhân dân, theo Quyết định số 212 /QĐ-CTN ngày 23 tháng 02 năm 2010 của Chủ tịch nước.

Mức trợ cấp 1 lần là: 13.700.000 đ

(Bằng chữ: Mười ba triệu bảy trăm ngàn đồng)

**Điều 2.** Trưởng Phòng Người có công, Trưởng Phòng Kế hoạch - Tài chính, Trưởng Phòng Lao động Thương binh Xã hội huyện Tân Thạnh về Bà Trần Thị Nuôi có trách nhiệm thi hành quyết định này.  
*V/V*

**Nơi nhận:**

- - Như điều 2;
- - Lưu VT.

**GIÁM ĐỐC**

PHÓ GIÁM ĐỐC

**Nguyễn Văn Ghim**');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (11, 1, 11, '11', 'Quyết định  
28/4/2010

Thị xã Tân An

UBND TỈNH LONG AN CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
SỞ LAO ĐỘNG THƯƠNG BINH VÀ XÃ HỘI Độc lập - Tự do - Hạnh phúc

Số : 650/TCV-SLĐTBXH

Tân An, ngày 27 tháng 04 năm 2010

Về việc giải quyết chế độ cho thân nhân  
Anh hùng Lực lượng vũ trang

Kính gửi : Phòng Lao động Thương binh và Xã hội  
huyện, thành phố

Thi hành Quyết định số 212/QĐ-CTN ngày 23/2/2010 của Chủ tịch nước về việc truy tặng danh hiệu anh hùng lực lượng vũ trang.

Căn cứ theo qui định Nghị định số 54/2006/NĐ-CP ngày 26/5/2006 của Chính phủ về việc hướng dẫn thi hành một số điều của Pháp lệnh ưu đãi người có công với cách mạng và Thông tư số 07/2006/TT-BLĐTBXH ngày 26/7/2006 của Bộ Lao động – Thương binh và Xã hội hướng dẫn về hồ sơ, lập hồ sơ thực hiện chế độ ưu đãi người có công với cách mạng.

Đề giải quyết kịp thời chế độ cho người có công với cách mạng (có danh sách đính kèm). Đề nghị Phòng Lao động-Thương binh và Xã hội huyện, thành phố phối hợp với UBND xã, phương hướng dẫn thân nhân lập bản khai (mẫu 4c-AH) và tổng hợp gửi về Sở Lao động Thương binh và Xã hội để xem xét và giải quyết chế độ trợ cấp cho thân nhân.

Trường hợp liệt sỹ không còn thân nhân chủ yếu (cha đẻ, mẹ đẻ, vợ hoặc chồng, con đẻ, người có công nuôi liệt sỹ) thì phải kèm theo biên bản hợp thân tộc có xác nhận của UBND xã nơi cư trú.

Nhận được công văn này, đề nghị Phòng Lao động Thương binh và Xã hội huyện, thành phố triển khai thực hiện ✓

**Nơi nhận :**

- - UBND tỉnh “báo cáo”;
- - GD, phó GD sở ;
- - Như trên;
- - Lưu: TBLS-NCC.

KT. GIÁM ĐỐC  
PHÓ GIÁM ĐỐC

Nguyễn Văn Ghim');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (12, 1, 12, '12', 'UBND TỈNH LONG AN  
SỞ LAO ĐỘNG THƯƠNG BINH  
VÀ XÃ HỘI

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

**DANH SÁCH TRUY TẶNG**  
**ANH HÙNG LỰC LƯỢNG VŨ TRANG NHÂN DÂN**  
(Kèm theo Quyết định số 212/QĐ-CTN ngày 23/2/2010 của Chủ tịch nước )

<table border="1"><tbody><tr><td>1</td><td>Liệt sỹ Đồ Công Thường, nguyên Ủy viên quân sự xã Phú Ngải Trị huyện Châu Thành, tỉnh Long An</td></tr><tr><td>2</td><td>Liệt sỹ Lê Văn Khuê, nguyên Chủ tịch Ủy ban hành chính kháng chiến xã Phước Tân Hưng, huyện Châu Thành</td></tr><tr><td>3</td><td>Liệt sỹ Trương Văn Nhường, nguyên Giao liên xã Đức Lập Hạ, huyện Đức Hòa, tỉnh Long An.</td></tr><tr><td>4</td><td>Liệt sỹ Nguyễn Thái Bình, nguyên sinh viên Việt Nam du học tại Mỹ . Quê xã Tân Kim, huyện Cần Giờ, tỉnh Long An.</td></tr><tr><td>5</td><td>Liệt sỹ ề Văn Giao (Lê Hùng Minh), nguyên Trung Đội trưởng , Đội 198 Thanh niên xung phong, Tổng đội Thanh niên xung phong Giải phóng miền Nam huyện Đức Huệ</td></tr><tr><td>6</td><td>Liệt sỹ Hồ Văn Ngà, nguyên Đội trưởng Đội công binh huyện Châu Thành, tỉnh Long An.</td></tr><tr><td>R<br/>7</td><td>Liệt sỹ Nguyễn Thị Bé (Nguyễn Hoàng Anh), nguyên Tiểu đội phó, Đội 198 Thanh niên xung phong, Tổng Đội Thanh niên xung phong Giải phóng miền Nam xã Đức Tân, huyện Tân Trụ.</td></tr><tr><td>8</td><td>Liệt sỹ Nguyễn Thị Lê (Năm Châu), nguyên Bí thư xã Mỹ Thạnh Bắc, huyện Đức Huệ, tỉnh Long An</td></tr><tr><td>9</td><td>Liệt sỹ Nguyễn Thành Tuấn , nguyên xã Đội trưởng xã Mỹ Thạnh Bắc, huyện Đức Huệ, tỉnh Long An</td></tr><tr><td>10</td><td>Liệt sỹ Nguyễn Văn Trạm, nguyên xã Đội phó xã Mỹ Hạnh (nay là xã Mỹ Hạnh Bắc), huyện Đức Hòa, tỉnh Long An</td></tr><tr><td>11</td><td>Liệt sỹ Võ Văn Thên, nguyên Du kích xã Mỹ Hạnh ( nay là xã Mỹ Hạnh Bắc) huyện Đức Hòa tỉnh Long An.</td></tr><tr><td>12</td><td>Liệt sỹ Nguyễn Văn Liên (Bảy Liên), nguyên Bí thư, kiêm xã Đội trưởng xã Hòa Khánh huyện Đức Hòa tỉnh Long An.</td></tr><tr><td>13</td><td>Liệt sỹ Nguyễn Văn Bực, nguyên Tiểu đội phó, Đại đội 313, huyện đội Châu Thành, tỉnh Long An.</td></tr><tr><td>14</td><td>Liệt sỹ Võ Văn Nô, nguyên Du kích xã Thanh Phú Long , huyện Châu Thành, tỉnh Long An</td></tr><tr><td>R<br/>15</td><td>Liệt sỹ Trần Công Vịnh, nguyên Phó Bí thư Huyện Đoàn Mộc Hóa, tỉnh Tân An ( nay là tỉnh Long An) <i>thân d. x. t. p. h. h.</i></td></tr><tr><td>16</td><td>Ông Hồ Ngọc Dấn (Dương Tấn Mào), nguyên Tỉnh Đội trưởng tỉnh Kiên Tường ( nay là tỉnh Long An) thành phố Tân An</td></tr></tbody></table>');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (13, 1, 13, '13', '41

Mẫu số 4c-AH  
**CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM**  
**Độc lập – Tự do – Hạnh phúc**

**BẢN KHAI VỀ NGƯỜI CÓ CÔNG**

**1. Phần khai về người có công:**

Họ và tên: ..... Nam (Nữ) ..... Năm sinh: .....  
 Nguyên quán: .....  
 Cơ quan, đơn vị công tác: .....  
 Nơi đăng ký hộ khẩu: .....  
 Đã được tặng danh hiệu (Anh hùng LLVT, Anh hùng LD trong kháng chiến) .....  
 Theo Quyết định số ..... ngày ..... tháng ..... năm ..... của Chủ tịch nước

**2. Phần khai về thân nhân (người đứng khai):**

Họ và tên: ..... Năm sinh: .....  
 Nguyên quán: .....  
 Trú quán: .....  
 Quan hệ với Anh hùng LLVT, Anh hùng LD trong kháng chiến: (vợ, chồng,  
 cha, mẹ, con...) .....  
 đã từ trần  
 ngày ..... tháng ..... năm .....

Tôi xin cam đoan lời khai trên là đúng, nếu sai tôi xin hoàn toàn chịu trách nhiệm trước pháp luật./.

Ông (bà)

Ngày ..... tháng ..... năm

Hiện cư trú tại:

Người khai  
 (Ký, ghi rõ họ và tên)

chưa hưởng tự cấp ưu đãi đối với Anh hùng  
 LLVT, Anh hùng LD trong kháng chiến.

.....ngày .....tháng .....năm .....

TM. UBND  
 Chủ tịch');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (14, 1, 14, '14', '(12)

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

BIÊN BẢN HỢP HỌ TỘC GIA ĐÌNH ANH HÙNG LLVT

Hôm nay, vào lúc ..... giờ, ngày ..... tháng ..... năm .....  
Tại nhà ông (bà) .....  
đã tiến hành cuộc hợp thân tộc.

Thành phần chúng tôi gồm có:

- 1 /- ..... Năm sinh ..... là ..... của AHLLVTND
- 2 /- ..... Năm sinh ..... là ..... của AHLLVTND
- 3 /- ..... Năm sinh ..... là ..... của AHLLVTND
- 4 /- ..... Năm sinh ..... là ..... của AHLLVTND
- 5 /- ..... Năm sinh ..... là ..... của AHLLVTND
- 6 /- ..... Năm sinh ..... là ..... của AHLLVTND
- 7 /- ..... Năm sinh ..... là ..... của AHLLVTND

Nội dung:

Ông (bà) ..... đại diện họ tộc đề nghị cho ông (bà) ..... thuộc hàng thừa kế thứ ..... trong họ tộc, được quyền thờ cúng và thừa hưởng mọi chế độ, quyền lợi, chính sách của ông (bà) ..... không ai được quyền thách mắng khiêu nại về sau.

Toàn thể gia tộc thống nhất kết luận ông (bà) ..... đủ điều kiện hưởng trợ cấp thân nhân Anh hùng LLVT nhân dân /

**Xác nhận**

**Của UBND xã, thị trấn**

*(Ký tên đóng dấu và ghi rõ họ tên)*

**Đồng ý**

**Ký tên của họ tộc**

*(Ký và ghi rõ họ tên)*

- 1 /- .....
- 2 /- .....
- 3 /- .....
- 4 /- .....
- 5 /- .....
- 6 /- .....
- 7 /- .....');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (15, 1, 15, '15', 'ỦY BAN NHÂN DÂN  
XÃ TÂN NINH

Điện thoại: 072.2815.150

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM

Độc lập - Tự do - Hạnh phúc

Tân Ninh, ngày 30 tháng 9 năm 2010

**PHIẾU GIAO - NHẬN HỒ SƠ**

(Hay phiếu chuyển giao hồ sơ)

Bộ phận tiếp nhận và trả kết quả chuyển hồ sơ của:

Ông, bà (tổ chức) ... Đã cũn ... Tân Ninh ... Mười

Địa chỉ: ấp Như ... quận xã Tân Ninh huyện Tân Thạnh tỉnh Long An

Nội dung: Đã cũn ... đại ... người ... co ... chợ

Đến (cơ quan, đơn vị, công chức tiếp nhận) một cửa sản ... thanh

Đề nghị một cửa ... 2 ... nghiên cứu, xem xét giải quyết và chuyển hồ sơ về bộ

phân tiếp nhận và trả kết quả của (đơn vị chuyển giao) để trả lại cho công dân vào ngày ... tháng ... năm ...

Trưởng hợp quá thời gian quy định, yêu cầu gửi phiếu trả lời, nêu rõ lý do và hẹn lại ngày trả hồ sơ cho Bộ phận tiếp nhận và trả kết quả để trả lời cho công dân

Ngày ... tháng ... năm ...

**ĐẠI DIỆN CƠ QUAN, ĐƠN VỊ TIẾP NHẬN**  
(Ký nhận)

**BỘ PHẬN TIẾP NHẬN VÀ TRẢ KẾT QUẢ**

(Ký giao)

*Handwritten signature and date: 30/9/10*

Ghi chú');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (16, 1, 16, '16', '(4)

2

Charges Dr to them.  
these notes.

20/10/2010

✓ Bar');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (17, 1, 17, '17', 'UBND HUYỆN TÂN THẠNH  
PHÒNG LAO ĐỘNG TB&XH

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

Số: 312 /TT-Tr-LDTB&XH

Tân Thạnh, ngày 18 tháng 10 năm 2010

SỞ LAO ĐỘNG VÀ THƯƠNG MẠI  
ĐẾN NGÀY 20/10/2010  
của P. NCC

**TỜ TRÌNH**

V/v trợ cấp một lần cho thân nhân Anh hùng LLVT

Căn cứ Nghị định số 54/2006/NĐ-CP ngày 26/6/2006 của Chính phủ về việc hướng dẫn thi hành một số điều của Pháp lệnh ưu đãi người có công với cách mạng; cụ thể tại điều 10, mục 2 của Nghị định này quy định: Người được truy tặng danh hiệu Anh hùng Lực lượng vũ trang nhân dân, Anh hùng Lao động trong kháng chiến thì thân nhân hoặc người thừa kế theo quy định của pháp luật được hưởng trợ cấp một lần.

Phòng Lao động - Thương binh và Xã hội huyện Tân Thạnh đề nghị Sở Lao động - Thương binh và Xã hội tỉnh Long An, Phòng TBLS và NCC xem xét giải quyết trợ cấp một lần đối với trường hợp của bà:

Trần Thị Nuôi

sinh năm 1956

Quê quán: Nhon Hòa Lập, Tân Thạnh, Long An

Trú quán: Tân Ninh, Tân Thạnh, Long An

Là con duy nhất của liệt sĩ Trần Công Vịnh, số hồ sơ LA/LS/27135, quê quán Mỹ An Phú, Thủ Thừa, Long An

Nhập ngũ: 10/1946

Chức vụ: Phó Bí thư Huyện đoàn Mộc Hóa

Hy sinh: 8/1957

Nơi hy sinh: Tân Hòa, Mộc Hóa

Đã được Chủ tịch nước phong tặng danh hiệu Anh hùng LLVT, Quyết định số 212/QĐ-CTN ngày 23/2/2010.

Đề nghị Sở Lao động - Thương binh và Xã hội tỉnh Long An, Phòng TBLS và NCC xem xét giải quyết trường hợp nêu trên./.

Nơi nhận:

- -Sở LDTB&XH;
- -Phòng TBLS&NCC;
- -Lãnh đạo phòng;
- -Lưu.

**TRƯỞNG PHÒNG**

PHÒNG  
LAO ĐỘNG

Nguyễn Sĩ Khoa');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (18, 1, 18, '18', 'UBND HUYỆN TÂN THẠNH  
PHÒNG LAO ĐỘNG TB&XH

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

Số: 312 /TTr-LĐTB&XH

Tân Thạnh, ngày 18 tháng 10 năm 2010

**TỜ TRÌNH**  
**V/v trợ cấp một lần cho thân nhân Anh hùng LLVT**

Căn cứ Nghị định số 54/2006/NĐ-CP ngày 26/6/2006 của Chính phủ về việc hướng dẫn thi hành một số điều của Pháp lệnh ưu đãi người có công với cách mạng; cụ thể tại điều 10, mục 2 của Nghị định này quy định: Người được truy tặng danh hiệu Anh hùng Lực lượng vũ trang nhân dân, Anh hùng Lao động trong kháng chiến thì thân nhân hoặc người thừa kế theo quy định của pháp luật được hưởng trợ cấp một lần.

Phòng Lao động - Thương binh và Xã hội huyện Tân Thạnh đề nghị Sở Lao động - Thương binh và Xã hội tỉnh Long An, Phòng TBLS và NCC xem xét giải quyết trợ cấp một lần đối với trường hợp của bà:

Trần Thị Nuôi sinh năm 1956

Quê quán: Nhon Hòa Lập, Tân Thạnh, Long An

Trú quán: Tân Ninh, Tân Thạnh, Long An

Là con duy nhất của liệt sĩ Trần Công Vịnh, số hồ sơ LA/LS/27135, quê quán Mỹ An Phú, Thủ Thừa, Long An

Nhập ngũ: 10/1946

Chức vụ: Phó Bí thư Huyện đoàn Mộc Hóa

Hy sinh: 8/1957

Nơi hy sinh: Tân Hòa, Mộc Hóa

Đã được Chủ tịch nước phong tặng danh hiệu Anh hùng LLVT, Quyết định số 212/QĐ-CTN ngày 23/2/2010.

Đề nghị Sở Lao động - Thương binh và Xã hội tỉnh Long An, Phòng TBLS và NCC xem xét giải quyết trường hợp nêu trên./.

Nơi nhận:

- -Sở LĐTBXH;
- -Phòng TBLS&NCC;
- -Lãnh đạo phòng;
- -Ltrư.

**TRƯỞNG PHÒNG**

Nguyễn Sĩ Khoa');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (19, 1, 19, '19', 'FROM : LAO ĐỘNG TBXH TÂN THẠNHFAX NO. : 384414018 Oct. 2010 10:39AM P15

UBND HUYỆN TÂN THẠNH  
 PHÒNG LAO ĐỘNG TB&XH

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
 Độc lập - Tự do - Hạnh phúc

Số: 312 /Tr-LĐTB&XH

Tân Thạnh, ngày 18 tháng 10 năm 2010

SỞ LAO ĐỘNG TB VÀ XE LONG AN  
 ĐẾN Số:  
 Ngày: 18/10/2010  
 Chuyển:

**TỜ TRÌNH**

V/v trợ cấp một lần cho thân nhân Anh hùng LLVT

Chữ ký Nghị định số 54/2006/NĐ-CP ngày 26/6/2006 của Chính phủ về việc hướng dẫn thi hành một số điều của Pháp lệnh ưu đãi người có công với cách mạng; cụ thể tại điều 10, mục 2 của Nghị định này quy định: Người được truy tặng danh hiệu Anh hùng Lực lượng vũ trang nhân dân, Anh hùng Lao động trong kháng chiến thì thân nhân hoặc người thừa kế theo quy định của pháp luật được hưởng trợ cấp một lần.

Phòng Lao động - Thương binh và Xã hội huyện Tân Thạnh đề nghị Sở Lao động - Thương binh và Xã hội tỉnh Long An, Phòng TBLS và NCC xem xét giải quyết trợ cấp một lần đối với trường hợp của bà:

Trần Thị Nuôi sinh năm 1956

Quê quán: Nhơn Hòa Lập, Tân Thạnh, Long An

Trú quán: Tân Ninh, Tân Thạnh, Long An

Là con duy nhất của liệt sĩ Trần Công Vịnh, số hồ sơ LA/LS/27135, quê quán Mỹ An Phú, Thủ Thừa, Long An

Nhập ngũ: 10/1946

Chức vụ: Phó Bí thư Huyện đoàn Mộc Hóa

Hy sinh: 8/1957

Nơi hy sinh: Tân Hòa, Mộc Hóa

Đã được Chủ tịch nước phong tặng danh hiệu Anh hùng LLVT, Quyết định số 212/QĐ-CTN ngày 23/2/2010.

Đề nghị Sở Lao động - Thương binh và Xã hội tỉnh Long An, Phòng TBLS và NCC xem xét giải quyết trường hợp nêu trên./.

Nơi nhận:

- -Sở LĐTBXH;
- -Phòng TBLS&NCC;
- -Lãnh đạo phòng;
- -Lưu.

TRƯỞNG PHÒNG

Nguyễn Sĩ Khoa

Ghi có Thư');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (20, 1, 20, '20', '4c-AH

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

BẢN KHAI VỀ NGƯỜI CÓ CÔNG

**I./-Phản khai về người có công:**

Họ và tên: Trần Công Vinh ..... Nam (nữ): Nam ..... Năm sinh: .....  
Nguyên quán: Mỹ An Phú, Thủ Thừa, Long An .....  
Cơ quan, đơn vị công tác: Phó Bí thư Huyện đoàn Mộc Hóa .....  
Nơi đăng ký hộ khẩu: Hy sinh tháng 8 năm 1957 .....  
Đã được tặng danh hiệu: Anh hùng lực lượng vũ trang nhân dân .....  
Theo Quyết định số 212/QĐ-CTN ngày 23/2/2010 của Chủ tịch nước .....

**II./-Phần khai về thân nhân: (Người đứng khai)**

Họ và tên: Trần Thị Nuôi ..... Năm sinh: 1956 .....  
Nguyên quán: Nhon Hòa Lập, Tân Thạnh, Long An .....  
Trú quán: Tân Ninh, Tân Thạnh, Long An .....  
Quan hệ với Anh hùng lực lượng vũ trang nhân dân: Con ruột .....  
Đã hy sinh: Tháng 8 năm 1957 .....

Tôi xin cam đoan lời khai trên là đúng, nếu sai tôi xin hoàn toàn chịu trách nhiệm trước pháp luật./.

Ông (bà): Trần Thị Nuôi.....  
Hiện cư trú tại: Tân Ninh, Tân .....  
Thạnh, Long An .....  
Chưa hưởng trợ cấp ưu đãi đối .....  
với Anh hùng LLVT nhân dân./.

Ngày 26 tháng 8 năm 2010  
**TM. UBND XÃ TÂN NINH**  
**KỊ CHỦ TỊCH**

Ngày 26 tháng 8 năm 2010  
**Người khai**

*Nuôi*

**Trần Thị Nuôi**');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (21, 1, 21, '21', '(H)

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
ĐỘC LẬP - TỰ DO - HẠNH PHÚC

**CHỦ TỊCH**  
NƯỚC CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM

**TẶNG DANH HIỆU**  
**ANH HÙNG LỰC LƯỢNG VŨ TRANG NHÂN DÂN**

Truy tặng Liệt sỹ **TRẦN CÔNG VINH**

*Nguyễn Phú Bí thư Huyện đoàn Mộc Hóa, tỉnh Tân An (nay là tỉnh Long An)  
Đã có thành tích đặc biệt xuất sắc trong cuộc kháng chiến chống Mỹ, Cứu nước*

Quyết định số: 212 QĐ/CTN ngày 23 tháng 02 năm 2010  
Vào sổ vàng số: 83

*Hà Nội, ngày 23 tháng 02 năm 2010*

CHỦ TỊCH

NƯỚC CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM

*Nhân*

Nguyễn Minh Triết');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (22, 1, 22, '22', '4c-AH

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

BẢN KHAI VỀ NGƯỜI CÓ CÔNG

**I./-Phần khai về người có công:**

Họ và tên: Trần Công Vịnh ..... Nam (nữ): Nam..... Năm sinh: .....  
Nguyên quán: Mỹ An Phú, Thủ Thừa, Long An .....  
Cơ quan, đơn vị công tác: Phó Bí thư Huyện đoàn Mộc Hóa .....  
Nơi đăng ký hộ khẩu: Hy sinh tháng 8 năm 1957 .....  
Đã được tặng danh hiệu Anh hùng lực lượng vũ trang nhân dân .....  
Theo Quyết định số: 212/QĐ-CTN ngày 23/2/2010 của Chủ tịch nước.....

**II./-Phần khai về thân nhân: (Người đứng khai)**

Họ và tên: Trần Thị Nuôi ..... Năm sinh: 1956 .....  
Nguyên quán: Nhơn Hòa Lập, Tân Thạnh, Long An .....  
Trú quán: Tân Ninh, Tân Thạnh, Long An .....  
Quan hệ với Anh hùng lực lượng vũ trang nhân dân: Con ruột .....  
Đã hy sinh: Tháng 8 năm 1957.....

Tôi xin cam đoan lời khai trên là đúng, nếu sai tôi xin hoàn toàn chịu trách nhiệm trước pháp luật./.

Ông (bà): Trần Thị Nuôi.....  
Hiện cư trú tại: Tân Ninh, Tân .....  
Thạnh, Long An.....  
Chưa hưởng trợ cấp ưu đãi .....  
với Anh hùng LLVT nhân dân./.

Ngày 26 tháng 8 năm 2010  
**TM. UBND XÃ TÂN NINH**

Ngày 26 tháng 8 năm 2010  
**Người khai**

nuôi

**Trần Thị Nuôi**

*Nguyễn Thanh Pang*');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (23, 1, 23, '23', '3

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
ĐỘC LẬP - TỰ DO - HẠNH PHÚC

**CHỦ TỊCH**

NƯỚC CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM

**TẶNG DANH HIỆU**

**ANH HÙNG LỰC LƯỢNG VŨ TRANG NHÂN DÂN**

Truy tặng Liệt sĩ **TRẦN CÔNG VINH**

*Nguyễn Phú Bí thư Huyện đoàn Mộc Hóa, tỉnh Tân An (nay là tỉnh Long An)  
Đã có thành tích đặc biệt xuất sắc trong cuộc kháng chiến chống Mỹ, Cứu nước*

Quyết định số: 242  
QĐ-CTN ngày 23 tháng 02 năm 2010  
Văn số tặng số: 63

*Hà Nội, ngày 23 tháng 02 năm 2010*

CHỦ TỊCH

NƯỚC CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM

Nguyễn Minh Triết');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (24, 1, 24, '24', '60Lưu①

UBND TỈNH LONG AN  
SỞ LAO ĐỘNG - THƯƠNG BINH  
VÀ XÃ HỘI

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

Số: 3 /QĐ-SLĐTBXH

Tân An, ngày 25 tháng 11 năm 2010

Số hồ sơ: 60

**QUYẾT ĐỊNH**

**Về việc trợ cấp ưu đãi Anh hùng lực lượng vũ trang nhân dân**

**GIÁM ĐỐC SỞ LAO ĐỘNG THƯƠNG BINH VÀ XÃ HỘI**

Căn cứ Nghị định số 54/2006/NĐ-CP ngày 26 tháng 5 năm 2006 của Chính phủ hướng dẫn thi hành một số điều Pháp lệnh ưu đãi người có công với cách mạng;

Căn cứ Quyết định số 212/QĐ-CTN ngày 23 tháng 02 năm 2010 của Chủ tịch nước;

Căn cứ Nghị định số 35//2010/NĐ-CP ngày 6 tháng 4 năm 2010 của Chính phủ quy định về mức trợ cấp, phụ cấp ưu đãi đối với người có công với cách mạng;

Xét đề nghị của Trưởng Phòng Người có công;

**QUYẾT ĐỊNH:**

**Điều 1.** Trợ cấp một lần đối với bà: Nguyễn Thị Phụ, Sinh năm: 1934 .

Nguyên quán: xã Vĩnh Lợi, huyện Tân Hưng, tỉnh Long An.

Trú quán: Phường II, TP Tân An, tỉnh Long An.

Là vợ của Anh hùng lực lượng vũ trang: Hồ Ngọc Đôn.

Nguyên quán: xã Thanh Phú, huyện Thanh Hóa, tỉnh Long An.

Trú quán: Phường II, TP Tân An, tỉnh Long An.

đã được truy tặng danh hiệu Anh hùng lực lượng vũ trang nhân dân, theo Quyết định số 212 /QĐ-CTN ngày 23 tháng 02 năm 2010 của Chủ tịch nước.

Mức trợ cấp 1 lần là: 13.700.000 đ

(Bằng chữ: Mười ba triệu bảy trăm ngàn đồng)

**Điều 2.** Trưởng Phòng Người có công, Trưởng Phòng Kế hoạch - Tài chính, Trưởng Phòng Lao động Thương binh Xã hội TP Tân An và bà Nguyễn Thị Phụ có trách nhiệm thi hành quyết định này. /Xác nhận

**Nơi nhận:**

- - Như điều 2;
- - Lưu VT.

Nguyễn Văn Ghim');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (25, 1, 25, '25', 'giao ...

(2)

**UBND TP TÂN AN  
PHÒNG LD-TB VÀ XH**

**CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập – Tự do – Hạnh phúc**

**Số 33 /CV-LĐTBXH**

*Tân An, ngày 22 tháng 6 năm 2010*

Về việc báo cáo đối tượng được  
truy tặng danh hiệu AHLLVT

Kính gửi: Sở LD-TB và XH Long An,

Thực hiện công văn 630/CV-SLĐTBXH ngày 27/4/2010 của Sở LD-TB và XH Long An về việc giải quyết chế độ cho thân nhân Anh hùng Lực lượng vũ trang.

Theo Công văn trên Sở LD-TB và XH tỉnh chỉ đạo hướng dẫn thân nhân AHLLVT lập bản kl.ư và tổng hợp gửi về Sở để xét giải quyết chế độ trợ cấp cho thân nhân.

Phòng LD-TB và XH thành phố Tân An báo cáo đối tượng như sau:

Người được truy tặng danh hiệu Anh hùng Lực lượng vũ trang.

Ông Hồ Ngọc Dần, sinh năm 1930, từ tuần ngày 9/10/1999,

Nguyên quán xã Thạnh Phú, huyện Thạnh Hóa, tỉnh Long An,

Hộ khẩu thường trú khu phố 8, phường 2, thành phố Tân An.

Quyết định truy tặng AHLLVT số 212/QĐ/CTN ngày 23/2/2010 của Chủ tịch nước;

Thân nhân chủ yếu (vợ): bà Nguyễn Thị Phụ, sinh 1934, cư trú khu phố 8, thành phố Tân An (kèm theo hồ sơ đã khai).

Phòng LD-TB và XH thành phố xin báo cáo theo chỉ đạo của Sở./.

**Nơi nhận:**

- - Như trên;
- - PCTvx UBND TX (b/c);
- - Lưu VT, d.

**Trần Thị Chiễm**');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (26, 1, 26, '26', 'Cùng Chs / Xuc Cam h<sup>o</sup> (b)  
CS  
20/3/10

UBND TỈNH LONG AN CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
SỞ LAO ĐỘNG THƯƠNG BINH Độc lập - Tự do - Hạnh phúc  
VÀ XÃ HỘI

Số: 650/CV-SLĐTBXH

Tân An, ngày 27 tháng 04 năm 2010

Về việc giải quyết chế độ cho thân nhân  
Anh hùng Lực lượng vũ trang

Kính gửi : Phòng Lao động Thương binh và Xã hội  
huyện, thành phố

Thì hành Quyết định số 212/QĐ-CTN ngày 23/2/2010 của Chủ tịch nước về việc truy tặng danh hiệu anh hùng lực lượng vũ trang.

Căn cứ theo quy định Nghị định số 54/2006/NĐ-CP ngày 26/5/2006 của Chính phủ về việc hướng dẫn thì hành một số điều của Pháp lệnh tư đãi người có công với cách mạng và Thông tư số 07/2006/TT-BLĐTBXH ngày 26/7/2006 của Bộ Lao động - Thương binh và Xã hội hướng dẫn về hồ sơ, lập hồ sơ thực hiện chế độ ưu đãi người có công với cách mạng.

Để giải quyết kịp thời chế độ cho người có công với cách mạng (có danh sách đính kèm). Đề nghị Phòng Lao động-Thương binh và Xã hội huyện, thành phố phối hợp với UBND xã, phường hướng dẫn thân nhân lập bản khai (mẫu 4c-AH) và tổng hợp gửi về Sở Lao động Thương binh và Xã hội để xem xét và giải quyết chế độ trợ cấp cho thân nhân.

Trường hợp liệt sỹ không còn thân nhân chủ yếu (cha đẻ, mẹ đẻ, vợ hoặc chồng, con đẻ, người có công nuôi liệt sỹ) thì phải kèm theo biên bản hợp thân tộc có xác nhận của UBND xã nơi cư trú.

Nhận được công văn này, đề nghị Phòng Lao động Thương binh và Xã hội huyện, thành phố triển khai thực hiện.

Nơi nhận :

- - UBND tỉnh "báo cáo";
- - GD, phó GD sở ;
- - Như trên;
- - Lưu: TBLS-NCC.

KT GIÁM ĐỐC  
PHÓ GIÁM ĐỐC

Nguyễn Văn Ghim');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (27, 1, 27, '27', 'LÀM AH LLVT: 60

Mẫu số 4c-AH

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM

Độc lập - Tự do - Hạnh phúc

# BẢN KHAI VỀ NGƯỜI CÓ CÔNG

1. Phần khai về người có công

Họ và tên: Họ, NGUYỄN VĂN, Nam (nữ) ĐƠN Năm sinh 1930. Nguyên quán:

THỊ XÃ PHÚ THỊNH, HUYỆN ÁO LẠNG, TỈNH QUẢNG NINH, VIỆT NAM  
Cơ quan, đơn vị công tác: CÔNG AN QUÂN NHÂN NHÂN QUÂN VIỆT NAM (CHỦNG ĐOÀN)

Nơi đăng ký hộ khẩu:

Đã được tặng danh hiệu (Anh hùng LLVT, Anh hùng LD trong kháng chiến):

Anh hùng LLVT, Anh hùng LD trong kháng chiến  
Theo Quyết định số 012, ngày 23 tháng 02, năm 2010 của chủ tịch nước

2. Phần khai về thân nhân (người đứng khai):

Họ và tên: Nguyễn Thị Phu, Năm sinh: 1934

Nguyên quán: Township, District, Province, Vietnam

Trú quán: 1937.125, Q.1, TP. TÂN AN, TỈNH LONG ANH, VIỆT NAM (Khu phố 8)

Quan hệ với Anh hùng LLVT, Anh hùng LD trong kháng chiến: (vợ, chồng, cha, mẹ, con, v.v)

đã từ trần ngày 03, tháng 10, năm 1999

Tôi cam đoan lời khai trên đúng, nếu sai tôi hoàn toàn chịu trách nhiệm trước pháp luật.

Ông(bà): Nguyễn Thị Phu Ngày 14 tháng 06, năm 2010.

hiện cư trú tại: 1937.125, Q.1, TP. TÂN AN, TỈNH LONG ANH, VIỆT NAM Người khai  
chưa hưởng trợ cấp ưu đãi đối với Anh hùng LLVT (Ký, ghi rõ họ tên)

Anh hùng LD trong kháng chiến.

12 ngày 18 tháng 6 năm 2010

CHỦ TỊCH

(Ký tên, đóng dấu)

Nguyễn Văn Hải

*Thư*  
Nguyễn Thị Phu');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (28, 1, 28, '28', '**BẢN SAO**

5

**CHỦ TỊCH NƯỚC**

Số: 212 /QĐ-CTN

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM

Độc lập - Tự do - Hạnh phúc

Hà Nội, ngày 23 tháng 2 năm 2010

**QUYẾT ĐỊNH**

Xét việc truy tặng danh hiệu Anh hùng Lực lượng vũ trang nhân dân

**CHỦ TỊCH**

**NƯỚC CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM**

Căn cứ Điều 103 của Hiến pháp nước Cộng hòa xã hội chủ nghĩa Việt Nam năm 1992;

Căn cứ Luật thi đua, khen thưởng;

Xét đề nghị của Thủ tướng Chính phủ tại Tờ trình số 295/TTrg-TCCV ngày 11 tháng 02 năm 2010,

**QUYẾT ĐỊNH**

**Điều 1.** Truy tặng danh hiệu Anh hùng Lực lượng vũ trang nhân dân cho:

1- 29 cá nhân (có danh sách kèm theo);

*Đã có thành tích đặc biệt xuất sắc trong cuộc kháng chiến chống thực dân Pháp xâm lược.*

2- 156 cá nhân (có danh sách kèm theo);

*Đã có thành tích đặc biệt xuất sắc trong cuộc kháng chiến chống Mỹ, cứu nước.*

**Điều 2.** Quyết định này có hiệu lực thi hành từ ngày ký.

Thủ tướng Chính phủ, Chủ nhiệm Văn phòng Chủ tịch nước chịu trách nhiệm thi hành Quyết định này. /

**CHỦ TỊCH  
NƯỚC CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM**

Nguyễn Minh Triết

Nơi nhận:

- - Chính phủ;
- - Văn phòng Chủ tịch nước;
- - Ban Thị đua - Khen thưởng TW;
- - Lưu: VT, Vụ TDKT-KTXH.');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (29, 1, 29, '29', '7

<table border="1">
<tr>
<td>88.</td>
<td>Lợi sỹ Phạm Thị Mạnh, nguyên Tiểu đội trưởng. Đc: 1255 Thanh niên xung phong Bắc Giang Long Khánh thuộc Tổng đội Thanh niên xung phong Giải phóng miền Nam.</td>
</tr>
<tr>
<td>89.</td>
<td>Lợi sỹ Hồ Thiên Nhân, nguyên Tỉnh đội phó tỉnh Phước Long (nay là tỉnh Bình Phước).</td>
</tr>
<tr>
<td>90.</td>
<td>Lợi sỹ Nguyễn Gia Lộc, nguyên Đội trưởng Đội 3, Biệt động Sài Gòn-Gia Định.</td>
</tr>
<tr>
<td>91.</td>
<td>Lợi sỹ Nguyễn Ngọc Đồng (Nguyễn Văn Ruy), nguyên Chính trị viên, Tiểu đoàn Phú Lợi II, Phân khu 6, Quân khu Sài Gòn-Gia Định.</td>
</tr>
<tr>
<td>92.</td>
<td>Lợi sỹ Lê Quang Cường, nguyên Đội trưởng Đội bảo vệ Tỉnh ủy Bà Rịa Long Khánh (nay là tỉnh Bà Rịa-Vũng Tàu).</td>
</tr>
<tr>
<td>93.</td>
<td>Lợi sỹ Huỳnh Minh Thanh, nguyên Bí thư chi bộ kiêm Chính trị viên xã Xuyên Mộc huyện Xuyên Mộc, tỉnh Bà Rịa-Vũng Tàu.</td>
</tr>
<tr>
<td>94.</td>
<td>Lợi sỹ Lưu Chí Hiếu, nguyên cán bộ Ban Công văn Quân ủy Quận 1, thành phố Sài Gòn - nguyên Tư chính trị Nhà tù Côn Đảo.</td>
</tr>
<tr>
<td>95.</td>
<td>Lợi sỹ Nguyễn Hùng Mạnh, nguyên Chiến sĩ giao liên xã Hội Mỹ, huyện Long Đà (nay là xã Phước Hội, huyện Đất Đỏ, tỉnh Bà Rịa-Vũng Tàu).</td>
</tr>
<tr>
<td>96.</td>
<td>Lợi sỹ Nguyễn Văn Chương, nguyên Trung đội trưởng, Đại đội 51, Huyện độ Xuyên Mộc, tỉnh Bà Rịa-Vũng Tàu.</td>
</tr>
<tr>
<td>97.</td>
<td>Lợi sỹ Trần Văn Chiến, nguyên Đại đội trưởng thuộc Tiểu đoàn 445, tỉnh Bà Rịa-Vũng Tàu.</td>
</tr>
<tr>
<td>98.</td>
<td>Lợi sỹ Võ Văn Khai, nguyên Tiểu đoàn trưởng Tiểu đoàn 445, tỉnh Bà Rịa-Vũng Tàu.</td>
</tr>
<tr>
<td>99.</td>
<td>Ông Ngô Thanh Văn (Ba Đen), nguyên Đội trưởng Đội Biệt động 11, Phân khu 6 Quân khu Sài Gòn-Gia Định.</td>
</tr>
<tr>
<td>100.</td>
<td>Ông Lê Tấn Quốc, nguyên Bí thư chi bộ, Chính trị viên Đội Biệt động 67, Quân khu Sài Gòn-Gia Định.</td>
</tr>
<tr>
<td>101.</td>
<td>Ông Tô Cẩm Vinh (Trần Ngọc Trình), nguyên Chiến sĩ Biệt động, Ban Hoa văn Đặc khu Sài Gòn-Chợ Lớn-Gia Định.</td>
</tr>
<tr>
<td>102.</td>
<td>Bà Nguyễn Thị Tư (Sáu Hoà), nguyên Ủy viên Ban quân sự Thành đoàn Sài Gòn-Gia Định.</td>
</tr>
<tr>
<td>103.</td>
<td>Ông Hồ Ngọc Dấn (Dương Tấn Mào), nguyên Tỉnh đội trưởng tỉnh Kiên Tường (nay là tỉnh Long An).</td>
</tr>
<tr>
<td>104.</td>
<td>Lợi sỹ Nguyễn Văn Lý, nguyên Trung đội bậc trưởng, Đại đội 66, Trung đoàn 81. Cục Hậu cần Miền.</td>
</tr>
<tr>
<td>105.</td>
<td>Lợi sỹ Võ Văn Sáu (Sáu Chiến, Sáu Mèo), nguyên Cán bộ công tác huấn luyện, Đại đội Biệt động thị xã Bến Tre, tỉnh Bến Tre.</td>
</tr>
<tr>
<td>106.</td>
<td>Lợi sỹ Huỳnh Văn Thon (Lê Hồng), nguyên Đại đội trưởng, Đại đội 1, Bộ đội địa phương huyện Chợ Lách, tỉnh Bến Tre.</td>
</tr>
<tr>
<td>107.</td>
<td>Lợi sỹ Huỳnh Văn Thức (Quyết Thắng), nguyên Tiểu đội trưởng Trinh sát, Bộ đội địa phương huyện Chợ Lách, tỉnh Bến Tre.</td>
</tr>
</table>

18 x

*[Handwritten mark]*');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (30, 1, 30, '30', 'UBND TỈNH LONG AN  
SỞ LÀO ĐỘNG THƯƠNG BINH  
VÀ XÃ HỘI

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

**DANH SÁCH TRUY TẶNG  
ANH HƯNG LỰC LƯỢNG VŨ TRANG NHÂN DÂN**

(Kèm theo Quyết định số 212/QĐ-CTN ngày 23/2/2010 của Chủ tịch nước )

<table border="1"><tbody><tr><td>1</td><td>Liệt sỹ Đồ Công Thường, nguyên Ủy viên quân sự xã Phú Ngải Trị huyện Châu Thành, tỉnh Long An</td></tr><tr><td>2</td><td>Liệt sỹ Lê Văn Khuê, nguyên Chủ tịch Ủy ban hành chính kháng chiến xã Phước Tân Hưng, huyện Châu Thành</td></tr><tr><td>3</td><td>Liệt sỹ Trương Văn Nhường, nguyên Giao liên xã Đức Lập Hạ, huyện Đức Hòa, tỉnh Long An.</td></tr><tr><td>4</td><td>Liệt sỹ Nguyễn Thái Bình, nguyên sinh viên Việt Nam du học tại Mỹ . Quê xã Tân Kim, huyện Cần Giuộc, tỉnh Long An.</td></tr><tr><td>5</td><td>Liệt sỹ Lê Văn Giao (Lê Hùng Minh), nguyên Trung Đội trưởng , Đội 198 Thanh niên xung phong, Tổng đội Thanh niên xung phong Giải phóng miền Nam huyện Đức Huệ</td></tr><tr><td>6</td><td>Liệt sỹ Hồ Văn Ngà, nguyên Đội trưởng Đội công binh huyện Châu Thành, tỉnh Long An.</td></tr><tr><td>7</td><td>Liệt sỹ Nguyễn Thị Bé (Nguyễn Hoàng Anh), nguyên Tiểu đội phó, Đội 198 Thanh niên xung phong, Tổng Đội Thanh niên xung phong Giải phóng miền Nam xã Đức Tân, huyện Tân Trụ.</td></tr><tr><td>8</td><td>Liệt sỹ Nguyễn Thị Lê (Nậm Châu), nguyên Bí thư xã Mỹ Thạnh Bắc, huyện Đức Huệ, tỉnh Long An</td></tr><tr><td>9</td><td>Liệt sỹ Nguyễn Thành Tuấn , nguyên xã Đội trưởng xã Mỹ Thạnh Bắc, huyện Đức Huệ, tỉnh Long An</td></tr><tr><td>10</td><td>Liệt sỹ Nguyễn Văn Trạm, nguyên xã Đội phó xã Mỹ Hạnh (nay là xã Mỹ Hạnh Bắc), huyện Đức Hòa, tỉnh Long An</td></tr><tr><td>11</td><td>Liệt sỹ Võ Văn Thần, nguyên Du kích xã Mỹ Hạnh ( nay là xã Mỹ Hạnh Bắc) huyện Đức Hòa tỉnh Long An.</td></tr><tr><td>12</td><td>Liệt sỹ Nguyễn Văn Liên (Bây Liên), nguyên Bí thư, kiêm xã Đội trưởng xã Hòa Khánh huyện Đức Hòa tỉnh Long An.</td></tr><tr><td>13</td><td>Liệt sỹ Nguyễn Văn Bực, nguyên Tiểu đội phó, Đại đội 313, huyện đội Châu Thành, tỉnh Long An.</td></tr><tr><td>14</td><td>Liệt sỹ Võ Văn Nô, nguyên Du kích xã Thanh Phú Long , huyện Châu Thành, tỉnh Long An</td></tr><tr><td>15</td><td>Liệt sỹ Trần Công Vĩnh, nguyên Phó Bí thư Huyện Đoàn Mộc Hóa, tỉnh Tân An ( nay là tỉnh Long An)</td></tr><tr><td>16</td><td>Ông Hồ Ngọc Dân (Dương Tấn Mào), nguyên Tỉnh Đội trưởng tỉnh Kiên Tường ( nay là tỉnh Long An) thành phố Tân An</td></tr></tbody></table>

09.08.2010  
Phạm  
+8');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (31, 1, 31, '31', '6

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM

Phường: .....  
Huyện: .....  
Tỉnh: .....

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM

Độc lập - Tự do - Hạnh phúc

\*\*\*\*\*

Số: .....  
Quyển số .....

**GIẤY BÁO TỬ**

Căn cứ giấy báo tử số ..... ngày ..... tháng ..... năm .....  
Của người (hoặc cơ quan) báo tử ..... Nguyễn Hữu Phú .....  
Nơi thường trú: ..... 47/13 ..... QL 62 ..... Phường 2 ..... KST .....  
..... Long An .....  
Số chứng minh nhân dân hoặc hộ chiếu .....  
Quan hệ với người chết: ..... Vợ ..... Nam, nữ .....

**NAY BÁO TỬ :**

Họ và tên người chết: ..... Hồ ..... Nguyễn ..... Đơn ..... Nam, nữ .....  
Sinh ngày: ..... tháng ..... năm ..... 1980 .....  
Dân tộc: ..... Kinh ..... Quốc tịch: ..... Việt Nam .....  
Nơi thường trú: ..... 47/13 ..... QL 62 ..... Phường 2 ..... KST .....  
Số CMND: ..... ngày cấp: ..... nơi cấp .....  
Chết ngày: ..... 09 ..... tháng ..... 7 ..... năm ..... 19.9.1989 .....  
Nơi chết: ..... 47/13 ..... QL 62 ..... Phường 2 ..... KST ..... Long An .....

Nguyên nhân chết: ..... bệnh chết .....  
.....  
.....

Việc mai táng phải tiến hành chậm nhất trong 24 giờ kể từ ngày chết, trường hợp có quyết định khác của cơ quan có thẩm quyền theo luật định.

Phường II ngày 12 tháng 7 năm 1999.  
TRƯỞNG CÔNG AN

Ngày 12 tháng 7 năm 1999

CÁN BỘ LẬP GIẤY

(Ký tên đóng dấu)

*[Handwritten signature]*  
Nguyễn văn Phú

Thị trấn: .....  
Thị xã: .....  
Thị trấn: .....');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (32, 1, 32, '32', '61

UBND TP TÂN AN  
PHÒNG LD-TB VÀ XH

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM

Độc lập – Tự do – Hạnh phúc

Số 468 /CV-LD-TBXH  
Về việc báo cáo đối tượng được  
truy tặng danh hiệu AHLLVT

Tân An, ngày 18 tháng 8 năm 2010

Kính gửi: Sở LD-TB và XH Long An

Thực hiện công văn 630/CV-SLD-TBXH ngày 27/4/2010 của Sở LD-TB và XH Long An về việc giải quyết chế độ cho thân nhân Anh hùng Lực lượng vũ trang.

Theo Công văn trên Sở LD-TB và XH tỉnh chỉ đạo hướng dẫn thân nhân AHLLVT lập bản khai và tổng hợp gửi về Sở để xét giải quyết chế độ trợ cấp cho thân nhân.

Phòng LD-TB và XH thành phố Tân An báo cáo đối tượng như sau:

Người được truy tặng danh hiệu Anh hùng Lực lượng vũ trang:

Liệt sỹ Lê Văn Khuê, sinh năm 1912; hy sinh ngày 2/9/1949;

Nguyên quán xã Phước Tân Hưng, huyện Châu Thành, tỉnh Long An;

Hồ sơ quản lý thờ cúng liệt sỹ tại phường 2, thành phố Tân An;

Quyết định truy tặng AHLLVT số 212/QĐ/CTN ngày 23/2/2010 của Chủ tịch nước;

Thân nhân chủ yếu đang thờ cúng là con trai Lê Thanh Thế, sinh 1933, cư trú số 74 đường Lê Văn Tao, phường 2, thành phố Tân An (kèm theo hồ sơ đã khai).

Phòng LD-TB và XH thành phố xin báo cáo theo chỉ đạo của Sở./.

Nơi nhận:

- - Như trên;
- - PCTvx UBND TX (b/c);
- - Ông Lê Thanh Thế;
- - Lưu VT, d.

**TRƯỞNG PHÒNG**

Trần Thị Chiễm');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (33, 1, 33, '33', 'UBND TỈNH LONG AN  
SỞ LAO ĐỘNG - THƯƠNG BINH  
VÀ XÃ HỘI

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

Số: 4 /QĐ-SLDTBXH

Tân An, ngày 15 tháng 11 năm 2010

Số hồ sơ: 61

**QUYẾT ĐỊNH**

**Về việc trợ cấp ưu đãi Anh hùng lực lượng vũ trang nhân dân**

**GIÁM ĐỐC SỞ LAO ĐỘNG THƯƠNG BINH VÀ XÃ HỘI**

Căn cứ Nghị định số 54/2006/NĐ-CP ngày 26 tháng 5 năm 2006 của Chính phủ hướng dẫn thi hành một số điều Pháp lệnh ưu đãi người có công với cách mạng;

Căn cứ Quyết định số 212/QĐ-CTN ngày 23 tháng 02 năm 2010 của Chủ tịch nước;

Căn cứ Nghị định số 35//2010/NĐ-CP ngày 6 tháng 4 năm 2010 của Chính phủ quy định về mức trợ cấp, phụ cấp ưu đãi đối với người có công với cách mạng;

Xét đề nghị của Trưởng Phòng Người có công;

**QUYẾT ĐỊNH:**

**Điều 1.** Trợ cấp một lần đối với ông: Lê Thanh Thế, Sinh năm: 1933.

Nguyên quán: xã Phước Tân Hưng, huyện Châu Thành, tỉnh Long An.  
Trú quán: Phường II, TP Tân An, tỉnh Long An.

Là con của Anh hùng lực lượng vũ trang: Lê Văn Khuê.

Nguyên quán: xã Phước Tân Hưng, huyện Châu Thành, tỉnh Long An.  
Trú quán: xã Phước Tân Hưng, huyện Châu Thành, tỉnh Long An.

đã được truy tặng danh hiệu Anh hùng lực lượng vũ trang nhân dân, theo Quyết định số 212/QĐ-CTN ngày 23 tháng 02 năm 2010 của Chủ tịch nước.

Mức trợ cấp 1 lần là: 13.700.000 đ

(Bằng chữ: Mười ba triệu bảy trăm ngàn đồng)

**Điều 2.** Trưởng Phòng Người có công, Trưởng Phòng Kế hoạch - Tài chính, Trưởng Phòng Lao động Thương binh Xã hội TP Tân An và ông Lê Thanh Thế có trách nhiệm thi hành quyết định này. / *Nguyễn Văn Ghim*

**Nơi nhận:**

- - Như điều 2;
- - Lưu VT.

**Nguyễn Văn Ghim**');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (34, 1, 34, '34', '4QUAN HỆ VỚI CHỦ HỘ Con

Họ và tên: LÊ TẤN PHƯỚC  
 Bí danh (tên thường gọi):                       
 Ngày sinh: 1989 Nam, nữ             
 Nơi sinh:                       
 Nguyên quán: Châu Thành, Long An  
 Dân tộc: Kinh Tôn giáo                       
 Nghề nghiệp:                       
 Nơi làm việc:                       
 Giấy CMND số: 301312099  
 Ngày cấp:            Nơi cấp                       
 Chuyển đến ngày: 20.02.90  
 Nơi thường trú trước khi chuyển đến:                     

Cán bộ đăng ký                      Ngày 2 tháng 2 năm 81  
 (Ghi rõ họ tên, ký)                      I Trưởng CA                     

Mai Lang Long  
 Chuyển đi ngày:                      Thiểu:                       
 Nơi chuyển đến:                     

Cán bộ đăng ký                      Ngày            tháng            năm             
 (Ghi rõ họ tên, ký)                      Trưởng CA                     

1CHỦ HỘ

Họ và tên: LÊ THANH THẾ  
 Bí danh (tên thường gọi):                       
 Ngày sinh: 05.11.1933 Nam, nữ             
 Nơi sinh:                       
 Nguyên quán: Châu Thành, Long An  
 Dân tộc: Kinh Tôn giáo                       
 Nghề nghiệp: Cán bộ thiếu trí  
 Nơi làm việc:                       
 Giấy CMND số:                       
 Ngày cấp:            Nơi cấp                       
 Chuyển đến ngày: 12.01.1980  
 Nơi thường trú trước khi chuyển đến:                     

Cán bộ đăng ký                      Ngày            tháng            năm             
 (Ghi rõ họ tên, ký)                      Trưởng CA                     

Chuyển đi ngày:                       
 Nơi chuyển đến:                     

Cán bộ đăng ký                      Ngày            tháng            năm             
 (Ghi rõ họ tên, ký)                      Trưởng CA');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (35, 1, 35, '35', '14/AHLVT: 61

Mẫu số 4c-AH

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM

Độc lập - Tự do - Hạnh phúc

BẢN KHAI VỀ NGƯỜI CÓ CÔNG

gấp 7 thực

1. Phần khai về người có công:

Họ và tên: LÊ VĂN KHTUÊ Nam (Nữ) Nam Năm sinh: 1912  
Nguyên quán: Xã Phước Tân Hưng, huyện Châu Thành, tỉnh Long An  
Cơ quan, đơn vị có công tác: Lữ đoàn hành chính kháng chiến  
Nơi đăng ký hộ khẩu: Xã Phước Tân Hưng, huyện Châu Thành, Long An  
Đã được tặng danh hiệu (Anh hùng LLVT, Anh hùng LD trong kháng chiến):  
Anh hùng chiến đấu, chiến thắng, Nhân dân  
Theo Quyết định số...2112... ngày 23 tháng 2 năm 2000 của Chủ tịch nước.

2. Phần khai về thân nhân (người đứng khai):

Họ và tên: LÊ THANH THÊ Năm sinh: 1933  
Nguyên quán: Xã Phước Tân Hưng, huyện Châu Thành, Long An  
Trú quán Tà Lẻ Văn Tân, Phường 2, TP. Tân Châu, Long An  
Quan hệ với Anh hùng LLVT, Anh hùng LD trong kháng chiến: (vợ, chồng, cha, mẹ, con...) con trai Anh hùng LLVT Lê Văn Khuê  
đã từ trần ngày 2 tháng 9 năm 1949

Tôi cam đoan lời khai trên là đúng, nếu sai tôi hoàn toàn chịu trách nhiệm trước pháp luật.

Ông (bà) Lê Thanh Thê con ông bà Văn Khuê Ngày 9 tháng 8 năm 2010  
Hiện cư trú tại: Tà Lẻ Văn Tân  
chưa hưởng trợ cấp ưu đãi đối với Anh hùng LLVT, (Người khai  
Anh hùng LD trong kháng chiến. (Ký, ghi rõ họ và tên)

Lê, ngày 12 tháng 8 năm 2010  
**CHỦ TỊCH**  
(Ký tên, đóng dấu)

**Nguyễn Văn Hải**

Lê Thanh Thê

189');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (36, 1, 36, '36', 'Mẫu số 4c-AHCỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúcBẢN KHAI VỀ NGƯỜI CÓ CÔNG

1. Phần khai về người có công:

Họ và tên: LÊ VĂN KHUÊ Nam (Nữ) Nam Năm sinh: 1919  
 Nguyên quán: Xã Phước Tồn Hùng, Châu Thủy, Long An  
 Cơ quan, đơn vị công tác: Lữ đoàn Hải quân Khánh Thuận  
 Nơi đăng ký hộ khẩu: Xã Phước Tồn Hùng, Châu Thủy, Long An  
 Đã được tặng danh hiệu (Anh hùng LLVT, Anh hùng LD trong kháng chiến):  
Anh hùng LLVT, Anh hùng LLVT, Anh hùng LD trong kháng chiến  
 Theo Quyết định số...212... ngày 23 tháng 2 năm 2010 của Chủ tịch nước

2. Phần khai về thân nhân (người đứng khai):

Họ và tên: LÊ THANH THẾ Năm sinh: 1933  
 Nguyên quán: Xã Phước Tồn Hùng, Châu Thủy, Long An  
 Trú quán: 44 Lê Văn Tào, Phường Long, TP. Tân An, Long An  
 Quan hệ với Anh hùng LLVT, Anh hùng LD trong kháng chiến: (vợ, chồng, cha, mẹ, con...) con trai Anh hùng LLVT Lê Văn Khuê  
 đã từ trần ngày 2 tháng 9 năm 1949

Tôi cam đoan lời khai trên là đúng, nếu sai tôi hoàn toàn chịu trách nhiệm trước pháp luật.

Ông (bà) Lê Thanh Thế con ông Lê Văn Khuê Ngày 9 tháng 8 năm 2010  
 Hiện cư trú tại: 44 Lê Văn Tào Người khai  
 chưa hưởng trợ cấp ưu đãi đối với Anh hùng LLVT, (Ký, ghi rõ họ và tên)  
 Anh hùng LD trong kháng chiến.

23, ngày 13 tháng 8 năm 2010

CHỦ TỊCH

(Ký tên, đóng dấu)

Nguyễn Văn Hải

Lê Thanh Thế

189');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (37, 1, 37, '37', '9

**THỨ TƯ TRAO TẶNG**  
**DANH HIỆU ANH HÙNG LỰC LƯỢNG VŨ TRANG NHÂN DÂN**  
 (ngày 28 tháng 4 năm 2010)

Để việc trao tặng Danh hiệu Anh hùng LLVTND được thuận lợi, Ban Tổ chức kính đề nghị các thân nhân Anh hùng chú ý: Nhờ số thứ tự để khi lên nhận đúng đúng số thứ tự mà Ban tổ chức đã dán trên sân sân khấu.

<table border="1">
<thead>
<tr>
<th>Số thứ tự</th>
<th>Thân nhân của Anh hùng Lực lượng vũ trang nhân dân</th>
</tr>
</thead>
<tbody>
<tr>
<td colspan="2"><b>ĐỢT ĐẦU:</b></td>
</tr>
<tr>
<td>1</td>
<td>Thân nhân Anh hùng <b>Nguyễn Thị Bảy</b></td>
</tr>
<tr>
<td>2</td>
<td>Thân nhân Anh hùng <b>Đỗ Công Thương</b></td>
</tr>
<tr>
<td>3</td>
<td>Thân nhân Anh hùng <b>Lê Văn Khuê</b> <i>(Thân nhân)</i></td>
</tr>
<tr>
<td>4</td>
<td>Thân nhân Anh hùng <b>Nguyễn Thái Bình</b></td>
</tr>
<tr>
<td>5</td>
<td>Thân nhân Anh hùng <b>Trương Văn Nhưòng</b></td>
</tr>
<tr>
<td>6</td>
<td>Thân nhân Anh hùng <b>Hồ Văn Ngà</b></td>
</tr>
<tr>
<td>7</td>
<td>Thân nhân Anh hùng <b>Lê Văn Giao</b> <i>(Lê Văn)</i></td>
</tr>
<tr>
<td>8</td>
<td>Thân nhân Anh hùng <b>Nguyễn Thị Bé</b> (Nguyễn Hoàng Anh)</td>
</tr>
<tr>
<td>9</td>
<td>Thân nhân Anh hùng <b>Nguyễn Thị Lệ</b> <i>(Sơn)</i></td>
</tr>
<tr>
<td colspan="2"><b>ĐỢT HAI</b></td>
</tr>
<tr>
<td>1</td>
<td>Thân nhân Anh hùng <b>Nguyễn Thành Toàn</b></td>
</tr>
<tr>
<td>2</td>
<td>Thân nhân Anh hùng <b>Nguyễn Văn Trại</b></td>
</tr>
<tr>
<td>3</td>
<td>Thân nhân Anh hùng <b>Võ Văn Thền</b> <i>(Võ)</i></td>
</tr>
<tr>
<td>4</td>
<td>Thân nhân Anh hùng <b>Nguyễn Văn Liên</b> <i>(Nguyễn Văn)</i></td>
</tr>
<tr>
<td>5</td>
<td>Thân nhân Anh hùng <b>Lê Văn Bực</b> <i>(Lê Văn)</i></td>
</tr>
<tr>
<td>6</td>
<td>Thân nhân Anh hùng <b>Võ Văn Nô</b> <i>(Võ Văn)</i></td>
</tr>
<tr>
<td>7</td>
<td>Thân nhân Anh hùng <b>Trần Công Vịnh</b> <i>(Trần Công)</i></td>
</tr>
<tr>
<td>8</td>
<td>Thân nhân Anh hùng <b>Định Văn Phu</b></td>
</tr>
<tr>
<td>9</td>
<td>Thân nhân Anh hùng <b>Hồ Ngọc Dấn</b> <i>(Hồ Ngọc)</i></td>
</tr>
</tbody>
</table>

Ban tổ chức kính mong thân nhân các Anh hùng quan tâm hỗ trợ chúng tôi cùng thực hiện tốt phần nghi thức công bố Quyết định và tổ chức trao tặng danh hiệu anh hùng LLVT ND.

Xin trân trọng cảm ơn !');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (38, 1, 38, '38', 'AHLLV7/611/0

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
ĐỘC LẬP - TỰ DO - HẠNH PHÚC

**CHỦ TỊCH**

NUỐC CỘNG HOÀ XÃ HỘI CHỦ NGHĨA VIỆT NAM

**TẶNG DANH HIỆU**

**ANH HÙNG LỰC LƯỢNG VŨ TRANG NHÂN DÂN**

Truy tặng Liệt sỹ **LÊ VĂN KHUÊ**

Nguyên Chủ tịch Ủy ban Hành chính Kháng chiến xã Phước Tân Hưng,  
huyện Châu Thành, tỉnh Long An

**Đã có thành tích đặc biệt xuất sắc trong cuộc kháng chiến chống thực dân Pháp xâm lược**

Chứng thực bản sao đúng với bản chính  
(Số: 4207.../CT38 quyên.../Lq...  
Phường 2, ngày 02 tháng 02 năm 2010  
(CHỦ TỊCH UBND PHƯỜNG 2)  
  
Lê Anh Tuấn

Quyết định số: 212 QĐ/CTN ngày 23 tháng 02 năm 2010  
Vào số vàng số: 15

Hà Nội, ngày 23 tháng 02 năm 2010  
CHỦ TỊCH  
NUỐC CỘNG HOÀ XÃ HỘI CHỦ NGHĨA VIỆT NAM  
  
  
Nguyễn Minh Triết');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (39, 1, 39, '39', 'AI11LV7161 (M)

BẢN SẢO

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
ĐỘC LẬP - TỰ DO - HẠNH PHÚC

**CHỦ TỊCH**

NUỐC CỘNG HOÀ XÃ HỘI CHỦ NGHĨA VIỆT NAM

**TẶNG DANH HIỆU**

**ANH HÙNG LỰC LƯỢNG VŨ TRANG NHÂN DÂN**

Truy tặng Liệt sỹ **LÊ VĂN KHUÊ**

Nguyên Chủ tịch Ủy ban Hành chính Kháng chiến xã Phước Tân Hưng,  
huyện Châu Thành, tỉnh Long An

**Đã có thành tích đặc biệt xuất sắc trong cuộc kháng chiến chống thực dân Pháp xâm lược**

Quyết định số 212 QĐ/ICTN ngày 23 tháng 02 năm 2010

Vào sổ vàng số 15

Chứng thực bởi: Cao đình với bộ chính  
(Số: 123456789, Nơi ở: quận 01,  
Phường 02, ngày 13 tháng 02 năm 2010)  
CHỦ TỊCH UBND PHƯỜNG 2

Nguyễn Thị Hồng Phái

Hà Nội, ngày 23 tháng 02 năm 2010

CHỦ TỊCH

Nguyễn Minh Triết');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (40, 1, 40, '40', 'UBND TỈNH LONG AN  
SỞ LAO ĐỘNG TB & XH  
Số : 62...../TBLS.GT

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

Tân An, ngày 29 tháng 10 Năm 2005

### GIẤY GIỚI THIỆU DI CHUYỂN HỒ SƠ

Kính gửi : Phòng LDTB & XH Huyện, Thị : Xã Tân An .....

Giới thiệu Ông, bà : Lê Thanh Thế  
là Cen. Bk. U vấn Khu. LA: 11929 +. Me. VN. TH. Lê Thị Thông  
Họ sơ số : LA: 11929. Số sơ :

Số BTQGC ..... QĐ ..... ngày .....

Hiện có hồ khẩu tại Phường 2 - Xã Tân An - Long An

Họ sơ xã M.V.N. TH từ xã Phước Tiến Hùng - Châu Thành  
nay chuyển về xã Phước - Xã Tân An

Đề giải quyết : quyền thu lương Me. VN. TH xã Thế Cống liệt sĩ.

Sở LDTB & XH Long An đề nghị Phòng LDTB & XH Huyện Thủ Xã Tân An  
vào sổ sách quản lý và xem xét giải quyết các chế độ CS Nhà nước  
qui định.

- - Nơi nhận
- - Như trên
- - Lưu

Giám đốc  
SỞ LDTB & XH

*(Signature)*

- Chú về Châu Thành lâu hơn xin chuyển danh liệu cá thẻ lực  
 lương từ trang của bệnh sỹ Lê Văn Khue tiếp cập An, thì tiếp cập  
 An mới cập tiếp quá theo danh liệu cá thẻ lực lương từ trang của  
 bệnh sỹ Lê Văn Khue. Chiến');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (41, 1, 41, '41', 'Lê 2

UBND TỈNH LONG AN    CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
SỞ LAO ĐỘNG THƯƠNG BINH    Độc lập - Tự do - Hạnh phúc  
VÀ XÃ HỘI

Số: 600/CV-SLDTBXH

Tân An, ngày 27 tháng 04 năm 2010

Về việc giải quyết chế độ cho thân nhân  
Anh hùng Lực lượng vũ trang

Kính gửi : Phòng Lao động Thương binh và Xã hội  
huyện, thành phố

Thì hành Quyết định số 212/QĐ-CTN ngày 23/2/2010 của Chủ tịch nước về việc truy tặng danh hiệu anh hùng lực lượng vũ trang.

Căn cứ theo qui định Nghị định số 54/2006/NĐ-CP ngày 26/5/2006 của Chính phủ về việc hướng dẫn thi hành một số điều của Pháp lệnh ưu đãi người có công với cách mạng và Thông tư số 07/2006/TT-BLDTBXH ngày 26/7/2006 của Bộ Lao động - Thương binh và Xã hội hướng dẫn về hồ sơ, lập hồ sơ thực hiện chế độ ưu đãi người có công với cách mạng.

Đề giải quyết kịp thời chế độ cho người có công với cách mạng (có danh sách đính kèm). Đề nghị Phòng Lao động-Thương binh và Xã hội huyện, thành phố phối hợp với UBND xã, phường hướng dẫn thân nhân lập bản khai (mẫu 4c-AH) và tổng hợp gửi về Sở Lao động Thương binh và Xã hội để xem xét và giải quyết chế độ trợ cấp cho thân nhân.

Trường hợp liệt sỹ không còn thân nhân chủ yếu (cha đẻ, mẹ đẻ, vợ hoặc chồng, con đẻ, người có công nuôi liệt sỹ ) thì phải kèm theo biên bản hợp thân tộc có xác nhận của UBND xã nơi cư trú.

Nhận được công văn này, đề nghị Phòng Lao động Thương binh và Xã hội huyện, thành phố triển khai thực hiện.

Nơi nhận :

- - UBND tỉnh "báo cáo";
- - GD, phó GD sở ;
- - Như trên;
- - Lưu: TBLS-NCC.

KT **GIÁM ĐỐC**  
**PHÓ GIÁM ĐỐC**

Nguyễn Văn Ghim');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (42, 1, 42, '42', 'CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

GIẤY CHỨNG MINH NHÂN DÂN

Số 304316592

Họ tên: LÊ-THANH-THẾ

Sinh ngày: 05/11/1933

Nguyên quán: Phước tan hưng

Châu thành, Long an

Nơi ĐKHK thường trú: 74 Lê Văn Tao  
Phường 2, Tân an, Long an');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (43, 1, 43, '43', '<table border="1"><tr><td>Dân tộc: <b>kinh</b></td><td>Tôn giáo: <b>không</b></td></tr><tr><td></td><td></td></tr><tr><td colspan="2">DẤU VẾT RIÊNG VÀ ĐI HÌNH<br/>seo chạm CO, 4cm trên<br/>trước đầu máy phải</td></tr><tr><td colspan="2">Ngày <b>12</b> tháng <b>11</b> năm <b>2004</b></td></tr><tr><td colspan="2">GIÁM ĐỐC CA TỈNH LONG AN</td></tr><tr><td colspan="2"> <b>Nguyễn Hữu</b></td></tr></table>

CHỦNG NHẬN SAO ĐÚNG VỚI BẢN CHÍNH  
SỞ CC ... **N69** ... QS **2** ... TP/CC  
Ngày **1** Tháng **3** ... Năm **2007**  
**CỘNG HÒA VIỆT NAM**

**ĐA THU LÊ PHÍ**

**Nguyễn Hữu Phước**');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (44, 1, 44, '44', 'UBND TỈNH LONG AN  
SỞ LAO ĐỘNG THƯƠNG BINH  
VÀ XÃ HỘI

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

2

**DANH SÁCH TRUY TẶNG  
ANH HÙNG LỰC LƯỢNG VŨ TRANG NHÂN DÂN**  
(Kèm theo Quyết định số 212/QĐ-CTN ngày 23/2/2010 của Chủ tịch nước )

<table border="1"><tbody><tr><td>1</td><td>Liệt sỹ Đô Công Thượng, nguyên Ủy viên quân sự xã Phú Ngãi Trị huyện Châu Thành, tỉnh Long An</td></tr><tr><td>2</td><td>Liệt sỹ Lê Văn Khuê, nguyên Chủ tịch Ủy ban hành chính kháng chiến xã Phước Tân Hưng, huyện Châu Thành</td></tr><tr><td>3</td><td>Liệt sỹ Trương Văn Nhường, nguyên Giao liên xã Đức Lập Hạ, huyện Đức Hòa, tỉnh Long An.</td></tr><tr><td>4</td><td>Liệt sỹ Nguyễn Thái Bình, nguyên sinh viên Việt Nam du học tại Mỹ . Quê xã Tân Kim, huyện Cần Giờ, tỉnh Long An.</td></tr><tr><td>5</td><td>liệt sỹ ế Văn Giego (Lê Hùng Minh), nguyên Trung đội trưởng , Đội 198 Thanh niên xung phong, Tổng đội Thanh niên xung phong Giải phóng miền Nam huyện Đức Huệ</td></tr><tr><td>6</td><td>Liệt sỹ Hồ Văn Ngà, nguyên Đội trưởng Đội công binh huyện Châu Thành, tỉnh Long An.</td></tr><tr><td>7</td><td>Liệt sỹ Nguyễn Thị Bé (Nguyễn Hoàng Anh), nguyên Tiểu đội phó, Đội 198 Thanh niên xung phong, Tổng Đội Thanh niên xung phong Giải phóng miền Nam xã Đức Tân, huyện Tân Trụ.</td></tr><tr><td>8</td><td>Liệt sỹ Nguyễn Thị Lê (Nằm Châu), nguyên Bí thư xã Mỹ Thạnh Bắc, huyện Đức Huệ, tỉnh Long An</td></tr><tr><td>9</td><td>Liệt sỹ Nguyễn Thành Tuấn , nguyên xã Đội trưởng xã Mỹ Thạnh Bắc, huyện Đức Huệ, tỉnh Long An</td></tr><tr><td>10</td><td>Liệt sỹ Nguyễn Văn Trạm, nguyên xã Đội phó xã Mỹ Hạnh (nay là xã Mỹ Hạnh Bắc), huyện Đức Hòa, tỉnh Long An</td></tr><tr><td>11</td><td>Liệt sỹ Võ Văn Thên, nguyên Du kích xã Mỹ Hạnh ( nay là xã Mỹ Hạnh Bắc) huyện Đức Hòa tỉnh Long An.</td></tr><tr><td>12</td><td>Liệt sỹ Nguyễn Văn Liên (Bây Liên), nguyên Bí thư, kiêm xã Đội trưởng xã Hòa Khánh huyện Đức Hòa tỉnh Long An.</td></tr><tr><td>13</td><td>Liệt sỹ Nguyễn Văn Bực, nguyên Tiểu đội phó, Đại đội 313, huyện đội Châu Thành, tỉnh Long An.</td></tr><tr><td>14</td><td>Liệt sỹ Võ Văn Nỗ, nguyên Du kích xã Thanh Phú Long , huyện Châu Thành, tỉnh Long An</td></tr><tr><td>15</td><td>Liệt sỹ Trần Công Vịnh, nguyên Phó Bí thư Huyện Đoàn Mộc Hóa, tỉnh Tân An ( nay là tỉnh Long An)</td></tr><tr><td>16</td><td>Ông Hồ Ngọc Dần (Dương Tấn Mào), nguyên Tỉnh Đội trưởng tỉnh Kiên Tường ( nay là tỉnh Long An) thành phố Tân An</td></tr></tbody></table>

09.08.2013  
Trợ');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (45, 1, 45, '45', 'CỘNG AN TỈNH LONG AN  
CỘNG AN THỊ XÃ TÂN AN

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

Số: 312 - GCN/CATX

Tân An, ngày 2... tháng 4... năm 1997

### GIẤY CHỨNG NHẬN

"Về chính đối số nhà, tên đường"

- - Căn cứ điều 2 quyết định 2554/QĐ.UB ngày 18/10/1997 của UBND tỉnh về đối đặt tên đường mới.
- - Để phù hợp xu hướng đổi mới, tăng cường quản lý Nhà nước trên địa bàn thị xã.

### CỘNG AN THỊ XÃ TÂN AN CHỨNG NHẬN:

Số nhà cũ: 48/40... đường (khom, ấp)... 96.5  
Phường 2... TXTA. Do ông (bà) LÊ THẠNH THẾ  
Ssn: 1935 số CMND... do Công an...  
cấp ngày... làm chủ hộ khẩu đã được chính đối số nhà, tên đường mới.

Giấy chứng nhận này chỉ có giá trị khi quan hệ giao dịch với các cơ quan có liên quan đến hộ tịch, hộ khẩu không có giá trị thay thế các loại giấy tờ khác.

TRƯỞNG CỘNG AN THỊ XÃ

Thị xã Tân An, Long An

Mẫu NK3a

BÁNSAO

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

TỈNH LONG AN

Độc lập - Tự do - Hạnh phúc  
Số: 10  
Ngày 2... tháng 4... năm 1997  
UBND PHƯỜNG 2

Trang: 1

## SỔ HỘ KHẨU GIA ĐÌNH Số 01009068

Ho và tên chủ hộ  
Số nhà, ngõ hẻm.  
Đường phố, xóm, ấp.  
Phường, xã, thị trấn.  
Quận, huyện, thị xã.

LÊ THẠNH THẾ  
74  
LÊ VĂN TẠO, KIỀU PHỎNG  
PHƯỜNG 2  
TÂN AN

Quyển số...  
Trang...

Số hồ sơ hộ khẩu 2509');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (46, 1, 46, '46', '2QUAN HỆ VỚI CHỦ HỘ

08

Họ và tên:

TRẦN THỊ NẤU

Bí danh (tên thường gọi):

Ngày sinh: 1950 Nam, nữ

Nơi sinh:

Nguyên quán: Châu Thành, Long An

Dân tộc: Kinh Tôn giáo

Nghề nghiệp: Dạy học

Nơi làm việc:

Giấy CMND số:

Ngày cấp: Nơi cấp

Chuyển đến ngày: 20 - 12 - 1982

Nơi thường trú trước khi chuyển đến:

Cán bộ đăng ký Ngày ... tháng ... năm

(Ghi rõ họ tên, ký) Trường CA

Chuyển đi ngày:

Nơi chuyển đến:

Cán bộ đăng ký Ngày ... tháng ... năm

(Ghi rõ họ tên, ký) Trường CA

QUAN HỆ VỚI CHỦ HỘ3

Họ và tên: LÊ THỊ MAI XUÂN

Bí danh (tên thường gọi):

Ngày sinh: 1979 Nam, nữ

Nơi sinh:

Nguyên quán: Châu Thành, Long An

Dân tộc: Kinh Tôn giáo

Nghề nghiệp: Học sinh

Nơi làm việc:

Giấy CMND số: 500.925.325

Ngày cấp: Nơi cấp

Chuyển đến ngày:

Nơi thường trú trước khi chuyển đến:

Cán bộ đăng ký Ngày ... tháng ... năm

(Ghi rõ họ tên, ký) Trường CA

Chuyển đi ngày:

Nơi chuyển đến:

Cán bộ đăng ký Ngày ... tháng ... năm

(Ghi rõ họ tên, ký) Trường CA');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (47, 1, 47, '47', 'QUAN HỆ VỚI CHỦ HỘ...Con.....

5

Họ và tên: T. THỊ MAI HƯỜNG

Bí danh (tên thường gọi): \_\_\_\_\_

Ngày sinh: 1977 Nam, nữ

Nơi sinh: thành phố HCM

Nguyên quán: chợ rẫy Long An

Dân tộc: Kinh Tôn giáo: \_\_\_\_\_

Nghề nghiệp: \_\_\_\_\_

Nơi làm việc: \_\_\_\_\_

Giấy CMND số: 300 855801

Ngày cấp: \_\_\_\_\_ Nơi cấp: \_\_\_\_\_

Chuyển đến ngày: 20.12.2001

Nơi thường trú trước khi chuyển đến: \_\_\_\_\_

ĐH đảo lạp, xã Phước Phước, TP HCM

Cán bộ đăng ký: \_\_\_\_\_ Ngày đăng ký: \_\_\_\_\_

(Ghi rõ họ tên, ký) \_\_\_\_\_

*Signature*

Thiếu: Thiếu tướng Đào

Chuyển đi ngày: \_\_\_\_\_

Nơi chuyển đến: \_\_\_\_\_

\_\_\_\_\_

Cán bộ đăng ký: \_\_\_\_\_ Ngày: \_\_\_\_\_ tháng \_\_\_\_\_ năm \_\_\_\_\_

(Ghi rõ họ tên, ký) \_\_\_\_\_ Trưởng CA \_\_\_\_\_');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (48, 1, 48, '48', '6QUAN HỆ VỚI CHỦ HỘ .....

Họ và tên: .....  
 Bí danh (tên thường gọi): .....  
 Ngày sinh ..... Nam, nữ  
 Nơi sinh: .....  
 Nguyên quán: .....  
 Dân tộc: ..... Tôn giáo .....  
 Nghề nghiệp: .....  
 Nơi làm việc: .....  
 Giấy CMND số: .....  
 Ngày cấp: ..... Nơi cấp .....  
 Chuyển đến ngày: .....  
 Nơi thường trú trước khi chuyển đến: .....

Cán bộ đăng ký ..... Ngày ..... tháng ..... năm .....  
 (Ghi rõ họ tên, ký) ..... Trưởng CA .....

Chuyển đi ngày: .....  
 Nơi chuyển đến: .....

Cán bộ đăng ký ..... Ngày ..... tháng ..... năm .....  
 (Ghi rõ họ tên, ký) ..... Trưởng CA .....

7QUAN HỆ VỚI CHỦ HỘ .....

Họ và tên: .....  
 Bí danh (tên thường gọi): .....  
 Ngày sinh ..... Nam, nữ  
 Nơi sinh: .....  
 Nguyên quán: .....  
 Dân tộc: ..... Tôn giáo .....  
 Nghề nghiệp: .....  
 Nơi làm việc: .....  
 Giấy CMND số: .....  
 Ngày cấp: ..... Nơi cấp .....  
 Chuyển đến ngày: .....  
 Nơi thường trú trước khi chuyển đến: .....

Cán bộ đăng ký ..... Ngày ..... tháng ..... năm .....  
 (Ghi rõ họ tên, ký) ..... Trưởng CA .....

Chuyển đi ngày: .....  
 Nơi chuyển đến: .....

Cán bộ đăng ký ..... Ngày ..... tháng ..... năm .....  
 (Ghi rõ họ tên, ký) ..... Trưởng CA .....');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (49, 1, 49, '49', '62  
UBND TỈNH LONG AN  
SỞ LAO ĐỘNG - THƯƠNG BINH  
VÀ XÃ HỘI

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

Số: 5 /QĐ-SLĐTBXH

Long An, ngày 01 tháng 3 năm 2011

Số hồ sơ: 62

**QUYẾT ĐỊNH**

**Về việc trợ cấp ưu đãi Anh hùng lực lượng vũ trang nhân dân**

**GIÁM ĐỐC SỞ LAO ĐỘNG THƯƠNG BINH VÀ XÃ HỘI**

Căn cứ Nghị định số 54/2006/NĐ-CP ngày 26 tháng 5 năm 2006 của Chính phủ hướng dẫn thi hành một số điều Pháp lệnh ưu đãi người có công với cách mạng;  
Căn cứ Quyết định số 738/QĐ-CTN ngày 28 tháng 5 năm 2010 của Chủ tịch nước;  
Căn cứ Nghị định số 35/2010/NĐ-CP ngày 06 tháng 4 năm 2010 của Chính phủ quy định về mức trợ cấp, phụ cấp ưu đãi đối với người có công với cách mạng;  
Xét đề nghị của Trưởng Phòng Người có công;

**QUYẾT ĐỊNH:**

**Điều 1.** Trợ cấp hàng tháng đối với ông Trương Văn Tâm; Sinh năm: 1927 .

Nguyên quán: Xã Vĩnh Thạnh, huyện Vĩnh Hưng, tỉnh Long An.

Trú quán: Xã Vĩnh Thuận, huyện Vĩnh Hưng, tỉnh Long An.

Được tặng danh hiệu Anh hùng Lực lượng vũ trang nhân dân, theo Quyết định số 738 /QĐ-CTN ngày 28 tháng 5 năm 2010 của Chủ tịch nước.

\*/ Mức trợ cấp hàng tháng được hưởng kể từ ngày 01/4/2011.

Số tiền 646.000 đ/ tháng (Bằng chữ: Sáu trăm bốn mươi sáu ngàn đồng).

\*/ Truy tính từ 01/6/2010 đến 31/3/2011 = 646,000 đ x 10 thg = 6,460,000 đ.

Bằng chữ: ( Sáu triệu bốn trăm sáu chục ngàn đồng chẵn).

**Điều 2.** Trưởng Phòng Người có công, Trưởng Phòng Kế hoạch - Tài chính, Trưởng Phòng Lao động Thương binh Xã hội huyện Vĩnh Hưng và ông Trương Văn Tâm có trách nhiệm thi hành quyết định này.

**Nơi nhận:**

- - Như điều 2;
- - Lưu VT.

**GIÁM ĐỐC**

PHÓ GIÁM ĐỐC

Nguyễn Văn Ghiem');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (50, 1, 50, '50', '2

Mẫu số 4c-AH

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

BẢN KHAI VỀ NGƯỜI CÓ CÔNG

1. Phần khai về người có công:

Họ và tên: TRẦN VĂN PHÚ Nam (Nữ) Nam: Năm sinh: 1987  
Nguyên quán: Xã Thanh Thủy - Vĩnh Hưng - huyện An  
Cơ quan, đơn vị công tác: Thị trường huyện  
Nơi đăng ký hộ khẩu: Xã LCT - Xã Vĩnh Hưng - Vĩnh Hưng - huyện An  
Đã được tặng danh hiệu (Anh hùng LLVT, Anh hùng LD trong kháng chiến):  
Anh Hùng LLVT  
Theo Quyết định số 788 ngày 28 tháng 5 năm 2010 của Chủ tịch nước

2. Phần khai về thân nhân (người đăng khai):

Họ và tên: ..... Năm sinh: .....  
Nguyên quán: .....  
Trú quán: .....  
Quan hệ với Anh hùng LLVT, Anh hùng LD trong kháng chiến: (vợ, chồng, cha, me, con...)  
đã từ trần ngày..... tháng..... năm.....

Tôi cam đoan lời khai trên là đúng, nếu sai tôi hoàn toàn chịu trách nhiệm trước pháp luật.

Ông (bà) ... Tr. Nguyễn Văn Đức  
Hiện cư trú tại: Xã LCT - Vĩnh Hưng - Vĩnh Hưng - huyện An  
chưa hưởng trợ cấp ưu đãi đối với Anh hùng LLVT,  
Anh hùng LD trong kháng chiến.

Ngày 06 tháng 11 năm 2011  
Người khai  
(Ký, ghi rõ họ và tên)

Nguyễn, ngày 06 tháng 11 năm 2011  
CHỦ TỊCH  
(Ký tên, đóng dấu)

10 Năm

Nguyễn Văn Đức

189

116');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (51, 1, 51, '51', '3

Mẫu số 4c-AH

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

BẢN KHAI VỀ NGƯỜI CÓ CÔNG

1. Phần khai về người có công:

Họ và tên: TRƯƠNG VĂN TÂM Nam (Nữ) Nữ, Năm sinh: 1987  
Nguyên quán: Vĩnh Thạnh, Vĩnh Thủy - Long An  
Cơ quan, đơn vị công tác: Thống binh  
Nơi đăng ký hộ khẩu: Thị xã Vĩnh Thủy - Vĩnh Thủy - Long An  
Đã được tặng danh hiệu (Anh hùng LLVT, Anh hùng LD trong kháng chiến):  
Anh hùng LLVT  
Theo Quyết định số 128 ngày 28 tháng 5 năm 2010 của Chủ tịch nước.

2. Phần khai về thân nhân (người đứng khai):

Họ và tên: \_\_\_\_\_ Năm sinh: \_\_\_\_\_  
Nguyên quán: \_\_\_\_\_  
Trú quán: \_\_\_\_\_  
Quan hệ với Anh hùng LLVT, Anh hùng LD trong kháng chiến: (vợ, chồng, cha, me, con, ...) \_\_\_\_\_  
đã từ trần ngày \_\_\_\_\_ tháng \_\_\_\_\_ năm \_\_\_\_\_

Tôi cam đoan lời khai trên là đúng, nếu sai tôi hoàn toàn chịu trách nhiệm trước pháp luật.

Ông (bà) Trương Văn Tâm  
Hiên cư trú tại: Thị xã Vĩnh Thủy - Vĩnh Thủy - Long An  
chưa hưởng trợ cấp ưu đãi đối với Anh hùng LLVT,  
Anh hùng LD trong kháng chiến.

Ngày 06 tháng 09 năm 2011  
Người khai  
(Ký, ghi rõ họ và tên)

Văn hóa, ngày 11 tháng 08 năm 2011  
CHỦ TỊCH  
(Ký tên, đóng dấu)

10 Tâm

Nguyễn Văn Lộc

189

MG');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (52, 1, 52, '52', 'AH1111112140

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
ĐỘC LẬP - TỰ DO - HẠNH PHÚC

**CHỦ TỊCH**  
NƯỚC CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM

**TẶNG DANH HIỆU**  
**ANH HÙNG LỰC LƯỢNG VŨ TRANG NHÂN DÂN**

*Đồng chí TRƯƠNG VĂN TÂM (TRƯƠNG VĂN RẤT, MÁ MƯỜI)*

*Nguyên Tỉnh đội phó, tỉnh Kiến Tường (nay là tỉnh Long An)*

*Đã có thành tích đặc biệt xuất sắc trong cuộc kháng chiến chống Mỹ cứu nước.*

Quyết định số: 738 QĐ/ICTN ngày 28 tháng 05 năm 2010  
Vào số vàng số: 18

Hà Nội, ngày 28 tháng 05 năm 2010  
CHỦ TỊCH

NƯỚC CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM

Nguyễn Minh Trí');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (53, 1, 53, '53', 'ALL:V11621 (5)

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
ĐỘC LẬP - TỰ DO - HẠNH PHÚC

**CHỦ TỊCH**

NUỐC CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM

**TẶNG DANH HIỆU**

**ANH HÙNG LỰC LƯỢNG VŨ TRANG NHÂN DÂN**

Đồng chí **TRƯƠNG VĂN TÂM (TRƯƠNG VĂN RẬT, MÁ MƯỜI)**

*Nguyễn Tình đội phó, tỉnh Kiến Tường (nay là tỉnh Long An)*

*Đã có thành tích đặc biệt xuất sắc trong cuộc kháng chiến chống Mỹ cứu nước.*

Quyết định số: 738 QĐ/CTN ngày 28 tháng 05 năm 2010  
Vào sổ vàng số: 18

*Hà Nội, ngày 28 tháng 05 năm 2010*

CHỦ TỊCH

NUỐC CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM

*Nguyễn Minh Triết*');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (54, 1, 54, '54', 'UBND TỈNH LONG AN  
SỞ LAO ĐỘNG THƯƠNG BINH  
VÀ XÃ HỘI

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

Số: 64 /QD. SLDTBXH

Long An, ngày 5 tháng 7 năm 2012  
Số hồ sơ: 64

**QUYẾT ĐỊNH**

Về việc trợ cấp ưu đãi Anh hùng lực lượng vũ trang nhân dân

**GIÁM ĐỐC SỞ LAO ĐỘNG - THƯƠNG BINH VÀ XÃ HỘI**

- - Căn cứ Nghị định số 54/2006/NĐ-CP ngày 26 tháng 5 năm 2006 của Chính phủ hướng dẫn thi hành Pháp lệnh ưu đãi người có công với cách mạng;
- - Căn cứ Quyết định số 212/QĐ-CTN ngày 23 tháng 02 năm 2010 của Chủ tịch nước ;
- - Căn cứ Nghị định số 38/2009/NĐ-CP ngày 23 tháng 4 năm 2009 của Chính phủ quy định mức trợ cấp, phụ cấp ưu đãi đối với người có công với cách mạng;
- - Theo đề nghị của Trưởng phòng Người có công;

**QUYẾT ĐỊNH**

**Điều 1.** Trợ cấp một lần đối với Bà Đinh Thị Một, sinh năm 1951.

Nguyên quán: Xã Tân Hòa, huyện Tân Thanh, tỉnh Long An.

Trú quán: Xã Tân Hòa, huyện Tân Thanh, tỉnh Long An.

Là em của liệt sỹ Đinh Văn Phu.

Nguyên quán: Xã Tân Hòa, huyện Mộc Lửa, tỉnh Long An.

Đã được truy tặng danh hiệu Anh hùng lực lượng vũ trang nhân dân, theo Quyết định số 212/QĐ-CTN ngày 23 tháng 02 năm 2010 của Chủ tịch nước.

Mức trợ cấp một lần là: 13.700.000 đồng.

**Điều 2.** Trưởng phòng Người có công, Trưởng phòng Kế hoạch - Tài chính, Trưởng phòng Lao động - Thương binh và Xã hội huyện Tân Thanh và Bà Đinh Thị Một chịu trách nhiệm thi hành Quyết định này.

**Nơi nhận:**

- - Như điều 2;
- Cục NCC- Bộ LĐTBXH;
- Lưu HSCS.

15 **GIÁM ĐỐC**  
ĐỖ GIÁM ĐỐC

Nguyễn Văn Ghim');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (55, 1, 55, '55', 'DANH SÁCH ANH HÙNG LỰC LƯỢNG VŨ TRANG NHÂN DÂN

1. 1. Liệt sỹ Nguyễn Thị Bảy, nguyên Bí thư Huyện ủy Cần Giuộc, tỉnh Long An.
2. 2. Liệt sỹ Đỗ Công Thường, nguyên Ủy viên Quân sự xã Phú Ngãi Trị, huyện Châu Thành, tỉnh Long An.
3. 3. Liệt sỹ Lê Văn Khuê, nguyên Chủ tịch Ủy ban Hành chính Kháng chiến xã Phước Tân Hưng, huyện Châu Thành, tỉnh Long An.
4. 4. Liệt sỹ Trương Văn Nhường, nguyên Giao liên xã Đức Lập Hạ, huyện Đức Hòa, tỉnh Long An.
5. 5. Liệt sỹ Nguyễn Thái Bình, nguyên Sinh viên yêu nước huyện Cần Giuộc, tỉnh Long An.
6. 6. Liệt sỹ Lê Văn Giao (Lê Hùng Minh), nguyên Trung đội trưởng, Đội 198 Thanh niên xung phong, Tổng đội Thanh niên xung phong Giải phóng miền Nam (xã Mỹ Thạnh Đông, huyện Đức Huệ).
7. 7. Liệt sỹ Hồ Văn Ngà, nguyên Đội trưởng Đội Công binh huyện Châu Thành, tỉnh Long An.
8. 8. Liệt sỹ Nguyễn Thị Bé (nguyên Hoàng Anh), nguyên Tiểu đội phó, Đội 198 Thanh niên xung phong, Tổng đội Thanh niên xung phong Giải phóng miền Nam (xã Đức Tân, huyện Tân Trù).
9. 9. Liệt sỹ Nguyễn Thị Lệ (Năm Châu), nguyên Bí thư xã Hoà Khánh, huyện Đức Hòa, tỉnh Long An.
10. 10. Liệt sỹ Nguyễn Thành Tuân, nguyên Xã đội trưởng xã Mỹ Thạnh Bắc huyện Đức Huệ, tỉnh Long An.
11. 11. Liệt sỹ Phạm Văn Trạm, nguyên Xã đội phó xã Mỹ Hạnh (nay là xã Mỹ Hạnh Bắc), huyện Đức Hòa, tỉnh Long An.
12. 12. Liệt sỹ Võ Văn Thên, nguyên Du kích xã Mỹ Hạnh (nay là xã Mỹ Hạnh Bắc), huyện Đức Hòa, tỉnh Long An.
13. 13. Liệt sỹ Nguyễn Văn Liên (Bảy Liên), nguyên Bí thư, kiêm Xã đội trưởng xã Hòa Khánh, huyện Đức Hòa, tỉnh Long An.
14. 14. Liệt sỹ Lê Văn Bực, nguyên Tiểu đội phó, Đại đội 313, Huyện đội Châu Thành, tỉnh Long An.
15. 15. Liệt sỹ Võ Văn Nô, nguyên Du kích xã Thanh Phú Long, huyện Châu Thành, tỉnh Long An.
16. 16. Liệt sỹ Trần Công Vịnh, nguyên Phó Bí thư Huyện đoàn Mộc Hóa, tỉnh Tân An (nay là tỉnh Long An).
17. 17. Liệt sỹ Đinh Văn Phu, nguyên Đại đội phó Đại đội Biệt động tỉnh Kiến Tường (nay là tỉnh Long An).
18. 18. Ông Hồ Ngọc Dần (Dương Tấn Mào), nguyên Tỉnh đội tỉnh Kiến Tường (nay là tỉnh Long An).');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (56, 1, 56, '56', '**ỦY BAN NHÂN DÂN  
TỈNH LONG AN**

**CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc**

Số: A308/TUBND-VX

Tân An, ngày 19 tháng 4 năm 2010

V/v trao tặng danh hiệu Anh hùng  
lực lượng vũ trang nhân dân

Kính gửi:

Phy NCE:

- + liên v/bản này
- + Tgđt cũ d/đ/đt AHLVT

- - Các thành viên Ban Tổ chức các ngày lễ lớn của tỉnh và tổ chức huyện;
- - Ban Tuyên giáo Tỉnh ủy;
- - Sở Nội vụ;
- - Bộ chỉ huy Quân sự tỉnh;
- - UBND huyện: Cần Giuộc, Châu Thành, Đức Hòa, Đức Huệ, Mộc Hóa, Tân Trụ, thành phố Tân An.

SỞ LAO ĐỘNG TRẪI XE LONG AN

L

Ngày 29/4/2010

Cửa

Sau khi xem xét công văn số 43/CV-TĐKT ngày 12/4/2010 của Ban Thi đua Khen thưởng, Sở Nội vụ về việc tổ chức trao tặng danh hiệu Anh hùng lực lượng vũ trang nhân dân tại lễ kỷ niệm 35 năm Ngày giải phóng hoàn toàn miền Nam, thống nhất đất nước; ý kiến thống nhất của Ban Tổ chức các ngày lễ lớn của tỉnh tại cuộc họp ngày 15/4/2010, UBND tỉnh có ý kiến như sau:

- Đồng ý tổ chức trao tặng danh hiệu Anh hùng lực lượng vũ trang nhân dân tại buổi lễ kỷ niệm 35 năm Ngày giải phóng hoàn toàn miền Nam, thống nhất đất nước (lúc 7 giờ 30 phút ngày 28/4/2010).

Chương trình buổi lễ kỷ niệm (theo kế hoạch số 958/Kh-BTC ngày 23/3/2010) được bổ sung 2 nội dung (sau phân phát biểu của Tỉnh Đoàn): - Công bố Quyết định, trao tặng danh hiệu AHLVTND cho 18 cá nhân. - Phát biểu cảm tưởng của đại diện gia đình được truy tặng danh hiệu AHLVTND.

- Giao Sở Nội vụ trực tiếp phụ trách phần lễ trao tặng danh hiệu Anh hùng lực lượng vũ trang nhân dân gồm: công bố Quyết định, trao tặng Bằng và huy hiệu AHLVTND cho 18 cá nhân, mời phát biểu cảm tưởng.

- Bộ chỉ huy Quân sự tỉnh: chuẩn bị Bằng, huy hiệu AHLVTND và cấp phát tiền thưởng; thông báo Thượng tá- Chính trị viên huyện đội Tân Thành Dương Ngọc Hùng, con trai của Anh hùng Hồ Ngọc Dân chuẩn bị phát biểu cảm tưởng tại buổi lễ.

- UBND các huyện có tên 18 cá nhân được truy tặng danh hiệu AHLVTND, chuyển Thư mời và tổ chức đưa đón đại diện gia đình AHLVTND thuộc địa phương minh tham dự lễ.

- Văn phòng UBND tỉnh phát hành Thư mời và bổ trí sơ đồ chỗ ngồi cho đại diện gia đình Anh hùng lực lượng vũ trang nhân dân.

- Sở Văn hóa, Thể thao và Du lịch chụp ảnh lưu niệm.

- Đề nghị Ban Tuyên giáo Tỉnh ủy bổ sung nội dung tổ chức trao tặng danh hiệu AHLVTND vào điển văn chính tại buổi lễ/.

Nơi nhận:

- - CT, PCT.UBND tỉnh (Trần Hữu Phước);
- - Như trên;
- - Giám đốc Sở VHTTDL;
- - Phòng NCVX;
- - Lưu: VT, V.

TM. ỦY BAN NHÂN DÂN TỈNH  
KT. CHỦ TỊCH  
PHÓ CHỦ TỊCH

Trần Hữu Phước');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (57, 1, 57, '57', '5  
65

UBND TỈNH LONG AN  
SỞ LAO ĐỘNG THƯƠNG BINH  
VÀ XÃ HỘI

CỘNG HOÀ XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập – Tự do – Hạnh phúc

Số: 65 /QĐ. SLDTBXH

Long An, ngày 26 tháng 7 năm 2012  
Số hồ sơ: 65

**QUYẾT ĐỊNH**

Về việc trợ cấp ưu đãi Anh hùng lực lượng vũ trang nhân dân

**GIÁM ĐỐC SỞ LAO ĐỘNG - THƯƠNG BINH VÀ XÃ HỘI**

- - Căn cứ Nghị định số 54/2006/NĐ-CP ngày 26 tháng 5 năm 2006 của Chính phủ hướng dẫn thi hành Pháp lệnh ưu đãi người có công với cách mạng;
- - Căn cứ Quyết định số 1815/QĐ-CTN ngày 17 tháng 10 năm 2011 của Chủ tịch nước ;
- - Căn cứ Nghị định số 52/2011/NĐ-CP ngày 30 tháng 6 năm 2011 và Nghị định số 47/2012/NĐ-CP ngày 28 tháng 5 năm 2012 của Chính phủ quy định về mức trợ cấp, phụ cấp ưu đãi đối với người có công với cách mạng;
- - Theo đề nghị của Trưởng phòng Người có công;

**QUYẾT ĐỊNH**

**Điều 1.** Trợ cấp đối với Ông: Trần Văn Năm (Năm Gấu), Sinh năm 1947. Nguyên quán: Xã Đông Thạnh, huyện Cần Giuộc, tỉnh Long An. Hiện ngụ: Xã Đông Thạnh, huyện Cần Giuộc, tỉnh Long An. Đã được phong tặng danh hiệu Anh hùng Lực lượng vũ trang nhân dân, theo Quyết định số 1815/QĐ-CTN ngày 17 tháng 10 năm 2011 của Chủ tịch nước.

**Điều 2:** Trợ cấp được hưởng hàng tháng từ ngày 01/8/2012 số tiền là 931.000 đồng/tháng.

**Bảng chữ:** Chín trăm ba mươi một ngàn đồng.

Truy tính từ ngày 17/10/2011 đến ngày 30/4/2012 = 735.000 đồng x 6,5 tháng = 4.777.500 đồng.

Truy tính từ ngày 01/5/2012 đến ngày 31/7/2012 = 931.000 đồng x 3 tháng = 2.793.000 đồng.

**Tổng cộng: 7.570.500 đồng.**

**Điều 3.** Trưởng phòng Người có công, Trưởng phòng Kế hoạch - Tài chính, Trưởng phòng Lao động - Thương binh và Xã hội huyện Cần Giuộc và Ông Trần Văn Năm chịu trách nhiệm thi hành Quyết định.

**Nơi nhận:**

- - Như điều 2;
- - Cục NCC- Bộ LĐTBXH;
- - Lưu HSCS.

**GIÁM ĐỐC**  
PHÓ GIÁM ĐỐC  
  
**Nguyễn Văn Chim**');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (58, 1, 58, '58', 'Ⓟ

Căn cứ theo NHĐ 52/KHM/NHCCM

ngày 30/6/2014.

Ka quyết định g/19 cho tổ  
trợ cấp hay thngguy p/14/30/KHM.  
từ 30/4/2012 & Trung từ 115/KHM.  
từ 30/7/2012 một lần NHĐ 43.

— / — / —');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (59, 1, 59, '59', '**CHỦ TỊCH NƯỚC**

**CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM**  
Độc lập – Tự do – Hạnh phúc

Số: 1815/QĐ-CTN

Hà Nội, ngày 17 tháng 10 năm 2011

**QUYẾT ĐỊNH**  
Về việc phong tặng danh hiệu Anh hùng lực lượng vũ trang nhân dân

**CHỦ TỊCH**  
**NƯỚC CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM**

Căn cứ Điều 103 của Hiến pháp nước Cộng hoà xã hội chủ nghĩa Việt Nam năm 1992;

Căn cứ Luật thi đua, khen thưởng;

Xét đề nghị của Thủ tướng Chính phủ tại Tờ trình số 1856/TTr-TTg ngày 12 tháng 10 năm 2011.

**QUYẾT ĐỊNH**

**Điều 1.** Phong tặng danh hiệu *Anh hùng Lực lượng vũ trang nhân dân* cho :

5- Đại tá Trần Văn Năm (Năm Gấu) - Nguyên Trung đội phó Trung đội 5 (B5) Trinh sát - Đoàn 180 An ninh Vũ trang miền Nam - Bộ Tư lệnh Cảnh vệ - Bộ Công an;

*Đã có thành tích đặc biệt xuất sắc trong cuộc kháng chiến chống Mỹ, cứu nước.*

**Điều 2.** Quyết định này có hiệu lực thi hành từ ngày ký.

Thủ tướng Chính phủ, Chủ nhiệm Văn phòng Chủ tịch nước và đồng chí Trần Văn Năm (Năm Gấu) chịu trách nhiệm thi hành quyết định này./.

**CHỦ TỊCH**  
**NƯỚC CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM**

Đã ký  
Trương Tấn Sang

**BỘ CÔNG AN**  
**BỘ TƯ LỆNH CẢNH VỆ**

Số: 96 /SL

**SAO Y BẢN CHÍNH**

Tp. Hồ Chí Minh, ngày 18 tháng 10 năm 2011

Thiếu tướng Vũ Xuân Sinh');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (60, 1, 60, '60', '66.  
**ỦY BAN NHÂN DÂN  
HUYỆN ĐỨC HÒA**

**CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc**

Số: 1026/QĐ-UBND

Đức Hòa, ngày 10 tháng 11 năm 2012

Số hồ sơ: LA/TB: 1026

**QUYẾT ĐỊNH**

**V/v thời trả trợ cấp ưu đãi hàng tháng, trợ cấp một lần  
cho thân nhân Anh hùng lực lượng vũ trang**

**ỦY BAN NHÂN DÂN HUYỆN ĐỨC HÒA**

Căn cứ Luật tổ chức HDND và UBND ngày 16 tháng 11 năm 2003;

Căn cứ Nghị định số 47/2012/NĐ-CP ngày 28/5/2012 của Chính phủ qui định mức trợ cấp, phụ cấp ưu đãi đối với người có công với cách mạng; và Quyết định số 1346/2007/QĐ-UBND ngày 29/5/2007 của Chủ tịch UBND tỉnh Long An về việc ủy quyền cho Chủ tịch các huyện, thị kỳ các quyết định thuộc lĩnh vực chính sách người có công;

Xét đề nghị của Trưởng phòng Lao động - Thương binh và Xã hội huyện,

**QUYẾT ĐỊNH**

**Điều 1.** Thời trả trợ cấp của ông Nguyễn Tấn Bửu, sinh năm 1946, hiện ở Khu phố 3 - thị trấn Đức Hòa - huyện Đức Hòa - tỉnh Long An, là Anh hùng lực lượng vũ trang. Số tiền trợ cấp 931.000 đồng/tháng. Đã hưởng hết tháng 9/2012.

Kể từ ngày 01/12/2012 ông Nguyễn Tấn Bửu không còn hưởng trợ cấp.

**Lý do:** ông Nguyễn Tấn Bửu đã chết ngày 28/9/2012, theo giấy chứng tử số 63 ngày 19/10/2012 của UBND thị trấn Đức Hòa.

**Điều 2.** Trợ cấp cho ông Nguyễn Tấn Đông, sinh năm 1967, là con của ông Nguyễn Tấn Bửu, hiện ở Khu phố 3 - thị trấn Đức Hòa - huyện Đức Hòa - tỉnh Long An.

Số tiền :

<table><tbody><tr><td>+ Mai tang phí :</td><td>=</td><td>Hướng bên thương binh</td></tr><tr><td>+ Trợ cấp một lần : 931.000 đ x 3 tháng</td><td>=</td><td>2.793.000 đ</td></tr></tbody></table>

**Tổng cộng: 2.793.000 đ**

2/ Đã sao kê tại Phòng LD-TBXH số tiền:

+ Từ 01/10/2012-30/11/2012: 931.000 đ/tháng x 02 tháng = 1.862.000 đồng

Số tiền phải cấp cho gia đình: **2.793.000 đồng**');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (61, 1, 61, '61', '**Điều 3.** Chánh văn phòng HĐND, UBND huyện, Trưởng Phòng Lao động – TBXH, Chủ tịch UBND thị trấn Đức Hòa và ông Nguyễn Tấn Đông căn cứ quyết định thi hành./.

**Nơi nhận:**

-Sở LĐTBXH;

-Như điều 3;

-Lâu.

**TM. ỦY BAN NHÂN DÂN HUYỆN  
Q. CHỦ TỊCH**

**\* Võ Thị Tuyết**');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (62, 1, 62, '62', '2

**ỦY BAN NHÂN DÂN**

*Ủy ban Nhân dân tỉnh*

**CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM**

**Độc lập Tự do Hạnh phúc**

**PHIẾU BÁO GIẢM**

(Ban hành kèm theo hướng dẫn số 176/LĐTBXH ngày 16/01/2005 của Sở Lao động - Thương binh và xã hội)

Họ và tên người có công: Nguyễn Văn Phúc năm sinh: 1946  
Nguyễn quân: ấp KCP xã: Đa huyện: Đức  
Hóa, tỉnh Long An.

Nơi nhận trợ cấp khi từ trần: ấp KCP xã Đa huyện Đức

Từ trần ngày: 28/10/2014 Theo giấy chứng tử số (B) ngày 01/10/2014 của UBND Tỉnh Đức huyện Đức

Thuộc đối tượng hưởng trợ tư đãi: (LTCM, TB, BB, TNLS, CCCM): BB, ATH  
Là sĩ: liệt sĩ ATH

Số sổ trợ cấp: Số sổ Số hộ số: 2026/1016 Tỷ lệ MSLD: 82 %

Các mức trợ cấp hưởng trợ đãi hàng tháng như sau:

- - Chế độ trợ cấp: 100.000 đ VI VI đ
- - Số tiền trợ cấp: 921.000 đ d
- - Phụ cấp khu vực: d
- - Chế độ trợ cấp: d
- - Số tiền trợ cấp: d
- - Phụ cấp khu vực: d

Tổng cộng số tiền đang nhận hàng tháng: d

Đã nhận tiền đến hết tháng: 09 năm 2019

Nay báo cắt giảm trợ cấp của Ông (bà) Nguyễn Văn Phúc

Kể từ tháng 10 năm 2019

Chế độ trợ cấp bao gồm:

- - Trợ cấp một lần: 100.000 đ
- + Mai táng phí: 1.000.000 đ
- + 3 tháng trợ cấp, phụ cấp: 921.000 x 3 tháng = 2.763.000 đ

Tổng cộng: 2.763.000 đ

Xin báo cáo để Sở Lao động - Thương binh và xã hội làm thủ tục giải quyết chế độ từ trần.

Ngày 19 tháng 10 năm 2019

TM/UBND Ủy ban Nhân dân tỉnh

CHỦ TỊCH

*Signature of the Provincial People''s Committee Chairman*

*Phùng Văn Đức*

Ngày 16 tháng 11 năm 2019

PHÒNG LAO ĐỘNG -TB&XH  
TRƯỞNG PHÒNG

*Trần Công Quyền*');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (63, 1, 63, '63', 'CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM

Độc lập - Tự do - Hạnh phúc

**BẢN KHAI CỦA THÂN NHÂN**  
**NGƯỜI CÓ CÔNG CÁCH MẠNG TỬ TRẦN**  
 (Ban hành kèm theo hướng dẫn số 176/LĐTBXH ngày 16/01/2005  
 của Sở Lao động - Thương binh và xã hội)

Họ và tên người tử trận: Nguyễn Văn Bình      năm sinh: 1946  
 Nguyên quán: Thị trấn Công An  
 Nơi nhận trợ cấp khi tử trận: Cấp 2  
 Thuộc đối tượng hưởng trợ ưu đãi: (LTTCM, TB, BB, TNLS, CCCM): Đ. H. H. VT AD  
 Số số trợ cấp: Số hồ sơ 26, Tỷ lệ MSLĐ: %  
 Tử trận ngày 28.1.1992 Theo giấy chứng tử số 68 ngày 19.1.1992 của UBND  
 Đã nhận tiền đền bù: 0 năm 2012  
 Số tiền: 921.000  
 Trường hợp chết: Đột Quét  
 Họ tên người đứng nhận tiền mai táng phí và 03 tháng trợ cấp: Nguyễn Văn Bình      Năm sinh: 1962  
 Hộ khẩu thường trú: Cấp 2  
 Quan hệ với người chết: Con trai

**DANH SÁCH THÂN NHÂN ĐỦ ĐIỀU KIỆN HƯỞNG TUẤT TỬ TRẦN**

(Dùng cho đối tượng người có công có chế độ tuất tử trận)

<table border="1">
<thead>
<tr>
<th>TT</th>
<th>Họ và tên</th>
<th>Ngày, tháng, năm sinh</th>
<th>Quan hệ</th>
<th>Nơi ở (đề nhận tuất)</th>
</tr>
</thead>
<tbody>
<tr>
<td>01</td>
<td><u>Lê Thị Xuân</u></td>
<td><u>1950</u></td>
<td><u>Vi vợ (TB)</u></td>
<td><u>Khu phố 2 Công An</u></td>
</tr>
<tr>
<td> </td>
<td> </td>
<td> </td>
<td> </td>
<td> </td>
</tr>
<tr>
<td> </td>
<td> </td>
<td> </td>
<td> </td>
<td> </td>
</tr>
<tr>
<td> </td>
<td> </td>
<td> </td>
<td> </td>
<td> </td>
</tr>
</tbody>
</table>

Ngày 19 tháng 10 năm 2012

UBND Thị trấn

**CHỦ TỊCH**

Phùng Văn Đức

Ngày 19 tháng 10 năm 2012

Người đứng khai nhận trợ cấp

(Ký ghi rõ họ tên)

Nguyễn Văn Bình');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (64, 1, 64, '64', 'CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

Số: 63/2012  
Quyển số: 01/2012

GIẤY CHỨNG TỪ  
(BÁN SAO)

Họ và tên: NGUYỄN TÂN BỬU Giới tính: Nam  
Ngày, tháng, năm sinh: 1946  
Dân tộc: Kinh Quốc tịch: Việt Nam  
Nơi thường trú/tạm trú cuối cùng: 174C khu phố 3, thị trấn Đức Hòa, huyện Đức Hòa, tỉnh Long An  
Số Giấy CMND/Hộ chiếu/Giấy tờ hợp lệ thay thế: 300158111  
Đã chết vào lúc: 09 giờ 20 phút, ngày 23 tháng 9 năm 2012  
Nơi chết: Tại nhà  
Nguyên nhân chết: Bệnh  
Giấy báo tử/Giấy tờ thay thế Giấy báo tử: Con khai báo do cấp ngày, tháng, năm  
Nơi đăng ký: UBND thị trấn Đức Hòa, huyện Đức Hòa, tỉnh Long An  
Ngày, tháng, năm đăng ký: 28/9/2012  
Ghi chú: Đã đăng ký đúng hạn

NGƯỜI THỰC HIỆN  
(Đã ký)  
Phạm Huỳnh

NGƯỜI KÝ GIẤY CHỨNG TỪ  
(Đã ký)  
PCT. Lê Thành Phong

Sao từ Số đăng ký khai tử  
Ngày 19 tháng 10 năm 2012  
NGƯỜI KÝ BÁN SAO GIẤY CHỨNG TỪ  
(Ký, ghi rõ một chữ "bán" và đóng dấu)

(TT số 08/2010/TT-BTP)  
Mã TPAH-2010-KT1.1a');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (65, 1, 65, '65', 'ỦY BAN NHÂN DÂN  
HUYỆN ĐỨC HÒA

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM

Độc lập - Tự do - Hạnh phúc

Số:67/QĐ-UBND

Đức Hòa, ngày 09 tháng 3 năm 2022  
Số hồ sơ: LA/LLVT: 67

**QUYẾT ĐỊNH**

**Về việc chấm dứt chế độ ưu đãi đối với thân nhân người có công**

**ỦY BAN NHÂN DÂN HUYỆN ĐỨC HÒA**

Căn cứ Luật tổ chức chính quyền địa phương ngày 19 tháng 6 năm 2015;

Căn cứ Luật sửa đổi bổ sung một số điều của Luật Tổ chức Chính quyền và Luật Tổ chức Chính quyền địa phương ngày 22 tháng 11 năm 2019;

Căn cứ Pháp lệnh số 02/2020/UBTVQH14 ngày 09 tháng 12 năm 2020; Nghị định 131/2021/NĐ-CP ngày 30/12/2021 của Chính phủ qui định chi tiết và biện pháp thi hành pháp lệnh ưu đãi người có công với cách mạng;

Xét tờ trình số: 22/TTr-LDTBXH ngày 08/3/2022 của Trưởng phòng Lao động - Thương binh và Xã hội huyện.

**QUYẾT ĐỊNH:**

**Điều 1.** Chấm dứt chế độ ưu đãi đối với thân nhân

1. Ông (bà) **Phan Thị Năm** sinh năm: 1945, Quê quán: xã Tân Phú, huyện Đức Hòa, tỉnh Long An

Nơi thường trú: xã Tân Phú, huyện Đức Hòa, tỉnh Long An Là **AHLLV.T.** Số hồ sơ người có công: **LA/67**

2. Lý do: **chết ngày 02/01/2022**

3. Thời gian chấm dứt chế độ ưu đãi: 1/4/2022

4. Truy thu chế độ ưu đãi từ ngày: 01/02/2022-31/3/2022: 1.361.000đ x 03 tháng = 2.722.000đ

(Bằng chữ: Hai triệu bảy trăm hai mươi hai ngàn đồng)

5. Buộc diện sao kê chế độ ưu đãi từ ngày: 01/02/2022-31/3/2022: 1.361.000đ x 03 tháng = 2.722.000đ

(Bằng chữ: Hai triệu bảy trăm hai mươi hai ngàn đồng)

**Điều 2.** Chánh văn phòng HDND, UBND huyện; Trưởng Phòng Lao động - TBXH huyện Đức Hòa, Chủ tịch UBND xã Tân Phú và ông (bà) **Phan Thị Năm** và thân nhân ông (bà) có tên ở điều 1 cần cử quyết định thi hành./

Nơi nhận:  
-Sở LDTBXH;  
-Như điều 2;  
-Lưu VT.

**TM. ỦY BAN NHÂN DÂN**

**KT. CHỦ TỊCH  
PHÓ CHỦ TỊCH**

**Liệu Văn Bùng**');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (66, 1, 66, '66', 'AHLLUT/6717

7

BẢN SAO

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

CHỦ TỊCH

NƯỚC CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
TẶNG DANH HIỆU

Nguyễn Thị Thiện

ANH HUNG LỰC LƯỢNG VŨ TRANG NHÂN DÂN

Bà **PHAN THỊ NẪM**

*Cơ sở mật của Ban An ninh xã Đức Lập Hạ, huyện Đức Hoà, tỉnh Long An  
Đã có thành tích đặc biệt xuất sắc trong cuộc kháng chiến chống Mỹ, cứu nước*

Quyết định số: 1815 QĐICTN ngày 17 tháng 10 năm 2011  
Vào số vàng số: 5

Hà Nội, ngày 17 tháng 10 năm 2011  
CHỦ TỊCH

Trương Tấn Sang');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (67, 1, 67, '67', 'UY BAN NHÂN DÂN  
HUYỆN ĐỨC HÒA

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

Số: 67/QĐ-UBND

Đức Hòa, ngày 09 tháng 3 năm 2022

Số hồ sơ: LA/LLVT: 67

**QUYẾT ĐỊNH**

**Về việc trợ cấp khi thân nhân người có công từ trần**

**ỦY BAN NHÂN DÂN HUYỆN ĐỨC HÒA**

*Căn cứ Luật tổ chức chính quyền địa phương ngày 19 tháng 6 năm 2015;*

*Căn cứ Luật sửa đổi bổ sung một số điều của Luật Tổ chức Chính quyền và Luật Tổ chức Chính quyền địa phương ngày 22 tháng 11 năm 2019;*

*Căn cứ Nghị định 131/2021/NĐ-CP ngày 30/12/2021 của Chính phủ và Quyết định số 1436/QĐ-UBND ngày 29/5/2007 của UBND tỉnh Long An về việc phân cấp Chủ tịch UBND huyện, thị xã ký quyết định thuộc lĩnh vực chính sách ưu đãi người có công với cách mạng;*

*Xét tờ trình số: 22/Ttr-LDTBXH ngày 08/3/2022 của Trưởng phòng Lao động - Thương binh và Xã hội huyện.*

**QUYẾT ĐỊNH:**

**Điều 1.** Trợ cấp mai táng phí đối với người thực hiện mai táng:

Họ và tên: Trần Công Thành năm sinh: 1981 Nam/Nữ: nam

Quê quán: xã Tân Phú, huyện Đức Hòa, tỉnh Long An.

Nơi thường trú: xã Tân Phú, huyện Đức Hòa, tỉnh Long An.

Là con của ông (bà): Phan Thị Năm, năm sinh: 1945

**Mức trợ cấp:** **Hướng bên Thương binh (Bằng chữ.)**

**Điều 2.** Trợ cấp một lần đối với ông (bà):

Họ và tên: Trần Công Thanh, năm sinh: 1981, Nam/Nữ: nam

Nơi thường trú: xã Tân Phú, huyện Đức Hòa, tỉnh Long An.

Là con của ông (bà): Phan Thị Năm, năm sinh: 1945

**Mức trợ cấp:** số tiền: 1.361.000đ x 03 tháng = 4.083.000đ **(Bằng chữ:)** Bốn triệu không trăm tám mươi ba ngàn đồng

**Điều 3.** Trợ cấp tuất hàng tháng với ông (bà): Trú quán người hướng tuất:

Quan hệ người từ trần:

Mức trợ cấp số tiền:,

Thời điểm hướng tuất:

Tổng cộng truy lĩnh số tiền:

**Điều 4.** Chánh văn phòng HĐND, UBND huyện; Trưởng Phòng Lao động – TBXH, huyện Đức Hòa. Chủ tịch UBND xã Hưu Thanh và ông (bà) có tên ở điều 1, điều 2, điều 3 căn cứ quyết định thi hành./.

**Nơi nhận:**

-Sở LĐTBXH;

-Như điều 2;

-Lưu VT.

**TM. ỦY BAN NHÂN DÂN  
KT. CHỦ TỊCH  
PHÓ CHỦ TỊCH**

**Liệu Văn Bùng**');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (68, 1, 68, '68', 'Cộng Hòa Xã Hội Chủ Nghĩa Việt Nam  
Độc lập – Tự do- Hạnh phúc

**BẢN KHAI CỦA THÂN NHÂN**  
**Hướng chế độ ưu đãi khi người có công từ trần**

**1. Họ và tên người từ trần : PHAN THỊ NĂM**

Sinh ngày tháng năm 1945 Nam/Nữ: Nữ

Nguyên quán: ấp Bàu Trai Thượng, xã Tân Phú, huyện Đức Hòa, tỉnh Long An

Trú quán: ấp Bàu Trai Thượng, xã Tân Phú, huyện Đức Hòa, tỉnh Long An

Thuộc đối tượng hưởng trợ cấp ưu đãi (1): **AHLLVT**

Số hồ sơ, số quyết định (nếu có): 67 tỉ lệ suy giảm khả năng lao động:

Từ trần ngày 02 tháng 01 năm 2022

Theo Giấy chứng tử số 08 ngày 11 tháng 01 năm 2022 của Ủy ban nhân dân xã Tân Phú

Trợ cấp đã nhận đến hết tháng: Mức trợ cấp: 1.361.000 đ

**2. Họ tên người đứng nhận mai táng phí: Nhận bên Thương binh**

Sinh ngày tháng ..... năm ..... Nam/Nữ : .....

Nguyên quán: ....., xã Tân Phú, huyện Đức Hòa, tỉnh Long An

Trú quán: ....., xã Tân Phú, huyện Đức Hòa, tỉnh Long An

Quan hệ với người có công với cách mạng từ trần:

**3. Họ tên người đứng nhận trợ cấp một lần: TRẦN CÔNG THANH**

Sinh ngày 01 tháng 01 năm 1981 Nam/Nữ : Nam

Nguyên quán: Ấp Bàu Trai Thượng, xã Tân Phú, huyện Đức Hòa, tỉnh Long An

Trú quán: Ấp Bàu Trai Thượng, xã Tân Phú, huyện Đức Hòa, tỉnh Long An

Quan hệ với người có công với cách mạng từ trần: Con ruột

**4. Thân nhân người có công:**

a/ Danh sách thân nhân (2):

<table border="1"><thead><tr><th>TT</th><th>Họ và tên</th><th>Năm sinh</th><th>Trú quán</th><th>Quan hệ với người có công</th><th>Nghề nghiệp</th><th>Hoàn cảnh hiện tại (3)</th></tr></thead><tbody><tr><td></td><td></td><td></td><td></td><td></td><td></td><td></td></tr></tbody></table>');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (69, 1, 69, '69', 'TỈNH LONG AN  
HUYỆN ĐỨC HÒA  
UBND XÃ TÂN PHÚ

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

Số: 08/TLKT-BS

Tân Phú, ngày 11 tháng 01 năm 2022

**TRÍCH LỤC KHAI TỬ**  
(BẢN SAO)

**Họ, chữ đệm, tên: PHAN THỊ NẰM**

Ngày, tháng, năm sinh: 1945

Giới tính: Nữ

Dân tộc: Kinh

Quốc tịch: Việt Nam

Số định danh cá nhân:

Giấy tờ tùy thân: Giấy CMND số 300168744, Công an tỉnh Long An cấp ngày 23/08/2013

Đã chết vào lúc 21 giờ 00 phút, ngày 02 tháng 01 năm 2022 ghi bằng chữ: Hai mươi một giờ, không phút, ngày hai, tháng một, năm hai nghìn không trăm hai mươi hai

**Nơi chết:** Tại nhà - Ấp Bàu Trai Thượng, xã Tân Phú, huyện Đức Hòa, tỉnh Long An  
Đã được đăng ký khai tử tại: UBND xã Tân Phú, huyện Đức Hòa, tỉnh Long An

Số: 04/2022 ngày 05 tháng 01 năm 2022

**Thực hiện trích lục tờ:** Số đăng ký khai tử

**NGƯỜI KÝ TRÍCH LỤC**  
(Ký, ghi rõ họ, chữ đệm, tên, chức vụ, đóng dấu)

**KT. CHỦ TỊCH  
PHÓ CHỦ TỊCH**

Nguyễn Văn Thành');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (70, 1, 70, '70', '**ỦY BAN NHÂN DÂN  
HUYỆN ĐỨC HÒA**

Số: 1815/QĐ-UBND

**CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc**

Đức Hòa, ngày 13 tháng 8 năm 2013

Số hồ sơ: LA/CC-1815

#HLLV: CX

**QUYẾT ĐỊNH**

**V/v trợ cấp hàng tháng đối với Anh hùng lực lượng vũ trang nhân dân,  
Anh hùng lao động trong thời kỳ kháng chiến**

**ỦY BAN NHÂN DÂN HUYỆN ĐỨC HÒA**

Căn cứ Luật tổ chức HĐND và UBND ngày 16 tháng 11 năm 2003;

Căn cứ Nghị định số 47/2012/ND-CP ngày 28/5/2012 của Chính phủ quy định mức trợ cấp, phụ cấp ưu đãi Người có công với cách mạng;

Căn cứ Nghị định số 31/2013/ND-CP ngày 09/4/2013 của Chính phủ quy định chi tiết, hướng dẫn thi hành một số điều của Pháp lệnh ưu đãi người có công với cách mạng;

Căn cứ Quyết định số 1346/2007/QĐ-UBND ngày 29/5/2007 của Chủ tịch UBND tỉnh Long An về việc ủy quyền cho Chủ tịch các huyện, thị xã các quyết định thuộc lĩnh vực chính sách người có công;

Xét đề nghị của Trưởng phòng Lao động - Thương binh và Xã hội huyện,

**QUYẾT ĐỊNH:**

**Điều 1.** Trợ cấp hàng tháng kể từ ngày 01 tháng 9 năm 2013 đối với bà Phan Thị Năm.

Sinh năm 1945, Nữ.

Nguyên quán: xã Đức Lập - huyện Đức Hòa - tỉnh Long An.

Trú quán: xã Tân Phú - huyện Đức Hòa - tỉnh Long An.

Mức trợ cấp: 931.000 đồng.

Bảng chữ: Chín trăm ba mươi một ngàn đồng.

**Điều 2.** Chánh văn phòng HĐND, UBND huyện; Trưởng Phòng Lao động - TBXH, Chủ tịch UBND xã Tân Phú và bà Phan Thị Năm chịu trách nhiệm thi hành quyết định này./..

**Nơi nhận:**

-Sở LDTBXH;

-Như điều 2;

-Lưu.

*[Signature]*

**TM. ỦY BAN NHÂN DÂN HUYỆN  
CHỦ TỊCH**

**Võ Thị Tuyết**');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (71, 1, 71, '71', '6

Mẫu AHI

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

BẢN KHAI CÁ NHÂN

Dùng cho Anh hùng lực lượng vũ trang nhân dân  
hoặc Anh hùng lao động trong thời kỳ kháng chiến

Họ và tên: Phan Thị Nam

Sinh ngày ... tháng ... năm 1945 Nam/Nữ: Nữ

Nguyên quán: Đức Lập, Đức Hòa, Long An

Trú quán: ấp. Bàu Trại Thượng, Đức Hòa, Long An

Cơ quan, đơn vị công tác:

Đã được phong tặng danh hiệu Anh hùng Lực lượng vũ trang nhân dân

Theo Quyết định số 18/15, ngày 17 tháng 10 năm 2011 của Chủ tịch nước /

..., ngày 11 tháng 1 năm 2013

Nguyễn, ngày 13 tháng 8 năm 2013

Xác nhận của UBND xã, phường Tân Phú  
Ông (bà) Phan Thị Nam hiện cư trú  
tại: ấp. Tân Phú, chưa hưởng trợ cấp ưu đãi  
đối với Anh hùng Lực lượng Vũ trang Nhân dân

Người khai  
(Ký ghi rõ họ và tên)

Nam

TM.UBND  
Tân Phú, ngày 13 tháng 8 năm 2013  
TM. ỦY BAN NHÂN DÂN XÃ  
KT. CHỦ TỊCH  
PHÓ CHỦ TỊCH

Phan Thị Nam

Nguyễn Thị Thiện');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (72, 1, 72, '72', 'b/ Phần khai chi tiết về con người có công từ đủ 18 tuổi trở lên đang tiếp tục đi học tại cơ sở đào tạo hoặc bị khuyết tật nặng, khuyết tật đặc biệt nặng.

<table border="1"><thead><tr><th>T</th><th>Họ và tên</th><th>Năm</th><th>Thời điểm bị</th><th>Thời điểm kết thúc</th><th colspan="2">Cơ sở giáo dục đang theo học</th></tr><tr><th>T</th><th></th><th>sinh</th><th>khuyết tật</th><th>bậc học phổ thông</th><th>Tên cơ sở</th><th>Thời gian bắt đầu đi học</th></tr></thead><tbody><tr><td></td><td></td><td></td><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td><td></td><td></td><td></td></tr></tbody></table>

.....Ngày .....tháng 02 năm 2022

Ngày 14 tháng 01 năm 2022

Xác nhận của UBND xã Tân Phú

Người khai

Ông (bà)...Tần Công Thành...hiện đang cư ngụ tại: Kv 03, Tp. ....

TM. ỦY BAN NHÂN DÂN

TRẦN CÔNG THANH

Nguyễn Hoài Thương');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (73, 1, 73, '73', 'CHỦ TỊCH NƯỚC

Số: 18/45/QĐ-CTN

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM

Độc lập - Tự do - Hạnh phúc

Hà Nội, ngày 17 tháng 10 năm 2011

II ĐỐI KHEN THƯỜNG TRUNG UYÊN

**ÔNG VĂN ĐẰN**

Số: 1644.....

Ngày 12 tháng 12 năm 20...

**QUYẾT ĐỊNH**

Về việc phong tặng danh hiệu Anh hùng Lực lượng vũ trang nhân dân

**CHỦ TỊCH**

**NƯỚC CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM**

Căn cứ Điều 103 của Hiến pháp nước Cộng hòa xã hội chủ nghĩa Việt Nam năm 1992;

Căn cứ Luật thi đua, khen thưởng;

Xét đề nghị của Thủ tướng Chính phủ tại Tờ trình số 1856/TT-TTg ngày 12 tháng 10 năm 2011,

**QUYẾT ĐỊNH**

**Điều 1.** Phong tặng danh hiệu Anh hùng Lực lượng vũ trang nhân dân cho:

1. 1- Trung tướng Châu Văn Mẫn (tên khai sinh là Châu Văn Dep), nguyên Phó Tổng cục trưởng Tổng cục III, Bộ Công an;
2. 2- Đại tá Nguyễn Rã, nguyên Giám đốc Công an tỉnh Quảng Nam - Đà Nẵng;
3. 3- Thiếu tướng Trương Hữu Quốc, nguyên Tổng cục trưởng Tổng cục Cảnh sát, Bộ Công an;
4. 4- Ông Nguyễn Quốc Thanh, nguyên Cán bộ Ban An ninh huyện Long Mỹ, tỉnh Hậu Giang;
5. 5- Đại tá Trần Văn Năm (Năm Gấu), nguyên Trung đội phó Trung đội 5 (B5) Trinh sát, Đoàn 180 An ninh Vũ trang miền Nam, Bộ Tư lệnh Cảnh vệ, Bộ Công an;
6. 6- Ông Ngô Thanh Nguyên, nguyên Cán bộ Đội 1, Đoàn 180 An ninh Vũ trang miền Nam, Bộ Tư lệnh Cảnh vệ, Bộ Công an;
7. 7- Bà Phan Thị Năm, Cơ sở mật của Ban An ninh xã Đức Lập Hạ, huyện Đức Hòa, tỉnh Long An.

*Đã có thành tích đặc biệt xuất sắc trong cuộc kháng chiến chống Mỹ, cứu nước.*

6a');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (74, 1, 74, '74', '2

Điều 2. Quyết định này có hiệu lực thi hành từ ngày 15.

Thu tương Chính phủ, Chủ nhiệm Văn phòng Chủ tịch nước và các cá nhân có tên tại Điều 1 chịu trách nhiệm thi hành Quyết định này. / *[Signature]*

CHỦ TỊCH  
NƯỚC CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM

*[Signature]*  
Trương Tấn Sang

Nơi nhận:

- - Chính phủ;
- - Chủ nhiệm VPCIN;
- - Ban Thi đua - Khen thưởng TW;
- - Lưu: VT, Vụ TĐKT-KTXH (2).

TỔNG CỤC III  
CỤC X15

Số 1203 / X15(P4)

Nơi nhận:

- -
- -
- - Lưu: VT (X15).

SAO Y BẢN CHÍNH

Hà Nội, ngày 25 tháng 10 năm 2014.

CỤC TRƯỞNG

*[Signature]*  
Thiếu tướng Đặng Thái Giáp

BẢN SAO

*[Signature]*  
Nguyễn Thị Thiệu');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (75, 1, 75, '75', '(3)

**ỦY BAN NHÂN DÂN CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
XÃ MỸ YÊN**');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (76, 1, 76, '76', 'CÔNG AN TỈNH LONG AN  
PHÒNG CÔNG TÁC CHÍNH TRỊ

Số: 295 /SL-CAT-PX15

*Nơi nhận:*

- - Phòng LĐTBXH- huyện Bến Lức;
- - Lưu PX15.

SAO LỤC BẢN SAO

Long An, ngày 03 tháng 9 năm 2013

TRƯỞNG PHÒNG

Thượng tá Đào Thị Diệu Hiền');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (77, 1, 77, '77', '687Mẫu AH4

**UBND TỈNH LONG AN  
SỞ LAO ĐỘNG - THƯƠNG BINH  
VÀ XÃ HỘI**

**CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc**

*Long An, ngày 21 tháng 10 năm 2013*

Số: 68 /QĐ

Số hồ sơ: LA/AHLTVT: 68.

**QUYẾT ĐỊNH**

**Về việc trợ cấp một lần đối với thân nhân hoặc người thờ cúng Anh hùng lực lượng vũ trang, Anh hùng lao động trong thời kỳ kháng chiến.**

**GIÁM ĐỐC SỞ LAO ĐỘNG-THƯƠNG BINH VÀ XÃ HỘI**

Căn cứ Nghị định số 31/2013/NĐ-CP ngày 9/4/2013 của Chính phủ quy định chi tiết, hướng dẫn thi hành một số điều của Pháp lệnh ưu đãi người có công với cách mạng;

Căn cứ Nghị định số 47/2012/NĐ-CP ngày 25/5/2012 của Chính phủ quy định về mức trợ cấp, phụ cấp ưu đãi đối với người có công với cách mạng;

Căn cứ Quyết định số 2246/QĐ-CTN ngày 19/12/2012 của Chủ tịch nước về việc truy tặng Danh hiệu Anh hùng lực lượng vũ trang nhân dân;

Xét đề nghị của Trưởng phòng Người có công,

**QUYẾT ĐỊNH :**

Điều 1. Trợ cấp 1 lần đối với ông Nguyễn Quang Tám, sinh năm 1960  
Nguyên quán: Xã Mỹ Yên, huyện Bến Lức, tỉnh Long An  
Trú quán: TT. Bến Lức, huyện Bến Lức, tỉnh Long An  
Là con của ông Nguyễn Văn Chèo, sinh năm 1926  
Nguyên quán: Xã Mỹ Yên, huyện Đức Hòa, tỉnh Long An  
đã được truy tặng danh hiệu Anh hùng lực lượng vũ trang nhân dân theo Quyết định số 2246/QĐ-CTN ngày 9/12/2012 của Chủ tịch nước.  
Đã từ trần ngày 25/5/1970

Mức trợ cấp 1 lần là : **22.200.000** đồng

(*Bằng chữ : Hai mươi hai triệu hai trăm ngàn đồng*)

Điều 2. Các ông (bà) Trưởng phòng Người có công, Trưởng phòng Kế hoạch-Tài chính, Trưởng phòng Lao động-Thương binh & Xã hội huyện Bến Lức và ông Nguyễn Quang Tám chịu trách nhiệm thi hành Quyết định này.

**Nơi nhận:**

-Như điều 2;

-Cục NCC-Bộ LĐTBXH;

-Lưu.

**GIÁM ĐỐC  
PHÓ GIÁM ĐỐC**

**Nguyễn Văn Ghiem**');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (78, 1, 78, '78', 'CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM

Độc lập – Tự do – Hạnh phúc

**ĐƠN ĐỀ NGHỊ ĐỊNH CHÍNH THÔNG TIN TRONG HỒ SƠ**

Liệt sĩ Nguyễn Văn Chèo

Kính gửi: **Sở LĐTBXH tỉnh Long An**

Họ và tên: Nguyễn Quang Tầm

Sinh năm: 1960, giới tính: Nam

Nguyên quán: xã Mỹ Yên, huyện Bến Lức, tỉnh Long An

Trú quán: 67 Mai Thị Tốn, KP5, TT Bến Lức, huyện Bến Lức, tỉnh Long An

Thuộc diện người có công: con của người có công

Thông tin trong hồ sơ: liệt sĩ Nguyễn Văn Chèo

Thông tin đề nghị định chính: liệt sĩ Nguyễn Văn Chèo, Nguyễn Văn Hiến là một người.

Các giấy tờ kèm theo có liên quan đến việc định chính thông tin: báo cáo tóm tắt quá trình hoạt động của Anh hùng LLVT Nguyễn Văn Hiến.

*Bến Lức, ngày 09 tháng 9 năm 2013*

*Xác nhận của chính quyền địa phương*

*MỸ YÊN, ngày 09 tháng 9 năm 2013*

*Phạm Duy Ấn*

*Bến Lức, ngày 9 tháng 9 năm 2013*

*Người khai*

**Nguyễn Quang Tầm**

1');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (79, 1, 79, '79', '6

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập – Tự do – Hạnh phúc

**BẢN KHAI CÁ NHÂN**

**Dùng cho thân nhân hoặc người thờ cúng Anh hùng LLVTND  
hoặc Anh hùng lao động trong thời kỳ kháng chiến.**

**1. Phần khai về người có công:**

Họ tên: Nguyễn Văn Hiến

Sinh năm: 1926, giới tính: Nam

Nguyên quán: xã Mỹ Yên, huyện Bến Lức, tỉnh Long An

Đã chết ngày 25 tháng 5 năm 1970

Được truy tặng danh hiệu Anh hùng Lực lượng vũ trang

Theo Quyết định số 2246 ngày 19 tháng 12 năm 2012 của Chủ tịch nước.

**2. Phần khai cá nhân:**

Họ và tên: Nguyễn Quang Tám

Sinh năm: 1960, giới tính: Nam

Nguyên quán: xã Mỹ Yên, huyện Bến Lức, tỉnh Long An

Trú quán: 67 Mai Thị Tốn, KP5, TT Bến Lức, huyện Bến Lức, tỉnh Long An

Mối quan hệ với người có công: con ruột

*Mỹ Yên, ngày 26 tháng 9 năm 2013  
Xác nhận của UBND xã Mỹ Yên*

*Bến Lức, ngày 23 tháng 9 năm 2013  
Người khai*

PHÓ CHỦ TỊCH  
  
*Phạm Duy An*

Nguyễn Quang Tám');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (80, 1, 80, '80', 'Trú quán: 67 Mai Thị Tốn, KP5, TT Bến Lức, huyện Bến Lức, tỉnh Long An  
CMND số: 300963604; ngày cấp: 11/11/1995; Nơi cấp: Công an Long An

### 3. NỘI DUNG ỦY QUYỀN:

Chúng tôi đồng ý ủy quyền cho Nguyễn Quang Tám để làm thủ tục đối bằng  
Tổ quốc ghi công cho ba chúng tôi là ông Nguyễn Văn Chèo (liệt sĩ, anh hùng lực  
lượng vũ trang)

**Xác nhận của UBND xã**  
**PHÓ CHU TỊCH**  
  
Phạm Duy Ấn

**Bên ủy quyền**

Nguyễn Thị Mai

**Bên được ủy quyền**

Nguyễn Quang Tám

Nguyễn Quang Huệ

Nguyễn Thị Hiên

Nguyễn Thị Bảy

Nguyễn Thị Kim Liên

Nguyễn Quang Tiến

Nguyễn Văn Quân

2');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (81, 1, 81, '81', 'LAI-AHLLVT: 68

2

**UBND HUYỆN BẾN LÚC  
PHÒNG LĐTB&XH**

**CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập – Tự do – Hạnh phúc**

Số: 298/ĐN-LĐTB&XH

Bến Lức, ngày 10 tháng 10 năm 2013

Về việc giải quyết trợ cấp một lần  
cho thân nhân AHLLVT Nguyễn Văn Hiến  
(Nguyễn Văn Chèo) – xã Mỹ Yên

Kính gửi: - BGD Sở Lao động – TBXH tỉnh Long An

Căn cứ Nghị định số 31/2013/NĐ-CP ngày 09/4/2013 của Chính phủ về việc  
hướng dẫn thi hành một số điều của Pháp lệnh ưu đãi người có công với cách  
mạng.

Căn cứ đề nghị số 03/ĐN-UBND ngày 26/9/2013 của UBND xã Mỹ Yên về  
việc trợ cấp cho đối tượng có công.

Phòng LĐ-TBXH huyện Bến Lức kết hợp với địa phương xác minh trường  
hợp ông Nguyễn Văn Hiến (Nguyễn Văn Chèo), sinh năm: 1926. Quê quán: Mỹ  
Yên – Bến Lức – Long An.

Ông Nguyễn Văn Hiến (Nguyễn Văn Chèo) là người tham gia hoạt động  
kháng chiến hy sinh ngày 25/5/1970, được công nhận liệt sĩ số hồ sơ LA/LS:13891.  
Ông được truy tặng danh hiệu Anh hùng lực lượng vũ trang nhân dân theo Quyết  
định số: 2246/QĐ-CTN ngày 19/12/2012 của Chủ tịch nước cộng hòa xã hội chủ  
nghĩa Việt Nam. Công an tỉnh Long An đã tổ chức lễ truy tặng danh hiệu AHLLVT  
cho ông nhân kỷ niệm 68 năm ngày Thành lập công an nhân dân (19/8/1945-  
19/8/2013).

Nay Phòng LĐ-TBXH huyện Bến Lức làm bản đề nghị trình BGD Sở  
LĐ-TBXH tỉnh Long An, giải quyết chế độ trợ cấp cho thân nhân ông Nguyễn Văn  
Hiến (Nguyễn Văn Chèo). Mức trợ cấp 1.100.000 đồng x 20 lần = 22.200.000 đ.

(Bằng chữ: Hai mươi hai triệu hai trăm ngàn đồng chẵn).

Mong được sự đồng ý của Sở LĐ-TBXH tỉnh Long An để giúp Phòng thực  
hiện tốt công tác chính sách.

**Nơi nhận:**

- - Như trên;
- - Lưu.

**PHÒNG LĐ – TBXH HUYỆN**

**KT. TRƯỞNG PHÒNG  
PHÓ TRƯỞNG PHÒNG**

*Phạm Xuân Hải*');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (82, 1, 82, '82', 'CHỦ TỊCH QUỐC

Số: 2246/QĐ-CTN

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

Hà Nội, ngày 19 tháng 12 năm 2012

**QUYẾT ĐỊNH**

Về việc truy tặng danh hiệu Anh hùng lực lượng vũ trang nhân dân

**CHỦ TỊCH**

NUỐC CỘNG HOÀ XÃ HỘI CHỦ NGHĨA VIỆT NAM

Căn cứ Điều 103 của Hiến pháp nước Cộng hòa xã hội chủ nghĩa Việt Nam năm 1992;

Căn cứ Luật thi đua, khen thưởng;

Xét đề nghị của Thủ tướng Chính phủ tại Tờ trình số: 2092/TTr-TTg ngày 10 tháng 12 năm 2012,

**QUYẾT ĐỊNH:**

Điều 1. Truy tặng danh hiệu Anh hùng lực lượng vũ trang nhân dân cho Liệt sĩ Nguyễn Văn Hiến (bí danh Năm Trung), nguyên Ủy viên Thường vụ Phân khu ủy - Trưởng ban An ninh Phân khu 2, nguyên Trưởng ty Công an tỉnh Long An.

ĐỂ có thành tích đặc biệt xuất sắc trong cuộc kháng chiến chống Mỹ, cứu nước.

Điều 2. Quyết định này có hiệu lực thi hành từ ngày ký.

Thủ tướng Chính phủ, Chủ nhiệm Văn phòng Chủ tịch nước chịu trách nhiệm thi hành Quyết định này.

**CHỦ TỊCH**

NUỐC CỘNG HOÀ XÃ HỘI CHỦ NGHĨA VIỆT NAM

Nơi nhận:

- - Chính phủ;
- - Chủ nhiệm VPCIN;
- - Ban Thi đua - Khen thưởng TW;
- - Lưu: VT, Vụ TDKT (2).

Trương Tấn Sang

**CỤC CÔNG TÁC CHÍNH TRỊ**

Số: 119 /SYQĐ-X15 (P.4...)

**SAO Y BẢN CHÍNH**

Hà Nội, ngày 25 tháng 01 năm 2013

**CỤC TRƯỜNG**

Nơi nhận:

... *Công an tỉnh Long An* ...

Lưu: VT.

Thủ tướng Đặng Thái Giáp');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (83, 1, 83, '83', '7

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập – Tự do – Hạnh phúc

**BIÊN BẢN ỦY QUYỀN**

Hôm nay, ngày 06 tháng 9 năm 2013, tại ấp 7B, xã Mỹ Yên, huyện Bến Lức, tỉnh Long An.

Chúng tôi gồm có:

**1. BÊN ỦY QUYỀN:** Gồm các ông (bà) có tên sau đây:

<table border="1">
<thead>
<tr>
<th rowspan="2">STT</th>
<th rowspan="2">Họ tên</th>
<th rowspan="2">Nơi cư trú</th>
<th colspan="3">CMND</th>
<th rowspan="2">Mối QH với người có công</th>
</tr>
<tr>
<th>Số</th>
<th>Ngày cấp</th>
<th>Nơi cấp</th>
</tr>
</thead>
<tbody>
<tr>
<td>1</td>
<td>Nguyễn Thị Mai</td>
<td>Mỹ Yên, BL, LA</td>
<td>301594155</td>
<td>27/2/2012</td>
<td>CA Long An</td>
<td>Con</td>
</tr>
<tr>
<td>2</td>
<td>Nguyễn Quang Huệ</td>
<td>Hòa Thành, Tây Ninh</td>
<td>299019602</td>
<td>9/4/2012</td>
<td>CA Tây Ninh</td>
<td>Con</td>
</tr>
<tr>
<td>3</td>
<td>Nguyễn Thị Hiền</td>
<td>Q.5, TP.HCM</td>
<td>020472637</td>
<td>04/9/1995</td>
<td>CA TP.HCM</td>
<td>Con</td>
</tr>
<tr>
<td>4</td>
<td>Nguyễn Thị Bảy</td>
<td>Q.5, TP.HCM</td>
<td>021606874</td>
<td>29/3/2007</td>
<td>CA TP.HCM</td>
<td>Con</td>
</tr>
<tr>
<td>5</td>
<td>Nguyễn Thị Kim Liên</td>
<td>Mỹ Yên, BL, LA</td>
<td>300374889</td>
<td>16/10/2008</td>
<td>CA Long An</td>
<td>Con</td>
</tr>
<tr>
<td>6</td>
<td>Nguyễn Quang Tiên</td>
<td>Mỹ Yên, BL, LA</td>
<td>300384916</td>
<td>3/2/1980</td>
<td>CA Long An</td>
<td>Con</td>
</tr>
<tr>
<td>7</td>
<td>Nguyễn Văn Quân</td>
<td>Bến Lức, Long An</td>
<td></td>
<td></td>
<td></td>
<td>Con</td>
</tr>
<tr>
<td>8</td>
<td>Nguyễn Quang Vinh</td>
<td>Bến Lức, Long An</td>
<td></td>
<td></td>
<td></td>
<td>Con (liệt sĩ)</td>
</tr>
</tbody>
</table>

**2. BÊN ĐƯỢC ỦY QUYỀN:**

Họ và tên: Nguyễn Quang Tâm

Sinh năm: 1960, Nam

1');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (84, 1, 84, '84', '69

①

**ỦY BAN NHÂN DÂN  
HUYỆN CHÂU THÀNH**

**CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc**

Số :1649 /QĐ-UBND

Châu thành, ngày 30 tháng 9 năm 2011

**Số hồ sơ LA:**

**QUYẾT ĐỊNH**

V/v thời trả trợ cấp ưu đãi người có công và trợ cấp mai táng phí  
trợ cấp một lần cho thân nhân NCC giúp đỡ cách mạng

**ỦY BAN NHÂN DÂN HUYỆN CHÂU THÀNH**

Căn cứ luật tổ chức HĐND và UBND ngày 26 tháng 11 năm 2003;

Căn cứ Nghị định số 52 /2011/NĐ-CP ngày 30/6/2011 của Chính Phủ và Căn  
cứ vào quyết định số 1436/QĐ-UBND ngày 29 tháng 5 năm 2007 của UBND Tỉnh  
Long An về việc phân cấp UBND Huyện, Thị Xã ký quyết định thuộc lĩnh vực  
chính sách ưu đãi người có công với cách mạng ;

Theo đề nghị của Trưởng phòng Lao động TB&XH huyện Châu Thành.

**QUYẾT ĐỊNH:**

**Điều 1.** Nay thời trả trợ cấp của ông (Bà): **Dương Thị Hoa** Năm sinh:1918  
Hiện ở: Ấp Hôi Xuân Thị Trấn Tâm Vu Huyện Châu Thành  
Là: AHLVT Số hồ sơ:  
Số tiền: 735.000 đồng. (Bằng chữ: Bảy trăm ba mươi lăm ngàn đồng )  
Đã hưởng đến hết tháng 9/2011  
Kể từ ngày 01/10/2011 ông(Bà): **Dương Thị Hoa** cắt trợ cấp  
Lý do: Bị bệnh chết ngày 14/09/2011 theo giấy chứng tử số 36 ngày  
26/9/2011 của UBND Thị Trấn Tâm Vu

**Điều 2.** Trợ cấp cho ông (bà): **Huỳnh Văn Chiêu** .Năm sinh:1956  
Hiện ở: Ấp Hôi Xuân Thị Trấn Tâm Vu Huyện Châu Thành  
Con của Ông(bà): **Dương Thị Hoa**  
1- Số tiền +Mai táng phí: Bền hưu trì  
+Trợ cấp 1 lần: 3 tháng x 735.000 đ = 2.205.000 đ  
**Tổng cộng:** 2.205.000 đ  
2-Đã nộp sao kê: 1/10/2011 đến 31/10/ 2011 : 1 tháng x 735.000 đ = 735.000đ  
**Số tiền còn lại cấp cho gia đình:** 2.205.000 đ  
Bằng chữ:Hai triệu hai trăm lẻ năm ngàn đồng

**Điều 3.** Chánh văn Phòng HĐND và UBND huyện Châu Thành, Trưởng Phòng Lao  
động TB&XH Huyện Châu Thành, Chủ tịch UBND Thị Trấn Tâm Vu và  
Ông(Bà) có tên ở điều 2 căn cứ quyết định thi hành /..

**Nơi nhận**

- -Như điều 3;
- -Lưu

**TM.ỦY BAN NHÂN DÂN HUYỆN  
CHỦ TỊCH**

Trương Văn Biết');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (85, 1, 85, '85', 'UBND HUYỆN CHÂU THÀNH  
PHÒNG LAO ĐỘNG -TBXH

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM

Độc Lập - Tự Do - Hạnh Phúc

Châu thành, ngày 28 tháng 9 năm 2011

### DANH SÁCH SAO KÊ

<table border="1"><thead><tr><th>TT</th><th>Họ và tên</th><th>Địa chỉ</th><th>Đối tượng</th><th>Số tiền TC</th><th>Ngày, tháng,<br/>năm chết</th><th>Ngày, tháng, năm sao kê</th><th>Số tháng<br/>sao kê</th><th>Số tiền</th></tr></thead><tbody><tr><td>1</td><td>Dương Thị Hoa</td><td>TT Tâm Vư</td><td>AHLLVT</td><td>735.000</td><td>14/09/2011</td><td>1/10/2001 đến 31/10/2011</td><td>1</td><td>735.000</td></tr><tr><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td>735.000</td></tr></tbody></table>

Cán bộ chính sách

Kế toán

Bằng tiền mặt mười lăm ngàn đồng

Điền Thị Phương Hồng');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (86, 1, 86, '86', 'ỦY BAN NHÂN DÂN  
XÃ: Tổ Dân: Tân N

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

**PHIẾU BÁO GIẢM**

(Ban hành kèm theo Hướng dẫn số ...../LDTBXH ngày ..../01/2005 của Sở Lao động-Thương binh và Xã hội)

Họ và tên người có công: Nguyễn Văn Hào ..... Năm sinh 1916 .....  
Nguyên quán: Xã Thanh Lữ - Huyện Thanh Hoá - Tỉnh Thanh Hoá .....  
Nơi nhận trợ cấp trước khi từ trần: Nhà dân tộc Thanh Hoá, Tỉnh Thanh Hoá .....  
Từ trần ngày 14/12/2001 ..... Theo giấy chứng tử số: 36 ..... Ngày 16/12/2001 .....  
của UBND xã phường Tổ Dân Tân N .....  
Thuộc đối tượng trợ cấp ưu đãi: (LTCM, TB, BB, TNLS ...) .....  
Số tiền trợ cấp: 4.250 ..... Số hồ sơ ..... Tỷ lệ MSLD (%) .....  
Số hộ trợ cấp: 4.250 ..... Số hộ sơ ..... Tỷ lệ MSLD (%) .....  
Các mức trợ cấp ưu đãi hàng tháng đang hưởng như sau:

- - Chế độ trợ cấp: ..... d. Phụ cấp ..... d
- Số tiền trợ cấp: ..... d. Phụ cấp ..... d
- - Chế độ trợ cấp: ..... d. Phụ cấp ..... d
- Số tiền trợ cấp: ..... d. Phụ cấp ..... d
- - Chế độ trợ cấp: ..... d. Phụ cấp ..... d
- Số tiền trợ cấp: ..... d. Phụ cấp ..... d
- - Chế độ trợ cấp: ..... d. Phụ cấp ..... d
- Số tiền trợ cấp: ..... d. Phụ cấp ..... d
- - Phụ cấp khu vực, hộ số ..... Số tiền ..... d

Tổng công số tiền đang nhận hàng tháng ..... 435.000 ..... đồng  
Đã nhận tiền trợ cấp đến hết tháng ..... 9 ..... năm 2001 .....  
Nay báo cáo giảm trợ cấp của Ông/Bà Nguyễn Văn Hào .....  
Kể từ tháng ..... 10 ..... năm ..... 2001 .....  
Các chế độ trợ cấp sau khi từ trần bao gồm:

- - Trợ cấp một lần:
  - + Mãi tang phí ..... đồng
  - + 3 tháng trợ cấp, phụ cấp 435.000 x 3 tháng = 1.305.000 ..... đồng

Tổng cộng: 1.305.000 ..... đồng  
- Trợ cấp ưu đãi ưu tiên (nếu có) theo quy định kèm theo.  
Yêu báo cáo đề Sở Lao động-Thương binh và Xã hội xem xét trợ giúp quyết chế độ từ trần.

Ngày 27 tháng 3 năm 2001  
UBND xã phường Tổ Dân Tân N  
**CHỦ TỊCH**  
Ký tên, đóng dấu

Ngày 27 tháng 3 năm 2001  
**PHÒNG TỔ CHỨC LAO ĐỘNG TB & XH**  
**PHÒNG TỔ CHỨC LAO ĐỘNG**  
(PHÒNG TỔ CHỨC LAO ĐỘNG THƯƠNG BINH VÀ XÃ HỘI)  
Đóng dấu  
Điệu Thị Phương Hồng');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (87, 1, 87, '87', 'CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

BẢN KHAI CỦA THIÊN NHÂN  
NGƯỜI CÓ CÔNG CÁCH MẠNG TỪ TRẦN  
(Ban hành kèm theo Hướng dẫn số ...../LĐTBXH ngày ..../01/2005  
của Sở Lao động-Thương binh và Xã hội)

Họ và tên người từ trần.....Đường Thị Hòa..... Năm sinh 1916  
 Nguyên quán.....xã.....Thị trấn Mỹ.....thị xã.....  
 Nơi nhận trợ cấp trước khi từ trần.....thị trấn Mỹ  
 Tư liệu chứng cứ chứng minh (LTCM, TB, BB, TNLS ) .....  
 Số sổ trợ cấp .....Sổ hộ sơ  
 Tỷ lệ mất sức lao động (%)  
 Từ trần ngày 24.10.1991... Theo giấy chứng từ số 46 Ngày 26.10.1991  
 của UBND xã/phương .. Thị trấn Mỹ  
 Đã nhận tiền trợ cấp đối đãi tháng 9 năm 1991  
 Số tiền 100.000  
 Phương pháp... bệnh  
 Thời gian... 18 tháng... Thời gian... trợ cấp  
 Thời gian... 2 ngày... Năm sinh 1916  
 Hộ khẩu... xã Mỹ... Thị trấn Mỹ - thị xã  
 Quốc tịch Việt Nam

ĐƠN VỊ TỔ CHỨC XỬ LÝ (CO CÔNG CÁCH MẠNG TỪ TRẦN)  
(Cụ thể đơn vị quản lý (cơ quan công tác xã hội))

<table border="1">
<thead>
<tr>
<th>STT</th>
<th>Tên người</th>
<th>Ngày tháng năm sinh</th>
<th>Quân</th>
<th>Thời gian (năm tháng ngày)</th>
</tr>
</thead>
<tbody>
<tr>
<td>01</td>
<td>Nguyễn Văn Châu</td>
<td>1916</td>
<td>Quân</td>
<td>đến 26.10.1991</td>
</tr>
<tr>
<td>02</td>
<td></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td>03</td>
<td></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td>04</td>
<td></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td>05</td>
<td></td>
<td></td>
<td></td>
<td></td>
</tr>
</tbody>
</table>

Ngày 27 năm 9 năm 1991  
 UBND xã, thị trấn, thị xã  
 CHỮ KÝ  
 (Ký tên, đóng dấu)

Ngày 27 tháng 9 năm 1991  
 Ng. ở cấp... trợ cấp  
 (Ký tên và ghi rõ họ tên)

Nguyễn Thành Hòa

Nguyễn Văn Châu');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (88, 1, 88, '88', 'CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập – Tự do – Hạnh phúc

Số: 36  
Quyển số: 01/2011

**GIẤY CHỨNG TỪ**  
(BẢN SAO)

Họ và tên: **DƯƠNG THỊ HOA**

Giới tính: **Nữ**

Ngày, tháng, năm sinh: **1918**

Dân tộc:

**Kinh**

Quốc tịch:

**Việt Nam**

Nơi thường trú/ tạm trú cuối cùng: **378A Ấp Hội Xuân, Thị trấn Tâm Vu, Huyện Châu Thành, Tỉnh Long an.**

Số Giấy CMND/Hộ chiếu/Giấy tờ hợp lệ thay thế: **300 338 298.**

Đã chết vào lúc **04** giờ **30** phút, ngày **14** tháng **09** năm **2011**.

Nơi chết: **Bệnh viện đa khoa Long an.**

Nguyên nhân chết: **suy tim, nhồi máu cơ tim, viêm phổi, bệnh phổi tắc nghẽn.**

Giấy báo tử/giấy tờ thay thế Giấy báo tử: số 40 quyển số 02 do **Trương Thị Hiền** phó giám đốc bệnh viện Long an cấp ngày 19 tháng 09 năm 2011.

Nơi đăng ký: **UBND Thị trấn Tâm Vu.**

Ngày, tháng, năm đăng ký: **26/ 09/ 2011.**

Ghi chú: **Đăng ký đúng hạn.**

**NGƯỜI THỰC HIỆN**

**NGƯỜI KÝ GIẤY GIẤY KHAI TỬ**

(Đã ký)  
**CHÂU VĂN CÁP**

(Đã ký)  
*Nguyễn Thanh Hiền*

Sao từ Số đăng ký khai tử

Ngày **26** tháng **09** năm **2011**

**NGƯỜI KÝ BẢN SAO GIẤY KHAI TỬ**

(Ký, ghi rõ họ tên, chức vụ và đóng dấu)

**CHỦ NHẠ**

*Nguyễn Thanh Hiền*');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (89, 1, 89, '89', '70

Lưu hồ sơ chuyển Tây Ninh

CHỦ TỊCH NƯỚC

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

Số.55/TKĐCTN

**CHỦ TỊCH  
NƯỚC CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM**

Căn cứ vào Điều 103 của Hiến pháp nước Cộng hòa xã hội chủ nghĩa Việt Nam;

Theo đề nghị của Thủ tướng Chính phủ tại Tờ trình số 4620/TCCB ngày 24/8/1995;  
Tờ trình số 4775/TCCB ngày 29/8/1995;

**QUYẾT ĐỊNH :**

I/ Truy tặng danh hiệu Anh hùng lực lượng vũ trang nhân dân cho :

- 1- Liệt sỹ Nguyễn Ngọc Bảo, sinh năm 1927, quê xã Yên Mạc, huyện Yên Mô, tỉnh Ninh Bình; đã lập được thành tích đặc biệt xuất sắc trong cuộc kháng chiến chống thực dân Pháp.
- 2- 32 cá nhân; đã lập được thành tích đặc biệt xuất sắc trong cuộc kháng chiến chống Mỹ cứu nước.

(Có danh sách cá nhân được tặng danh hiệu đính kèm).

II/ Tặng danh hiệu Anh hùng lực lượng vũ trang nhân dân cho :

- - 148 đơn vị;
- - 12 cá nhân,

đã có thành tích đặc biệt xuất sắc trong cuộc kháng chiến chống Mỹ cứu nước.

(Có danh sách đơn vị và cá nhân được tặng danh hiệu đính kèm).

III/ Tặng danh hiệu Anh hùng Lao động cho Viện 69 thuộc Bộ Tư lệnh 969, Bộ Quốc phòng, đã chủ động sáng tạo trong lao động, nghiên cứu ứng dụng tiến bộ khoa học kỹ thuật, hoàn thành xuất sắc nhiệm vụ y học đặc biệt được Đảng, Nhà nước giao.

Hà Nội, ngày 30 tháng 8 năm 1995

CHỦ TỊCH  
NƯỚC CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (90, 1, 90, '90', 'I.- Truy tặng danh hiệu Anh hùng LLVT nhân dân cho :

1) Liệt sỹ : Dương Văn Hiếu, xã Tân Phú, huyện Đức Hòa.

2) Liệt sỹ : Đỗ Văn Bồn, xã Nhơn Hòa Lập, Tân Thạnh.

Đã có thành tích đặc biệt xuất sắc trong cuộc kháng chiến chống Mỹ cứu nước.

II.- Tặng danh hiệu Anh hùng LLVT nhân dân cho :

03 đơn vị và 02 cá nhân.

1) Nhân dân và Cán bộ xã Long Hòa, huyện Cần Đước

2) Nhân dân và Cán bộ xã Bình Phong Thạnh, Mộc Hóa

3) Nhân dân và Cán bộ xã Mỹ Lộc Thạnh, Thủ Thừa

4) Mẹ : Cao Thị Mai, xã Bình Trinh Đông, huyện Tân Trụ

5) Bà : Trần Thị Sừa, xã Thạnh Lợi, huyện Bến Lức.

Đã có thành tích đặc biệt xuất sắc trong cuộc kháng chiến chống Mỹ cứu nước.

Hà Nội, ngày 30 tháng 8 năm 1995

Chủ tịch

Nước cộng hòa xã hội CNVN

Đã ký

Lê Đức Anh.');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (91, 1, 91, '91', 'Khai Nhân

Trân trọng gửi Sứ giả hữu danh, kính thưa cấp liệt sỹ tại UWBT  
nay chuyển về thi thảo tận châu huyện tận châu, đã nhận  
được đơn hết tháng 2 và quá hết, NLCVT.

Viêng Thị Hoàng Trung Thuận

Xác nhận

Theo đơn trình bày của Bộ Tiểu Đội Sứ giả là đúng.  
Kính chuyển tới UWBT và XL trình Long an Xưa, xét cho  
bà được chuyển thể thể từ cấp nhất liệt sỹ và tiếp cấp  
Anch hùng liệt liệt hữu danh về nơi cư trú mới.

Tân An, ngày 7/02/2008  
P. P. NCS.Vũ - UWBT và XL TX

Giản Chí Chiêm');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (92, 1, 92, '92', 'THANH TOÁN CHỈ PHÍ

CA THIỂM TRA<sup>2</sup>

HLS TỪ ĐÂY');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (93, 1, 93, '93', 'UBND TỈNH LONG AN  
SỞ LAO ĐỘNG TB&XH

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc Lập - Tự do - Hạnh phúc

Số: 58/LĐTBXH

Tân An, ngày 05 tháng 2 năm 2007

## GIẤY GIỚI THIỆU DI CHUYỂN

Kính gửi: Sở Lao động - Thương binh và Xã hội tỉnh Tây Ninh

Sở Lao động - Thương binh và Xã hội tỉnh Long An giới thiệu di chuyển:

Bà: **Trần Thị Sửa** - Sinh-năm: **1945**.

Đang hưởng trợ cấp: Anh hùng lực lượng vũ trang nhân dân.

Số hồ sơ: **557KT/CTN**.

Nay về cư ngụ tại: Thị trấn Tân Châu, huyện Tân Châu, tỉnh Tây Ninh.

Bà: **Trần Thị Sửa** đang lĩnh trợ cấp hàng tháng tại tỉnh Long An theo quyết định số 557KT/CTN ngày 30 tháng 8 năm 1995 của chủ tịch nước.

Đề nghị đơn vị mới tiếp nhận hồ sơ và chi trả trợ cấp từ tháng 03 năm 2007.

**Số tiền: 300.000 đồng.**

Hồ sơ đương sự kèm theo gồm có:

1. 1- Đơn xin chuyển chế độ AHLLVT.
2. 2- Quyết định số: 557KT/CTN.
3. 3- Danh sách chi trả trợ cấp hàng tháng tại tỉnh Long An.

Tổng cộng: **03 tờ**.

Nơi nhận:

- - Như trên;
- - Lưu VT-CS.

*Nguyễn Văn Hoàng*');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (94, 1, 94, '94', 'HS TB Mới

Trả lời thư

Dương văn Quang -  
bộ văn Đức (trên) ở đây

<table border="1"><tr><td>- Mỹ An</td><td>56%</td><td>(4395)</td></tr><tr><td>TB</td><td></td><td></td></tr><tr><td>- Mỹ An</td><td>27%</td><td>(7407)</td></tr></table>');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (95, 1, 95, '95', 'Cộng hòa Xã hội Chủ nghĩa Việt Nam. ③  
Độc lập - Tự Do - Hạnh phúc.

### ĐƠN XIN

"Chuyển chỗ ở lưỡng tuần liệt sỹ" của A.H.L.V.  
Kính gửi: - Ban Lao động, Xã hội PI - Thị xã Tân Mu.  
- Phòng Lao động Xã hội Thị xã Tân Mu.  
- Sở Lao động TB và Xã hội long Mu.

Tôi tên: Trần Thị Sáu, hiện đang lưỡng tuần  
của liệt sỹ Nguyễn Văn Kiết là chồng ở PI - Thị xã  
Tân An, Thủ long. Hiện nay tôi đang cư trú tại nhà  
Tân Châu, huyện Tân Châu, Thủ bấy Ninh. Để đề  
về thuận lợi trong sinh hoạt, hiện nay tôi chuyển  
thờ Khẩu và liêng hầu, cái Khẩu phụ cấp khác  
về Thị trấn Tân Châu - huyện Tân Châu.

Nay tôi làm đơn xin này kính mở lao động  
Thầy Bửu, Xã hội các cấp lao động Kiến cho  
tôi được chuyển thờ ở lại nhà để địa điều kiện  
để trợ giúp sinh hoạt hằng tháng được thuận lợi  
Xin cảm ơn các đc.

Tây Ninh ngày 29.07. 2007

Người làm đơn

Z. Sue

Trần Thị Sáu');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (96, 1, 96, '96', '08 V

9

UBND TỈNH LONG AN  
SỞ LAO ĐỘNG TB&XH

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập – Tự do - Hạnh phúc

Số : 08/LĐTBXH.BC

Tân An, ngày 20 tháng 04 năm 2006

Số hồ sơ LA/08

### PHIẾU ĐIỀU CHỈNH TRỢ CẤP

Họ và tên: **Nguyễn Thị Quận** - Năm sinh: **1938**

Hiện ở: **xã Bình Trinh Đông, huyện Tân Trụ, tỉnh Long An**

Là: **con của ông (bà): Cao Thị Mai chết ngày: 23/12/2006**

Đã hưởng chế độ: **Anh hùng lực lượng vũ trang**

**I. Mức trợ cấp theo Nghị định 210/2004/NĐ-CP ngày 20/12/2004 của Chính phủ (gia đình đã hưởng):**

1. Mai tang phí: **Hưởng bên liệt sỹ.**

2. Trợ cấp 1 lần: **03 tháng x 250000 đồng = 750000 đồng**

**Tổng cộng I = (1)+(2) = 750000 đồng**

**II. Mức trợ cấp theo Nghị định 147/2005/NĐ-CP ngày 30/11/2005 của Chính phủ, như sau:**

1. Mai tang phí: **Hưởng bên liệt sỹ.**

2. Trợ cấp 1 lần: **03 tháng x 300000 đồng = 900000 đồng**

**Tổng cộng II = (1)+(2) = 900000 đồng**

**III. Số tiền chênh lệch cấp thêm cho gia đình:**

**Tổng cộng (II) – Tổng cộng (I) = 150000 đồng**

**(Bằng chữ: Một trăm năm mươi ngàn đồng)**

**PHÒNG CHÍNH SÁCH TBLS**

*Signature*');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (97, 1, 97, '97', 'Lời báo cáo

2

UBND TỈNH LONG AN  
SỞ LAO ĐỘNG TB&XH

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập – Tự do – Hạnh phúc

Số : 08 /QĐ-LĐTBXH.XH

Tân An, ngày 20 tháng 02 năm 2006

LA/08

**QUYẾT ĐỊNH**

V/v trợ cấp tiền mai táng phí, trợ cấp một lần  
cho gia đình Anh hùng lực lượng vũ trang

**GIÁM ĐỐC SỞ LAO ĐỘNG THƯƠNG BINH VÀ XÃ HỘI**

Căn cứ quyết định số 5438/UB-QĐ ngày 28 tháng 11 năm 1995 của UBND tỉnh Long An về việc ủy quyền Sở Lao động – Thương binh và Xã hội cấp giấy chứng nhận và trợ cấp đối với người có công với cách mạng;

Căn cứ Điều 2, Nghị định số 210/2004/NĐ-CP ngày 20 tháng 12 năm 2004 của Chính phủ về chế độ trợ cấp, phụ cấp ưu đãi đối với người có công với cách mạng;

Xét hồ sơ cần giám và trợ cấp một lần của Phòng Nội vụ – Lao động TBXH huyện, TX Tân Trụ đối với thân nhân người có công CM: Cao Thị Mai;

Theo đề nghị của Ông Trưởng phòng Chính sách TBSL;

**QUYẾT ĐỊNH**

**Điều 1.** Nay trợ cấp cho:

Ông (Bà): **Nguyễn Thị Quận** - Sinh năm: **1938**.

Hiện ở: xã Bình Trinh Đông, huyện Tân Trụ, Tỉnh Long An

Là: con của AHLLVT (Bà): **Cao Thị Mai**.

Đã chết ngày 23/12/2005

1/-Số tiền: + Mai táng phí: **Đã hưởng bên liệt sỹ**.

+ Trợ cấp 1 lần (3 tháng TC): **250.000 đ x 3 th = 750.000 đ**.

**Tổng cộng: 750.000 đ.**

2/-Trừ tiền cấp bổ do cắt trề: **500.000 (từ tháng 01/2006 đến tháng 02/2006)**

**Số tiền còn lại cấp cho gia đình: 250.000 đ.**

(Bằng chữ: Hai trăm năm mươi ngàn đồng).

**Điều 2.** Trưởng phòng Chính sách Thương binh liệt sỹ, Trưởng phòng kế hoạch Tài vụ, Trưởng phòng Nội vụ Lao động TBXH huyện Tân Trụ và Ông (bà) có tên ở Điều 1, căn cứ quyết định thi hành.

**Nơi nhận:**

- - Như điều 2;
- - LưuVT D.QDTC/Han.

**GIÁM ĐỐC**  
C. PHÓ GIÁM ĐỐC  
SỞ LAO ĐỘNG  
THƯƠNG BINH  
VÀ XÃ HỘI  
Nguyễn Thị Phương');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (98, 1, 98, '98', 'ỦY BAN NHÂN DÂN  
HUYỆN TÂN TRỤ

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

Số: 111 /QĐ-UBND

Tân Trụ, ngày 13 tháng 02 năm 2006  
Số hồ sơ: LA/08

**QUYẾT ĐỊNH**  
**Về việc cắt trợ cấp ưu đãi AHLLVT**

**CHỦ TỊCH ỦY BAN NHÂN DÂN HUYỆN TÂN TRỤ**

Căn cứ luật Tổ chức Hội đồng nhân dân và Ủy ban nhân dân ngày 26 tháng 11 năm 2003;

Căn cứ Nghị định số 28/CP ngày 29 tháng 4 năm 1995 của Chính phủ hướng dẫn thi hành một số điều của Pháp lệnh ưu đãi người hoạt động cách mạng, liệt sỹ và gia đình liệt sỹ, thương binh, bệnh binh, người hoạt động kháng chiến, người có công giúp đỡ cách mạng;

Căn cứ Quyết định số: 3453/1998/UB.QĐ ngày 23/11/1998 của Chủ tịch Ủy ban nhân dân tỉnh Long An, về việc ủy quyền cho Ủy ban Nhân dân huyện, thị, ký các quyết định thuộc lĩnh vực chính sách người có công;

Xét đề nghị số 02/NV-LDTB&XH ngày 10 tháng 02 năm 2006 của Ông Trưởng phòng Nội vụ-Lao động thương binh & Xã hội huyện Tân Trụ.

**QUYẾT ĐỊNH:**

**Điều 1.** Nay cắt 01 định suất Anh hùng lực lượng vũ trang

Bà Cao Thị Mai, Sinh Năm : 1908

Quê quán xã Bình Trinh Đông huyện Tân Trụ Tỉnh Long An

Mức trợ cấp hưởng đến hết tháng 02/2006 của Bà Cao Thị Mai Số tiền: 250.000đ ( Hai trăm năm chục ngàn đồng )

**Điều 2.** Kể từ ngày 01 tháng 03 năm 2006

Có mức trợ cấp: Không định suất, Số tiền: Không

Lý do: Cắt trợ cấp AHLLVT Bà Mai đã chết ngày 23 /12/2005 theo giấy đề nghị của UBND xã Bình Trinh Đông ký ngày 11 tháng 1 năm 2006

Truy thu nộp về Sở trợ cấp tháng 1+2/2006 số tiền: 500.000đ ( Năm trăm ngàn đồng).

**Điều 3.** Ông Chánh Văn phòng HĐND và UBND huyện Tân Trụ, Trưởng phòng Nội vụ-LDTB&XH, Chủ tịch UBND xã Bình Trinh Đông và gia đình Ông (Bà) có tên trên chịu trách nhiệm thi hành quyết định này.

Quyết định này có hiệu lực kể từ ngày ký *14/2*

Nơi Nhận:

-Sở LĐTBXH,  
-Như điều 3,  
-Lưu VP.

CHỦ TỊCH

Nguyễn Ngọc Đây');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (99, 1, 99, '99', 'ỦY BAN NHÂN DÂN  
XÃ: Bến Tre

CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM  
Độc lập - Tự do - Hạnh phúc

**PHIẾU BÁO GIẢM**

(Ban hành kèm theo Hướng dẫn số ..... /LDTBXH ngày .../01/2005 của Sở Lao động-Thương binh và Xã hội)

Họ và tên người có công: Cao Thị Mai ... Năm sinh: 1908

Nguyên quán: Xã Bình Phước, Huyện Phước Điền, Tỉnh Long An

Nơi nhận trợ cấp trước khi tử trận: .....

Từ trận ngày 13.11.2005. Theo giấy chứng tử số: 01 Ngày 10.11.2006

của UBND xã/phường: Bến Tre

Thuộc đối tượng hưởng trợ cấp ưu đãi: (LTCM, TB, BB, TNLS ...)

... Anh thực lực lượng vũ trang nhân dân

Số sổ trợ cấp: 08 ... Số hồ sơ: ... Tỷ lệ MSLD (%) .....

Các mức trợ cấp ưu đãi hưởng đang hưởng như sau:

- Chế độ trợ cấp: Anh hưởng LLVT khi còn đang

Số tiền trợ cấp: 250.000 d Phụ cấp .....

- Chế độ trợ cấp: .....

Số tiền trợ cấp: .....

- Chế độ trợ cấp: .....

Số tiền trợ cấp: .....

- Chế độ trợ cấp: .....

Số tiền trợ cấp: .....

- Phụ cấp khu vực, hè sở: .....

Số tiền: 250.000 đồng

**Tổng công số tiền đang nhận hàng tháng**

Đã nhận tiền trợ cấp đến hết tháng: 1 năm: 2008

Nay báo cắt giảm trợ cấp của Ông/Bà: Cao Thị Mai

Kể từ tháng 2 năm 2008

Các chế độ trợ cấp sau khi tử trận bao gồm:

- Trợ cấp một lần:

+ Mai táng phí: .....

+ 3 tháng trợ cấp, phụ cấp: 250.000 x 3 tháng = 750.000 đồng

**Tổng công:** .....

- Trợ cấp tuất tử trận (nếu có), theo bản khai kèm theo.

Xin báo cáo đề Sở Lao động-Thương binh và Xã hội làm thủ tục giải quyết chế độ tử trận.

Ngày 11 tháng 01 năm 2008

UBND xã, phường: Bến Tre

**CHỦ TỊCH**

(Ký tên, đóng dấu)

Trần Tấn Dep

Ngày 10 tháng 02 năm 2008  
PHÒNG NỘI VỤ - Lao động TB và XH  
KI-TRƯỜNG PHÒNG

(Ký tên, đóng dấu)

Lê Văn Phước');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (100, 1, 100, '100', 'CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM

Độc lập - Tự do - Hạnh phúc

BẢN KHAI CỦA THÂN NHÂN

NGƯỜI CÓ CÔNG CÁCH MẠNG TỪ TRẦN

(Ban hành kèm theo Hướng dẫn số /LDTBXH ngày /01/2005 của Sở Lao động-Thương binh và Xã hội)

Họ và tên người từ trần Cao Thị Mai Năm sinh 1958
Nguyên quán Xã Bình Thành, Huyện Tân Phú, Tỉnh Long An
Nơi nhận trợ cấp trước khi từ trần Xã Bình Thành
Thuộc đối tượng hưởng trợ cấp ưu đãi (LTCM, TB, BB, TNLS)
Số trợ cấp 08 Số hộ sơ
Tỷ lệ mất sức lao động (%)
Từ ngày 23/12/2005 Theo giấy chứng từ số 01 Ngày 10.1.2006
Địa chỉ: Xã phường Bình Thành
Họ nhận tiền trợ cấp đến hết tháng 1 năm 2006
Số tiền 250.000
Trường hợp chết
Họ tên người đứng nhận tiền mai táng phí và 3 tháng trợ cấp, phụ cấp
Nguyễn Thị Xuân Năm sinh 1938
Họ khẩu thương trú Xã Bình Thành
Quan hệ với người chết con

DANH SÁCH THÂN NHÂN DÙ ĐIỀU KIỆN HƯỚNG TUẤT TỪ TRẦN (dùng cho đối tượng người có công có chế độ tuất từ trần)

Table with 4 columns: Số TT, Họ và tên, Ngày tháng năm sinh, Quan hệ, and Nơi ở (để nhận tuất). Rows 01-05 are empty.

Ngày 10 tháng 1 năm 2006
UBND xã, phường Bình Thành
CHỦ TỊCH
(Ký tên đóng dấu)

Ngày 10 tháng 1 năm 2006
Người đứng khai nhận trợ cấp
(Ký tên và ghi rõ họ tên)

Official stamp of the People''s Committee of Binh Thanh Commune, Long An Province, with handwritten signature and name Trần Bá Dep.

Handwritten signature and name Nguyễn Thị Xuân.');
INSERT INTO raw_pages (raw_page_id, source_file_id, page_no, page_marker, raw_text) VALUES (101, 1, 101, '101', 'ỦY BAN NHÂN DÂN CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM Mẫu TP/HT-1999-C.2.a  
Xã/Phường Bình Trinh Đông Độc lập - Tự do - Hạnh phúc Số: ... 01/06...  
Huyện/Quận Tân Trụ Quyền số: 01 ...  
Tỉnh/Thành phố Long An

# GIẤY CHỨNG TỬ (BẢN SAO)

Họ và tên: CAO THỊ MAI Giới tính NỮ  
Ngày, tháng, năm sinh: 1908  
Đân tộc: Kinh Quốc tịch Việt Nam  
Quê quán: Xã Bình Trinh Đông, Tân Trụ, Long An  
Nơi thường trú/Tam trú cuối cùng: Xã Bình Trinh Đông, Tân Trụ, Long An  
Giấy CMND/Giấy tờ hợp lệ thay thế: .....  
Số: .....  
Cấp tại: ..... ngày ..... tháng ..... năm .....  
Đã chết vào lúc 09 giờ 30 phút, ngày 23 tháng 12 năm 2005  
Nơi chết: Xã Bình Trinh Đông, Tân Trụ, Long An  
Nguyên nhân chết: Bệnh

Cán bộ hộ tịch  
(Đã ký)  
Nguyễn Văn Thành Phong

30, ngày 10, tháng 01 năm 2006  
T/M ỦY BAN NHÂN DÂN .....  
CHỦ TỊCH  
(Đã ký)  
TRẦN TÂN ĐỆP

Sao từ Sở Đăng ký khai tử  
BTĐ ngày 10 tháng 01 năm 2006  
T/M ỦY BAN NHÂN DÂN .....  
CHỦ TỊCH  
(Ký và ghi rõ họ tên, đóng dấu)

Trần Tấn Đệ

01/2005/QĐ số 1205/QĐ/TP HTQ QĐ.1');
INSERT INTO raw_page_fts(rowid, raw_text) SELECT raw_page_id, raw_text FROM raw_pages;
INSERT INTO persons VALUES
(1, 'Nguyễn Văn Chiếu', NULL, 'Nam', 1930, 'Mỹ Thành, Cai Lậy, Tiền Giang', 'Phường 6, thị xã Tân An, tỉnh Long An', 'honored_person', 'Anh hùng LLVTND.'),
(2, 'Nguyễn Văn Báo', NULL, 'Nam', 1932, 'xã Đức Tân, huyện Tân Trụ, tỉnh Long An', 'xã Đức Tân, huyện Tân Trụ, tỉnh Long An', 'beneficiary', 'Cha của liệt sỹ Nguyễn Thị Bé.'),
(3, 'Nguyễn Thị Bé', 'Nguyễn Hoàng Anh', 'Nữ', NULL, 'xã Đức Tân, huyện Tân Trụ, tỉnh Long An', 'xã Đức Tân, huyện Tân Trụ, tỉnh Long An', 'honored_person', 'Liệt sỹ, nguyên Tiểu đội phó Đội 198 TNXP.'),
(4, 'Trần Thị Nuôi', NULL, 'Nữ', 1956, 'Xã Nhơn Hòa Lập, huyện Tân Thạnh, tỉnh Long An', 'Xã Tân Ninh, huyện Tân Thạnh, tỉnh Long An', 'beneficiary', 'Con của liệt sỹ Trần Công Vịnh.'),
(5, 'Trần Công Vịnh', NULL, 'Nam', NULL, 'Xã Nhơn Hòa Lập, huyện Tân Thạnh, tỉnh Long An', NULL, 'honored_person', 'Liệt sỹ, Phó Bí thư Huyện Đoàn Mộc Hóa.'),
(6, 'Cao Thị Mai', NULL, 'Nữ', 1908, 'xã Bình Trinh Đông, huyện Tân Trụ, tỉnh Long An', 'xã Bình Trinh Đông, huyện Tân Trụ, tỉnh Long An', 'honored_person', 'Được hưởng AHLLVTND, qua đời ngày 2005-12-23.'),
(7, 'Nguyễn Thị Quận', NULL, 'Nữ', 1938, NULL, 'xã Bình Trinh Đông, huyện Tân Trụ, tỉnh Long An', 'beneficiary', 'Con của Cao Thị Mai.'),
(8, 'Trần Thị Sửa', 'Trần Thị Sáu', 'Nữ', 1945, NULL, 'Thị trấn Tân Châu, huyện Tân Châu, tỉnh Tây Ninh', 'beneficiary', 'Đang hưởng trợ cấp AHLLVTND và làm thủ tục di chuyển hồ sơ.');
INSERT INTO organizations VALUES
(1, 'Sở Lao động Thương binh và Xã hội tỉnh Long An', 'provincial_department', 'Long An'),
(2, 'Chủ tịch nước', 'state_office', 'Việt Nam'),
(3, 'UBND huyện Tân Trụ', 'district_people_committee', 'Long An');
INSERT INTO decisions VALUES
(1, '57/QĐ-LĐTBXH', 'Trợ cấp Anh hùng Lực lượng vũ trang nhân dân', 1, '2006-02-20', 'benefit_decision', 1, 'Trợ cấp cho Nguyễn Văn Chiếu.'),
(2, '634/2005/QĐ/CTN', 'Phong tặng danh hiệu Anh hùng Lực lượng vũ trang nhân dân', 2, '2005-06-27', 'honor_decision', 2, 'Phong tặng cho nhiều tập thể, cá nhân.'),
(3, '212/QĐ-CTN', 'Truy tặng danh hiệu Anh hùng Lực lượng vũ trang nhân dân', 2, '2010-02-23', 'honor_decision', 9, 'Truy tặng cho nhiều cá nhân.'),
(4, '58/QĐ-SLDTBXH', 'Trợ cấp ưu đãi Anh hùng lực lượng vũ trang nhân dân', 1, '2010-05-25', 'benefit_decision', 4, 'Trợ cấp một lần cho Nguyễn Văn Báo.'),
(5, '59/QĐ-SLDTBXH', 'Trợ cấp ưu đãi Anh hùng lực lượng vũ trang nhân dân', 1, '2010-10-19', 'benefit_decision', 10, 'Trợ cấp một lần cho Trần Thị Nuôi.'),
(6, '08/QĐ-LĐTBXH.XH', 'Trợ cấp tiền mai táng phí, trợ cấp một lần cho gia đình Anh hùng lực lượng vũ trang', 1, '2006-02-20', 'benefit_decision', 97, 'Trợ cấp cho Nguyễn Thị Quận do Cao Thị Mai từ trần.'),
(7, '111/QĐ-UBND', 'Cắt trợ cấp ưu đãi AHLLVT', 3, '2006-02-13', 'benefit_adjustment', 98, 'Cắt trợ cấp của Cao Thị Mai sau khi qua đời.');
INSERT INTO honors VALUES
(1, 1, 2, 'Anh hùng Lực lượng vũ trang nhân dân', 'phong_tang', 'Kháng chiến chống Mỹ, cứu nước', NULL),
(2, 3, 3, 'Anh hùng Lực lượng vũ trang nhân dân', 'truy_tang', 'Kháng chiến chống Mỹ, cứu nước', NULL),
(3, 5, 3, 'Anh hùng Lực lượng vũ trang nhân dân', 'truy_tang', 'Kháng chiến chống Mỹ, cứu nước', NULL),
(4, 6, 2, 'Anh hùng Lực lượng vũ trang nhân dân', 'phong_tang', 'Kháng chiến chống Mỹ, cứu nước', 'Theo hồ sơ đang hưởng và điều chỉnh trợ cấp.');
INSERT INTO relationships VALUES
(1, 2, 3, NULL, 'cha', NULL),
(2, 4, 5, NULL, 'con', NULL),
(3, 7, 6, NULL, 'con', NULL);
INSERT INTO benefit_cases VALUES
(1, 1, 1, 1, 'tro_cap_mot_lan_va_truy_lanh', '2005-06-01', 3000000, 300000, 'VND', 'active', 'Có truy lãnh 2 giai đoạn, tổng cộng 5.800.000 đồng.'),
(2, 2, 3, 4, 'tro_cap_mot_lan_than_nhan', '2010-05-25', 13700000, NULL, 'VND', 'active', 'Thân nhân hưởng do Nguyễn Thị Bé được truy tặng.'),
(3, 4, 5, 5, 'tro_cap_mot_lan_than_nhan', '2010-10-19', 13700000, NULL, 'VND', 'active', 'Thân nhân hưởng do Trần Công Vịnh được truy tặng.'),
(4, 7, 6, 6, 'mai_tang_phi_va_tro_cap_mot_lan', '2006-02-20', 750000, NULL, 'VND', 'closed', 'Sau khi trừ truy thu còn thực cấp 250.000 đồng.'),
(5, 8, 8, 2, 'di_chuyen_tro_cap_hang_thang', '2007-03-01', NULL, 300000, 'VND', 'moved', 'Hồ sơ di chuyển từ Long An sang Tây Ninh.');
INSERT INTO payment_periods VALUES
(1, 1, '2005-06-01', '2005-09-30', 4, 250000, 1000000, 'Truy lãnh giai đoạn 1.'),
(2, 1, '2005-10-01', '2006-03-31', 6, 300000, 1800000, 'Truy lãnh giai đoạn 2.'),
(3, 4, '2006-01-01', '2006-02-28', 2, 250000, 500000, 'Khoản truy thu do đã cắt trợ cấp.'),
(4, 4, NULL, NULL, NULL, NULL, 150000, 'Số tiền chênh lệch cấp thêm cho gia đình theo phiếu điều chỉnh trợ cấp.');
COMMIT;
