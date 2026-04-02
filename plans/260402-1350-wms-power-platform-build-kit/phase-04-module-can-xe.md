# Phase 4: Module Cân Xe — ACS Integration (v2)

## Context
- [Plan Overview](plan.md)
- [Phase 0 — ACS Gateway](phase-00-acs-data-gateway.md)
- [ACS Analysis](../reports/brainstorm-260402-1521-acs-amms-data-integration.md)

## Overview
- **Priority:** P1
- **Status:** pending
- **Description:** Tích hợp dữ liệu cân từ ACS AMMS IoT (SQL Server) vào Power Apps/SharePoint. **KHÔNG build module cân mới** — ACS desktop app xử lý hardware + nhập liệu.

## Thay đổi so với v1
- ~~Build 5 screens cân xe trong Power Apps~~ → Chỉ build 2 screens đọc/xem dữ liệu
- ~~Kết nối cân điện tử~~ → ACS đã xử lý
- ~~Power Fx formulas tính trọng tải~~ → ACS đã tính
- **Mới:** Power Automate sync SQL ACS → SharePoint
- **Mới:** Power BI dashboard cho báo cáo cân (Phase 6)

## Architecture

```
┌─────────────────────────┐
│  ACS AMMS IoT Desktop   │  ← Nhân viên cân nhập liệu tại đây
│  (Đang chạy, không sửa) │  ← Camera + cảm biến + cân điện tử
│  DB: ACSAMMS_TAMPHUOC   │
└────────────┬────────────┘
             │ SQL (read-only)
             ▼
┌────────────────────────────┐
│  On-Premises Data Gateway  │  ← Phase 0
└────────────┬───────────────┘
             │
     ┌───────┴──────────┐
     ▼                  ▼
┌──────────┐    ┌──────────────┐
│ Power    │    │ Power        │
│ Automate │    │ BI           │
│ Sync     │    │ Dashboard    │  ← Phase 6
│ Flow     │    └──────────────┘
└─────┬────┘
      │ Create/Update items
      ▼
┌──────────────────┐
│ SharePoint List  │
│ CAN_PhieuCan_ACS │  ← Read-only mirror
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Power Apps       │
│ 2 screens:       │
│ - Danh sách cân  │
│ - Báo cáo cân    │
└──────────────────┘
```

## SharePoint List: CAN_PhieuCan_ACS (mirror từ ACS)

List này là **read-only mirror** — chỉ Power Automate ghi, users không sửa.

| Column | Type | Source từ ACS | Notes |
|--------|------|--------------|-------|
| Title | Single line | SoPhieuCan | PK, e.g. 2604021048 |
| BienSoXe | Single line | BienSo | 60C-53580 |
| RoMooc | Single line | RoMooc | 60R-01745 |
| KhachHang_NCC | Single line | KhachHang/NCC | Text (không lookup) |
| HangHoa | Single line | HangHoa | CỦI, DĂM CAO SU, etc. |
| Kho | Single line | Kho | |
| NhaVanTai | Single line | NhaVanTai | |
| LaiXe | Single line | LaiXe | |
| TLCanLan1_KG | Number | TL cân lần 1 | |
| TGCanLan1 | DateTime | TG cân lần 1 | |
| TLCanLan2_KG | Number | TL cân lần 2 | |
| TGCanLan2 | DateTime | TG cân lần 2 | |
| TLHang_KG | Number | TL hàng | = |L1 - L2| |
| LoaiCan | Choice | Cân nhập / Cân xuất / Tự động | |
| GhiChu | Single line | Ghi chú | |
| ChungTu | Single line | Chứng từ | |
| ACS_SyncedAt | DateTime | — | Thời điểm sync |
| **Index:** Title, TGCanLan1, BienSoXe, KhachHang_NCC |

## Power Automate: ACS Sync Flow

**Trigger:** Recurrence — mỗi 5 phút

**Logic:**
```
1. Get last sync timestamp từ SYS_Counters (Title = "ACS_LastSync")
2. SQL query:
   SELECT * FROM [PhieuCan_Table]
   WHERE ModifiedDate > @{variables('lastSync')}
   ORDER BY ModifiedDate ASC
3. For each record:
   - Check nếu Title (SoPhieu) đã tồn tại trong SharePoint
     - Có → Update item
     - Không → Create item
4. Update SYS_Counters.ACS_LastSync = utcNow()
```

**Lưu ý:** Tên table thực tế cần xác nhận sau Phase 0 (khảo sát DB schema).

## Power Apps Screens (chỉ 2 screens)

### S01: Danh Sách Phiếu Cân (Read-only)
**Purpose:** Xem dữ liệu cân từ ACS, filter/search.

**Layout:**
- Filter bar: ngày (from/to), biển số xe, khách hàng, loại cân
- Gallery hiển thị: Số phiếu, Biển số, KH/NCC, Hàng hóa, TL hàng, Thời gian
- Detail panel khi chọn 1 phiếu
- Badge "Từ ACS" để phân biệt với dữ liệu Power Apps

**Key Formulas:**
```
// Filter — delegation-safe
Filter('CAN_PhieuCan_ACS',
    TGCanLan1 >= dpTuNgay.SelectedDate
    And TGCanLan1 <= DateAdd(dpDenNgay.SelectedDate, 1, TimeUnit.Days)
    And (IsBlank(txtBienSo.Text) Or StartsWith(BienSoXe, txtBienSo.Text))
)
```

```
// Gallery subtitle — hiển thị trọng lượng
Text(ThisItem.TLHang_KG, "#,##0") & " kg | " &
ThisItem.KhachHang_NCC & " | " &
ThisItem.HangHoa
```

### S02: Báo Cáo Cân (Summary)
**Purpose:** Tổng hợp theo ngày/tuần/tháng cho quản lý.

**Layout:**
- Period selector
- Summary cards: tổng phiếu, tổng trọng lượng, top khách hàng
- Embedded Power BI report (nếu có license)

**Key Formulas:**
```
// Load collection cho aggregation
ClearCollect(colBaoCaoCan,
    Filter('CAN_PhieuCan_ACS',
        TGCanLan1 >= varStartDate
        And TGCanLan1 <= varEndDate
    )
);

Set(nTongPhieu, CountRows(colBaoCaoCan));
Set(nTongTrongLuong, Sum(colBaoCaoCan, TLHang_KG));
```

## Liên kết với Module Vận Tải

Dữ liệu cân từ ACS có trường **Biển số xe** và **Nhà vận tải** → có thể liên kết với VT_ChuyenHang:

```
// Trong VT_ChuyenHang detail screen, hiển thị phiếu cân liên quan
Filter('CAN_PhieuCan_ACS',
    BienSoXe = galChuyenHang.Selected.BienSoXe.Value
    And TGCanLan1 >= galChuyenHang.Selected.NgayKhoiHanh
)
```

## Todo List

- [ ] Phase 0 hoàn thành (Gateway + SQL access)
- [ ] Khảo sát ACS database schema (tên tables/columns thực tế)
- [ ] Tạo SharePoint List CAN_PhieuCan_ACS
- [ ] Build Power Automate ACS Sync Flow
- [ ] Build S01: Danh Sách Phiếu Cân
- [ ] Build S02: Báo Cáo Cân
- [ ] Test sync: verify dữ liệu khớp ACS
- [ ] Link phiếu cân với chuyến hàng (VT module)

## Success Criteria

- Dữ liệu cân từ ACS xuất hiện trong SharePoint/Power Apps trong vòng 5 phút
- Filter/search phiếu cân delegation-safe
- Không ảnh hưởng hiệu suất ACS (read-only)
- Users KHÔNG nhập liệu cân trong Power Apps — chỉ xem
