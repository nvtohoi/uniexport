# Phase 2: Module Kho (Warehouse) Reference Docs

## Context
- [Plan Overview](plan.md)
- [Phase 1 — Data Model](phase-01-sharepoint-provisioning.md)
- [Brainstorm Report](../reports/brainstorm-260402-1350-wms-power-platform-design-review.md)

## Overview
- **Priority:** P0
- **Status:** pending
- **Description:** Complete Power Apps reference docs for Warehouse module — 7 screens with corrected Power Fx formulas (delegation-safe), screen layouts, navigation flow.

## Key Insights
- All `CountRows` replaced with SYS_Counters flow
- All `Year()` filters replaced with date-range comparisons
- Stock updates go through KHO_GiaoDichLog queue, not direct Patch
- `SortByColumns` only on indexed columns or on local collections
- Use `Concurrent()` in OnStart for parallel data loading
- Use `Named Formulas` (App.Formulas) for reusable expressions

## Screens

### S01: Dashboard Ton Kho
**Purpose:** Overview of current stock levels, low-stock alerts, recent activity.

**Layout:**
- Top bar: App title, user name, role badge, refresh button
- Left panel: Gallery of low-stock items (TonKhoHienTai <= TonKhoToiThieu), sorted ascending
- Right panel: Summary cards (total items, total low-stock, last sync time)
- Bottom: Recent 10 transactions from KHO_GiaoDichLog

**Key Formulas:**

```
// App.OnStart — Load data concurrently
Concurrent(
    ClearCollect(colHangHoa,
        Filter('KHO_DanhMucHang', TrangThai.Value = "Dang dung")
    ),
    ClearCollect(colNhaCungCap,
        Filter('KHO_NhaCungCap', TrangThai.Value = "Hoat dong")
    ),
    Set(gCurrentUser, Office365Users.MyProfile()),
    ClearCollect(colKhachHang,
        Filter('KHO_KhachHang', TrangThai.Value = "Hoat dong")
    )
);

// Role detection (see Phase 6 for full security)
Set(gRole, "Operator"); // Default, overridden by role check flow
```

```
// Gallery Low Stock — Items property
SortByColumns(
    Filter(colHangHoa,
        TonKhoHienTai <= TonKhoToiThieu
    ),
    "TonKhoHienTai",
    SortOrder.Ascending
)
// NOTE: This sorts a local collection (colHangHoa), NOT SharePoint directly.
// Safe from delegation issues.
```

```
// Card: Total Low Stock Items
CountRows(
    Filter(colHangHoa, TonKhoHienTai <= TonKhoToiThieu)
)
// CountRows on local collection = OK. CountRows on SharePoint = NOT OK.
```

### S02: Nhap Phieu Nhap (Create Inbound Receipt)
**Purpose:** Create new phieu nhap with header + line items.

**Layout:**
- Header form: NgayNhap (date picker), NhaCungCap (dropdown from colNhaCungCap), SoHoaDon (text), GhiChu
- Line items gallery: MaHang (dropdown), SoLuong, DonGiaNhap, ThanhTien (auto-calc label)
- Buttons: "Them dong" (add line), "Luu nhap" (save as draft), "Gui duyet" (submit for approval)
- Auto-generated So Phieu displayed at top

**Key Formulas:**

```
// Generate So Phieu via Power Automate counter flow
// Call this when screen loads for new phieu
Set(gSoPhieuNhap,
    PowerAutomate_GetNextNumber.Run("PN-" & Text(Year(Today()), "0000")).soPhieu
);
// Flow returns formatted string like "PN-2026-0042"
```

```
// Line item collection (local, not yet saved to SharePoint)
// "Them dong" button OnSelect:
Collect(colChiTietNhapTemp,
    {
        LineNum: CountRows(colChiTietNhapTemp) + 1,
        MaHang: ddMaHang.Selected.Title,
        TenHang: ddMaHang.Selected.TenHang,
        DonViTinh: ddMaHang.Selected.DonViTinh.Value,
        SoLuong: Value(txtSoLuong.Text),
        DonGiaNhap: Value(txtDonGia.Text),
        ThanhTien: Value(txtSoLuong.Text) * Value(txtDonGia.Text)
    }
);
```

```
// "Luu nhap" button OnSelect — Save header + details
// Step 1: Create header
Patch('KHO_PhieuNhap', Defaults('KHO_PhieuNhap'),
    {
        Title: gSoPhieuNhap,
        NgayNhap: dpNgayNhap.SelectedDate,
        NhaCungCap: {
            Id: LookUp(colNhaCungCap, Title = ddNCC.Selected.Title).ID,
            Value: ddNCC.Selected.Title
        },
        SoHoaDon: txtSoHoaDon.Text,
        TrangThai: {Value: "Nhap"},
        NguoiNhap: {
            Claims: "i:0#.f|membership|" & gCurrentUser.Mail,
            Email: gCurrentUser.Mail,
            DisplayName: gCurrentUser.DisplayName
        },
        GhiChu: txtGhiChu.Text
    }
);

// Step 2: Save each line item
ForAll(colChiTietNhapTemp,
    Patch('KHO_ChiTietNhap', Defaults('KHO_ChiTietNhap'),
        {
            Title: gSoPhieuNhap & "-" & Text(LineNum, "000"),
            SoPhieuNhap: {
                Id: LookUp('KHO_PhieuNhap', Title = gSoPhieuNhap).ID,
                Value: gSoPhieuNhap
            },
            MaHang: {
                Id: LookUp('KHO_DanhMucHang', Title = MaHang).ID,
                Value: MaHang
            },
            SoLuong: SoLuong,
            DonGiaNhap: DonGiaNhap
        }
    )
);

// Step 3: Log to audit
PowerAutomate_AuditLog.Run(
    gCurrentUser.Mail, "Create", "KHO", "KHO_PhieuNhap", gSoPhieuNhap
);

Notify("Da luu phieu nhap " & gSoPhieuNhap, NotificationType.Success);
```

```
// "Gui duyet" button OnSelect — Change status to Cho duyet
Patch('KHO_PhieuNhap',
    LookUp('KHO_PhieuNhap', Title = gSoPhieuNhap),
    { TrangThai: {Value: "Cho duyet"} }
);
// This triggers Power Automate approval flow (Phase 5, Flow 3)
```

### S03: Duyet Phieu Nhap (Approve Inbound Receipt)
**Purpose:** Supervisor reviews and approves/rejects phieu nhap.

**Layout:**
- Gallery of pending phieu (TrangThai = "Cho duyet")
- Detail panel: header info + line items gallery (read-only)
- Buttons: "Duyet" (approve), "Tu choi" (reject) with comment field

**Key Formulas:**

```
// Gallery Items — Pending approval phieu, delegation-safe
Filter('KHO_PhieuNhap',
    TrangThai.Value = "Cho duyet"
)
// TrangThai is indexed. This is delegation-safe.
```

```
// "Duyet" button OnSelect
Patch('KHO_PhieuNhap',
    galPhieuChoDuyet.Selected,
    {
        TrangThai: {Value: "Da duyet"},
        NguoiDuyet: {
            Claims: "i:0#.f|membership|" & gCurrentUser.Mail,
            Email: gCurrentUser.Mail
        },
        NgayDuyet: Today()
    }
);

// Queue stock updates for each line item
ForAll(
    Filter('KHO_ChiTietNhap',
        SoPhieuNhap.Value = galPhieuChoDuyet.Selected.Title
    ),
    PowerAutomate_QueueStockUpdate.Run(
        MaHang.Value,
        "NHAP",
        SoLuong,
        galPhieuChoDuyet.Selected.Title
    )
);

Notify("Da duyet phieu " & galPhieuChoDuyet.Selected.Title, NotificationType.Success);
```

### S04: Nhap Phieu Xuat (Create Outbound Shipment)
**Purpose:** Create phieu xuat with stock validation.

**Layout:** Similar to S02 but with:
- KhachHang text field (not lookup)
- MucDichXuat dropdown
- Real-time stock validation when adding line items

**Key Formulas:**

```
// Validate stock before adding line item
Set(nTonHienTai,
    LookUp(colHangHoa, Title = ddMaHang.Selected.Title).TonKhoHienTai
);

If(
    Value(txtSoLuongXuat.Text) > nTonHienTai,
    Notify(
        "Ton kho khong du! Hien con: " &
        Text(nTonHienTai) & " " &
        ddMaHang.Selected.DonViTinh.Value,
        NotificationType.Error, 5000
    ),
    // OK — add to temp collection
    Collect(colChiTietXuatTemp, {
        LineNum: CountRows(colChiTietXuatTemp) + 1,
        MaHang: ddMaHang.Selected.Title,
        TenHang: ddMaHang.Selected.TenHang,
        SoLuong: Value(txtSoLuongXuat.Text),
        DonGiaXuat: Value(txtDonGiaXuat.Text),
        ThanhTien: Value(txtSoLuongXuat.Text) * Value(txtDonGiaXuat.Text),
        TonSauXuat: nTonHienTai - Value(txtSoLuongXuat.Text)
    })
);
```

```
// On approval, queue XUAT transactions (same pattern as S03 but LoaiGiaoDich = "XUAT")
```

### S05: Lich Su Giao Dich (Transaction History)
**Purpose:** Search and filter past phieu nhap/xuat.

**Layout:**
- Filter bar: date range (from/to), loai phieu (nhap/xuat), trang thai, ma hang
- Gallery of matching phieu
- Detail view on select

**Key Formulas:**

```
// Delegation-safe date range filter
Filter('KHO_PhieuNhap',
    NgayNhap >= dpTuNgay.SelectedDate
    And NgayNhap <= dpDenNgay.SelectedDate
    And (ddTrangThai.Selected.Value = "Tat ca"
         Or TrangThai.Value = ddTrangThai.Selected.Value)
)
// NgayNhap and TrangThai are both indexed = delegation-safe
// Default date range: current month (Today() - 30 to Today())
```

### S06: Bao Cao Ton Kho (Stock Report)
**Purpose:** Export stock report to Excel, embed Power BI.

**Layout:**
- Summary table from colHangHoa collection
- "Xuat Excel" button
- Power BI embedded frame (optional, requires Power BI license)

**Key Formulas:**

```
// Export to Excel — uses Office365 connector
// Collect filtered data, then export
ClearCollect(colBaoCao,
    AddColumns(colHangHoa,
        "TrangThaiTon",
        If(TonKhoHienTai <= TonKhoToiThieu, "Sap het", "Binh thuong")
    )
);
// Note: Power Apps has no native Excel export.
// Options:
// 1. Power Automate flow that creates Excel in SharePoint
// 2. Use Export() function (limited availability)
// 3. Power BI report with export capability (recommended)
```

### S07: Danh Muc Hang (Product Catalog CRUD)
**Purpose:** Admin/Supervisor manage product catalog.

**Layout:**
- Gallery with search
- Edit form (side panel or new screen)
- Add new / Edit / Deactivate buttons

**Key Formulas:**

```
// Search — delegation-safe using StartsWith (not Search)
Filter('KHO_DanhMucHang',
    StartsWith(Title, txtTimKiem.Text)
    Or StartsWith(TenHang, txtTimKiem.Text)
)
// StartsWith is delegation-safe on SharePoint. Search() is NOT.
```

```
// Visibility by role
btnThemMoi.Visible = gRole = "Admin" Or gRole = "Supervisor"
btnXoa.Visible = gRole = "Admin"
```

## Navigation Flow

```
Dashboard (S01)
├── Nhap Phieu Nhap (S02)
├── Duyet Phieu Nhap (S03) — Supervisor/Admin only
├── Nhap Phieu Xuat (S04)
├── Lich Su Giao Dich (S05)
├── Bao Cao Ton Kho (S06)
└── Danh Muc Hang (S07) — Supervisor/Admin only
```

## Todo List

- [ ] Write complete screen specs doc with layout wireframes
- [ ] Write all corrected Power Fx formulas
- [ ] Document navigation flow and button visibility rules
- [ ] Document error handling patterns (Notify, IfError)
- [ ] Document offline considerations (SaveData/LoadData for collections)

## Success Criteria

- All formulas are delegation-safe (no Year(), CountRows on SP, Search())
- Stock updates use queue pattern, not direct Patch
- Phieu numbering uses counter flow
- Role-based visibility on all screens
- Search uses StartsWith (delegable) not Search (non-delegable)
