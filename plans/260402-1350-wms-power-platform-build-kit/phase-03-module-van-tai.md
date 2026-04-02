# Phase 3: Module Van Tai (Transportation) Reference Docs

## Context
- [Plan Overview](plan.md)
- [Phase 1 — Data Model](phase-01-sharepoint-provisioning.md)

## Overview
- **Priority:** P0
- **Status:** pending
- **Description:** Power Apps reference for Transportation module — 6 screens, vehicle/driver management, dispatch board, mobile driver UI.

## Key Insights
- Drivers use mobile (phone) — screen design must be phone-optimized
- Vehicle status (San sang/Dang chay/Bao tri) must update atomically with shipment status
- Date expiry alerts (dang kiem, bao hiem, GPLX) use DateDiff against Today()
- Dropdown filters must exclude expired/unavailable vehicles and drivers

## Screens

### S01: Bang Dieu Phoi Xe (Dispatch Board)
**Purpose:** Kanban-style view of shipments by status.

**Layout:**
- 3 column layout: Cho xac nhan | Dang chay | Hoan thanh
- Each card: So lenh, Bien so, Lai xe, Diem giao, thoi gian
- Tap card to view detail / update status

**Key Formulas:**

```
// Gallery "Cho xac nhan" — Items
Filter('VT_ChuyenHang',
    TrangThai.Value = "Cho xac nhan"
    And NgayKhoiHanh >= DateAdd(Today(), -7, TimeUnit.Days)
    And NgayKhoiHanh <= DateAdd(Today(), 30, TimeUnit.Days)
)
// NgayKhoiHanh and TrangThai are indexed = delegation-safe
// Limit to -7 days past to +30 days future
```

```
// Gallery "Dang chay" — Items
Filter('VT_ChuyenHang',
    TrangThai.Value = "Dang chay"
)
```

```
// Gallery "Hoan thanh" — Items (last 7 days only)
Filter('VT_ChuyenHang',
    TrangThai.Value = "Hoan thanh"
    And NgayKhoiHanh >= DateAdd(Today(), -7, TimeUnit.Days)
)
```

### S02: Tao Lenh Van Chuyen (Create Shipment Order)
**Purpose:** Dispatcher creates shipment, assigns vehicle + driver.

**Layout:**
- Form: NgayKhoiHanh, BienSoXe (dropdown), MaLaiXe (dropdown), DiemNhan, DiemGiao, KhachHang, HangHoaVanChuyen, KhoiLuong, CuocPhi
- So lenh auto-generated via counter flow

**Key Formulas:**

```
// Vehicle dropdown — only available + valid vehicles
Filter(colDanhMucXe,
    TrangThaiXe.Value = "San sang"
    And DangKiemHanDate > Today()
    And BaoHiemHanDate > Today()
)
// Uses local collection loaded in OnStart
```

```
// Driver dropdown — only active drivers with valid license
Filter(colLaiXe,
    TrangThai.Value = "Dang lam"
    And GPLX_HanDate > Today()
)
```

```
// Generate So Lenh
Set(gSoLenh,
    PowerAutomate_GetNextNumber.Run("LVC-" & Text(Year(Today()), "0000")).soPhieu
);
```

```
// Save + update vehicle status
Patch('VT_ChuyenHang', Defaults('VT_ChuyenHang'),
    {
        Title: gSoLenh,
        NgayKhoiHanh: dpNgayKhoiHanh.SelectedDate,
        BienSoXe: { Id: ddXe.Selected.ID, Value: ddXe.Selected.Title },
        MaLaiXe: { Id: ddLaiXe.Selected.ID, Value: ddLaiXe.Selected.Title },
        DiemNhan: txtDiemNhan.Text,
        DiemGiao: txtDiemGiao.Text,
        KhachHang: txtKhachHang.Text,
        HangHoaVanChuyen: txtHangHoa.Text,
        KhoiLuong: Value(txtKhoiLuong.Text),
        CuocPhi: Value(txtCuocPhi.Text),
        TrangThai: {Value: "Cho xac nhan"}
    }
);

// Set vehicle status to "Dang chay" when shipment confirmed
// (Done when status changes to "Dang chay", not on creation)
```

### S03: Theo Doi Chuyen Hang (Shipment Tracking)
**Purpose:** View shipment detail, update status, timeline.

**Layout:**
- Header: all shipment info (read-only for non-admin)
- Status timeline: Cho xac nhan → Dang chay → Hoan thanh
- Action buttons based on current status

**Key Formulas:**

```
// "Xac nhan khoi hanh" button (Dispatcher confirms)
Patch('VT_ChuyenHang',
    LookUp('VT_ChuyenHang', Title = gSelectedLenh),
    { TrangThai: {Value: "Dang chay"} }
);
// Update vehicle to "Dang chay"
Patch('VT_DanhMucXe',
    LookUp('VT_DanhMucXe', Title = gSelectedXe),
    { TrangThaiXe: {Value: "Dang chay"} }
);
```

```
// "Hoan thanh giao hang" button (Driver on mobile)
Patch('VT_ChuyenHang',
    LookUp('VT_ChuyenHang', Title = lblSoLenh.Text),
    {
        TrangThai: {Value: "Hoan thanh"},
        GioHoanThanhThucTe: Now()
    }
);
// Reset vehicle to "San sang"
Patch('VT_DanhMucXe',
    LookUp('VT_DanhMucXe', Title = lblBienSo.Text),
    { TrangThaiXe: {Value: "San sang"} }
);
// Notify dispatcher
PowerAutomate_ThongBaoHoanThanh.Run(
    lblSoLenh.Text,
    gCurrentUser.DisplayName
);
```

### S04: Quan Ly Xe (Vehicle Management)
**Purpose:** CRUD vehicles, expiry alerts.

**Layout:**
- Gallery with color-coded status badges
- Warning icons for expiring registration/insurance
- Edit form

**Key Formulas:**

```
// Expiry warning — Label Visible property
DateDiff(Today(), ThisItem.DangKiemHanDate, TimeUnit.Days) <= 30
Or DateDiff(Today(), ThisItem.BaoHiemHanDate, TimeUnit.Days) <= 30
```

```
// Expiry warning — Label Color property
If(
    DateDiff(Today(), ThisItem.DangKiemHanDate, TimeUnit.Days) <= 0
    Or DateDiff(Today(), ThisItem.BaoHiemHanDate, TimeUnit.Days) <= 0,
    Color.Red,        // Already expired
    If(
        DateDiff(Today(), ThisItem.DangKiemHanDate, TimeUnit.Days) <= 30
        Or DateDiff(Today(), ThisItem.BaoHiemHanDate, TimeUnit.Days) <= 30,
        Color.Orange,  // Expiring soon
        Color.Green    // OK
    )
)
```

### S05: Quan Ly Lai Xe (Driver Management)
**Purpose:** CRUD drivers, license expiry alerts.

**Layout:** Similar to S04 but for drivers. GPLX expiry warning.

**Key Formulas:**

```
// GPLX expiry check
If(
    DateDiff(Today(), ThisItem.GPLX_HanDate, TimeUnit.Days) <= 0,
    "HET HAN",
    If(
        DateDiff(Today(), ThisItem.GPLX_HanDate, TimeUnit.Days) <= 30,
        "Sap het han (" & DateDiff(Today(), ThisItem.GPLX_HanDate, TimeUnit.Days) & " ngay)",
        "Con han"
    )
)
```

### S06: Chi Phi Xe (Vehicle Expenses)
**Purpose:** Log fuel, toll, repair costs per vehicle.

**Layout:**
- Filter by vehicle, date range, expense type
- Form: BienSoXe (dropdown), NgayChi, LoaiChiPhi, SoTien, HinhAnh (camera), SoChuyenLienQuan (optional), GhiChu
- Summary totals per vehicle

**Key Formulas:**

```
// Filter expenses — delegation-safe
Filter('VT_ChiPhiXe',
    BienSoXe.Value = ddFilterXe.Selected.Title
    And NgayChi >= dpTuNgay.SelectedDate
    And NgayChi <= dpDenNgay.SelectedDate
)
// BienSoXe and NgayChi are indexed
```

```
// Camera capture for receipt
Set(varHinhAnh, Camera1.Photo);
// Save via Patch with HinhAnh field
```

## Navigation Flow

```
Dispatch Board (S01)
├── Tao Lenh (S02)
├── Theo Doi (S03) — also accessible from S01 card tap
├── Quan Ly Xe (S04)
├── Quan Ly Lai Xe (S05)
└── Chi Phi Xe (S06)
```

## Mobile Considerations

- Driver screens (S03 status update) should work on phone layout
- Use responsive containers or separate phone-optimized screen
- Camera integration for S06 receipt photos
- Large touch targets (min 44px) for field workers

## Todo List

- [ ] Write screen specs with wireframes
- [ ] Write all Power Fx formulas (corrected)
- [ ] Document mobile/phone layout considerations
- [ ] Document vehicle status state machine
- [ ] Document driver assignment validation rules

## Success Criteria

- Vehicle dropdown only shows valid, available vehicles
- Driver dropdown only shows active drivers with valid license
- Vehicle status updates atomically with shipment status
- Expiry alerts visible with color coding
- Mobile-friendly layout for driver screens
- Expense tracking with photo capture
