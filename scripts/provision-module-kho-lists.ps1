<#
.SYNOPSIS
    Provisions all KHO (Warehouse) module SharePoint lists.
.DESCRIPTION
    Creates 8 lists for the KHO module with full column definitions.
    All operations are idempotent – existing lists and fields are skipped.
.PARAMETER SiteUrl
    The target SharePoint site URL.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$SiteUrl
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Re-connect if called standalone ─────────────────────────────────────────
try {
    $ctx = Get-PnPContext
    if ($null -eq $ctx) { throw "No context" }
}
catch {
    Connect-PnPOnline -Url $SiteUrl -Interactive
}

# ── Helper: create list if not exists ───────────────────────────────────────
function Ensure-PnPList {
    param([string]$ListTitle, [string]$Template = "GenericList")
    $list = Get-PnPList -Identity $ListTitle -ErrorAction SilentlyContinue
    if ($null -eq $list) {
        Write-Host "  Creating list: $ListTitle" -ForegroundColor Yellow
        $list = New-PnPList -Title $ListTitle -Template $Template
        Start-Sleep -Milliseconds 500
    }
    else {
        Write-Host "  List exists  : $ListTitle" -ForegroundColor Gray
    }
    return $list
}

# ── Helper: add field if not exists ─────────────────────────────────────────
function Ensure-PnPField {
    param(
        [string]$ListTitle,
        [string]$DisplayName,
        [string]$InternalName,
        [string]$FieldType,
        [hashtable]$ExtraParams = @{}
    )
    $existing = Get-PnPField -List $ListTitle -Identity $InternalName -ErrorAction SilentlyContinue
    if ($null -eq $existing) {
        $params = @{
            List        = $ListTitle
            DisplayName = $DisplayName
            InternalName = $InternalName
            Type        = $FieldType
            AddToDefaultView = $true
        } + $ExtraParams
        Add-PnPField @params | Out-Null
    }
}

# ── Helper: add Choice field if not exists ───────────────────────────────────
function Ensure-PnPChoiceField {
    param(
        [string]$ListTitle,
        [string]$DisplayName,
        [string]$InternalName,
        [string[]]$Choices,
        [string]$DefaultValue = ""
    )
    $existing = Get-PnPField -List $ListTitle -Identity $InternalName -ErrorAction SilentlyContinue
    if ($null -eq $existing) {
        $choiceXml = "<Field Type='Choice' DisplayName='$DisplayName' Name='$InternalName' StaticName='$InternalName'>"
        if ($DefaultValue) { $choiceXml += "<Default>$DefaultValue</Default>" }
        $choiceXml += "<CHOICES>"
        foreach ($c in $Choices) { $choiceXml += "<CHOICE>$c</CHOICE>" }
        $choiceXml += "</CHOICES></Field>"
        Add-PnPFieldFromXml -List $ListTitle -FieldXml $choiceXml | Out-Null
    }
}

# ── Helper: add Lookup field if not exists ───────────────────────────────────
function Ensure-PnPLookupField {
    param(
        [string]$ListTitle,
        [string]$DisplayName,
        [string]$InternalName,
        [string]$LookupList,
        [string]$LookupField = "Title"
    )
    $existing = Get-PnPField -List $ListTitle -Identity $InternalName -ErrorAction SilentlyContinue
    if ($null -eq $existing) {
        Add-PnPField -List $ListTitle `
            -DisplayName $DisplayName `
            -InternalName $InternalName `
            -Type Lookup `
            -AddToDefaultView $true `
            -LookupList $LookupList `
            -LookupField $LookupField | Out-Null
    }
}

# ════════════════════════════════════════════════════════════════════════════
# 1. KHO_NhaCungCap  (Suppliers)
# ════════════════════════════════════════════════════════════════════════════
Write-Host "`n[KHO] KHO_NhaCungCap" -ForegroundColor Cyan
Ensure-PnPList "KHO_NhaCungCap"
Ensure-PnPField       "KHO_NhaCungCap" "Ten NCC"        "TenNCC"       "Text"
Ensure-PnPField       "KHO_NhaCungCap" "Dia Chi"        "DiaChi"       "Note"
Ensure-PnPField       "KHO_NhaCungCap" "So Dien Thoai"  "SoDienThoai"  "Text"
Ensure-PnPField       "KHO_NhaCungCap" "Email"          "Email"        "Text"
Ensure-PnPField       "KHO_NhaCungCap" "Ma So Thue"     "MaSoThue"     "Text"
Ensure-PnPChoiceField "KHO_NhaCungCap" "Trang Thai"     "TrangThai"    @("Hoat dong","Ngung") "Hoat dong"

# ════════════════════════════════════════════════════════════════════════════
# 2. KHO_DanhMucHang  (Item Catalogue)
# ════════════════════════════════════════════════════════════════════════════
Write-Host "`n[KHO] KHO_DanhMucHang" -ForegroundColor Cyan
Ensure-PnPList "KHO_DanhMucHang"
Ensure-PnPField       "KHO_DanhMucHang" "Ten Hang"         "TenHang"          "Text"
Ensure-PnPChoiceField "KHO_DanhMucHang" "Nhom Hang"        "NhomHang"         @("Nguyen lieu","Thanh pham","Bao bi","Phu tung","Khac")
Ensure-PnPChoiceField "KHO_DanhMucHang" "Don Vi Tinh"      "DonViTinh"        @("Kg","Tan","Thung","Chiec","Lit","Bao","Cuon")
Ensure-PnPField       "KHO_DanhMucHang" "Ton Kho Toi Thieu" "TonKhoToiThieu"  "Number"
Ensure-PnPField       "KHO_DanhMucHang" "Ton Kho Hien Tai" "TonKhoHienTai"   "Number" @{ DefaultValue = "0" }
Ensure-PnPField       "KHO_DanhMucHang" "Vi Tri Kho"       "ViTriKho"         "Text"
Ensure-PnPField       "KHO_DanhMucHang" "Mo Ta"            "MoTa"             "Note"
Ensure-PnPChoiceField "KHO_DanhMucHang" "Trang Thai"       "TrangThai"        @("Dang dung","Ngung") "Dang dung"

# ════════════════════════════════════════════════════════════════════════════
# 3. KHO_PhieuNhap  (Goods Receipt Header)
# ════════════════════════════════════════════════════════════════════════════
Write-Host "`n[KHO] KHO_PhieuNhap" -ForegroundColor Cyan
Ensure-PnPList "KHO_PhieuNhap"
Ensure-PnPField       "KHO_PhieuNhap" "Ngay Nhap"    "NgayNhap"    "DateTime" @{ DateOnly = $true }
Ensure-PnPLookupField "KHO_PhieuNhap" "Nha Cung Cap" "NhaCungCap"  "KHO_NhaCungCap"
Ensure-PnPField       "KHO_PhieuNhap" "So Hoa Don"   "SoHoaDon"    "Text"
Ensure-PnPChoiceField "KHO_PhieuNhap" "Trang Thai"   "TrangThai"   @("Nhap","Cho duyet","Da duyet","Tu choi") "Nhap"
Ensure-PnPField       "KHO_PhieuNhap" "Nguoi Nhap"   "NguoiNhap"   "User"
Ensure-PnPField       "KHO_PhieuNhap" "Nguoi Duyet"  "NguoiDuyet"  "User"
Ensure-PnPField       "KHO_PhieuNhap" "Ngay Duyet"   "NgayDuyet"   "DateTime" @{ DateOnly = $true }
Ensure-PnPField       "KHO_PhieuNhap" "Ghi Chu"      "GhiChu"      "Note"

# ════════════════════════════════════════════════════════════════════════════
# 4. KHO_ChiTietNhap  (Goods Receipt Line Items)
# ════════════════════════════════════════════════════════════════════════════
Write-Host "`n[KHO] KHO_ChiTietNhap" -ForegroundColor Cyan
Ensure-PnPList "KHO_ChiTietNhap"
Ensure-PnPLookupField "KHO_ChiTietNhap" "So Phieu Nhap"      "SoPhieuNhap"      "KHO_PhieuNhap"
Ensure-PnPLookupField "KHO_ChiTietNhap" "Ma Hang"            "MaHang"           "KHO_DanhMucHang"
Ensure-PnPField       "KHO_ChiTietNhap" "So Luong"           "SoLuong"          "Number"
Ensure-PnPField       "KHO_ChiTietNhap" "Don Gia Nhap"       "DonGiaNhap"       "Currency"
Ensure-PnPField       "KHO_ChiTietNhap" "So Luong Thuc Nhan" "SoLuongThucNhan"  "Number"
Ensure-PnPField       "KHO_ChiTietNhap" "Ghi Chu"            "GhiChu"           "Text"

# ════════════════════════════════════════════════════════════════════════════
# 5. KHO_PhieuXuat  (Goods Issue Header)
# ════════════════════════════════════════════════════════════════════════════
Write-Host "`n[KHO] KHO_PhieuXuat" -ForegroundColor Cyan
Ensure-PnPList "KHO_PhieuXuat"
Ensure-PnPField       "KHO_PhieuXuat" "Ngay Xuat"   "NgayXuat"   "DateTime" @{ DateOnly = $true }
Ensure-PnPField       "KHO_PhieuXuat" "Khach Hang"  "KhachHang"  "Text"
Ensure-PnPChoiceField "KHO_PhieuXuat" "Muc Dich Xuat" "MucDichXuat" @("Ban hang","Noi bo","Tra hang")
Ensure-PnPChoiceField "KHO_PhieuXuat" "Trang Thai"  "TrangThai"  @("Nhap","Cho duyet","Da duyet","Tu choi") "Nhap"
Ensure-PnPField       "KHO_PhieuXuat" "Nguoi Xuat"  "NguoiXuat"  "User"
Ensure-PnPField       "KHO_PhieuXuat" "Nguoi Duyet" "NguoiDuyet" "User"
Ensure-PnPField       "KHO_PhieuXuat" "Ghi Chu"     "GhiChu"     "Note"

# ════════════════════════════════════════════════════════════════════════════
# 6. KHO_ChiTietXuat  (Goods Issue Line Items)
# ════════════════════════════════════════════════════════════════════════════
Write-Host "`n[KHO] KHO_ChiTietXuat" -ForegroundColor Cyan
Ensure-PnPList "KHO_ChiTietXuat"
Ensure-PnPLookupField "KHO_ChiTietXuat" "So Phieu Xuat" "SoPhieuXuat" "KHO_PhieuXuat"
Ensure-PnPLookupField "KHO_ChiTietXuat" "Ma Hang"       "MaHang"      "KHO_DanhMucHang"
Ensure-PnPField       "KHO_ChiTietXuat" "So Luong"      "SoLuong"     "Number"
Ensure-PnPField       "KHO_ChiTietXuat" "Don Gia Xuat"  "DonGiaXuat"  "Currency"
Ensure-PnPField       "KHO_ChiTietXuat" "Ghi Chu"       "GhiChu"      "Text"

# ════════════════════════════════════════════════════════════════════════════
# 7. KHO_GiaoDichLog  (Transaction Log / inventory movement queue)
# ════════════════════════════════════════════════════════════════════════════
Write-Host "`n[KHO] KHO_GiaoDichLog" -ForegroundColor Cyan
Ensure-PnPList "KHO_GiaoDichLog"
Ensure-PnPField       "KHO_GiaoDichLog" "Ma Hang"          "MaHang"          "Text"
Ensure-PnPChoiceField "KHO_GiaoDichLog" "Loai Giao Dich"   "LoaiGiaoDich"    @("NHAP","XUAT")
Ensure-PnPField       "KHO_GiaoDichLog" "So Luong"         "SoLuong"         "Number"
Ensure-PnPField       "KHO_GiaoDichLog" "So Phieu Lien Quan" "SoPhieuLienQuan" "Text"
Ensure-PnPField       "KHO_GiaoDichLog" "Processed"        "Processed"       "Boolean" @{ DefaultValue = "0" }
Ensure-PnPField       "KHO_GiaoDichLog" "Processed Date"   "ProcessedDate"   "DateTime"
Ensure-PnPField       "KHO_GiaoDichLog" "Error Message"    "ErrorMessage"    "Text"

# ════════════════════════════════════════════════════════════════════════════
# 8. KHO_KhachHang  (Customers)
# ════════════════════════════════════════════════════════════════════════════
Write-Host "`n[KHO] KHO_KhachHang" -ForegroundColor Cyan
Ensure-PnPList "KHO_KhachHang"
Ensure-PnPField       "KHO_KhachHang" "Ten KH"        "TenKH"       "Text"
Ensure-PnPField       "KHO_KhachHang" "Dia Chi"        "DiaChi"      "Note"
Ensure-PnPField       "KHO_KhachHang" "So Dien Thoai"  "SoDienThoai" "Text"
Ensure-PnPField       "KHO_KhachHang" "Email"          "Email"       "Text"
Ensure-PnPChoiceField "KHO_KhachHang" "Trang Thai"     "TrangThai"   @("Hoat dong","Ngung") "Hoat dong"

Write-Host "`n[KHO] All KHO lists provisioned successfully." -ForegroundColor Green
