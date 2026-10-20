<#
.SYNOPSIS
    Phát hành bộ cài của một app lên trongtkm/updates và cập nhật <app>/latest.json.

.DESCRIPTION
    1. Tính SHA256 của bộ cài.
    2. Tạo GitHub Release tag <app>-v<version> và tải bộ cài lên (gh CLI).
    3. Ghi <app>/latest.json (UTF-8 không BOM), commit và push lên main.
    Thứ tự này bảo đảm manifest không bao giờ trỏ tới file chưa tồn tại.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9-]+$')]
    [string]$App,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+(\.\d+){1,3}$')]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [string]$Installer,

    [string]$Notes = "",

    [switch]$Mandatory,

    [string]$MinVersion,

    [string]$Repo = "trongtkm/updates",

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$installerPath = (Resolve-Path $Installer).Path
$assetName = Split-Path -Leaf $installerPath
$tag = "$App-v$Version"

# Gõ nhầm -Version là phát hành sai ngay, nên so với ProductVersion của chính file .exe.
$fileVersion = (Get-Item -LiteralPath $installerPath).VersionInfo.ProductVersion
if ($fileVersion) { $fileVersion = $fileVersion.Trim() }
if ($fileVersion -and ($fileVersion -ne $Version)) {
    throw "Version $Version không khớp ProductVersion của bộ cài ($fileVersion)."
}

# Không cho phát hành lùi phiên bản so với latest.json đang có.
$currentManifest = Join-Path (Join-Path $root $App) "latest.json"
if (Test-Path -LiteralPath $currentManifest) {
    $currentVersion = (Get-Content -LiteralPath $currentManifest -Raw -Encoding UTF8 | ConvertFrom-Json).version
    if ($currentVersion -and ([version]$Version -le [version]$currentVersion)) {
        throw "Version $Version không mới hơn bản đang phát hành ($currentVersion)."
    }
}

if (-not $DryRun) {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw "Chưa có GitHub CLI (gh). Cài từ https://cli.github.com/ rồi chạy 'gh auth login'."
    }
    Push-Location $root
    try {
        if (git status --porcelain) { throw "Repo updates còn thay đổi chưa commit. Dọn trước rồi chạy lại." }
        git pull --ff-only
        if ($LASTEXITCODE -ne 0) { throw "git pull thất bại." }
    } finally { Pop-Location }
}

$sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $installerPath).Hash
Write-Host "Bộ cài : $installerPath"
Write-Host "SHA256 : $sha256"
Write-Host "Tag    : $tag"

$downloadUrl = "https://github.com/$Repo/releases/download/$tag/$assetName"
$releaseUrl = "https://github.com/$Repo/releases/tag/$tag"

$manifest = [ordered]@{
    app       = $App
    version   = $Version
    url       = $downloadUrl
    changelog = $releaseUrl
    notes     = $Notes
    published = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    mandatory = [ordered]@{
        value      = [bool]$Mandatory
        minVersion = $(if ($MinVersion) { $MinVersion } else { $null })
        mode       = 0
    }
    checksum  = [ordered]@{
        value            = $sha256
        hashingAlgorithm = "SHA256"
    }
}
$json = $manifest | ConvertTo-Json -Depth 5

if ($DryRun) {
    Write-Host "`n[DryRun] latest.json sẽ là:`n$json"
    return
}

$notesText = if ($Notes) { $Notes } else { "$App $Version" }
$notesText += "`n`nSHA256: ``$sha256``"

gh release create $tag $installerPath --repo $Repo --title "$App $Version" --notes $notesText
if ($LASTEXITCODE -ne 0) { throw "Tạo release $tag thất bại (tag đã có?)." }

$appDir = Join-Path $root $App
New-Item -ItemType Directory -Force -Path $appDir | Out-Null
$manifestPath = Join-Path $appDir "latest.json"
[System.IO.File]::WriteAllText($manifestPath, $json + "`n", (New-Object System.Text.UTF8Encoding($false)))

Push-Location $root
try {
    git add -- "$App/latest.json"
    git commit -m "$App $Version"
    if ($LASTEXITCODE -ne 0) { throw "git commit thất bại." }
    git push
    if ($LASTEXITCODE -ne 0) { throw "git push thất bại. Release đã tạo; push lại tay để cập nhật manifest." }
} finally { Pop-Location }

Write-Host "`nXong: $releaseUrl"
