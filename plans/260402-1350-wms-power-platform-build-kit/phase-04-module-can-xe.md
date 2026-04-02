# Phase 4: Module Cân Xe — Full Build (v3)

## Context
- [Plan Overview](plan.md)
- [Phase 1 — Data Model](phase-01-sharepoint-provisioning.md)
- [ACS Analysis](../reports/brainstorm-260402-1521-acs-amms-data-integration.md) — tham khảo thiết kế

## Overview
- **Priority:** P0
- **Status:** pending
- **Description:** Build module Cân xe trên Power Apps, thay thế ACS AMMS IoT. MVP dùng nhập tay, sau đó tích hợp hardware.

## Key Insights (từ phân tích ACS)
- Quy trình 2 lần cân: Cân vào (tare) → Cân ra (gross) → TL hàng = |Vào - Ra|
- ACS hỗ trợ 3 loại: Cân nhập / Cân xuất / Tự động
- Fields ACS dùng: Số phiếu, Biển số, Rơ mooc, KH/NCC, Hàng hóa, Kho, Nhà vận tải, Lái xe
- ACS có 3 camera (biển số + cân vào + cân ra) — Power Apps hỗ trợ camera chụp ảnh
- Báo cáo ACS: theo KH, hàng hóa, xe, tổng hợp nhập xuất, ca làm việc

## Data Model (SharePoint Lists)

### CAN_PhieuCan
| Column | Type | Required | Notes |
|--------|------|----------|-------|
| Title | Single line | Yes | Số phiếu (PC-2026-0001) |
| NgayCan | DateTime | Yes | Ngày/giờ tạo phiếu |
| BienSoXe | Lookup → VT_DanhMucXe | No | Xe đăng ký |
| BienSoXeText | Single line | No | Nhập tay cho xe vãng lai |
| RoMooc | Single line | No | Biển số rơ mooc |
| KhachHang_NCC | Single line | Yes | Khách hàng / NCC |
| HangHoa | Single line | Yes | Tên hàng hóa |
| LoaiHang | Choice | Yes | Nguyen lieu / Thanh pham / Phe lieu / Khac |
| Kho | Single line | No | Kho liên quan |
| NhaVanTai | Single line | No | Nhà vận tải |
| LaiXe | Single line | No | Tên lái xe |
| LoaiCan | Choice | Yes | Can nhap / Can xuat / Tu dong |
| CanVao_KG | Number | No | Trọng lượng cân vào (kg) |
| GioCanVao | DateTime | No | Thời gian cân vào |
| CanRa_KG | Number | No | Trọng lượng cân ra (kg) |
| GioCanRa | DateTime | No | Thời gian cân ra |
| TLHang_KG | Number | No | = Abs(CanVao - CanRa), tính trong Power Apps |
| TaiTrongToiDaXe | Number | No | Copy từ DanhMucXe (kg) |
| TinhTrangTaiTrong | Choice | No | OK / Qua tai |
| NguoiCanVao | Person | No | |
| NguoiCanRa | Person | No | |
| CaLamViec | Choice | No | Ca 1 / Ca 2 / Ca 3 |
| HinhAnhCanVao | Thumbnail | No | Ảnh chụp xe cân vào |
| HinhAnhCanRa | Thumbnail | No | Ảnh chụp xe cân ra |
| GhiChu | Multiline | No | |
| ChungTu | Single line | No | Số chứng từ liên quan |
| TrangThai | Choice | Yes | Cho can ra / Hoan thanh / Huy |
| LienKetChuyenHang | Lookup → VT_ChuyenHang | No | Link với lệnh vận chuyển |
| TramCan | Lookup → CAN_TramCan | No | |
| **Index:** Title, NgayCan, BienSoXe, TrangThai, KhachHang_NCC |

### CAN_TramCan
| Column | Type | Required | Notes |
|--------|------|----------|-------|
| Title | Single line | Yes | Mã trạm (TC-01) |
| TenTram | Single line | Yes | |
| ViTri | Single line | No | |
| TaiTrongToiDa_Tan | Number | Yes | |
| TrangThai | Choice | Yes | Hoat dong / Bao tri |

## Screens (5 screens)

### S01: Cân Vào
**Purpose:** Tạo phiếu cân mới, nhập thông tin xe và trọng lượng cân vào.

**Layout:**
- Toggle: Xe đăng ký (dropdown) / Xe vãng lai (nhập tay)
- Auto-fill từ xe: TaiTrongToiDa, Lái xe (nếu có chuyến đang chạy)
- Form: KH/NCC, Hàng hóa, Loại hàng, Kho, Nhà vận tải, Loại cân
- Nhập cân: CanVao_KG (số), chụp ảnh xe
- Button: "Lưu Cân Vào"

**Key Formulas:**
```
// Generate số phiếu
Set(gSoPhieuCan,
    PowerAutomate_GetNextNumber.Run("PC-" & Text(Year(Today()), "0000")).soPhieu
);

// Lưu cân vào
Patch('CAN_PhieuCan', Defaults('CAN_PhieuCan'),
    {
        Title: gSoPhieuCan,
        NgayCan: Now(),
        BienSoXe: If(!IsBlank(gSelectedXe),
            { Id: gSelectedXe.ID, Value: gSelectedXe.Title }, Blank()),
        BienSoXeText: If(IsBlank(gSelectedXe), txtBienSoManual.Text, ""),
        RoMooc: txtRoMooc.Text,
        KhachHang_NCC: txtKhachHang.Text,
        HangHoa: txtHangHoa.Text,
        LoaiHang: ddLoaiHang.Selected,
        Kho: ddKho.Selected.Value,
        NhaVanTai: txtNhaVanTai.Text,
        LaiXe: txtLaiXe.Text,
        LoaiCan: ddLoaiCan.Selected,
        CanVao_KG: Value(txtCanVao.Text),
        GioCanVao: Now(),
        TaiTrongToiDaXe: If(!IsBlank(gSelectedXe),
            gSelectedXe.TaiTrongToiDa * 1000, 0),
        NguoiCanVao: {
            Claims: "i:0#.f|membership|" & gCurrentUser.Mail,
            Email: gCurrentUser.Mail
        },
        CaLamViec: ddCaLamViec.Selected,
        TrangThai: {Value: "Cho can ra"}
    }
);
```

### S02: Cân Ra
**Purpose:** Hoàn thành phiếu cân — nhập trọng lượng cân ra, tính trọng tải hàng.

**Layout:**
- Tìm phiếu: theo Số phiếu hoặc Biển số xe (status "Cho can ra")
- Hiển thị info cân vào (read-only)
- Nhập: CanRa_KG, chụp ảnh xe
- Auto-calc: TL hàng = |Vào - Ra|, hiển thị realtime
- Cảnh báo quá tải (đổi màu đỏ)
- Button: "Hoàn thành Cân Ra"

**Key Formulas:**
```
// Tìm phiếu chờ cân ra — delegation-safe
Filter('CAN_PhieuCan',
    TrangThai.Value = "Cho can ra"
    And (StartsWith(Title, txtSearch.Text)
         Or StartsWith(BienSoXeText, txtSearch.Text))
)

// Realtime tính trọng tải
If(
    IsBlank(txtCanRa.Text) Or IsBlank(lblCanVao.Text),
    "-- kg",
    Text(Abs(Value(txtCanRa.Text) - Value(lblCanVao.Text)), "#,##0") & " kg"
)

// Cảnh báo quá tải — Color
If(
    Abs(Value(txtCanRa.Text) - Value(lblCanVao.Text)) > Value(lblTaiTrongMax.Text),
    Color.Red,
    RGBA(0, 200, 150, 1)
)

// Hoàn thành cân ra
Set(nTrongTai, Abs(Value(txtCanRa.Text) - Value(lblCanVao.Text)));
Patch('CAN_PhieuCan',
    LookUp('CAN_PhieuCan', Title = gSoPhieu),
    {
        CanRa_KG: Value(txtCanRa.Text),
        GioCanRa: Now(),
        TLHang_KG: nTrongTai,
        NguoiCanRa: { Claims: "i:0#.f|membership|" & gCurrentUser.Mail },
        TrangThai: {Value: "Hoan thanh"},
        TinhTrangTaiTrong: If(nTrongTai > Value(lblTaiTrongMax.Text),
            {Value: "Qua tai"}, {Value: "OK"})
    }
);
// Alert quá tải
If(nTrongTai > Value(lblTaiTrongMax.Text),
    PowerAutomate_CanhBaoQuaTai.Run(gSoPhieu, lblBienSo.Text, Text(nTrongTai))
);
```

### S03: Danh Sách Phiếu Cân
**Purpose:** Filter/search phiếu cân theo ngày, xe, KH, trạng thái.

**Key Formulas:**
```
Filter('CAN_PhieuCan',
    NgayCan >= dpTuNgay.SelectedDate
    And NgayCan <= DateAdd(dpDenNgay.SelectedDate, 1, TimeUnit.Days)
    And (ddTrangThai.Selected.Value = "Tat ca"
         Or TrangThai.Value = ddTrangThai.Selected.Value)
)
```

### S04: Báo Cáo Cân
**Purpose:** Tổng hợp theo ngày/tuần/tháng — tham khảo layout ACS web portal.

**Layout (giống ACS):**
- Summary: Tổng TL cân vào, Tổng TL cân ra, Tổng TL hàng
- Bảng chi tiết
- Filter: ngày, KH, hàng hóa, ca làm việc, kho
- Export button

### S05: Cảnh Báo Quá Tải
**Purpose:** Danh sách xe quá tải hôm nay.

## Scale Hardware Integration Roadmap

### MVP (Bây giờ): Nhập tay
- Operator đọc số trên bảng hiển thị cân → nhập vào Power Apps
- Chụp ảnh xe bằng camera điện thoại/tablet
- Đủ dùng để thay thế ACS ngay

### Phase 2: CSV Import
- Phần mềm cân (indicator software) xuất CSV mỗi lần cân
- Power Automate watch folder → parse → update SharePoint
- Giảm nhập tay, giữ Power Apps làm UI

### Phase 3: Desktop Agent + WebSocket
- App nhỏ (.NET) chạy trên máy trạm cân
- Đọc COM port RS-232 từ indicator
- Push số cân lên web qua WebSocket
- Power Apps nhận realtime (qua Power Automate hoặc custom connector)

## Todo List

- [ ] Thêm CAN lists vào Phase 1 provisioning
- [ ] Build S01: Cân Vào
- [ ] Build S02: Cân Ra
- [ ] Build S03: Danh Sách Phiếu Cân
- [ ] Build S04: Báo Cáo Cân
- [ ] Build S05: Cảnh Báo Quá Tải
- [ ] Build Flow cảnh báo quá tải (Phase 5)
- [ ] Test quy trình cân 2 lần end-to-end
- [ ] Document scale hardware roadmap

## Success Criteria

- Quy trình 2 lần cân hoạt động: Cân Vào → Cân Ra → TL hàng tính đúng
- Cảnh báo quá tải hiển thị + Teams notification
- Search phiếu cân delegation-safe
- Báo cáo tổng hợp giống ACS web portal
- Camera chụp ảnh xe hoạt động
- Hỗ trợ cả xe đăng ký và xe vãng lai
