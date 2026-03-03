param(
    [Parameter(Mandatory = $false)]
    [string]$Action = "install", # install, link, clean, dist, coverage

    [Parameter(Mandatory = $false)]
    [string]$WowPath = "C:\Program Files (x86)\World of Warcraft",

    [Parameter(Mandatory = $false)]
    [string]$Flavor = "retail" # retail, classic, classic_era
)

$AddonName = "DingTimer"
$SourceDir = Join-Path $PSScriptRoot $AddonName
$TargetAddonDir = Join-Path $WowPath "_${Flavor}_\Interface\AddOns"
$TargetPath = Join-Path $TargetAddonDir $AddonName

function Confirm-Path {
    param($path)
    if (!(Test-Path $path)) {
        Write-Error "Path not found: $path"
        exit 1
    }
}

if ($Action -eq "install") {
    Confirm-Path $SourceDir
    Confirm-Path $TargetAddonDir

    Write-Host "Installing $AddonName to $TargetPath..." -ForegroundColor Cyan
    if (Test-Path $TargetPath) {
        Remove-Item -Recurse -Force $TargetPath
    }
    Copy-Item -Recurse -Path $SourceDir -Destination $TargetPath
    Write-Host "Success!" -ForegroundColor Green
}
elseif ($Action -eq "link") {
    Confirm-Path $SourceDir
    Confirm-Path $TargetAddonDir

    Write-Host "Creating Symbolic Link for $AddonName..." -ForegroundColor Cyan
    if (Test-Path $TargetPath) {
        Write-Host "Removing existing folder/link..." -ForegroundColor Yellow
        Remove-Item -Recurse -Force $TargetPath
    }
    
    # Requires Admin privileges
    New-Item -ItemType SymbolicLink -Path $TargetPath -Target $SourceDir
    Write-Host "Link created! Changes in this folder will reflect instantly in-game (after /reload)." -ForegroundColor Green
}
elseif ($Action -eq "clean") {
    if (Test-Path $TargetPath) {
        Write-Host "Cleaning $AddonName from $TargetPath..." -ForegroundColor Yellow
        Remove-Item -Recurse -Force $TargetPath
        Write-Host "Cleaned." -ForegroundColor Green
    }
    else {
        Write-Host "Addon not found in target path. Nothing to clean."
    }
}
elseif ($Action -eq "dist") {
    $TocFile = Join-Path $SourceDir "$AddonName.toc"
    $Version = (Select-String -Path $TocFile -Pattern '^## Version:\s*(.+)').Matches[0].Groups[1].Value.Trim()
    $ZipFile = Join-Path $PSScriptRoot "$AddonName-v$Version.zip"
    Write-Host "Creating distribution zip: $ZipFile" -ForegroundColor Cyan
    if (Test-Path $ZipFile) { Remove-Item $ZipFile }
    
    # We zip the folder, not the contents, so it extracts correctly into AddOns/
    Compress-Archive -Path $SourceDir -DestinationPath $ZipFile
    Write-Host "Created $ZipFile" -ForegroundColor Green
}
elseif ($Action -eq "coverage") {
    $CoverageScript = Join-Path $PSScriptRoot "coverage.ps1"
    Confirm-Path $CoverageScript

    Write-Host "Running Lua coverage..." -ForegroundColor Cyan
    & $CoverageScript -Clean
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
    Write-Host "Coverage complete." -ForegroundColor Green
}
else {
    Write-Host "Unknown action: $Action" -ForegroundColor Red
    Write-Host "Use: .\manage.ps1 -Action [install|link|clean|dist|coverage] -Flavor [retail|classic|classic_era]"
}
