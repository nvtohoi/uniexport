# So sánh: Power Apps vs Web App vs Desktop App cho Hệ thống WMS

**Ngày:** 02/04/2026
**Dự án:** Hệ thống Quản lý Kho – Vận tải – Cân xe
**Quy mô:** 100+ users, 3 modules, tích hợp M365 hiện có

---

## Bối cảnh

- Đội ngũ phát triển: Full dev team (3+ người, Frontend + Backend + DevOps)
- Yêu cầu đặc biệt:
  - Kết nối trực tiếp cân điện tử (COM/USB/API)
  - Hoạt động offline (mất mạng vẫn dùng được)
  - Báo cáo phức tạp (pivot, chart, export Excel)

---

## Bảng điểm tổng hợp

| Tiêu chí | Power Apps | Web App (React + .NET) | Desktop App (.NET WPF) |
|----------|:---------:|:---------------------:|:---------------------:|
| Kết nối cân điện tử (COM/USB) | 1/10 | 5/10 (qua API bridge) | **10/10** |
| Offline support | 3/10 | 7/10 (PWA + IndexedDB) | **9/10** (SQLite local) |
| Báo cáo phức tạp | 4/10 (cần Power BI) | **8/10** (Chart.js, AG Grid) | **8/10** |
| Tốc độ phát triển | **8/10** | 5/10 | 4/10 |
| Chi phí license | 3/10 ($2K-4K/tháng) | **9/10** (~$100/tháng) | **9/10** |
| Bảo trì dài hạn | 6/10 | **8/10** | 5/10 |
| Mobile support | **8/10** | **8/10** (responsive) | 2/10 |
| Tích hợp M365 | **10/10** | 6/10 (Graph API) | 5/10 |
| Scalability (100+ users) | 4/10 (SP 5000 row limit) | **9/10** (SQL database) | **8/10** |
| Deploy & update | **9/10** | **8/10** (CI/CD) | 3/10 |
| **TỔNG** | **56/100** | **73/100** | **63/100** |

---

## 1. Power Apps Canvas — KHÔNG PHÙ HỢP

### Vấn đề cốt lõi

**Cân điện tử:** Power Apps **KHÔNG THỂ** đọc cổng COM/USB/Serial. Đây là deal-breaker lớn nhất.
- Phải xây Azure Function làm bridge (thêm $200-500/tháng)
- Hoặc dùng phần mềm cân xuất CSV rồi Power Automate import (delay 1-5 phút)
- **Không có cách nào đọc cân realtime trong Power Apps**

**Offline:** `SaveData`/`LoadData` của Power Apps rất hạn chế:
- Chỉ cache collections (không cache lookups)
- Không đồng bộ 2 chiều khi online lại
- Xung đột dữ liệu khi nhiều người offline cùng lúc → mất data

**Báo cáo:** Power Apps không có chart/pivot native tốt. Phải dùng Power BI ($10/user/tháng thêm).

**SharePoint delegation limit:** Giới hạn 2000-5000 records, cần archival strategy phức tạp.

### Chi phí thực tế cho 100 users

| Hạng mục | Chi phí/tháng |
|----------|--------------|
| Power Apps Per User ($20 × 100) | $2,000 |
| Power Automate ($15 × 30) | $450 |
| Power BI Pro ($10 × 20) | $200 |
| Azure Function (bridge) | ~$100 |
| **TỔNG** | **~$2,750/tháng = $33,000/năm** |

### Khi nào nên dùng Power Apps
- Team không có developer
- Hệ thống đơn giản, < 50 users
- Không cần kết nối hardware
- Đã có M365 license và muốn tận dụng

---

## 2. Web App (React + .NET API + SQL Server) — **KHUYẾN NGHỊ**

### Tại sao phù hợp nhất

**Cân điện tử:** Xây một **local agent** nhỏ chạy trên máy trạm cân:

```
[Cân điện tử] → COM port → [Local Agent (.NET)] → WebSocket → [Web App]
```

Agent đọc serial port, gửi dữ liệu realtime lên web app qua WebSocket. User thấy số cân hiển thị tức thì trên trình duyệt.

**Offline:** PWA (Progressive Web App) + IndexedDB:
- Cache form nhập liệu offline
- Đồng bộ khi có mạng lại (background sync)
- Service Worker giữ app hoạt động khi mất mạng
- Conflict resolution bằng queue

**Báo cáo:** Tự do tùy chỉnh:
- AG Grid / TanStack Table cho pivot table
- Chart.js / Recharts cho biểu đồ
- Export Excel trực tiếp (SheetJS)
- Không cần Power BI license

**Tích hợp M365:**
- Auth: Entra ID SSO (đăng nhập bằng tài khoản công ty)
- Email/Teams: Microsoft Graph API gửi thông báo
- SharePoint: lưu file đính kèm (hóa đơn, ảnh xe)
- Vẫn giữ được toàn bộ tích hợp M365

### Stack đề xuất

| Layer | Công nghệ |
|-------|----------|
| Frontend | React + TypeScript + Vite |
| UI Components | Ant Design hoặc MUI |
| Tables/Reports | TanStack Table + Recharts |
| Offline | PWA plugin + IndexedDB |
| Backend | .NET 8 Web API (hoặc Node.js/Express) |
| Realtime | SignalR (WebSocket cho cân xe) |
| ORM | Entity Framework Core |
| Database | SQL Server (Azure SQL hoặc on-prem) |
| Auth | Microsoft Entra ID (MSAL.js) |
| Deploy | Azure App Service hoặc on-premise IIS |

### Chi phí

| Hạng mục | Chi phí/tháng |
|----------|--------------|
| Azure App Service (B1) | ~$55 |
| Azure SQL (S1) | ~$30 |
| Azure SignalR (free tier) | $0 |
| Domain + SSL | ~$1 |
| **TỔNG** | **~$100/tháng = $1,200/năm** |

**Tiết kiệm $31,800/năm so với Power Apps!**

### Nhược điểm
- Thời gian build: 2-4 tháng (vs 2-4 tuần Power Apps)
- Cần dev team maintain liên tục
- Phức tạp hơn về DevOps (CI/CD, monitoring)

---

## 3. Desktop App (.NET WPF / Electron) — CHỈ PHÙ HỢP CHO TRẠM CÂN

### Ưu điểm
- Đọc COM/Serial port **trực tiếp**, không cần bridge
- Offline 100% (SQLite local)
- Hiệu năng cao

### Nhược điểm
- **Deploy là ác mộng** với 100+ users: cài đặt từng máy, cập nhật từng máy
- Không có mobile support cho lái xe
- Khó bảo trì khi có nhiều version trên nhiều máy
- Không truy cập được từ bên ngoài công ty

### Khi nào dùng
Chỉ cho trạm cân (1-2 máy tính cố định kết nối với cân)

---

## 4. Đề xuất: HYBRID — Web App + Scale Agent

Kết hợp ưu điểm của Web App và Desktop:

```
┌──────────────────────────────────────────────────┐
│             WEB APP (React + .NET API)            │
│                                                   │
│  ┌─────────┐  ┌─────────┐  ┌──────────────────┐  │
│  │ Kho     │  │ Vận tải │  │ Cân xe           │  │
│  │ Module  │  │ Module  │  │ Module           │  │
│  └────┬────┘  └────┬────┘  └────────┬─────────┘  │
│       │            │                │             │
│       └────────────┼────────────────┘             │
│                    │                              │
│          ┌─────────▼──────────┐                   │
│          │  .NET API          │                   │
│          │  SignalR Hub       │                   │
│          │  SQL Server        │                   │
│          └─────────┬──────────┘                   │
└────────────────────┼──────────────────────────────┘
                     │ WebSocket
        ┌────────────▼─────────────┐
        │  SCALE AGENT (Desktop)   │
        │  .NET Console App nhỏ    │
        │  Chạy trên máy trạm cân │
        │  Đọc COM port → push     │
        │  data lên web qua WS     │
        └──────────────────────────┘
```

**Scale Agent** là app nhỏ (~100 dòng code):
- Chạy ngầm trên máy tính trạm cân (auto-start với Windows)
- Đọc serial port từ cân điện tử
- Push số cân lên Web App qua WebSocket
- Web App hiển thị realtime trên màn hình Cân Vào / Cân Ra
- Chỉ cần cài đặt trên 1-2 máy (trạm cân), không phải 100+ máy

---

## Tóm tắt khuyến nghị

| Tiêu chí | Kết luận |
|----------|---------|
| **Lựa chọn tốt nhất** | Web App + Scale Agent (Hybrid) |
| **Lý do chính** | Giải quyết cả 3 yêu cầu đặc biệt (cân HW, offline, báo cáo) |
| **Chi phí** | ~$1,200/năm vs $33,000/năm (Power Apps) |
| **Thời gian build** | 2-4 tháng |
| **Team cần** | 1 Frontend (React), 1 Backend (.NET), 1 tester |
| **Rủi ro chính** | Thời gian build lâu hơn Power Apps |

---

## Câu hỏi chưa giải quyết

1. Scale vendor cụ thể nào sẽ sử dụng? (cần biết protocol: RS-232, Modbus, API?)
2. Hạ tầng deploy: Azure cloud hay on-premise server?
3. Có cần tích hợp với ERP/SAP hiện có không?
4. Budget cho development phase (2-4 tháng)?
5. Mạng nội bộ tại kho/trạm cân ổn định không? (ảnh hưởng offline strategy)
