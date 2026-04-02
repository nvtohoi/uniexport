<#
.SYNOPSIS
    Seeds initial counter rows into the SYS_Counters list.
.DESCRIPTION
    Inserts one row per counter sequence used by the WMS system.
    Idempotent: checks for an existing item with the same Title before inserting.
    Run after provision-system-lists.ps1.
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

$ListName = "SYS_Counters"

# ── Helper: upsert a counter row ─────────────────────────────────────────────
function Ensure-CounterRow {
    param(
        [string]$Title,
        [int]$CurrentValue,
        [string]$Prefix,
        [int]$NamHienTai
    )
    $existing = Get-PnPListItem -List $ListName `
        -Query "<View><Query><Where><Eq><FieldRef Name='Title'/><Value Type='Text'>$Title</Value></Eq></Where></Query></View>" `
        -ErrorAction SilentlyContinue

    if ($existing -and $existing.Count -gt 0) {
        Write-Host "  Counter exists   : $Title" -ForegroundColor Gray
    }
    else {
        Add-PnPListItem -List $ListName -Values @{
            Title        = $Title
            CurrentValue = $CurrentValue
            Prefix       = $Prefix
            NamHienTai   = $NamHienTai
        } | Out-Null
        Write-Host "  Counter inserted : $Title  (prefix=$Prefix, year=$NamHienTai)" -ForegroundColor Yellow
    }
}

# ── Seed rows ────────────────────────────────────────────────────────────────
Write-Host "`n[SEED] Seeding SYS_Counters..." -ForegroundColor Cyan

# Phieu Nhap (Goods Receipt) sequence
Ensure-CounterRow -Title "PN-2026"  -CurrentValue 0 -Prefix "PN"  -NamHienTai 2026

# Phieu Xuat (Goods Issue) sequence
Ensure-CounterRow -Title "PX-2026"  -CurrentValue 0 -Prefix "PX"  -NamHienTai 2026

# Lenh Van Chuyen (Transport Order) sequence
Ensure-CounterRow -Title "LVC-2026" -CurrentValue 0 -Prefix "LVC" -NamHienTai 2026

# Phieu Chi (Expense Voucher) sequence
Ensure-CounterRow -Title "PC-2026"  -CurrentValue 0 -Prefix "PC"  -NamHienTai 2026

Write-Host "`n[SEED] Counter seeding complete." -ForegroundColor Green
