# Phase 1: Data Gateway + ACS SQL Connection

## Overview
- **Priority:** P0 (prerequisite cho Phase 6 Power BI)
- **Status:** pending
- **Effort:** Low (1-2 ngày)
- **Description:** Cài On-Premises Data Gateway, kết nối SQL Server ACS cho Power BI + Power Automate.

## Mục tiêu

Cho phép Power BI và Power Automate đọc dữ liệu cân từ SQL Server ACS (`ACSAMMS_TAMPHUOC`) trong mạng nội bộ.

## Steps

### 1. Thu thập thông tin SQL Server ACS
- IP address / hostname
- Port (mặc định 1433)
- Xin hoặc tạo SQL read-only account
- Xác nhận tên DB: `ACSAMMS_TAMPHUOC`

### 2. Tạo SQL Read-Only Account
```sql
CREATE LOGIN PowerBI_Reader WITH PASSWORD = '[strong-password]';
USE ACSAMMS_TAMPHUOC;
CREATE USER PowerBI_Reader FOR LOGIN PowerBI_Reader;
ALTER ROLE db_datareader ADD MEMBER PowerBI_Reader;
```

### 3. Cài On-Premises Data Gateway
- Download: https://aka.ms/on-premises-data-gateway-installer
- Cài trên máy Windows trong LAN (cùng mạng với SQL Server ACS)
- Chọn "Standard" mode
- Đăng nhập M365 admin account
- Tạo recovery key

### 4. Đăng ký Data Source
- Power Platform Admin Center → Gateways → Add data source
- Type: SQL Server
- Server: [IP:Port], DB: ACSAMMS_TAMPHUOC
- Auth: Basic (PowerBI_Reader account)
- Test connection

### 5. Khảo sát Database Schema
```sql
-- Liệt kê tables
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_CATALOG = 'ACSAMMS_TAMPHUOC' ORDER BY TABLE_NAME;

-- Xem columns của table phiếu cân
SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = '[tên table phiếu cân]';
```

### 6. Verify
- Power BI Desktop → Get Data → SQL Server (qua gateway) → thấy data
- Power Automate → SQL connector → test query

## Todo List
- [ ] Lấy IP/port SQL Server từ IT
- [ ] Tạo SQL read-only account
- [ ] Cài gateway trên máy LAN
- [ ] Đăng ký data source
- [ ] Khảo sát DB schema, document tables/columns
- [ ] Test Power BI connection
- [ ] Test Power Automate connection

## Success Criteria
- Power BI query được dữ liệu phiếu cân từ ACS
- Latency < 2s
- Read-only, không ảnh hưởng ACS
