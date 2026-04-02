<#
.SYNOPSIS
    Main orchestrator for WMS SharePoint Online site provisioning.
.DESCRIPTION
    Creates or connects to a Communication Site and runs all sub-scripts
    in dependency order with idempotency checks throughout.
.PARAMETER TenantUrl
    The SharePoint tenant URL, e.g. https://contoso.sharepoint.com
.PARAMETER SiteName
    The site URL suffix, e.g. "wms" → https://contoso.sharepoint.com/sites/wms
.PARAMETER SiteOwner
    The UPN of the site owner, e.g. admin@contoso.com
.EXAMPLE
    .\provision-sharepoint-site.ps1 -TenantUrl "https://contoso.sharepoint.com" -SiteName "wms" -SiteOwner "admin@contoso.com"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantUrl,

    [Parameter(Mandatory = $true)]
    [string]$SiteName,

    [Parameter(Mandatory = $true)]
    [string]$SiteOwner
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Derived values ──────────────────────────────────────────────────────────
$SiteUrl = "$TenantUrl/sites/$SiteName"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=== WMS SharePoint Provisioning ===" -ForegroundColor Cyan
Write-Host "Tenant : $TenantUrl"
Write-Host "Site   : $SiteUrl"
Write-Host "Owner  : $SiteOwner"
Write-Host ""

# ── Step 1: Connect to SharePoint Online ────────────────────────────────────
Write-Host "[1/7] Connecting to SharePoint Online..." -ForegroundColor Yellow
try {
    Connect-PnPOnline -Url $TenantUrl -Interactive
    Write-Host "      Connected to tenant." -ForegroundColor Green
}
catch {
    Write-Error "Failed to connect to $TenantUrl: $_"
    exit 1
}

# ── Step 2: Create Communication Site if not exists ─────────────────────────
Write-Host "[2/7] Checking / creating site $SiteUrl..." -ForegroundColor Yellow
try {
    $existingSite = Get-PnPTenantSite -Url $SiteUrl -ErrorAction SilentlyContinue
    if ($null -eq $existingSite) {
        Write-Host "      Site not found – creating Communication Site..." -ForegroundColor Yellow
        New-PnPSite -Type CommunicationSite `
            -Title "WMS - Warehouse Management System" `
            -Url $SiteUrl `
            -Owner $SiteOwner `
            -Lcid 1066
        Write-Host "      Site created." -ForegroundColor Green
        # Wait for provisioning to complete
        Start-Sleep -Seconds 30
    }
    else {
        Write-Host "      Site already exists – skipping creation." -ForegroundColor Green
    }
}
catch {
    Write-Error "Failed to create/verify site $SiteUrl: $_"
    exit 1
}

# ── Step 3: Re-connect to the provisioned site ───────────────────────────────
Write-Host "[3/7] Connecting to site $SiteUrl..." -ForegroundColor Yellow
try {
    Connect-PnPOnline -Url $SiteUrl -Interactive
    Write-Host "      Connected to site." -ForegroundColor Green
}
catch {
    Write-Error "Failed to connect to site $SiteUrl: $_"
    exit 1
}

# ── Step 4: System lists (no dependencies) ───────────────────────────────────
Write-Host "[4/7] Provisioning system lists..." -ForegroundColor Yellow
try {
    & "$ScriptDir\provision-system-lists.ps1" -SiteUrl $SiteUrl
    Write-Host "      System lists done." -ForegroundColor Green
}
catch {
    Write-Error "provision-system-lists.ps1 failed: $_"
    exit 1
}

# ── Step 5: KHO module lists ─────────────────────────────────────────────────
Write-Host "[5/7] Provisioning KHO (warehouse) lists..." -ForegroundColor Yellow
try {
    & "$ScriptDir\provision-module-kho-lists.ps1" -SiteUrl $SiteUrl
    Write-Host "      KHO lists done." -ForegroundColor Green
}
catch {
    Write-Error "provision-module-kho-lists.ps1 failed: $_"
    exit 1
}

# ── Step 6: VT module lists ──────────────────────────────────────────────────
Write-Host "[6/7] Provisioning VT (transport) lists..." -ForegroundColor Yellow
try {
    & "$ScriptDir\provision-module-vantai-lists.ps1" -SiteUrl $SiteUrl
    Write-Host "      VT lists done." -ForegroundColor Green
}
catch {
    Write-Error "provision-module-vantai-lists.ps1 failed: $_"
    exit 1
}

# ── Step 7: Indexes, views, and seed data ────────────────────────────────────
Write-Host "[7/7] Adding indexes/views and seeding counter data..." -ForegroundColor Yellow
try {
    & "$ScriptDir\provision-indexes-and-views.ps1" -SiteUrl $SiteUrl
    Write-Host "      Indexes and views done." -ForegroundColor Green

    & "$ScriptDir\seed-counter-data.ps1" -SiteUrl $SiteUrl
    Write-Host "      Counter seed data done." -ForegroundColor Green
}
catch {
    Write-Error "Post-provisioning step failed: $_"
    exit 1
}

Write-Host ""
Write-Host "=== Provisioning complete ===" -ForegroundColor Cyan
Write-Host "Site URL: $SiteUrl"
