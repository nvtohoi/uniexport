# Phase 6: Power BI Dashboards

## Overview
- **Priority:** P1
- **Status:** pending
- **Effort:** Medium
- **Description:** 3 dashboards kết nối SQL Server ACS (cân xe) + SharePoint (Kho, Vận tải).

## Dashboards

### 1. Dashboard Cân Xe (từ ACS SQL Server)
- Tổng phiếu cân theo ngày/tuần/tháng
- Tổng trọng lượng theo hàng hóa, khách hàng
- Top 10 KH theo khối lượng
- Xu hướng (line chart)
- Filter: ngày, kho, hàng hóa, KH/NCC, ca làm việc
- Cảnh báo quá tải

### 2. Dashboard Kho (từ SharePoint)
- Tồn kho hiện tại vs ngưỡng tối thiểu
- Nhập/Xuất theo thời gian
- Top hàng hóa xuất nhiều nhất
- Cảnh báo hàng sắp hết

### 3. Dashboard Vận Tải (từ SharePoint)
- Chuyến hàng theo trạng thái (Kanban view)
- Chi phí xe theo tháng
- Tỷ lệ hoàn thành đúng hạn
- Cảnh báo hết hạn đăng kiểm/bảo hiểm

## Data Sources

| Dashboard | Source | Connection |
|-----------|--------|-----------|
| Cân Xe | SQL Server ACSAMMS_TAMPHUOC | On-Premises Data Gateway (Phase 1) |
| Kho | SharePoint Lists (KHO_*) | SharePoint Online connector |
| Vận Tải | SharePoint Lists (VT_*) | SharePoint Online connector |

## Steps
1. Power BI Desktop → connect SQL ACS qua gateway
2. Connect SharePoint Lists
3. Build 3 dashboards
4. Publish → Power BI Service
5. Set scheduled refresh (30 phút ACS, 1 giờ SharePoint)
6. Share với AD groups
7. Embed trong Teams (tùy chọn)

## Todo List
- [ ] Connect ACS SQL (sau Phase 1)
- [ ] Connect SharePoint Lists (sau Phase 2)
- [ ] Build Dashboard Cân Xe
- [ ] Build Dashboard Kho
- [ ] Build Dashboard Vận Tải
- [ ] Publish + schedule refresh
- [ ] Share với users
