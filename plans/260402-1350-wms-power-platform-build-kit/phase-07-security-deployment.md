# Phase 6: Security & Deployment Guide

## Context
- [Plan Overview](plan.md)
- [Phase 1 — Data Model](phase-01-sharepoint-provisioning.md)

## Overview
- **Priority:** P1
- **Status:** pending
- **Description:** Azure AD groups, SharePoint permissions, Power Apps role checking, deployment checklist, UAT test scenarios.

## Key Insights
- Security MUST be enforced at SharePoint level, not just Power Apps UI
- Power Apps button hiding is UI-only — data accessible via SharePoint if permissions wrong
- Use Azure AD Security Groups (not M365 Groups) for permission assignment
- Office365Groups.ListGroupsV2() is slow — use a cached role lookup instead

## Azure AD Group Setup

### Groups to Create

| Group Name | Type | Members | Purpose |
|-----------|------|---------|---------|
| App-WMS-Admin | Security | IT admins, Warehouse manager | Full control all modules |
| App-WMS-Supervisor | Security | Team leads, Shift supervisors | Approve/manage, no delete |
| App-WMS-Operator-Kho | Security | Warehouse staff | Create phieu, view stock |
| App-WMS-Operator-VT | Security | Dispatchers, Drivers | Create shipments, update status |
| App-WMS-Operator-CAN | Security | Scale operators | Create/complete phieu can |
| App-WMS-Director | Security | Directors, C-level | Read-only all modules |

**Note:** Split Operator into 3 sub-groups by module. Not all operators need all apps.

### SharePoint Permission Levels

| SharePoint Permission | Capabilities | Assigned Groups |
|----------------------|-------------|----------------|
| Full Control | Everything | App-WMS-Admin |
| WMS-Contribute | Add, Edit items. No delete. | App-WMS-Supervisor |
| WMS-Operator | Add, Edit own items only | App-WMS-Operator-* |
| Read | View only | App-WMS-Director |

**Custom Permission Level "WMS-Contribute":**
- List Permissions: Add Items, Edit Items, View Items, View Versions, Open Items
- NOT: Delete Items, Manage Lists, Override Checkouts

**Custom Permission Level "WMS-Operator":**
- Same as WMS-Contribute
- Site Settings → Advanced → "Create items and edit items that were created by the user" = ON (if using item-level permissions)

### Permission Assignment per List

| List | Admin | Supervisor | Operator | Director |
|------|-------|-----------|----------|----------|
| KHO_DanhMucHang | Full | WMS-Contribute | Read | Read |
| KHO_PhieuNhap | Full | WMS-Contribute | WMS-Operator | Read |
| KHO_ChiTietNhap | Full | WMS-Contribute | WMS-Operator | Read |
| KHO_PhieuXuat | Full | WMS-Contribute | WMS-Operator | Read |
| KHO_ChiTietXuat | Full | WMS-Contribute | WMS-Operator | Read |
| VT_DanhMucXe | Full | WMS-Contribute | Read | Read |
| VT_LaiXe | Full | WMS-Contribute | Read | Read |
| VT_ChuyenHang | Full | WMS-Contribute | WMS-Operator | Read |
| VT_ChiPhiXe | Full | WMS-Contribute | WMS-Operator | Read |
| CAN_PhieuCan | Full | WMS-Contribute | WMS-Operator | Read |
| CAN_TramCan | Full | WMS-Contribute | Read | Read |
| SYS_Counters | Full | Read | Read | Read |
| AUDIT_Log | Full | Read | Read | Read |
| KHO_GiaoDichLog | Full | Read | Read | Read |

## Power Apps Role Checking

### Recommended Approach: Role Lookup List

Instead of slow `Office365Groups.ListGroupsV2()`, create a simple `SYS_UserRoles` list:

| Column | Type | Notes |
|--------|------|-------|
| Title | Single line | User email |
| Role | Choice | Admin / Supervisor / Operator / Director |
| Module | Choice (multi) | KHO / VT / CAN / ALL |

**App.OnStart formula:**

```
// Fast role lookup — single SharePoint query
Set(gCurrentUser, Office365Users.MyProfile());

Set(gUserRole,
    LookUp('SYS_UserRoles',
        Title = Lower(gCurrentUser.Mail)
    )
);

Set(gRole,
    If(!IsBlank(gUserRole),
        gUserRole.Role.Value,
        "Operator"  // Default fallback
    )
);

Set(gModules,
    If(!IsBlank(gUserRole),
        gUserRole.Module,
        {Value: "ALL"}  // Or restrict based on which app
    )
);

// Convenience booleans
Set(gIsAdmin, gRole = "Admin");
Set(gIsSupervisor, gRole = "Admin" Or gRole = "Supervisor");
Set(gIsDirector, gRole = "Director");
```

### UI Visibility Rules

```
// Delete button — Admin only
btnXoa.Visible = gIsAdmin

// Approve button — Admin + Supervisor
btnDuyet.Visible = gIsSupervisor

// Create button — Not Director
btnTaoMoi.Visible = Not(gIsDirector)

// Settings screen — Admin only
btnCaiDat.Visible = gIsAdmin

// Export report — Admin + Supervisor + Director
btnXuatBaoCao.Visible = gIsAdmin Or gIsSupervisor Or gIsDirector
```

### Form Mode by Role

```
// Form mode — read-only for Director
If(gIsDirector,
    FormMode.View,
    If(gIsAdmin Or gIsSupervisor,
        FormMode.Edit,
        FormMode.New  // Operators can create but not edit others' items
    )
)
```

## Deployment Checklist

### Pre-Deployment (Infrastructure)

- [ ] 1. Create dedicated SharePoint Communication Site
  - URL: `https://[tenant].sharepoint.com/sites/WMS`
  - Owner: IT Admin
- [ ] 2. Run PnP provisioning scripts (Phase 1)
  - `provision-sharepoint-site.ps1`
  - Verify all lists created with correct columns
- [ ] 3. Create Azure AD Security Groups (6 groups)
  - Via Azure Portal → Azure Active Directory → Groups
- [ ] 4. Configure SharePoint permissions
  - Create custom permission levels (WMS-Contribute, WMS-Operator)
  - Assign groups to lists per matrix above
  - Break inheritance on lists that need different permissions
- [ ] 5. Create SYS_UserRoles entries
  - Add all admin/supervisor users manually
  - Operators default to "Operator" if not in list
- [ ] 6. Seed SYS_Counters data
  - Run `seed-counter-data.ps1`
- [ ] 7. Enable versioning on all lists
  - List Settings → Versioning → Create a version each time an item is edited

### App Build (Power Apps Studio)

- [ ] 8. Build App KHO (7 screens per Phase 2)
  - Connect to SharePoint site
  - Implement all formulas
  - Add Power Automate flow connections
- [ ] 9. Build App VT (6 screens per Phase 3)
- [ ] 10. Build App CAN (5 screens per Phase 4)
- [ ] 11. Build all Power Automate flows (Phase 5)
  - Test each flow individually
  - Connect flows to apps

### Testing (UAT)

- [ ] 12. Internal testing (IT team, 2-3 people)
  - Test all CRUD operations
  - Test approval workflow end-to-end
  - Test overload alert
  - Test stock queue processing
  - Test counter uniqueness (concurrent phieu creation)
- [ ] 13. Pilot testing (5-10 real users)
  - 2 warehouse staff (Kho module)
  - 2 dispatchers + 1 driver (VT module)
  - 2 scale operators (CAN module)
  - 1 supervisor (approval testing)
  - 1 director (read-only verification)
- [ ] 14. Fix issues from pilot feedback
- [ ] 15. Performance testing
  - Load 1000+ sample records in key lists
  - Verify delegation works (galleries show correct data)
  - Verify app load time < 5 seconds

### Go-Live

- [ ] 16. Share Power Apps with AD groups
  - App KHO → App-WMS-Admin, App-WMS-Supervisor, App-WMS-Operator-Kho, App-WMS-Director
  - App VT → App-WMS-Admin, App-WMS-Supervisor, App-WMS-Operator-VT, App-WMS-Director
  - App CAN → App-WMS-Admin, App-WMS-Supervisor, App-WMS-Operator-CAN, App-WMS-Director
- [ ] 17. Add apps to Microsoft Teams
  - Create "WMS" Teams team or channel
  - Add apps as tabs
- [ ] 18. User training
  - 1-hour session per module per role
  - Create quick-reference guide (1-pager per module)
- [ ] 19. Go-live announcement
  - Email + Teams announcement
  - Include app links, support contact
- [ ] 20. Monitor first week
  - Check Power Automate flow run history daily
  - Monitor AUDIT_Log for anomalies
  - Respond to user issues within 4 hours

### Post Go-Live

- [ ] 21. Verify Flow 8 archival runs correctly (after 1 month)
- [ ] 22. Review Power Platform analytics
  - App usage, active users, error rates
- [ ] 23. Collect user feedback (after 2 weeks)
- [ ] 24. Plan Phase 2 enhancements
  - Scale hardware CSV integration
  - Power BI dashboards
  - Offline support for drivers

## UAT Test Scenarios

### Kho Module

| # | Scenario | Steps | Expected Result |
|---|---------|-------|----------------|
| K1 | Create phieu nhap | S02: Fill form, add 3 line items, save as draft | Phieu saved with status "Nhap", unique So Phieu |
| K2 | Submit for approval | Change status to "Cho duyet" | Approval notification in Teams |
| K3 | Approve phieu | Supervisor approves in Teams/app | Status → "Da duyet", stock queue entries created |
| K4 | Stock updated | Wait 2 min for queue processing | DanhMucHang.TonKhoHienTai increased |
| K5 | Low stock alert | Set TonKhoToiThieu > TonKhoHienTai | Teams alert posted |
| K6 | Xuat with insufficient stock | Try to xuat more than available | Error notification shown |
| K7 | Concurrent phieu creation | 2 users create phieu simultaneously | Different So Phieu numbers |

### Van Tai Module

| # | Scenario | Steps | Expected Result |
|---|---------|-------|----------------|
| V1 | Create shipment | S02: Select vehicle + driver, fill route | Order created, vehicle still "San sang" |
| V2 | Confirm departure | Dispatcher confirms | Vehicle status → "Dang chay" |
| V3 | Driver completes | Driver taps "Hoan thanh" on mobile | Vehicle → "San sang", Teams notification |
| V4 | Expired vehicle hidden | Vehicle with past DangKiemHanDate | Not shown in dropdown |
| V5 | Expiry alert | Vehicle with ≤30 days to expiry | Warning icon + weekly email |

### Can Xe Module

| # | Scenario | Steps | Expected Result |
|---|---------|-------|----------------|
| C1 | Weigh-in | S01: Enter vehicle, weight, save | Phieu created, status "Cho can ra" |
| C2 | Weigh-out | S02: Find phieu, enter CanRa | TrongTai calculated, status "Hoan thanh" |
| C3 | Overload detected | CanRa - CanVao > TaiTrongToiDa | Red warning, Teams alert sent |
| C4 | Walk-in vehicle | Toggle to manual entry | Phieu created without vehicle lookup |
| C5 | Search phieu | Search by So Phieu or Bien So | Correct results returned |

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| User bypasses Power Apps, edits SharePoint directly | High | SharePoint permissions enforce rules. Train users. |
| SYS_UserRoles not maintained | Medium | Default to "Operator". Admin reviews monthly. |
| Power Automate flow fails silently | High | Error handling posts to Teams. Monitor flow run history. |
| Too many flows hit daily action limit | Medium | Optimize loops, batch operations. Monitor usage. |

## Security Considerations

- **No secrets in scripts** — use interactive auth or managed identity
- **Audit trail** — SharePoint versioning + AUDIT_Log for custom events
- **Data residency** — SharePoint Online data stays in M365 tenant region
- **Backup** — SharePoint has built-in recycle bin (93 days). For long-term, use SharePoint backup solutions.
- **GDPR** — Person columns contain user data. Document data processing in privacy policy.
