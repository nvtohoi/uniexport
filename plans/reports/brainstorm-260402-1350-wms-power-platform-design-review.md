# Brainstorm: WMS Power Platform Design Review

**Date:** 2026-04-02
**Role:** Solution architect, extending existing M365
**Approach:** SharePoint-only (patched), Power Apps Studio no-code
**Timeline:** No fixed deadline, quality over speed

---

## Problem Statement

Design review of 3-module WMS system (Kho, Van tai, Can xe) on Power Platform. 100+ users, SharePoint Lists backend, Power Apps Canvas frontend, Power Automate workflows.

## Critical Issues Identified

### 1. Race Condition on TonKhoHienTai
- Flow pattern: Read → Calculate → Update has no locking
- Concurrent nhap/xuat corrupts stock
- **Fix:** Transaction log queue (`KHO_GiaoDichLog`), scheduled flow processes sequentially

### 2. Phieu Auto-Number uses CountRows (non-delegable + race condition)
- CountRows only counts first 500/2000 rows
- Concurrent users get duplicate numbers
- **Fix:** `SYS_Counters` list, Power Automate atomic increment flow

### 3. Delegation Violations
- `Year()` in Filter = non-delegable
- `CountRows` = non-delegable
- Active lists will exceed 2000 rows in 1-2 months
- **Fix:** Date-range filters, indexed columns, monthly archival to `*_Archive` lists

### 4. Scale Hardware Integration Gap
- Design assumes manual entry
- Power Apps Canvas cannot read serial ports
- **Recommendation:** Start manual (Phase 1), add CSV import via Power Automate (Phase 2)

## High-Risk Issues

- SharePoint vs Dataverse: staying SharePoint-only with workarounds (archival, queue pattern)
- Cost: segment users by role, not all need all 3 apps. Per App plan for occasional users
- Security: Office365Groups.ListGroupsV2() is slow/fragile. Set proper SharePoint permissions, not just UI hiding
- No offline support for field workers

## Design Strengths

- Clean data model naming (prefix per module)
- Proper header/detail pattern
- Approval workflow design solid
- Role matrix well thought out
- Deployment checklist practical

## New Lists Required

- `KHO_GiaoDichLog` — stock transaction queue
- `SYS_Counters` — atomic counter for phieu numbering
- `AUDIT_Log` — custom audit trail
- `*_Archive` lists — for each transactional table

## Decision: Full Build Kit

User wants:
1. PnP PowerShell scripts — provision SharePoint site, all lists, columns, indexes, choices
2. Organized markdown docs — formulas, flow configs, screen specs
3. Power Automate flow step-by-step configs
4. All critical fixes incorporated into the build kit

## Unresolved Questions

1. Which scale hardware vendor/model will be used?
2. Exact user count breakdown by role (Admin/Supervisor/Operator/Director)?
3. Existing SharePoint site URL to extend, or create new?
4. Are there existing NhaCungCap/KhachHang lists to integrate with?
5. Which Teams channels for notifications?
