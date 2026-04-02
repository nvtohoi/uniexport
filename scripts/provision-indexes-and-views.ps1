<#
.SYNOPSIS
    Adds column indexes to all WMS SharePoint lists for query performance.
.DESCRIPTION
    Indexes are idempotent – script checks for existing indexes before adding.
    Covers KHO, VT, and SYS/AUDIT lists.
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

# ── Helper: add index on a field if not already indexed ─────────────────────
function Ensure-PnPFieldIndex {
    param(
        [string]$ListTitle,
        [string]$FieldInternalName
    )
    try {
        $field = Get-PnPField -List $ListTitle -Identity $FieldInternalName -ErrorAction SilentlyContinue
        if ($null -eq $field) {
            Write-Host "  SKIP (field not found): $ListTitle.$FieldInternalName" -ForegroundColor DarkGray
            return
        }
        if ($field.Indexed) {
            Write-Host "  Index exists : $ListTitle.$FieldInternalName" -ForegroundColor Gray
            return
        }
        # Set-PnPField updates field properties; Indexed = true adds the index
        Set-PnPField -List $ListTitle -Identity $FieldInternalName -Values @{ Indexed = $true } | Out-Null
        Write-Host "  Index added  : $ListTitle.$FieldInternalName" -ForegroundColor Yellow
        Start-Sleep -Milliseconds 200
    }
    catch {
        Write-Warning "  Failed to index $ListTitle.$FieldInternalName : $_"
    }
}

# ════════════════════════════════════════════════════════════════════════════
# KHO Module indexes
# ════════════════════════════════════════════════════════════════════════════
Write-Host "`n[IDX] KHO_NhaCungCap" -ForegroundColor Cyan
Ensure-PnPFieldIndex "KHO_NhaCungCap" "Title"
Ensure-PnPFieldIndex "KHO_NhaCungCap" "TrangThai"

Write-Host "`n[IDX] KHO_DanhMucHang" -ForegroundColor Cyan
Ensure-PnPFieldIndex "KHO_DanhMucHang" "Title"
Ensure-PnPFieldIndex "KHO_DanhMucHang" "TrangThai"
Ensure-PnPFieldIndex "KHO_DanhMucHang" "TonKhoHienTai"

Write-Host "`n[IDX] KHO_PhieuNhap" -ForegroundColor Cyan
Ensure-PnPFieldIndex "KHO_PhieuNhap" "Title"
Ensure-PnPFieldIndex "KHO_PhieuNhap" "NgayNhap"
Ensure-PnPFieldIndex "KHO_PhieuNhap" "TrangThai"

Write-Host "`n[IDX] KHO_ChiTietNhap" -ForegroundColor Cyan
Ensure-PnPFieldIndex "KHO_ChiTietNhap" "SoPhieuNhap"

Write-Host "`n[IDX] KHO_PhieuXuat" -ForegroundColor Cyan
Ensure-PnPFieldIndex "KHO_PhieuXuat" "Title"
Ensure-PnPFieldIndex "KHO_PhieuXuat" "NgayXuat"
Ensure-PnPFieldIndex "KHO_PhieuXuat" "TrangThai"

Write-Host "`n[IDX] KHO_ChiTietXuat" -ForegroundColor Cyan
Ensure-PnPFieldIndex "KHO_ChiTietXuat" "SoPhieuXuat"

Write-Host "`n[IDX] KHO_GiaoDichLog" -ForegroundColor Cyan
Ensure-PnPFieldIndex "KHO_GiaoDichLog" "Processed"

# ════════════════════════════════════════════════════════════════════════════
# VT Module indexes
# ════════════════════════════════════════════════════════════════════════════
Write-Host "`n[IDX] VT_DanhMucXe" -ForegroundColor Cyan
Ensure-PnPFieldIndex "VT_DanhMucXe" "Title"
Ensure-PnPFieldIndex "VT_DanhMucXe" "TrangThaiXe"
Ensure-PnPFieldIndex "VT_DanhMucXe" "DangKiemHanDate"
Ensure-PnPFieldIndex "VT_DanhMucXe" "BaoHiemHanDate"

Write-Host "`n[IDX] VT_LaiXe" -ForegroundColor Cyan
Ensure-PnPFieldIndex "VT_LaiXe" "Title"
Ensure-PnPFieldIndex "VT_LaiXe" "TrangThai"
Ensure-PnPFieldIndex "VT_LaiXe" "GPLX_HanDate"

Write-Host "`n[IDX] VT_ChuyenHang" -ForegroundColor Cyan
Ensure-PnPFieldIndex "VT_ChuyenHang" "Title"
Ensure-PnPFieldIndex "VT_ChuyenHang" "NgayKhoiHanh"
Ensure-PnPFieldIndex "VT_ChuyenHang" "TrangThai"
Ensure-PnPFieldIndex "VT_ChuyenHang" "BienSoXe"

Write-Host "`n[IDX] VT_ChiPhiXe" -ForegroundColor Cyan
Ensure-PnPFieldIndex "VT_ChiPhiXe" "BienSoXe"
Ensure-PnPFieldIndex "VT_ChiPhiXe" "NgayChi"
Ensure-PnPFieldIndex "VT_ChiPhiXe" "LoaiChiPhi"

# ════════════════════════════════════════════════════════════════════════════
# AUDIT_Log indexes
# ════════════════════════════════════════════════════════════════════════════
Write-Host "`n[IDX] AUDIT_Log" -ForegroundColor Cyan
Ensure-PnPFieldIndex "AUDIT_Log" "Module"
Ensure-PnPFieldIndex "AUDIT_Log" "Action"

Write-Host "`n[IDX] All indexes applied successfully." -ForegroundColor Green
