---
status: in-progress
created: 2026-04-02
updated: 2026-04-02
slug: wms-power-platform-build-kit
blockedBy: []
blocks: []
---

# WMS Power Platform Build Kit (v4 — Final)

Kho + Vận tải build mới trên Power Apps. Cân xe giữ ACS AMMS IoT, đọc data từ SQL Server.

## Context

- **Reports:** `plans/reports/brainstorm-260402-*.md`
- **User role:** Solution architect, full dev team (3+), extending existing M365
- **Stack:** Power Apps Canvas + SharePoint Online + Power Automate + Power BI
- **Scale:** 100+ users, 3 modules
- **Timeline:** No fixed deadline

## Hệ thống hiện có

- **Cân xe:** ACS AMMS IoT (desktop app tại trạm cân)
  - DB: SQL Server `ACSAMMS_TAMPHUOC`
  - 3 camera + 2 cảm biến + đọc cân realtime
  - Dữ liệu sync về server SQL
  - Web portal có sẵn báo cáo (Inbound/Outbound/Delivery)
- **Kho:** Chưa có → build mới
- **Vận tải:** Chưa có → build mới

## Phases

| # | Phase | Status | Priority | Effort |
|---|-------|--------|----------|--------|
| 1 | [Data Gateway + ACS Connection](phase-01-data-gateway.md) | pending | P0 | Low |
| 2 | [SharePoint Provisioning](phase-02-sharepoint-provisioning.md) | pending | P0 | Medium |
| 3 | [Module Kho (Power Apps)](phase-03-module-kho.md) | pending | P0 | Medium |
| 4 | [Module Vận Tải (Power Apps)](phase-04-module-van-tai.md) | pending | P0 | Medium |
| 5 | [Power Automate Flows](phase-05-power-automate-flows.md) | pending | P0 | Medium |
| 6 | [Power BI Dashboards](phase-06-power-bi-dashboards.md) | pending | P1 | Medium |
| 7 | [Security & Deployment](phase-07-security-deployment.md) | pending | P1 | Medium |

## Dependencies

```
Phase 1 (Gateway) ──→ Phase 6 (Power BI — cân xe data)
Phase 2 (SharePoint) ──→ Phase 3 (Kho)
                     ──→ Phase 4 (Vận tải)
                     ──→ Phase 5 (Flows)
Phase 1 + 2 can run in parallel
Phase 3 + 4 can run in parallel
All phases ──→ Phase 7 (Security & Deploy)
```

## Scope rõ ràng

| Module | Approach | Build gì |
|--------|----------|---------|
| **Cân xe** | Giữ ACS AMMS IoT | Gateway + Power BI dashboard đọc SQL |
| **Kho** | Build mới | 7 screens Power Apps + SharePoint Lists + Flows |
| **Vận tải** | Build mới | 6 screens Power Apps + SharePoint Lists + Flows |
| **Báo cáo** | Power BI | 3 dashboards (Cân từ SQL, Kho + VT từ SharePoint) |

## Critical Fixes (cho Kho + VT)

1. Stock race condition → queue pattern (`KHO_GiaoDichLog`)
2. Phieu auto-number → `SYS_Counters` + Power Automate atomic increment
3. Delegation-safe queries (no `Year()`, no `CountRows` on SP)
4. Monthly archival → keep lists under 5000 items
5. Security at SharePoint level, not just UI hiding
