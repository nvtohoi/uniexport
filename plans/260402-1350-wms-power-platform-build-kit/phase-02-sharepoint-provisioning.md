# Phase 1: SharePoint Provisioning Scripts

## Context
- [Brainstorm Report](../reports/brainstorm-260402-1350-wms-power-platform-design-review.md)
- [Plan Overview](plan.md)

## Overview
- **Priority:** P0
- **Status:** pending
- **Description:** PnP PowerShell scripts to provision dedicated SharePoint site with all lists, columns, indexes, choices, lookups for the WMS system.

## Key Insights
- SharePoint has max 20 indexed columns per list — must prioritize
- Lookup columns must reference lists that already exist → creation order matters
- Choice columns need Vietnamese values with no diacritics in internal names
- Calculated columns (ThanhTien, TrongTaiHang) should be created but may need Power Apps formula fallback for delegation

## Requirements

### Functional
- Single main script orchestrates all sub-scripts in correct order
- Idempotent — safe to re-run without duplicating lists/columns
- Creates dedicated Communication Site or Team Site
- All 18+ lists with correct column types
- Column indexes on delegation-critical fields
- Default views per list

### Non-Functional
- Scripts must work with PnP.PowerShell module v2.x+
- Support for SharePoint Online only (no on-prem)
- Parameterized tenant URL and site name

## Architecture

### List Creation Order (dependency-aware)
```
1. Master data (no dependencies):
   - KHO_NhaCungCap
   - KHO_DanhMucHang
   - VT_DanhMucXe
   - VT_LaiXe
   - CAN_TramCan
   - SYS_Counters
   - AUDIT_Log

2. Transaction headers (depend on master):
   - KHO_PhieuNhap       → Lookup: KHO_NhaCungCap
   - KHO_PhieuXuat        → (KhachHang is text, no lookup needed)
   - VT_ChuyenHang        → Lookup: VT_DanhMucXe, VT_LaiXe
   - CAN_PhieuCan         → Lookup: VT_DanhMucXe

3. Transaction details (depend on headers):
   - KHO_ChiTietNhap      → Lookup: KHO_PhieuNhap, KHO_DanhMucHang
   - KHO_ChiTietXuat      → Lookup: KHO_PhieuXuat, KHO_DanhMucHang
   - VT_ChiPhiXe          → Lookup: VT_DanhMucXe, VT_ChuyenHang

4. Cross-module links (depend on multiple):
   - CAN_PhieuCan.LienKetChuyenHang → Lookup: VT_ChuyenHang
   - VT_ChuyenHang.PhieuCanID       → Lookup: CAN_PhieuCan

5. System/Queue lists:
   - KHO_GiaoDichLog
   - KHO_KhachHang

6. Archive lists (mirrors of transactional):
   - KHO_PhieuNhap_Archive
   - KHO_ChiTietNhap_Archive
   - KHO_PhieuXuat_Archive
   - KHO_ChiTietXuat_Archive
   - VT_ChuyenHang_Archive
   - VT_ChiPhiXe_Archive
   - CAN_PhieuCan_Archive
```

### Complete Data Model

#### KHO_NhaCungCap (Suppliers)
| Column | Internal Name | Type | Required | Notes |
|--------|--------------|------|----------|-------|
| Title | Title | Single line | Yes | Ma NCC (NCC-001) |
| TenNCC | TenNCC | Single line | Yes | Ten nha cung cap |
| DiaChi | DiaChi | Multiline | No | |
| SoDienThoai | SoDienThoai | Single line | No | |
| Email | Email | Single line | No | |
| MaSoThue | MaSoThue | Single line | No | Tax ID |
| TrangThai | TrangThai | Choice | Yes | Hoat dong / Ngung |
| **Index:** Title, TrangThai |

#### KHO_DanhMucHang (Product Catalog)
| Column | Internal Name | Type | Required | Notes |
|--------|--------------|------|----------|-------|
| Title | Title | Single line | Yes | Ma hang (HH-001) |
| TenHang | TenHang | Single line | Yes | |
| NhomHang | NhomHang | Choice | Yes | Nguyen lieu / Thanh pham / Bao bi / Phu tung / Khac |
| DonViTinh | DonViTinh | Choice | Yes | Kg / Tan / Thung / Chiec / Lit / Bao / Cuon |
| TonKhoToiThieu | TonKhoToiThieu | Number | Yes | Min stock threshold |
| TonKhoHienTai | TonKhoHienTai | Number | Yes | Updated by Flow only |
| ViTriKho | ViTriKho | Single line | No | Location code (A1-B3) |
| MoTa | MoTa | Multiline | No | |
| TrangThai | TrangThai | Choice | Yes | Dang dung / Ngung |
| **Index:** Title, TrangThai, TonKhoHienTai |

#### KHO_PhieuNhap (Inbound Receipts)
| Column | Internal Name | Type | Required | Notes |
|--------|--------------|------|----------|-------|
| Title | Title | Single line | Yes | So phieu (PN-2026-0001) |
| NgayNhap | NgayNhap | Date Only | Yes | |
| NhaCungCap | NhaCungCap | Lookup → KHO_NhaCungCap | Yes | |
| SoHoaDon | SoHoaDon | Single line | No | Invoice reference |
| TrangThai | TrangThai | Choice | Yes | Nhap / Cho duyet / Da duyet / Tu choi |
| NguoiNhap | NguoiNhap | Person | Yes | |
| NguoiDuyet | NguoiDuyet | Person | No | |
| NgayDuyet | NgayDuyet | Date Only | No | |
| GhiChu | GhiChu | Multiline | No | |
| **Index:** Title, NgayNhap, TrangThai, NhaCungCap |

#### KHO_ChiTietNhap (Inbound Line Items)
| Column | Internal Name | Type | Required | Notes |
|--------|--------------|------|----------|-------|
| Title | Title | Single line | Yes | Auto: "{SoPhieu}-{LineNum}" |
| SoPhieuNhap | SoPhieuNhap | Lookup → KHO_PhieuNhap | Yes | FK |
| MaHang | MaHang | Lookup → KHO_DanhMucHang | Yes | |
| SoLuong | SoLuong | Number | Yes | Ordered qty |
| DonGiaNhap | DonGiaNhap | Currency | Yes | |
| ThanhTien | ThanhTien | Calculated | — | = SoLuong * DonGiaNhap |
| SoLuongThucNhan | SoLuongThucNhan | Number | No | Actual received |
| GhiChu | GhiChu | Single line | No | Discrepancy reason |
| **Index:** SoPhieuNhap |

#### KHO_PhieuXuat (Outbound Shipments)
| Column | Internal Name | Type | Required | Notes |
|--------|--------------|------|----------|-------|
| Title | Title | Single line | Yes | So phieu (PX-2026-0001) |
| NgayXuat | NgayXuat | Date Only | Yes | |
| KhachHang | KhachHang | Single line | Yes | Customer name (text) |
| MucDichXuat | MucDichXuat | Choice | Yes | Ban hang / Noi bo / Tra hang |
| TrangThai | TrangThai | Choice | Yes | Nhap / Cho duyet / Da duyet / Tu choi |
| NguoiXuat | NguoiXuat | Person | Yes | |
| NguoiDuyet | NguoiDuyet | Person | No | |
| GhiChu | GhiChu | Multiline | No | |
| **Index:** Title, NgayXuat, TrangThai |

#### KHO_ChiTietXuat (Outbound Line Items)
| Column | Internal Name | Type | Required | Notes |
|--------|--------------|------|----------|-------|
| Title | Title | Single line | Yes | Auto: "{SoPhieu}-{LineNum}" |
| SoPhieuXuat | SoPhieuXuat | Lookup → KHO_PhieuXuat | Yes | FK |
| MaHang | MaHang | Lookup → KHO_DanhMucHang | Yes | |
| SoLuong | SoLuong | Number | Yes | |
| DonGiaXuat | DonGiaXuat | Currency | Yes | |
| ThanhTien | ThanhTien | Calculated | — | = SoLuong * DonGiaXuat |
| GhiChu | GhiChu | Single line | No | |
| **Index:** SoPhieuXuat |

#### VT_DanhMucXe (Vehicle Fleet)
| Column | Internal Name | Type | Required | Notes |
|--------|--------------|------|----------|-------|
| Title | Title | Single line | Yes | Bien so xe (51C-12345) |
| TenXe | TenXe | Single line | No | Model name |
| LoaiXe | LoaiXe | Choice | Yes | Xe tai / Container / Dau keo / Ban tai |
| TaiTrongToiDa | TaiTrongToiDa | Number | Yes | Max load in Tan |
| NamSanXuat | NamSanXuat | Number | No | |
| DangKiemHanDate | DangKiemHanDate | Date Only | Yes | Registration expiry |
| BaoHiemHanDate | BaoHiemHanDate | Date Only | Yes | Insurance expiry |
| TrangThaiXe | TrangThaiXe | Choice | Yes | San sang / Dang chay / Bao tri |
| GhiChu | GhiChu | Multiline | No | |
| **Index:** Title, TrangThaiXe, DangKiemHanDate, BaoHiemHanDate |

#### VT_LaiXe (Drivers)
| Column | Internal Name | Type | Required | Notes |
|--------|--------------|------|----------|-------|
| Title | Title | Single line | Yes | Ma lai xe (LX-001) |
| HoTen | HoTen | Single line | Yes | |
| SoDienThoai | SoDienThoai | Single line | Yes | |
| GPLX_HangLai | GPLX_HangLai | Choice | Yes | B2 / C / D / E / F |
| GPLX_HanDate | GPLX_HanDate | Date Only | Yes | License expiry |
| TrangThai | TrangThai | Choice | Yes | Dang lam / Nghi / Nghi viec |
| GhiChu | GhiChu | Multiline | No | |
| **Index:** Title, TrangThai, GPLX_HanDate |

#### VT_ChuyenHang (Shipment Orders)
| Column | Internal Name | Type | Required | Notes |
|--------|--------------|------|----------|-------|
| Title | Title | Single line | Yes | So lenh (LVC-2026-0001) |
| NgayKhoiHanh | NgayKhoiHanh | Date Only | Yes | |
| BienSoXe | BienSoXe | Lookup → VT_DanhMucXe | Yes | |
| MaLaiXe | MaLaiXe | Lookup → VT_LaiXe | Yes | |
| DiemNhan | DiemNhan | Single line | Yes | Pickup address |
| DiemGiao | DiemGiao | Single line | Yes | Delivery address |
| KhachHang | KhachHang | Single line | No | |
| HangHoaVanChuyen | HangHoaVanChuyen | Multiline | No | Cargo description |
| KhoiLuong | KhoiLuong | Number | No | Tons |
| TrangThai | TrangThai | Choice | Yes | Cho xac nhan / Dang chay / Hoan thanh / Huy |
| GioHoanThanhThucTe | GioHoanThanhThucTe | DateTime | No | |
| CuocPhi | CuocPhi | Currency | No | |
| PhieuCanID | PhieuCanID | Lookup → CAN_PhieuCan | No | Cross-module link (add after CAN list created) |
| GhiChu | GhiChu | Multiline | No | |
| **Index:** Title, NgayKhoiHanh, TrangThai, BienSoXe |

#### VT_ChiPhiXe (Vehicle Expenses)
| Column | Internal Name | Type | Required | Notes |
|--------|--------------|------|----------|-------|
| Title | Title | Single line | Yes | Auto-generated |
| BienSoXe | BienSoXe | Lookup → VT_DanhMucXe | Yes | |
| NgayChi | NgayChi | Date Only | Yes | |
| LoaiChiPhi | LoaiChiPhi | Choice | Yes | Xang dau / Phi cau duong / Sua chua / Bao duong / Khac |
| SoTien | SoTien | Currency | Yes | |
| SoChuyenLienQuan | SoChuyenLienQuan | Lookup → VT_ChuyenHang | No | |
| HinhAnh | HinhAnh | Thumbnail | No | Receipt photo |
| NguoiNhap | NguoiNhap | Person | Yes | |
| GhiChu | GhiChu | Multiline | No | |
| **Index:** BienSoXe, NgayChi, LoaiChiPhi |

#### CAN_PhieuCan (Weighing Tickets)
| Column | Internal Name | Type | Required | Notes |
|--------|--------------|------|----------|-------|
| Title | Title | Single line | Yes | So phieu (PC-2026-0001) |
| NgayCan | NgayCan | DateTime | Yes | |
| BienSoXe | BienSoXe | Lookup → VT_DanhMucXe | No | Nullable for walk-in vehicles |
| BienSoXeText | BienSoXeText | Single line | No | Manual entry for unregistered vehicles |
| TenLaiXe | TenLaiXe | Single line | No | |
| LoaiHang | LoaiHang | Choice | Yes | Nguyen lieu / Thanh pham / Phe lieu / Khac |
| TenHang | TenHang | Single line | No | |
| CanVao_KG | CanVao_KG | Number | No | Weight in (kg) — nullable until weighed |
| GioCanVao | GioCanVao | DateTime | No | |
| CanRa_KG | CanRa_KG | Number | No | Weight out (kg) |
| GioCanRa | GioCanRa | DateTime | No | |
| TrongTaiHang_KG | TrongTaiHang_KG | Number | No | Calculated in Power Apps: Abs(CanVao - CanRa) |
| TaiTrongToiDaXe | TaiTrongToiDaXe | Number | No | Copied from DanhMucXe at creation |
| TinhTrangTaiTrong | TinhTrangTaiTrong | Choice | No | OK / Qua tai |
| NhaMayGiao | NhaMayGiao | Single line | No | |
| NhaMayNhan | NhaMayNhan | Single line | No | |
| NguoiCanVao | NguoiCanVao | Person | No | |
| NguoiCanRa | NguoiCanRa | Person | No | |
| HinhAnhXe | HinhAnhXe | Thumbnail | No | |
| GhiChu | GhiChu | Multiline | No | |
| TrangThai | TrangThai | Choice | Yes | Cho can ra / Hoan thanh / Huy |
| LienKetChuyenHang | LienKetChuyenHang | Lookup → VT_ChuyenHang | No | |
| TramCan | TramCan | Lookup → CAN_TramCan | No | |
| **Index:** Title, NgayCan, BienSoXe, TrangThai |

**Note:** TrongTaiHang_KG is stored as Number (not Calculated) — calculated in Power Apps formula and written back via Patch. This avoids delegation issues with SharePoint Calculated columns.

#### CAN_TramCan (Weighing Stations)
| Column | Internal Name | Type | Required | Notes |
|--------|--------------|------|----------|-------|
| Title | Title | Single line | Yes | Ma tram (TC-01) |
| TenTram | TenTram | Single line | Yes | |
| ViTri | ViTri | Single line | No | Address |
| TaiTrongToiDa_Tan | TaiTrongToiDa_Tan | Number | Yes | Max station capacity |
| TrangThai | TrangThai | Choice | Yes | Hoat dong / Bao tri |

#### KHO_GiaoDichLog (Stock Transaction Queue)
| Column | Internal Name | Type | Required | Notes |
|--------|--------------|------|----------|-------|
| Title | Title | Single line | Yes | Auto: timestamp-based |
| MaHang | MaHang | Single line | Yes | Product code (text, not lookup for speed) |
| LoaiGiaoDich | LoaiGiaoDich | Choice | Yes | NHAP / XUAT |
| SoLuong | SoLuong | Number | Yes | |
| SoPhieuLienQuan | SoPhieuLienQuan | Single line | No | Reference to phieu nhap/xuat |
| Processed | Processed | Yes/No | Yes | Default: No |
| ProcessedDate | ProcessedDate | DateTime | No | |
| ErrorMessage | ErrorMessage | Single line | No | |
| **Index:** Processed, Created |

#### SYS_Counters (Atomic Counters)
| Column | Internal Name | Type | Required | Notes |
|--------|--------------|------|----------|-------|
| Title | Title | Single line | Yes | Counter name (PN-2026, PX-2026, etc.) |
| CurrentValue | CurrentValue | Number | Yes | |
| Prefix | Prefix | Single line | Yes | e.g. "PN", "PX", "LVC", "PC" |
| NamHienTai | NamHienTai | Number | Yes | Year this counter belongs to |

**Seed data:** PN-2026 (0), PX-2026 (0), LVC-2026 (0), PC-2026 (0)

#### AUDIT_Log
| Column | Internal Name | Type | Required | Notes |
|--------|--------------|------|----------|-------|
| Title | Title | Single line | Yes | Auto: timestamp |
| UserEmail | UserEmail | Single line | Yes | |
| UserName | UserName | Single line | Yes | |
| Action | Action | Choice | Yes | Create / Update / Delete / Approve / Reject |
| Module | Module | Choice | Yes | KHO / VT / CAN / SYS |
| RecordType | RecordType | Single line | Yes | List name |
| RecordID | RecordID | Single line | Yes | Item Title/ID |
| Details | Details | Multiline | No | JSON or text description |
| **Index:** Created, Module, Action |

## Related Code Files

### Files to Create
- `scripts/provision-sharepoint-site.ps1` — Main orchestrator
- `scripts/provision-module-kho-lists.ps1` — KHO module lists
- `scripts/provision-module-vantai-lists.ps1` — VT module lists
- `scripts/provision-module-canxe-lists.ps1` — CAN module lists
- `scripts/provision-system-lists.ps1` — System lists
- `scripts/provision-indexes-and-views.ps1` — Indexes + views
- `scripts/seed-counter-data.ps1` — Initial counter values

## Implementation Steps

1. Create `scripts/` directory
2. Write main orchestrator `provision-sharepoint-site.ps1`:
   - Accept params: `$TenantUrl`, `$SiteName`, `$SiteOwner`
   - Connect to SharePoint Online via `Connect-PnPOnline`
   - Create Communication Site
   - Call sub-scripts in dependency order
3. Write `provision-module-kho-lists.ps1`:
   - Create KHO_NhaCungCap, KHO_DanhMucHang (master data first)
   - Create KHO_PhieuNhap, KHO_PhieuXuat (headers)
   - Create KHO_ChiTietNhap, KHO_ChiTietXuat (details)
   - Create KHO_KhachHang, KHO_GiaoDichLog
4. Write `provision-module-vantai-lists.ps1`:
   - Create VT_DanhMucXe, VT_LaiXe (master)
   - Create VT_ChuyenHang (header)
   - Create VT_ChiPhiXe (detail)
5. Write `provision-module-canxe-lists.ps1`:
   - Create CAN_TramCan (master)
   - Create CAN_PhieuCan (with lookups to VT_DanhMucXe, VT_ChuyenHang)
6. Write `provision-system-lists.ps1`:
   - Create SYS_Counters, AUDIT_Log
   - Create all *_Archive lists (same schema as originals, no lookups)
7. Write `provision-indexes-and-views.ps1`:
   - Add indexes as specified per list
   - Create default views: "Active Items", "This Month", "Pending Approval"
8. Write `seed-counter-data.ps1`:
   - Insert initial counter rows for current year
9. Add cross-module lookup columns (PhieuCanID on VT_ChuyenHang, LienKetChuyenHang on CAN_PhieuCan)

## Todo List

- [ ] Create scripts/ directory
- [ ] Write provision-sharepoint-site.ps1 (orchestrator)
- [ ] Write provision-module-kho-lists.ps1
- [ ] Write provision-module-vantai-lists.ps1
- [ ] Write provision-module-canxe-lists.ps1
- [ ] Write provision-system-lists.ps1
- [ ] Write provision-indexes-and-views.ps1
- [ ] Write seed-counter-data.ps1
- [ ] Add cross-module lookups script
- [ ] Test idempotency (re-run without errors)

## Success Criteria

- All scripts run without error on a clean tenant
- All lists created with correct column types and choices
- Indexes applied to delegation-critical columns
- Counter seed data present
- Archive lists mirror transactional list schemas
- Scripts are idempotent

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| PnP module version incompatibility | Medium | Pin to PnP.PowerShell 2.x, test on latest |
| Lookup column creation fails if target list missing | High | Strict creation order in orchestrator |
| SharePoint Online throttling during provisioning | Low | Add `Start-Sleep` between batch operations |
| Calculated columns not delegation-friendly | Medium | Use Number columns + Power Apps formulas instead |

## Security Considerations

- Scripts require SharePoint Admin or Site Collection Admin permissions
- No secrets stored in scripts — credentials via `Connect-PnPOnline -Interactive`
- Site permissions set in Phase 6, not in provisioning scripts
