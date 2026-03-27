param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $false)]
    [string]$AddonRoot = "DingTimer",

    [Parameter(Mandatory = $false)]
    [string]$OutputDir = "release-assets",

    [Parameter(Mandatory = $false)]
    [string]$ReleaseNotes = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$addonPath = Join-Path $repoRoot $AddonRoot
$resolvedOutputDir = if ([System.IO.Path]::IsPathRooted($OutputDir)) {
    $OutputDir
} else {
    Join-Path $repoRoot $OutputDir
}

$semverPattern = '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*))*))?(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$'

if ($Version -notmatch $semverPattern) {
    throw "Version '$Version' is not valid semver. Use a tag like v1.1.1 or v1.1.1-beta.1."
}

if (-not (Test-Path -LiteralPath $addonPath -PathType Container)) {
    throw "Addon folder '$AddonRoot' was not found at '$addonPath'."
}

$tocPath = Join-Path $addonPath ("{0}.toc" -f [System.IO.Path]::GetFileName($AddonRoot))
if (-not (Test-Path -LiteralPath $tocPath -PathType Leaf)) {
    throw "Expected TOC file was not found at '$tocPath'."
}

$tocVersionMatch = Select-String -Path $tocPath -Pattern '^## Version:\s*(.+)$'
if (-not $tocVersionMatch) {
    throw "Unable to read addon version from '$tocPath'."
}

$tocVersion = $tocVersionMatch.Matches[0].Groups[1].Value.Trim()
if ($tocVersion -ne $Version) {
    throw "TOC version '$tocVersion' does not match release version '$Version'. Update $tocPath before releasing."
}

$zipName = "DingTimer-v$Version.zip"
$zipPath = Join-Path $resolvedOutputDir $zipName
$manifestPath = Join-Path $resolvedOutputDir "addon-manifest.json"

New-Item -ItemType Directory -Path $resolvedOutputDir -Force | Out-Null

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

if (Test-Path -LiteralPath $manifestPath) {
    Remove-Item -LiteralPath $manifestPath -Force
}

Compress-Archive -Path $addonPath -DestinationPath $zipPath -Force

$hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    $rootNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($entry in $archive.Entries) {
        if ([string]::IsNullOrEmpty($entry.FullName)) {
            continue
        }

        $trimmed = $entry.FullName.TrimStart('./').TrimEnd('/')
        if ([string]::IsNullOrEmpty($trimmed)) {
            continue
        }

        $rootSegment = $trimmed.Split('/')[0]
        if (-not [string]::IsNullOrEmpty($rootSegment)) {
            [void]$rootNames.Add($rootSegment)
        }
    }

    if ($rootNames.Count -ne 1 -or -not $rootNames.Contains("DingTimer")) {
        $foundRoots = ($rootNames | Sort-Object) -join ', '
        throw "Zip root validation failed. Expected only 'DingTimer' at the archive root, found: $foundRoots"
    }
}
finally {
    $archive.Dispose()
}

$manifest = [ordered]@{
    schemaVersion       = 1
    addonId             = "ding-timer"
    displayName         = "DingTimer"
    version             = $Version
    targetSupport       = @("Bronzebeard")
    folders             = @("DingTimer")
    assetName           = $zipName
    sha256              = $hash
    minInstallerVersion = "1.0.0"
    releaseNotes        = $ReleaseNotes
}

$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath -Encoding utf8

$writtenManifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

if ($writtenManifest.addonId -ne "ding-timer") {
    throw "Manifest validation failed: addonId must be 'ding-timer'."
}

if (@($writtenManifest.folders).Count -ne 1 -or @($writtenManifest.folders)[0] -ne "DingTimer") {
    throw "Manifest validation failed: folders must be ['DingTimer']."
}

if ($writtenManifest.assetName -ne $zipName) {
    throw "Manifest validation failed: assetName does not match the zip asset name."
}

if (-not (@($writtenManifest.targetSupport) -contains "Bronzebeard")) {
    throw "Manifest validation failed: targetSupport must include 'Bronzebeard'."
}

if ($writtenManifest.version -ne $Version) {
    throw "Manifest validation failed: version must match the tag version without the leading v."
}

Write-Host "Built release assets:" -ForegroundColor Green
Write-Host "- $zipPath"
Write-Host "- $manifestPath"
