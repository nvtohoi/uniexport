<#
.SYNOPSIS
    Provisions system-wide and shared SharePoint lists.
.DESCRIPTION
    Creates SYS_Counters, AUDIT_Log, and CAN_TramCan lists.
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

# ════════════════════════════════════════════════════════════════════════════
# 1. SYS_Counters  (Auto-number sequence store)
# ════════════════════════════════════════════════════════════════════════════
Write-Host "`n[SYS] SYS_Counters" -ForegroundColor Cyan
Ensure-PnPList "SYS_Counters"
# Title = counter name (PK), e.g. "PN-2026"
Ensure-PnPField "SYS_Counters" "Current Value" "CurrentValue"  "Number" @{ DefaultValue = "0" }
Ensure-PnPField "SYS_Counters" "Prefix"        "Prefix"        "Text"
Ensure-PnPField "SYS_Counters" "Nam Hien Tai"  "NamHienTai"   "Number"

# ════════════════════════════════════════════════════════════════════════════
# 2. AUDIT_Log  (System-wide audit trail)
# ════════════════════════════════════════════════════════════════════════════
Write-Host "`n[SYS] AUDIT_Log" -ForegroundColor Cyan
Ensure-PnPList "AUDIT_Log"
Ensure-PnPField       "AUDIT_Log" "User Email"  "UserEmail"   "Text"
Ensure-PnPField       "AUDIT_Log" "User Name"   "UserName"    "Text"
Ensure-PnPChoiceField "AUDIT_Log" "Action"      "Action"      @("Create","Update","Delete","Approve","Reject")
Ensure-PnPChoiceField "AUDIT_Log" "Module"      "Module"      @("KHO","VT","CAN","SYS")
Ensure-PnPField       "AUDIT_Log" "Record Type" "RecordType"  "Text"
Ensure-PnPField       "AUDIT_Log" "Record ID"   "RecordID"    "Text"
Ensure-PnPField       "AUDIT_Log" "Details"     "Details"     "Note"

# ════════════════════════════════════════════════════════════════════════════
# 3. CAN_TramCan  (Weighbridge Stations)
# ════════════════════════════════════════════════════════════════════════════
Write-Host "`n[SYS] CAN_TramCan" -ForegroundColor Cyan
Ensure-PnPList "CAN_TramCan"
# Title = tram can code (PK)
Ensure-PnPField       "CAN_TramCan" "Ten Tram"         "TenTram"          "Text"
Ensure-PnPField       "CAN_TramCan" "Vi Tri"           "ViTri"            "Text"
Ensure-PnPField       "CAN_TramCan" "Tai Trong Toi Da" "TaiTrongToiDa_Tan" "Number"
Ensure-PnPChoiceField "CAN_TramCan" "Trang Thai"       "TrangThai"        @("Hoat dong","Bao tri") "Hoat dong"

Write-Host "`n[SYS] All system lists provisioned successfully." -ForegroundColor Green
