param(
    [string]$OutputDir = "release-assets",

    [string]$ReleaseNotes = "",

    [string]$ExpectedVersion,

    [switch]$PublishRelease,

    [int]$PublishTimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

function Invoke-Tool {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [string[]]$Arguments = @(),

        [switch]$IgnoreExitCode
    )

    $result = & $FilePath @Arguments 2>&1
    if (-not $IgnoreExitCode -and $LASTEXITCODE -ne 0) {
        $rendered = if ($result) { ($result | Out-String).Trim() } else { "" }
        if ($rendered) {
            throw "$FilePath $($Arguments -join ' ') failed: $rendered"
        }

        throw "$FilePath $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
    }

    return $result
}

function Get-OriginRepository {
    $remoteUrl = (Invoke-Tool -FilePath "git" -Arguments @("-C", $repoRoot, "remote", "get-url", "origin")) |
        Select-Object -First 1
    $remoteUrl = [string]$remoteUrl

    if ($remoteUrl -match 'github\.com[:/](?<owner>[^/]+)/(?<repo>[^/.]+?)(?:\.git)?$') {
        return @{
            Owner = $Matches.owner
            Repo  = $Matches.repo
            Url   = $remoteUrl
        }
    }

    throw "Origin remote '$remoteUrl' is not a supported GitHub repository URL."
}

function Get-LatestRelease {
    param(
        [Parameter(Mandatory)]
        [string]$Owner,

        [Parameter(Mandatory)]
        [string]$Repo
    )

    $headers = @{ "User-Agent" = "Codex-Build-AscensionRelease" }
    try {
        return Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/$Owner/$Repo/releases/latest"
    }
    catch {
        $response = $_.Exception.Response
        if ($response -and [int]$response.StatusCode -eq 404) {
            return $null
        }

        throw
    }
}

function Test-RemoteTagExists {
    param(
        [Parameter(Mandatory)]
        [string]$TagName
    )

    $refs = Invoke-Tool -FilePath "git" -Arguments @("-C", $repoRoot, "ls-remote", "--tags", "origin", "refs/tags/$TagName")
    return -not [string]::IsNullOrWhiteSpace((($refs | Out-String).Trim()))
}

function Wait-ForPublishedRelease {
    param(
        [Parameter(Mandatory)]
        [string]$Owner,

        [Parameter(Mandatory)]
        [string]$Repo,

        [Parameter(Mandatory)]
        [string]$TagName,

        [Parameter(Mandatory)]
        [string]$ExpectedZipName,

        [Parameter(Mandatory)]
        [int]$TimeoutSeconds
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $release = Get-LatestRelease -Owner $Owner -Repo $Repo
        if ($release -and $release.tag_name -eq $TagName) {
            $assetNames = @($release.assets | ForEach-Object { $_.name })
            if ($assetNames -contains "addon-manifest.json" -and $assetNames -contains $ExpectedZipName) {
                return $release
            }
        }

        Start-Sleep -Seconds 5
    } while ((Get-Date) -lt $deadline)

    return $null
}

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

if ($PublishTimeoutSeconds -lt 0) {
    throw "PublishTimeoutSeconds must be zero or greater."
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
Write-Host ""
Write-Host "Installer visibility note:" -ForegroundColor Yellow
Write-Host "AscensionUp reads the latest published GitHub release for '$addonId', not local files."
if (-not $PublishRelease) {
    Write-Host "To expose version $Version in the installer, publish tag v$Version so the release workflow uploads:"
    Write-Host "- $zipName"
    Write-Host "- addon-manifest.json"
}

if (-not $PublishRelease) {
    return
}

$tagName = "v$Version"
$repoInfo = Get-OriginRepository
$statusOutput = (Invoke-Tool -FilePath "git" -Arguments @("-C", $repoRoot, "status", "--porcelain")) | Out-String
if (-not [string]::IsNullOrWhiteSpace($statusOutput)) {
    throw "Refusing to publish with uncommitted changes in '$repoRoot'. Commit or stash changes first."
}

$currentHead = [string](Invoke-Tool -FilePath "git" -Arguments @("-C", $repoRoot, "rev-parse", "HEAD") | Select-Object -First 1)
$localTagCommit = [string](Invoke-Tool -FilePath "git" -Arguments @("-C", $repoRoot, "rev-parse", "-q", "--verify", "refs/tags/$tagName^{}") -IgnoreExitCode | Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace($localTagCommit)) {
    Write-Host ""
    Write-Host "Creating local tag $tagName at $currentHead" -ForegroundColor Cyan
    Invoke-Tool -FilePath "git" -Arguments @("-C", $repoRoot, "tag", "-a", $tagName, "-m", "$displayName $tagName")
}
elseif ($localTagCommit -ne $currentHead) {
    throw "Local tag '$tagName' points to $localTagCommit, but HEAD is $currentHead. Move or delete the tag before publishing."
}
else {
    Write-Host ""
    Write-Host "Local tag $tagName already exists at HEAD." -ForegroundColor Cyan
}

$remoteTagExists = Test-RemoteTagExists -TagName $tagName
if (-not $remoteTagExists) {
    Write-Host "Pushing tag $tagName to origin..." -ForegroundColor Cyan
    Invoke-Tool -FilePath "git" -Arguments @("-C", $repoRoot, "push", "origin", $tagName)
}
else {
    Write-Host "Remote tag $tagName already exists." -ForegroundColor Cyan
}

$latestRelease = Get-LatestRelease -Owner $repoInfo.Owner -Repo $repoInfo.Repo
if ($latestRelease -and $latestRelease.tag_name -eq $tagName) {
    $assetNames = @($latestRelease.assets | ForEach-Object { $_.name })
    if ($assetNames -contains "addon-manifest.json" -and $assetNames -contains $zipName) {
        Write-Host "Release $tagName is already published with installer assets." -ForegroundColor Green
        return
    }
}

Write-Host "Waiting for GitHub Actions to publish release $tagName..." -ForegroundColor Cyan
$publishedRelease = Wait-ForPublishedRelease -Owner $repoInfo.Owner -Repo $repoInfo.Repo -TagName $tagName -ExpectedZipName $zipName -TimeoutSeconds $PublishTimeoutSeconds

if ($publishedRelease) {
    Write-Host "Published release is now visible to the installer:" -ForegroundColor Green
    Write-Host "- $($publishedRelease.html_url)"
    return
}

throw "Tag $tagName was pushed, but GitHub did not publish a matching release within $PublishTimeoutSeconds seconds."
