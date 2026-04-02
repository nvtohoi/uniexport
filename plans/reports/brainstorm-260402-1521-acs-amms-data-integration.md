# Phân tích: ACS AMMS IoT — Hệ thống cân hiện có & Chiến lược tích hợp

**Ngày:** 02/04/2026

---

## Phát hiện quan trọng

Hệ thống cân xe **đã có sẵn và đang hoạt động** — phần mềm ACS AMMS IoT.

## Thông tin hệ thống hiện có (từ screenshot)

| Thành phần | Chi tiết |
|-----------|----------|
| Phần mềm | AMMS IoT - Digitize operations - Hệ thống quản lý cầu cân |
| Loại | Windows Desktop App |
| Database | SQL Server — tên DB: `ACSAMMS_TAMPHUOC` |
| Trạm cân | Bàn cân 01, 2 cảm biến |
| Camera | 3 camera (nhận dạng biển số + giám sát cân vào/ra) |
| Realtime | Đọc cân trực tiếp (hiển thị KG realtime) |
| Dữ liệu mẫu | 44 bản ghi ngày 02/04/2026 |
| User | tamphuoc (đang đăng nhập) |

## Cấu trúc dữ liệu ACS (quan sát từ giao diện)

### Form nhập phiếu cân
- Số phiếu (auto-generated: 2604021048)
- Biển số xe + Rơ mooc
- KH/NCC (Khách hàng / Nhà cung cấp)
- Hàng hóa
- Kho
- Nhà vận tải
- Lái xe
- Ghi chú, Chứng từ
- Chế độ: Cân nhập / Cân xuất / Tự động

### Dữ liệu cân
- TL cân lần 1 (kg) + Thời gian cân lần 1
- TL cân lần 2 (kg) + Thời gian cân lần 2
- TL hàng (kg) = |Lần 1 - Lần 2|

### Grid phiếu cân
- Số phiếu cân, Biển số, Rơ mooc, TG cân L1, TL cân L1, Khách hàng/NCC, Hàng hóa
- Filters: Cân vào / Cân cả vào và ra / Cân ra bị cân lại / Phiếu cân bị xóa / Hủy chuyển
- Xem theo ngày, Tìm kiếm

### Camera
- 3 camera giám sát (biển số + cân vào + cân ra)
- Lưu hình ảnh cân vào / cân ra

## Thay đổi chiến lược

### Trước (giả định không có hệ thống cân)
- Cần build 3 modules từ đầu: Kho + Vận tải + Cân xe
- Hardware integration là deal-breaker cho Power Apps
- Web App + Scale Agent là khuyến nghị

### Sau (đã có ACS AMMS IoT)
- Module Cân xe: **KHÔNG CẦN BUILD** — chỉ cần đọc dữ liệu từ SQL Server ACS
- Module Kho + Vận tải: Build mới trên Power Apps (khả thi vì không cần hardware)
- Power Apps **trở lại khả thi** (score 56 → ~75/100)

## 3 phương án lấy dữ liệu từ ACS

### A. Power BI → SQL Server (trực tiếp) — Cho báo cáo
- Power BI Desktop → Get Data → SQL Server → ACSAMMS_TAMPHUOC
- Auto refresh mỗi 30 phút
- Cần: On-Premises Data Gateway nếu SQL trong mạng LAN
- Thời gian: 1-2 ngày

### B. Power Automate → SQL → SharePoint — Cho Power Apps
- Scheduled flow mỗi 5 phút
- SQL connector đọc records mới → tạo items trong SharePoint List
- Power Apps đọc từ SharePoint (delegation-safe)
- Cần: On-Premises Data Gateway
- Thời gian: 1-2 ngày

### C. Power BI + Power Automate (kết hợp)
- Power BI cho dashboard/báo cáo phức tạp
- Power Automate sync cho Power Apps CRUD
- Cần: On-Premises Data Gateway (1 lần cài đặt, dùng cho cả 2)

## Yêu cầu kỹ thuật

### On-Premises Data Gateway
- Cài trên 1 máy Windows trong cùng mạng LAN với SQL Server ACS
- Miễn phí (Standard mode)
- Cho phép Power BI + Power Automate truy cập SQL nội bộ

### SQL Server access
- Cần tài khoản SQL Server đọc DB ACSAMMS_TAMPHUOC
- Chỉ cần quyền SELECT (read-only)
- Liên hệ ACS hoặc IT admin để lấy connection string

## Câu hỏi cần giải quyết

1. SQL Server ACS chạy trên máy nào? IP? Port? (thường 1433)
2. Có tài khoản SQL read-only cho DB ACSAMMS_TAMPHUOC chưa?
3. ACS có API hoặc tài liệu database schema không?
4. Có bao nhiêu trạm cân (hiện thấy Bàn cân 01)?
5. Dữ liệu cần sync: chỉ phiếu cân hay cả master data (KH, hàng hóa, kho)?
6. On-Premises Data Gateway cài được trên máy nào trong mạng LAN?
