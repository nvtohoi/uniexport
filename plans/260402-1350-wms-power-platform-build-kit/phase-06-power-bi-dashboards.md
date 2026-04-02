# Phase 6: Power BI Dashboards

## Context
- [Plan Overview](plan.md)
- [Phase 0 — ACS Gateway](phase-00-acs-data-gateway.md)

## Overview
- **Priority:** P1
- **Status:** pending
- **Description:** Power BI dashboards kết nối trực tiếp SQL Server ACS + SharePoint Lists cho báo cáo phức tạp.

## Dashboards

### Dashboard 1: Cân Xe (từ ACS SQL)
- Tổng phiếu cân theo ngày/tuần/tháng
- Tổng trọng lượng theo hàng hóa, khách hàng
- Top 10 khách hàng theo khối lượng
- Biểu đồ xu hướng (line chart)
- Filter: ngày, kho, hàng hóa, KH/NCC

### Dashboard 2: Kho (từ SharePoint)
- Tồn kho hiện tại vs ngưỡng tối thiểu
- Nhập/Xuất theo thời gian
- Top hàng hóa xuất nhiều nhất
- Cảnh báo hàng sắp hết

### Dashboard 3: Vận Tải (từ SharePoint)
- Chuyến hàng theo trạng thái
- Chi phí xe theo tháng
- Tỷ lệ hoàn thành đúng hạn
- Cảnh báo hết hạn đăng kiểm/bảo hiểm

## Data Sources

| Dashboard | Source | Connection |
|-----------|--------|-----------|
| Cân Xe | SQL Server ACSAMMS_TAMPHUOC | Via On-Premises Data Gateway |
| Kho | SharePoint Lists (KHO_*) | SharePoint Online connector |
| Vận Tải | SharePoint Lists (VT_*) | SharePoint Online connector |

## Implementation Steps

1. Cài Power BI Desktop
2. Connect SQL Server ACS qua gateway → import tables phiếu cân
3. Connect SharePoint Lists → import KHO + VT data
4. Build 3 dashboards với visuals
5. Publish lên Power BI Service
6. Set scheduled refresh (mỗi 30 phút cho ACS, 1 giờ cho SharePoint)
7. Share với AD groups (Director, Supervisor, Admin)
8. Embed trong Power Apps hoặc Teams (tùy chọn)

## Todo List

- [ ] Power BI Desktop cài đặt
- [ ] Kết nối ACS SQL qua gateway
- [ ] Kết nối SharePoint Lists
- [ ] Build Dashboard Cân Xe
- [ ] Build Dashboard Kho
- [ ] Build Dashboard Vận Tải
- [ ] Publish + set refresh schedule
- [ ] Share với users

## Success Criteria

- Dashboards tự động refresh, dữ liệu không quá 30 phút tuổi
- Ban giám đốc xem được từ browser/mobile
- Filter interactive hoạt động tốt
