# Phase 4: Module Can Xe (Vehicle Weighing) Reference Docs

## Context
- [Plan Overview](plan.md)
- [Phase 1 — Data Model](phase-01-sharepoint-provisioning.md)

## Overview
- **Priority:** P0
- **Status:** pending
- **Description:** Power Apps reference for Weighing module — 5 screens, two-step weigh process (in/out), overload detection, scale hardware integration notes.

## Key Insights
- Weighing is a two-step process: Can Vao (weigh-in) creates record, Can Ra (weigh-out) completes it
- TrongTaiHang = Abs(CanVao - CanRa) — calculated in Power Apps, stored as Number (not SharePoint Calculated)
- Overload = TrongTaiHang > TaiTrongToiDa * 1000 (convert Tan to KG)
- Must support both registered vehicles (lookup) and walk-in vehicles (manual text entry)
- Phase 1: manual weight entry. Phase 2: CSV import from scale software

## Screens

### S01: Can Vao (Weigh-In)
**Purpose:** Record vehicle entering the weighing station.

**Layout:**
- Vehicle selector: search by Bien so (dropdown from colDanhMucXe) OR manual text entry toggle
- Auto-fill: TenLaiXe, TaiTrongToiDa from selected vehicle
- Fields: LoaiHang (dropdown), TenHang, NhaMayGiao, NhaMayNhan
- Weight input: CanVao_KG (number input, manual)
- Camera: capture vehicle photo
- Optional: link to existing VT_ChuyenHang (dropdown of active shipments for this vehicle)
- Button: "Luu Can Vao"

**Key Formulas:**

```
// Generate So Phieu Can
Set(gSoPhieuCan,
    PowerAutomate_GetNextNumber.Run("PC-" & Text(Year(Today()), "0000")).soPhieu
);
```

```
// Vehicle search toggle — registered vs walk-in
If(togRegistered.Value,
    // Registered vehicle — use lookup
    Set(gSelectedXe,
        LookUp(colDanhMucXe, Title = ddBienSo.Selected.Title)
    );
    Set(gTaiTrongMax, gSelectedXe.TaiTrongToiDa);
    Set(gTenLaiXe,
        LookUp(colLaiXe,
            // Find driver currently assigned to this vehicle
            // via active shipment
            true
        ).HoTen
    ),
    // Walk-in vehicle — manual entry
    Set(gSelectedXe, Blank());
    Set(gTaiTrongMax, 0);
)
```

```
// "Luu Can Vao" button OnSelect
Patch('CAN_PhieuCan', Defaults('CAN_PhieuCan'),
    {
        Title: gSoPhieuCan,
        NgayCan: Now(),
        BienSoXe: If(!IsBlank(gSelectedXe),
            { Id: gSelectedXe.ID, Value: gSelectedXe.Title },
            Blank()
        ),
        BienSoXeText: If(IsBlank(gSelectedXe), txtBienSoManual.Text, ""),
        TenLaiXe: txtTenLaiXe.Text,
        LoaiHang: ddLoaiHang.Selected,
        TenHang: txtTenHang.Text,
        CanVao_KG: Value(txtCanVao.Text),
        GioCanVao: Now(),
        TaiTrongToiDaXe: gTaiTrongMax * 1000,  // Convert Tan to KG
        NhaMayGiao: txtNhaMayGiao.Text,
        NhaMayNhan: txtNhaMayNhan.Text,
        NguoiCanVao: {
            Claims: "i:0#.f|membership|" & gCurrentUser.Mail,
            Email: gCurrentUser.Mail
        },
        TrangThai: {Value: "Cho can ra"},
        TramCan: If(!IsBlank(ddTramCan.Selected),
            { Id: ddTramCan.Selected.ID, Value: ddTramCan.Selected.Title },
            Blank()
        ),
        LienKetChuyenHang: If(!IsBlank(ddChuyenHang.Selected),
            { Id: ddChuyenHang.Selected.ID, Value: ddChuyenHang.Selected.Title },
            Blank()
        )
    }
);

Notify("Da luu phieu can vao: " & gSoPhieuCan, NotificationType.Success);
Navigate(scr_DanhSachPhieuCan, ScreenTransition.None);
```

### S02: Can Ra (Weigh-Out)
**Purpose:** Complete weighing by entering outbound weight.

**Layout:**
- Search: lookup phieu can by Title (So phieu) or BienSoXe
- Display: Can Vao info (read-only), GioCanVao, vehicle details
- Input: CanRa_KG
- Auto-calc display: TrongTaiHang_KG = Abs(CanVao - CanRa)
- Overload indicator: red/green label
- Button: "Hoan thanh Can Ra"

**Key Formulas:**

```
// Search pending phieu — delegation-safe
Filter('CAN_PhieuCan',
    TrangThai.Value = "Cho can ra"
    And (
        StartsWith(Title, txtSearch.Text)
        Or BienSoXe.Value = txtSearch.Text
    )
)
// Title and BienSoXe are indexed. StartsWith is delegable.
```

```
// Real-time weight calculation — Label Text property
If(
    IsBlank(txtCanRa.Text) Or IsBlank(lblCanVao.Text),
    "-- kg",
    Text(
        Abs(Value(txtCanRa.Text) - Value(lblCanVao.Text)),
        "#,##0"
    ) & " kg"
)
```

```
// Overload indicator — Label Color property
If(
    IsBlank(txtCanRa.Text) Or IsBlank(lblCanVao.Text),
    Color.Gray,
    If(
        Abs(Value(txtCanRa.Text) - Value(lblCanVao.Text))
        > Value(lblTaiTrongMax.Text),  // Already in KG from Can Vao
        Color.Red,
        RGBA(0, 200, 150, 1)  // Green = OK
    )
)
```

```
// Overload warning text
If(
    Abs(Value(txtCanRa.Text) - Value(lblCanVao.Text))
    > Value(lblTaiTrongMax.Text),
    "⚠ QUA TAI - Vuot " &
    Text(
        Abs(Value(txtCanRa.Text) - Value(lblCanVao.Text)) - Value(lblTaiTrongMax.Text),
        "#,##0"
    ) & " kg",
    "OK"
)
```

```
// "Hoan thanh Can Ra" button OnSelect
Set(nTrongTai,
    Abs(Value(txtCanRa.Text) - Value(lblCanVao.Text))
);

Patch('CAN_PhieuCan',
    LookUp('CAN_PhieuCan', Title = gSoPhieu),
    {
        CanRa_KG: Value(txtCanRa.Text),
        GioCanRa: Now(),
        TrongTaiHang_KG: nTrongTai,
        NguoiCanRa: {
            Claims: "i:0#.f|membership|" & gCurrentUser.Mail,
            Email: gCurrentUser.Mail
        },
        TrangThai: {Value: "Hoan thanh"},
        TinhTrangTaiTrong: If(
            nTrongTai > Value(lblTaiTrongMax.Text),
            {Value: "Qua tai"},
            {Value: "OK"}
        )
    }
);

// Trigger overload alert if needed
If(
    nTrongTai > Value(lblTaiTrongMax.Text),
    PowerAutomate_CanhBaoQuaTai.Run(
        gSoPhieu,
        Text(LookUp('CAN_PhieuCan', Title = gSoPhieu).BienSoXe.Value),
        Text(nTrongTai)
    )
);

Notify("Da hoan thanh phieu can: " & gSoPhieu, NotificationType.Success);
Navigate(scr_XacNhanCanRa, ScreenTransition.Cover);
```

### S03: Danh Sach Phieu Can (Weighing Ticket List)
**Purpose:** Filter and search past weighing tickets.

**Layout:**
- Filter bar: date range, vehicle, status (Cho can ra / Hoan thanh / Huy)
- Gallery with key info: So phieu, Bien so, TrongTai, TinhTrang, NgayCan
- Color-coded: red for Qua tai, green for OK, yellow for Cho can ra

**Key Formulas:**

```
// Delegation-safe filter
Filter('CAN_PhieuCan',
    NgayCan >= dpTuNgay.SelectedDate
    And NgayCan <= DateAdd(dpDenNgay.SelectedDate, 1, TimeUnit.Days)
    And (ddTrangThai.Selected.Value = "Tat ca"
         Or TrangThai.Value = ddTrangThai.Selected.Value)
)
// NgayCan and TrangThai are indexed
// Default: today only
```

### S04: Bao Cao Can (Weighing Reports)
**Purpose:** Summary reports by day/week/month.

**Layout:**
- Period selector: Ngay / Tuan / Thang
- Summary cards: total phieu, total trong tai, total qua tai
- Gallery detail
- Export button (via Power Automate flow to Excel)

**Key Formulas:**

```
// Summary — use local collection for aggregation
ClearCollect(colBaoCaoCan,
    Filter('CAN_PhieuCan',
        NgayCan >= varStartDate
        And NgayCan <= varEndDate
        And TrangThai.Value = "Hoan thanh"
    )
);

// Then aggregate locally (safe from delegation)
Set(nTongPhieu, CountRows(colBaoCaoCan));
Set(nTongTrongTai, Sum(colBaoCaoCan, TrongTaiHang_KG));
Set(nTongQuaTai,
    CountRows(Filter(colBaoCaoCan, TinhTrangTaiTrong.Value = "Qua tai"))
);
```

### S05: Canh Bao Qua Tai (Overload Alerts)
**Purpose:** Real-time list of overloaded vehicles.

**Layout:**
- Gallery of phieu with TinhTrangTaiTrong = "Qua tai"
- Filter by date range
- Detail: vehicle info, weight details, how much over limit

**Key Formulas:**

```
// Overloaded tickets — today by default
Filter('CAN_PhieuCan',
    TinhTrangTaiTrong.Value = "Qua tai"
    And NgayCan >= Today()
)
```

## Scale Hardware Integration

### Phase 1: Manual Entry (MVP)
- Operator reads digital display on physical scale
- Types weight into txtCanVao / txtCanRa fields
- Photo capture of vehicle on scale as verification
- Acceptable for initial deployment

### Phase 2: CSV Import (Future)
**Architecture:**
```
Physical Scale → Scale Software (vendor) → CSV file
    → SharePoint Document Library (watched folder)
        → Power Automate: On file created
            → Parse CSV
            → Create/Update CAN_PhieuCan record
                → Power Apps: Refresh gallery
```

**Power Automate flow steps:**
1. Trigger: "When a file is created" in `WMS_ScaleImport` document library
2. Get file content
3. Parse CSV (Compose + split actions)
4. For each row: Create item in CAN_PhieuCan or Update existing (match by BienSoXe + status "Cho can ra")
5. Move processed file to `WMS_ScaleImport/Processed/` folder
6. Delete original

**CSV format (propose to scale vendor):**
```csv
BienSoXe,CanVao_KG,GioCanVao,CanRa_KG,GioCanRa
51C-12345,15200,2026-04-02T08:30:00,8500,2026-04-02T09:15:00
```

### Phase 3: Real-time API (Advanced, optional)
- Azure Function reads scale API
- Custom connector in Power Apps
- Real-time weight display in app
- Requires Azure subscription + development effort

## Navigation Flow

```
Can Vao (S01)
├── Can Ra (S02)
├── Danh Sach Phieu (S03)
│   └── Detail view → Can Ra (if pending)
├── Bao Cao (S04)
└── Canh Bao Qua Tai (S05)
```

## Todo List

- [ ] Write screen specs with wireframes
- [ ] Write all Power Fx formulas
- [ ] Document two-step weigh process flow
- [ ] Document scale integration options
- [ ] Propose CSV format to scale vendor
- [ ] Document overload calculation and alerting

## Success Criteria

- Two-step weigh process works end-to-end (Can Vao → Can Ra)
- Overload detected and alerted in real-time
- Supports both registered and walk-in vehicles
- Search by So Phieu or Bien So Xe (delegation-safe)
- Scale hardware integration path documented for Phase 2
- Photo capture of vehicles on scale
