param(
    [Parameter(Mandatory = $false)]
    [string]$OutputDir = "release-assets",

    [Parameter(Mandatory = $false)]
    [string]$ReleaseNotes = "",

    [Parameter(Mandatory = $false)]
    [string]$ExpectedVersion
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$releaseConfigPath = Join-Path $repoRoot "addon-release.json"
$resolvedOutputDir = if ([System.IO.Path]::IsPathRooted($OutputDir)) {
    $OutputDir
} else {
    Join-Path $repoRoot $OutputDir
}

if (-not (Test-Path -LiteralPath $releaseConfigPath -PathType Leaf)) {
    throw "Expected release metadata file was not found at '$releaseConfigPath'."
}

$releaseConfig = Get-Content -LiteralPath $releaseConfigPath -Raw | ConvertFrom-Json

if ($releaseConfig.schemaVersion -ne 1) {
    throw "Release metadata schemaVersion must be 1."
}

$addonId = [string]$releaseConfig.addonId
$displayName = [string]$releaseConfig.displayName
$Version = [string]$releaseConfig.version
$targetSupport = @($releaseConfig.targetSupport)
$folders = @($releaseConfig.folders)
$minInstallerVersion = [string]$releaseConfig.minInstallerVersion

if ([string]::IsNullOrWhiteSpace($addonId) -or
    [string]::IsNullOrWhiteSpace($displayName) -or
    [string]::IsNullOrWhiteSpace($Version) -or
    [string]::IsNullOrWhiteSpace($minInstallerVersion)) {
    throw "Release metadata is missing one of: addonId, displayName, version, minInstallerVersion."
}

if ($folders.Count -ne 1) {
    throw "Release metadata must define exactly one managed folder."
}

$addonRoot = [string]$folders[0]
$addonPath = Join-Path $repoRoot $addonRoot

$semverPattern = '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*))*))?(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$'

if ($Version -notmatch $semverPattern) {
    throw "Version '$Version' is not valid semver. Use a tag like v1.1.1 or v1.1.1-beta.1."
}

if ($ExpectedVersion -and $ExpectedVersion -ne $Version) {
    throw "Release metadata version '$Version' does not match expected version '$ExpectedVersion'."
}

if ($minInstallerVersion -notmatch $semverPattern) {
    throw "minInstallerVersion '$minInstallerVersion' is not valid semver."
}

if ($targetSupport.Count -eq 0) {
    throw "Release metadata must define at least one supported target."
}

if (-not (Test-Path -LiteralPath $addonPath -PathType Container)) {
    throw "Addon folder '$addonRoot' was not found at '$addonPath'."
}

$tocPath = Join-Path $addonPath ("{0}.toc" -f [System.IO.Path]::GetFileName($addonRoot))
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

$zipName = "$addonRoot-v$Version.zip"
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

        $normalizedEntry = $entry.FullName.Replace('\', '/')
        $trimmed = $normalizedEntry.TrimStart('./').TrimEnd('/')
        if ([string]::IsNullOrEmpty($trimmed)) {
            continue
        }

        $rootSegment = $trimmed.Split('/')[0]
        if (-not [string]::IsNullOrEmpty($rootSegment)) {
            [void]$rootNames.Add($rootSegment)
        }
    }

    if ($rootNames.Count -ne 1 -or -not $rootNames.Contains($addonRoot)) {
        $foundRoots = ($rootNames | Sort-Object) -join ', '
        throw "Zip root validation failed. Expected only '$addonRoot' at the archive root, found: $foundRoots"
    }
}
finally {
    $archive.Dispose()
}

$manifest = [ordered]@{
    schemaVersion       = 1
    addonId             = $addonId
    displayName         = $displayName
    version             = $Version
    targetSupport       = $targetSupport
    folders             = $folders
    assetName           = $zipName
    sha256              = $hash
    minInstallerVersion = $minInstallerVersion
    releaseNotes        = $ReleaseNotes
}

$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath -Encoding utf8

$writtenManifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

if ($writtenManifest.addonId -ne $addonId) {
    throw "Manifest validation failed: addonId must be '$addonId'."
}

if (@($writtenManifest.folders).Count -ne $folders.Count) {
    throw "Manifest validation failed: folders do not match release metadata."
}

if ($writtenManifest.assetName -ne $zipName) {
    throw "Manifest validation failed: assetName does not match the zip asset name."
}

foreach ($folder in $folders) {
    if (-not (@($writtenManifest.folders) -contains $folder)) {
        throw "Manifest validation failed: folders do not match release metadata."
    }
}

foreach ($target in $targetSupport) {
    if (-not (@($writtenManifest.targetSupport) -contains $target)) {
        throw "Manifest validation failed: targetSupport does not match release metadata."
    }
}

if ($writtenManifest.minInstallerVersion -ne $minInstallerVersion) {
    throw "Manifest validation failed: minInstallerVersion does not match release metadata."
}

if ($writtenManifest.version -ne $Version) {
    throw "Manifest validation failed: version must match the tag version without the leading v."
}

Write-Host "Built release assets:" -ForegroundColor Green
Write-Host "- $zipPath"
Write-Host "- $manifestPath"
