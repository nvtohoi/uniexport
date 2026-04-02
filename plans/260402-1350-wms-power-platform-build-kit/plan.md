---
status: in-progress
created: 2026-04-02
updated: 2026-04-02
slug: wms-power-platform-build-kit
blockedBy: []
blocks: []
---

# WMS Power Platform Build Kit (v2 — ACS Integration)

Build kit for WMS on Power Platform. Module Cân xe tích hợp từ ACS AMMS IoT (SQL Server) thay vì build mới.

## Context

- **Brainstorm:** `plans/reports/brainstorm-260402-1350-wms-power-platform-design-review.md`
- **So sánh:** `plans/reports/brainstorm-260402-1445-so-sanh-power-apps-web-app-desktop.md`
- **ACS Analysis:** `plans/reports/brainstorm-260402-1521-acs-amms-data-integration.md`
- **User role:** Solution architect extending existing M365
- **Stack:** Power Apps Canvas + SharePoint Online + Power Automate + Power BI
- **Existing system:** ACS AMMS IoT (SQL Server `ACSAMMS_TAMPHUOC`) — quản lý cân xe
- **Scale:** 100+ users, 3 modules (Kho build mới, Van tai build mới, Can xe đọc từ ACS)
- **Timeline:** No fixed deadline

## Phases

| # | Phase | Status | Priority | Effort | Thay đổi v2 |
|---|-------|--------|----------|--------|-------------|
| 0 | [ACS Data Gateway Setup](phase-00-acs-data-gateway.md) | pending | P0 | Low | **MỚI** |
| 1 | [SharePoint Provisioning Scripts](phase-01-sharepoint-provisioning.md) | pending | P0 | Medium | Giảm (bỏ CAN lists) |
| 2 | [Module Kho Reference Docs](phase-02-module-kho.md) | pending | P0 | Medium | Không đổi |
| 3 | [Module Van Tai Reference Docs](phase-03-module-van-tai.md) | pending | P0 | Medium | Không đổi |
| 4 | [Module Cân Xe — ACS Integration](phase-04-module-can-xe.md) | pending | P1 | Low | **ĐỔI: đọc từ ACS, không build** |
| 5 | [Power Automate Flow Configs](phase-05-power-automate-flows.md) | pending | P0 | Medium | Thêm ACS sync flow, bỏ flow cân |
| 6 | [Power BI Dashboards](phase-06-power-bi-dashboards.md) | pending | P1 | Medium | **MỚI** — thay thế security-only |
| 7 | [Security & Deployment Guide](phase-07-security-deployment.md) | pending | P1 | Medium | Đổi số, thêm Gateway |

## Dependencies

```
Phase 0 (Gateway) ──→ Phase 4 (Cân xe ACS) ──→ Phase 6 (Power BI)
                  ──→ Phase 5 (Flows, ACS sync part)
Phase 1 (SharePoint) ──→ Phase 2 (Kho)
                     ──→ Phase 3 (Van tai)
                     ──→ Phase 5 (Flows, non-ACS part)
All phases ──→ Phase 7 (Security & Deploy)
```

- Phase 0 + Phase 1 can run in parallel (independent)
- Phase 2, 3, 4 can run in parallel after their dependencies
- Phase 6 (Power BI) after Phase 0 gateway is set up

## Critical Fixes (giữ nguyên)

1. Stock counter race condition → queue pattern (`KHO_GiaoDichLog`)
2. Phieu auto-number → `SYS_Counters` + Power Automate atomic increment
3. All delegation violations fixed (no `Year()`, no `CountRows` on SharePoint)
4. Monthly archival strategy for staying under 5000-item threshold
5. Proper security at SharePoint level, not just UI hiding

## Key Change: ACS Integration

Module Cân xe **không build mới** — dữ liệu cân đọc từ ACS AMMS IoT:
- ACS desktop app xử lý hardware (cân + camera + cảm biến)
- SQL Server `ACSAMMS_TAMPHUOC` chứa dữ liệu phiếu cân
- On-Premises Data Gateway kết nối SQL → Power BI + Power Automate
- Power BI dashboard cho báo cáo cân xe
- Power Automate sync dữ liệu cân → SharePoint (nếu cần hiển thị trong Power Apps)

## Output Structure

```
plans/260402-1350-wms-power-platform-build-kit/
├── plan.md
├── phase-00-acs-data-gateway.md          # MỚI: Gateway + SQL connection
├── phase-01-sharepoint-provisioning.md   # CẬP NHẬT: bỏ CAN lists
├── phase-02-module-kho.md                # Không đổi
├── phase-03-module-van-tai.md            # Không đổi
├── phase-04-module-can-xe.md             # CẬP NHẬT: ACS integration
├── phase-05-power-automate-flows.md      # CẬP NHẬT: thêm ACS sync
├── phase-06-power-bi-dashboards.md       # MỚI
└── phase-07-security-deployment.md       # Đổi số từ 06
```
