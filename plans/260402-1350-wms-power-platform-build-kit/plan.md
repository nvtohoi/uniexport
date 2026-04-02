---
status: in-progress
created: 2026-04-02
updated: 2026-04-02
slug: wms-power-platform-build-kit
blockedBy: []
blocks: []
---

# WMS Power Platform Build Kit (v3 — Full Build)

Build kit cho hệ thống WMS 3 modules trên Power Platform. Tự build toàn bộ, thay thế ACS.

## Context

- **Reports:** `plans/reports/brainstorm-260402-*.md`
- **User role:** Solution architect, full dev team (3+), extending existing M365
- **Stack:** Power Apps Canvas + SharePoint Online + Power Automate + Power BI
- **Scale:** 100+ users, 3 modules
- **Timeline:** No fixed deadline
- **Quyết định:** Bỏ ACS AMMS IoT (đang thuê), tự build module Cân xe trên Power Apps
- **Hardware cân:** Sẽ cần giải pháp kết nối cân điện tử (manual entry MVP, sau đó CSV/API)

## Phases

| # | Phase | Status | Priority | Effort |
|---|-------|--------|----------|--------|
| 1 | [SharePoint Provisioning Scripts](phase-01-sharepoint-provisioning.md) | pending | P0 | High |
| 2 | [Module Kho Reference Docs](phase-02-module-kho.md) | pending | P0 | Medium |
| 3 | [Module Van Tai Reference Docs](phase-03-module-van-tai.md) | pending | P0 | Medium |
| 4 | [Module Can Xe Reference Docs](phase-04-module-can-xe.md) | pending | P0 | High |
| 5 | [Power Automate Flow Configs](phase-05-power-automate-flows.md) | pending | P0 | High |
| 6 | [Security & Deployment Guide](phase-06-security-deployment.md) | pending | P1 | Medium |

## Dependencies

- Phase 1 (SharePoint) must be built first — all other phases reference its data model
- Phases 2, 3, 4 are independent, can be built in parallel
- Phase 5 (flows) depends on Phase 1 data model
- Phase 6 (security) depends on all prior phases

## Critical Fixes

1. Stock counter race condition → queue pattern (`KHO_GiaoDichLog`)
2. Phieu auto-number → `SYS_Counters` + Power Automate atomic increment
3. All delegation violations fixed (no `Year()`, no `CountRows` on SharePoint)
4. Monthly archival strategy for staying under 5000-item threshold
5. Proper security at SharePoint level, not just UI hiding

## Cân xe Strategy (thay thế ACS)

- **Phase 1 (MVP):** Nhập tay số cân vào Power Apps + chụp ảnh xe
- **Phase 2 (sau):** Scale software xuất CSV → Power Automate import tự động
- **Phase 3 (nâng cao):** Desktop agent đọc COM port → WebSocket → Power Apps realtime
- Data model tham khảo từ ACS AMMS IoT (đã phân tích giao diện)

## Insights từ ACS (áp dụng vào thiết kế)

Từ phân tích ACS desktop + web portal:
- Hỗ trợ 2 lần cân (cân vào + cân ra) trên cùng 1 phiếu
- 3 camera giám sát (biển số + cân vào + cân ra)
- Phân loại: Cân nhập / Cân xuất / Tự động
- Báo cáo: theo KH, hàng hóa, xe, tổng hợp nhập xuất
- Fields: Số phiếu, Biển số, Rơ mooc, KH/NCC, Hàng hóa, Kho, Nhà vận tải, Lái xe

## Output Structure

```
plans/260402-1350-wms-power-platform-build-kit/
├── plan.md
├── phase-01-sharepoint-provisioning.md
├── phase-02-module-kho.md
├── phase-03-module-van-tai.md
├── phase-04-module-can-xe.md
├── phase-05-power-automate-flows.md
└── phase-06-security-deployment.md

scripts/
├── provision-sharepoint-site.ps1
├── provision-module-kho-lists.ps1
├── provision-module-vantai-lists.ps1
├── provision-module-canxe-lists.ps1
├── provision-system-lists.ps1
└── provision-indexes-and-views.ps1
```
