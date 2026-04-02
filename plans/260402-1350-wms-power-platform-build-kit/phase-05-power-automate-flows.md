# Phase 5: Power Automate Flow Configs

## Context
- [Plan Overview](plan.md)
- [Phase 1 — Data Model](phase-01-sharepoint-provisioning.md)

## Overview
- **Priority:** P0
- **Status:** pending
- **Description:** Step-by-step configuration for 8 Power Automate flows covering stock management, approvals, alerts, reporting, counters, and archival.

## Flow Summary

| # | Name | Trigger Type | Module | Critical Fix |
|---|------|-------------|--------|-------------|
| 1 | Stock Queue Processor | Scheduled (2 min) | KHO | Fixes race condition |
| 2 | Low Stock Alert | Scheduled (daily 7AM) | KHO | — |
| 3 | Phieu Nhap Approval | Automated (SP item changed) | KHO | — |
| 4 | Overload Alert | Instant (Power Apps) | CAN | — |
| 5 | Vehicle/Insurance Expiry | Scheduled (weekly Mon 8AM) | VT | — |
| 6 | Daily/Weekly Report | Scheduled (daily 6PM) | ALL | — |
| 7 | Counter Increment | Instant (Power Apps) | SYS | Fixes phieu numbering |
| 8 | Monthly Data Archival | Scheduled (1st of month 2AM) | ALL | Fixes delegation limit |

---

## Flow 1: Stock Queue Processor

**Purpose:** Process stock transactions from KHO_GiaoDichLog sequentially, preventing race conditions.

**Trigger:** Recurrence — Every 2 minutes

**Steps:**

```
1. Trigger: Recurrence (2 minutes)

2. Get items: SharePoint → Get items
   Site: [WMS Site]
   List: KHO_GiaoDichLog
   Filter Query: Processed eq 0
   Order By: Created asc
   Top Count: 50

3. Condition: length(body('Get_items')?['value']) > 0
   If No → Terminate (nothing to process)

4. Apply to each: body('Get_items')?['value']

   4a. Get item: SharePoint → Get item
       List: KHO_DanhMucHang
       Filter: Title eq '@{items('Apply_to_each')?['MaHang']}'
       (Use "Get items" with filter, take First())

   4b. Compose "NewStock":
       if(
         equals(items('Apply_to_each')?['LoaiGiaoDich']?['Value'], 'NHAP'),
         add(
           body('Get_item_DanhMuc')?['TonKhoHienTai'],
           items('Apply_to_each')?['SoLuong']
         ),
         sub(
           body('Get_item_DanhMuc')?['TonKhoHienTai'],
           items('Apply_to_each')?['SoLuong']
         )
       )

   4c. Condition: NewStock < 0
       If Yes → Set NewStock = 0, log error

   4d. Update item: SharePoint → Update item
       List: KHO_DanhMucHang
       Id: body('Get_item_DanhMuc')?['ID']
       TonKhoHienTai: outputs('NewStock')

   4e. Update item: SharePoint → Update item
       List: KHO_GiaoDichLog
       Id: items('Apply_to_each')?['ID']
       Processed: Yes
       ProcessedDate: utcNow()

   4f. Condition: outputs('NewStock') <= body('Get_item_DanhMuc')?['TonKhoToiThieu']
       If Yes →
         Post message to Teams channel:
         "⚠ CANH BAO: [TenHang] chi con [NewStock] [DonViTinh]"

5. (End Apply to each)
```

**Error handling:** Wrap step 4d-4e in a Scope with Configure Run After → set ErrorMessage on failure, mark Processed = Yes to prevent infinite retry.

---

## Flow 2: Low Stock Alert

**Purpose:** Daily email/Teams digest of all low-stock items.

**Trigger:** Recurrence — Daily at 7:00 AM (Vietnam timezone)

**Steps:**

```
1. Trigger: Recurrence (Daily, 7:00 AM, UTC+7)

2. Get items: SharePoint → Get items
   List: KHO_DanhMucHang
   Filter Query: TrangThai eq 'Dang dung'
   Top Count: 500

3. Filter array:
   From: body('Get_items')?['value']
   Where: item()?['TonKhoHienTai'] <= item()?['TonKhoToiThieu']

4. Condition: length(body('Filter_array')) > 0
   If No → Terminate

5. Create HTML table:
   From: body('Filter_array')
   Columns: MaHang (Title), TenHang, TonKhoHienTai, TonKhoToiThieu, DonViTinh

6. Post adaptive card to Teams channel:
   Channel: [Kho-Alerts channel]
   Title: "Bao cao hang sap het - " & formatDateTime(utcNow(), 'dd/MM/yyyy')
   Body: HTML table from step 5

7. (Optional) Send email v2:
   To: [Thu kho group email]
   Subject: same as step 6
   Body: HTML table
```

---

## Flow 3: Phieu Nhap Approval

**Purpose:** Route phieu nhap for supervisor approval when status changes to "Cho duyet".

**Trigger:** When an item is created or modified — List: KHO_PhieuNhap

**Steps:**

```
1. Trigger: When an item is created or modified
   List: KHO_PhieuNhap

2. Trigger condition (Settings → Trigger conditions):
   @equals(triggerBody()?['TrangThai']?['Value'], 'Cho duyet')

3. Get items: KHO_ChiTietNhap
   Filter: SoPhieuNhap eq triggerBody()?['ID']
   (Get line items for context)

4. Start and wait for an approval:
   Approval type: First to respond
   Title: "Duyet Phieu Nhap: " + triggerBody()?['Title']
   Assigned to: [Supervisor group members or specific emails]
   Details:
     "So phieu: @{triggerBody()?['Title']}
      Ngay nhap: @{triggerBody()?['NgayNhap']}
      NCC: @{triggerBody()?['NhaCungCap']?['Value']}
      Nguoi nhap: @{triggerBody()?['NguoiNhap']?['DisplayName']}
      So dong: @{length(body('Get_items_ChiTiet')?['value'])}
      [Chi tiet dong hang hoa se duoc liet ke o day]"

5. Condition: body('Start_and_wait_for_an_approval')?['outcome'] = 'Approve'

   If Approved:
   5a. Update item: KHO_PhieuNhap
       TrangThai: "Da duyet"
       NguoiDuyet: approver email
       NgayDuyet: utcNow()

   5b. Apply to each: ChiTietNhap items
       → Create item in KHO_GiaoDichLog:
         MaHang: current item MaHang.Value
         LoaiGiaoDich: "NHAP"
         SoLuong: current item SoLuong (or SoLuongThucNhan if filled)
         SoPhieuLienQuan: triggerBody()?['Title']
         Processed: No

   If Rejected:
   5c. Update item: KHO_PhieuNhap
       TrangThai: "Tu choi"

   5d. Send email to NguoiNhap:
       Subject: "Phieu nhap [Title] bi tu choi"
       Body: Rejection comments from approver
```

---

## Flow 4: Overload Alert

**Purpose:** Instant Teams notification when vehicle exceeds max load.

**Trigger:** Instant — Power Apps

**Inputs:**
- SoPhieuCan (text)
- BienSoXe (text)
- TrongTaiKG (text)

**Steps:**

```
1. Trigger: PowerApps (V2)
   Inputs: SoPhieuCan, BienSoXe, TrongTaiKG

2. Get item: CAN_PhieuCan
   Filter: Title eq triggerBody()?['SoPhieuCan']

3. Post adaptive card to Teams channel:
   Channel: [VanTai-Alerts channel]
   Title: "⚠ CANH BAO QUA TAI"
   Body:
     "Phieu can: @{triggerBody()?['SoPhieuCan']}
      Bien so: @{triggerBody()?['BienSoXe']}
      Trong tai hang: @{triggerBody()?['TrongTaiKG']} kg
      Tai trong toi da: @{body('Get_item')?['TaiTrongToiDaXe']} kg
      Vuot: @{sub(int(triggerBody()?['TrongTaiKG']), body('Get_item')?['TaiTrongToiDaXe'])} kg
      Thoi gian: @{formatDateTime(utcNow(), 'dd/MM/yyyy HH:mm')}"

4. (Optional) Send email to transport manager
```

---

## Flow 5: Vehicle/Insurance Expiry Alert

**Purpose:** Weekly check for vehicles/drivers with expiring documents.

**Trigger:** Recurrence — Weekly, Monday 8:00 AM

**Steps:**

```
1. Trigger: Recurrence (Weekly, Mon, 8:00 AM, UTC+7)

2. Get items: VT_DanhMucXe
   Filter: TrangThaiXe ne 'Ngung'
   Top Count: 500

3. Filter array "ExpiringVehicles":
   Where:
     item()?['DangKiemHanDate'] <= addDays(utcNow(), 30)
     OR item()?['BaoHiemHanDate'] <= addDays(utcNow(), 30)

4. Get items: VT_LaiXe
   Filter: TrangThai eq 'Dang lam'

5. Filter array "ExpiringDrivers":
   Where: item()?['GPLX_HanDate'] <= addDays(utcNow(), 30)

6. Condition: length(ExpiringVehicles) > 0 OR length(ExpiringDrivers) > 0
   If No → Terminate

7. Create HTML table for vehicles
8. Create HTML table for drivers
9. Post to Teams channel [VanTai-Alerts]
10. Send email to transport manager
```

---

## Flow 6: Daily/Weekly Report

**Purpose:** Generate summary report and send to management.

**Trigger:** Recurrence — Daily at 6:00 PM (end of business)

**Steps:**

```
1. Trigger: Recurrence (Daily, 6:00 PM, UTC+7)

2. Get items: KHO_GiaoDichLog
   Filter: Created ge '@{formatDateTime(startOfDay(utcNow()), 'yyyy-MM-ddTHH:mm:ssZ')}'

3. Get items: VT_ChuyenHang
   Filter: NgayKhoiHanh ge '@{formatDateTime(startOfDay(utcNow()), 'yyyy-MM-dd')}'

4. Get items: CAN_PhieuCan
   Filter: NgayCan ge '@{formatDateTime(startOfDay(utcNow()), 'yyyy-MM-ddTHH:mm:ssZ')}'

5. Compose summary:
   - Kho: X phieu nhap, Y phieu xuat, Z giao dich
   - Van tai: X chuyen hoan thanh, Y chuyen dang chay
   - Can xe: X phieu can, Y qua tai

6. (Optional) Create Excel file in SharePoint
   List: WMS_Reports document library
   Filename: "BaoCao_@{formatDateTime(utcNow(), 'yyyyMMdd')}.xlsx"

7. Post to Teams channel [Management]
8. Send email to directors
```

---

## Flow 7: Counter Increment (Atomic Phieu Numbering)

**Purpose:** Atomically increment counter and return formatted phieu number.

**Trigger:** Instant — Power Apps

**Inputs:**
- CounterName (text) — e.g., "PN-2026"

**Steps:**

```
1. Trigger: PowerApps (V2)
   Input: CounterName

2. Get items: SYS_Counters
   Filter: Title eq triggerBody()?['CounterName']
   Top Count: 1

3. Condition: length(body('Get_items')?['value']) = 0
   If Yes → Create counter with CurrentValue = 0

4. Compose "NewValue":
   add(first(body('Get_items')?['value'])?['CurrentValue'], 1)

5. Update item: SYS_Counters
   Id: first(body('Get_items')?['value'])?['ID']
   CurrentValue: outputs('NewValue')

6. Compose "FormattedNumber":
   concat(
     first(body('Get_items')?['value'])?['Prefix'],
     '-',
     formatNumber(first(body('Get_items')?['value'])?['NamHienTai'], '0000'),
     '-',
     formatNumber(outputs('NewValue'), '0000')
   )
   // Result: "PN-2026-0042"

7. Respond to PowerApp:
   Output: soPhieu = outputs('FormattedNumber')
```

**Note:** Power Automate processes instant flows sequentially per trigger, so concurrent calls from different users will NOT get the same number. This is the key fix for the duplicate numbering issue.

---

## Flow 8: Monthly Data Archival

**Purpose:** Move old records to archive lists, keeping active lists under 5000 items.

**Trigger:** Recurrence — 1st of month, 2:00 AM

**Steps:**

```
1. Trigger: Recurrence (Monthly, Day 1, 2:00 AM, UTC+7)

2. Compose "ArchiveDate":
   addDays(startOfMonth(utcNow()), -365)
   // Archive records older than 12 months

3. For each archivable list:
   (KHO_PhieuNhap, KHO_ChiTietNhap, KHO_PhieuXuat, KHO_ChiTietXuat,
    VT_ChuyenHang, VT_ChiPhiXe, CAN_PhieuCan)

   3a. Get items from source list:
       Filter: Created lt '@{outputs('ArchiveDate')}'
       Top Count: 100 (batch size — SharePoint throttle protection)

   3b. Apply to each:
       → Create item in [ListName]_Archive (copy all fields)
       → Delete item from source list
       → Pause 200ms (throttle protection)

   3c. Repeat 3a-3b until no more items returned
       (Use a Do Until loop with condition: length = 0)

4. Also archive processed KHO_GiaoDichLog entries:
   Filter: Processed eq 1 AND Created lt addDays(utcNow(), -30)
   (Keep only 30 days of processed transactions)

5. Post summary to Teams:
   "Archival complete: X records moved to archive lists"

6. (Optional) Send email report to admin
```

**Important:** Archive lists have same columns as source but NO lookup columns (store values as text). This avoids broken lookups when source records are deleted.

---

## Shared Patterns

### Error Handling Template
```
Scope "Try":
  [main actions]

Scope "Catch" (Configure run after: has failed, has timed out):
  Create item: AUDIT_Log
    Action: "Error"
    Module: [module]
    Details: concat(result('Try')?['error']?['message'])

  Post to Teams: "[Flow Name] failed: [error details]"
```

### Throttle Protection
- Add `Start-Sleep` of 200ms between SharePoint write operations in loops
- Batch size: max 100 items per loop iteration
- Use "Retry policy" on SharePoint actions: Fixed interval, 3 retries, 10s interval

## Todo List

- [ ] Build Flow 1: Stock Queue Processor
- [ ] Build Flow 2: Low Stock Alert
- [ ] Build Flow 3: Phieu Nhap Approval
- [ ] Build Flow 4: Overload Alert
- [ ] Build Flow 5: Vehicle/Insurance Expiry
- [ ] Build Flow 6: Daily/Weekly Report
- [ ] Build Flow 7: Counter Increment
- [ ] Build Flow 8: Monthly Data Archival
- [ ] Test all flows with sample data
- [ ] Configure error handling on all flows
- [ ] Set up Teams channels for notifications

## Success Criteria

- Flow 1 processes queue without race conditions
- Flow 3 approval works end-to-end (submit → approve → stock updated)
- Flow 7 returns unique numbers under concurrent usage
- Flow 8 keeps active lists under 5000 items
- All flows have error handling and Teams notification on failure
- No flow exceeds Power Automate daily action limits
