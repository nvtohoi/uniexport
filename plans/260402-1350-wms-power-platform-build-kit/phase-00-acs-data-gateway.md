# Phase 0: ACS Data Gateway Setup

## Context
- [Plan Overview](plan.md)
- [ACS Analysis](../reports/brainstorm-260402-1521-acs-amms-data-integration.md)

## Overview
- **Priority:** P0 (prerequisite cho Phase 4, 5, 6)
- **Status:** pending
- **Description:** Cài đặt On-Premises Data Gateway, kết nối SQL Server ACS AMMS IoT với Power Platform.

## Key Insights
- ACS AMMS IoT lưu dữ liệu trong SQL Server, DB name: `ACSAMMS_TAMPHUOC`
- On-Premises Data Gateway là bridge miễn phí cho phép Power BI + Power Automate truy cập SQL nội bộ
- Chỉ cần cài 1 lần trên 1 máy Windows trong cùng mạng LAN

## Requirements

### Functional
- Power BI Desktop kết nối được DB ACSAMMS_TAMPHUOC
- Power Automate đọc được tables/views từ ACS
- Dữ liệu phiếu cân sync mỗi 5 phút (hoặc realtime nếu dùng SQL trigger)

### Non-Functional
- Gateway machine phải luôn bật (24/7 hoặc giờ hành chính)
- Read-only access vào ACS database (không ghi, không sửa)
- Network latency < 1s từ gateway đến SQL Server

## Prerequisites (cần xác nhận với IT/ACS)

### 1. Thông tin SQL Server ACS
- [ ] IP address / hostname của SQL Server
- [ ] Port (mặc định 1433)
- [ ] SQL Authentication account (read-only)
- [ ] Database name: `ACSAMMS_TAMPHUOC` (xác nhận)
- [ ] Có firewall rules cho phép kết nối từ gateway machine?

### 2. Máy cài Gateway
- [ ] Windows Server hoặc Windows 10/11 (luôn bật)
- [ ] Cùng mạng LAN với SQL Server ACS
- [ ] .NET Framework 4.7.2+ đã cài
- [ ] Có internet access (gateway cần kết nối ra Microsoft cloud)
- [ ] Tài khoản M365 admin để đăng ký gateway

### 3. ACS Database Schema (cần khảo sát)
- [ ] Liên hệ ACS để xin tài liệu database schema
- [ ] Hoặc dùng SQL Server Management Studio (SSMS) khảo sát tables
- [ ] Xác định tables chính: phiếu cân, khách hàng, hàng hóa, xe

## Implementation Steps

### Step 1: Khảo sát ACS Database
```sql
-- Kết nối SSMS vào SQL Server ACS
-- Liệt kê tất cả tables
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_CATALOG = 'ACSAMMS_TAMPHUOC'
ORDER BY TABLE_NAME;

-- Xem cấu trúc table phiếu cân (tên table cần xác nhận)
-- Dự đoán có thể là: PhieuCan, WeighTicket, tblPhieuCan, etc.
```

### Step 2: Tạo SQL read-only account
```sql
-- Chạy trên SQL Server ACS (cần SA rights)
CREATE LOGIN PowerBI_Reader WITH PASSWORD = '[strong-password]';
USE ACSAMMS_TAMPHUOC;
CREATE USER PowerBI_Reader FOR LOGIN PowerBI_Reader;
ALTER ROLE db_datareader ADD MEMBER PowerBI_Reader;
-- Chỉ SELECT, không INSERT/UPDATE/DELETE
```

### Step 3: Cài On-Premises Data Gateway
1. Download từ: https://aka.ms/on-premises-data-gateway-installer
2. Cài đặt trên máy gateway (chọn "Standard" mode)
3. Đăng nhập bằng tài khoản M365 admin
4. Đặt tên gateway: `WMS-Gateway-[TenNhaMay]`
5. Tạo recovery key (lưu an toàn)

### Step 4: Đăng ký Data Source trong Power Platform Admin
1. Vào https://admin.powerplatform.microsoft.com
2. Data → Gateways → chọn gateway vừa cài
3. Add data source:
   - Type: SQL Server
   - Server: [IP:Port]
   - Database: ACSAMMS_TAMPHUOC
   - Authentication: Basic (SQL account PowerBI_Reader)
4. Test connection

### Step 5: Verify kết nối
- Power BI Desktop → Get Data → SQL Server → chọn gateway
- Verify tables hiển thị, data đúng
- Power Automate → SQL Server connector → chọn gateway → test query

## ACS Database Schema (dự đoán, cần verify)

Dựa trên screenshot giao diện AMMS IoT, tables có thể bao gồm:

| Table (dự đoán) | Nội dung | Mapping SharePoint |
|-----------------|---------|-------------------|
| PhieuCan / WeighTicket | Phiếu cân (SoPhieu, BienSo, TL cân 1/2, TL hàng) | CAN_PhieuCan_ACS |
| KhachHang / Customer | Khách hàng / NCC | Lookup data |
| HangHoa / Product | Danh mục hàng hóa | Lookup data |
| Xe / Vehicle | Danh mục xe | VT_DanhMucXe (merge) |
| LaiXe / Driver | Lái xe | VT_LaiXe (merge) |
| Kho / Warehouse | Kho | KHO mapping |
| NhaVanTai / Carrier | Nhà vận tải | VT data |

**Cần khảo sát thực tế bằng SSMS để xác nhận.**

## Todo List

- [ ] Xác nhận IP/port SQL Server ACS với IT
- [ ] Xin hoặc tạo SQL read-only account
- [ ] Khảo sát database schema bằng SSMS
- [ ] Cài On-Premises Data Gateway
- [ ] Đăng ký data source trong Power Platform Admin
- [ ] Test kết nối Power BI → SQL ACS
- [ ] Test kết nối Power Automate → SQL ACS
- [ ] Document database schema thực tế

## Success Criteria

- Power BI Desktop query được dữ liệu phiếu cân từ ACS
- Power Automate đọc được tables ACS qua gateway
- Latency < 2s cho mỗi query
- Read-only — không ảnh hưởng hoạt động ACS

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| ACS không cho phép truy cập DB | Critical | Thương lượng, đề xuất read-only view |
| Gateway machine restart → mất kết nối | Medium | Cài gateway as Windows Service (auto-start) |
| ACS update DB schema → queries hỏng | Medium | Dùng SQL Views thay vì query trực tiếp tables |
| Performance impact lên ACS khi Power BI query | Low | Read-only account, query off-peak, scheduled refresh |
