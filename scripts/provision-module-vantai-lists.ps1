<#
.SYNOPSIS
    Provisions all VT (Van Tai / Transport) module SharePoint lists.
.DESCRIPTION
    Creates 4 lists for the VT module with full column definitions.
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

# ── Helper: add simple field if not exists ──────────────────────────────────
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
            List             = $ListTitle
            DisplayName      = $DisplayName
            InternalName     = $InternalName
            Type             = $FieldType
            AddToDefaultView = $true
        } + $ExtraParams
        Add-PnPField @params | Out-Null
    }
}

# ── Helper: add Choice field if not exists ──────────────────────────────────
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

# ── Helper: add Lookup field if not exists ──────────────────────────────────
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
# 1. VT_DanhMucXe  (Vehicle Registry)
# ════════════════════════════════════════════════════════════════════════════
Write-Host "`n[VT] VT_DanhMucXe" -ForegroundColor Cyan
Ensure-PnPList "VT_DanhMucXe"
# Title = Bien So Xe (plate number, PK)
Ensure-PnPField       "VT_DanhMucXe" "Ten Xe"              "TenXe"           "Text"
Ensure-PnPChoiceField "VT_DanhMucXe" "Loai Xe"             "LoaiXe"          @("Xe tai","Container","Dau keo","Ban tai")
Ensure-PnPField       "VT_DanhMucXe" "Tai Trong Toi Da"    "TaiTrongToiDa"   "Number"
Ensure-PnPField       "VT_DanhMucXe" "Nam San Xuat"        "NamSanXuat"      "Number"
Ensure-PnPField       "VT_DanhMucXe" "Dang Kiem Han"       "DangKiemHanDate" "DateTime" @{ DateOnly = $true }
Ensure-PnPField       "VT_DanhMucXe" "Bao Hiem Han"        "BaoHiemHanDate"  "DateTime" @{ DateOnly = $true }
Ensure-PnPChoiceField "VT_DanhMucXe" "Trang Thai Xe"       "TrangThaiXe"     @("San sang","Dang chay","Bao tri") "San sang"
Ensure-PnPField       "VT_DanhMucXe" "Ghi Chu"             "GhiChu"          "Note"

# ════════════════════════════════════════════════════════════════════════════
# 2. VT_LaiXe  (Drivers)
# ════════════════════════════════════════════════════════════════════════════
Write-Host "`n[VT] VT_LaiXe" -ForegroundColor Cyan
Ensure-PnPList "VT_LaiXe"
# Title = Ma Lai Xe (driver code, PK)
Ensure-PnPField       "VT_LaiXe" "Ho Ten"       "HoTen"       "Text"
Ensure-PnPField       "VT_LaiXe" "So Dien Thoai" "SoDienThoai" "Text"
Ensure-PnPChoiceField "VT_LaiXe" "GPLX Hang Lai" "GPLX_HangLai" @("B2","C","D","E","F")
Ensure-PnPField       "VT_LaiXe" "GPLX Han"     "GPLX_HanDate" "DateTime" @{ DateOnly = $true }
Ensure-PnPChoiceField "VT_LaiXe" "Trang Thai"   "TrangThai"   @("Dang lam","Nghi","Nghi viec") "Dang lam"
Ensure-PnPField       "VT_LaiXe" "Ghi Chu"      "GhiChu"      "Note"

# ════════════════════════════════════════════════════════════════════════════
# 3. VT_ChuyenHang  (Shipment Orders)
# ════════════════════════════════════════════════════════════════════════════
Write-Host "`n[VT] VT_ChuyenHang" -ForegroundColor Cyan
Ensure-PnPList "VT_ChuyenHang"
# Title = So Lenh Van Chuyen (dispatch order number, PK)
Ensure-PnPField       "VT_ChuyenHang" "Ngay Khoi Hanh"       "NgayKhoiHanh"        "DateTime" @{ DateOnly = $true }
Ensure-PnPLookupField "VT_ChuyenHang" "Bien So Xe"           "BienSoXe"            "VT_DanhMucXe"
Ensure-PnPLookupField "VT_ChuyenHang" "Ma Lai Xe"            "MaLaiXe"             "VT_LaiXe"
Ensure-PnPField       "VT_ChuyenHang" "Diem Nhan"            "DiemNhan"            "Text"
Ensure-PnPField       "VT_ChuyenHang" "Diem Giao"            "DiemGiao"            "Text"
Ensure-PnPField       "VT_ChuyenHang" "Khach Hang"           "KhachHang"           "Text"
Ensure-PnPField       "VT_ChuyenHang" "Hang Hoa Van Chuyen"  "HangHoaVanChuyen"    "Note"
Ensure-PnPField       "VT_ChuyenHang" "Khoi Luong"           "KhoiLuong"           "Number"
Ensure-PnPChoiceField "VT_ChuyenHang" "Trang Thai"           "TrangThai"           @("Cho xac nhan","Dang chay","Hoan thanh","Huy") "Cho xac nhan"
Ensure-PnPField       "VT_ChuyenHang" "Gio Hoan Thanh Thuc Te" "GioHoanThanhThucTe" "DateTime"
Ensure-PnPField       "VT_ChuyenHang" "Cuoc Phi"             "CuocPhi"             "Currency"
Ensure-PnPField       "VT_ChuyenHang" "Ghi Chu"              "GhiChu"              "Note"

# ════════════════════════════════════════════════════════════════════════════
# 4. VT_ChiPhiXe  (Vehicle Expenses)
# ════════════════════════════════════════════════════════════════════════════
Write-Host "`n[VT] VT_ChiPhiXe" -ForegroundColor Cyan
Ensure-PnPList "VT_ChiPhiXe"
Ensure-PnPLookupField "VT_ChiPhiXe" "Bien So Xe"         "BienSoXe"         "VT_DanhMucXe"
Ensure-PnPField       "VT_ChiPhiXe" "Ngay Chi"           "NgayChi"          "DateTime" @{ DateOnly = $true }
Ensure-PnPChoiceField "VT_ChiPhiXe" "Loai Chi Phi"       "LoaiChiPhi"       @("Xang dau","Phi cau duong","Sua chua","Bao duong","Khac")
Ensure-PnPField       "VT_ChiPhiXe" "So Tien"            "SoTien"           "Currency"
Ensure-PnPLookupField "VT_ChiPhiXe" "So Chuyen Lien Quan" "SoChuyenLienQuan" "VT_ChuyenHang"
Ensure-PnPField       "VT_ChiPhiXe" "Nguoi Nhap"         "NguoiNhap"        "User"
Ensure-PnPField       "VT_ChiPhiXe" "Ghi Chu"            "GhiChu"           "Note"

Write-Host "`n[VT] All VT lists provisioned successfully." -ForegroundColor Green
