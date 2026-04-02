---
status: pending
created: 2026-04-02
slug: wms-power-platform-build-kit
blockedBy: []
blocks: []
---

# WMS Power Platform Build Kit

Build kit for a 3-module Warehouse Management System on Microsoft Power Platform (SharePoint-only, patched approach).

## Context

- **Brainstorm:** `plans/reports/brainstorm-260402-1350-wms-power-platform-design-review.md`
- **User role:** Solution architect extending existing M365
- **Stack:** Power Apps Canvas + SharePoint Online + Power Automate
- **Scale:** 100+ users, 3 modules (Kho, Van tai, Can xe)
- **Timeline:** No fixed deadline

## Phases

| # | Phase | Status | Priority | Effort |
|---|-------|--------|----------|--------|
| 1 | [SharePoint Provisioning Scripts](phase-01-sharepoint-provisioning.md) | pending | P0 | High |
| 2 | [Module Kho Reference Docs](phase-02-module-kho.md) | pending | P0 | Medium |
| 3 | [Module Van Tai Reference Docs](phase-03-module-van-tai.md) | pending | P0 | Medium |
| 4 | [Module Can Xe Reference Docs](phase-04-module-can-xe.md) | pending | P0 | Medium |
| 5 | [Power Automate Flow Configs](phase-05-power-automate-flows.md) | pending | P0 | High |
| 6 | [Security & Deployment Guide](phase-06-security-deployment.md) | pending | P1 | Medium |

## Dependencies

- Phase 1 (SharePoint) must be built first — all other phases reference its data model
- Phases 2-4 (modules) are independent of each other, can be built in parallel
- Phase 5 (flows) depends on Phase 1 data model but can be written alongside Phases 2-4
- Phase 6 (security) depends on all prior phases

## Critical Fixes Incorporated

1. Stock counter race condition → queue pattern (`KHO_GiaoDichLog`)
2. Phieu auto-number → `SYS_Counters` + Power Automate atomic increment
3. All delegation violations fixed (no `Year()`, no `CountRows` on SharePoint)
4. Monthly archival strategy for staying under 5000-item threshold
5. Proper security at SharePoint level, not just UI hiding

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
├── provision-sharepoint-site.ps1        # Main provisioning script
├── provision-module-kho-lists.ps1       # Kho module lists
├── provision-module-vantai-lists.ps1    # Van tai module lists
├── provision-module-canxe-lists.ps1     # Can xe module lists
├── provision-system-lists.ps1           # System lists (Counters, Audit, Archive)
└── provision-indexes-and-views.ps1      # Indexes + default views
```
