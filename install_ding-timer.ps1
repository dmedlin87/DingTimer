param(
    [Parameter(Mandatory = $false)]
    [string]$Action = "install", # install, link, clean, dist, coverage

    [Parameter(Mandatory = $false)]
    [string]$WowPath = "C:\Program Files\Ascension Launcher\resources\client",

    [Parameter(Mandatory = $false)]
    [string]$Flavor = "retail" # retail, classic, classic_era

    ,
    [Parameter(Mandatory = $false)]
    [switch]$PauseOnExit
)

$AddonName = "DingTimer"
$SourceDir = Join-Path $PSScriptRoot $AddonName
$DirectAddonDir = Join-Path $WowPath "Interface\AddOns"
$FlavorAddonDir = Join-Path $WowPath "_${Flavor}_\Interface\AddOns"
$TargetAddonDir = if (Test-Path $DirectAddonDir) { $DirectAddonDir } else { $FlavorAddonDir }
$TargetPath = Join-Path $TargetAddonDir $AddonName

function Confirm-Path {
    
    param($path)
    if (!(Test-Path $path)) {
        Write-Error "Path not found: $path"
        Exit-Script 1
    }
}

function Wait-ForExitAcknowledgement {
    if (-not $PauseOnExit) {
        return
    }

    Write-Host ""
    Write-Host "Press Enter to close this window..." -ForegroundColor DarkGray
    [void](Read-Host)
}

function Exit-Script {
    param([int]$Code = 0)

    Wait-ForExitAcknowledgement
    exit $Code
}

function Invoke-Operation {
    param(
        [scriptblock]$Operation,
        [string]$FailureMessage
    )

    try {
        & $Operation
    }
    catch {
        Write-Error "$FailureMessage $($_.Exception.Message)"
        Exit-Script 1
    }
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Format-Argument {
    param([string]$Value)
    if ($null -eq $Value) {
        return '""'
    }

    return '"' + ($Value -replace '"', '\"') + '"'
}

function Assert-Administrator {
    param([string]$ActionDescription)

    if (Test-IsAdministrator) {
        return
    }

    $scriptPath = $MyInvocation.PSCommandPath
    if ([string]::IsNullOrWhiteSpace($scriptPath)) {
        Write-Error "$ActionDescription requires administrator privileges. Re-run PowerShell as Administrator."
        Exit-Script 1
    }

    $argList = @(
        "-NoProfile"
        "-ExecutionPolicy"
        "Bypass"
        "-File"
        (Format-Argument $scriptPath)
        "-Action"
        (Format-Argument $Action)
        "-WowPath"
        (Format-Argument $WowPath)
        "-Flavor"
        (Format-Argument $Flavor)
        "-PauseOnExit"
    ) -join ' '

    try {
        Start-Process PowerShell -Verb RunAs -ArgumentList $argList | Out-Null
        Write-Host "$ActionDescription requires elevation. Opened an administrator PowerShell to continue." -ForegroundColor Yellow
        Exit-Script 0
    }
    catch {
        Write-Error "Failed to relaunch PowerShell as Administrator. $($_.Exception.Message)"
        Exit-Script 1
    }
}

function Confirm-WriteAccess {
    param(
        [string]$DirectoryPath,
        [string]$ActionDescription
    )

    Assert-Administrator -ActionDescription $ActionDescription

    $probePath = Join-Path $DirectoryPath ".dingtimer-write-test"
    try {
        New-Item -ItemType File -Path $probePath -Force -ErrorAction Stop | Out-Null
        Remove-Item -Path $probePath -Force -ErrorAction Stop
    }
    catch {
        Write-Error "$ActionDescription requires write access to '$DirectoryPath'. $($_.Exception.Message)"
        Exit-Script 1
    }
}

if ($Action -eq "install") {
    Confirm-Path $SourceDir
    Confirm-Path $TargetAddonDir
    Confirm-WriteAccess -DirectoryPath $TargetAddonDir -ActionDescription "Installing $AddonName"

    Write-Host "Installing $AddonName to $TargetPath..." -ForegroundColor Cyan
    if (Test-Path $TargetPath) {
        Invoke-Operation -FailureMessage "Failed to remove existing addon." -Operation {
            Remove-Item -Recurse -Force -ErrorAction Stop $TargetPath
        }
    }
    Invoke-Operation -FailureMessage "Failed to install addon." -Operation {
        Copy-Item -Recurse -Path $SourceDir -Destination $TargetPath -ErrorAction Stop
    }
    Write-Host "Success!" -ForegroundColor Green
}
elseif ($Action -eq "link") {
    Confirm-Path $SourceDir
    Confirm-Path $TargetAddonDir
    Confirm-WriteAccess -DirectoryPath $TargetAddonDir -ActionDescription "Linking $AddonName"

    Write-Host "Creating Symbolic Link for $AddonName..." -ForegroundColor Cyan
    if (Test-Path $TargetPath) {
        Write-Host "Removing existing folder/link..." -ForegroundColor Yellow
        Invoke-Operation -FailureMessage "Failed to remove existing addon before linking." -Operation {
            Remove-Item -Recurse -Force -ErrorAction Stop $TargetPath
        }
    }
    
    # Requires Admin privileges
    Invoke-Operation -FailureMessage "Failed to create symbolic link." -Operation {
        New-Item -ItemType SymbolicLink -Path $TargetPath -Target $SourceDir -ErrorAction Stop
    }
    Write-Host "Link created! Changes in this folder will reflect instantly in-game (after /reload)." -ForegroundColor Green
}
elseif ($Action -eq "clean") {
    if (Test-Path $TargetPath) {
        Confirm-WriteAccess -DirectoryPath $TargetAddonDir -ActionDescription "Cleaning $AddonName"
        Write-Host "Cleaning $AddonName from $TargetPath..." -ForegroundColor Yellow
        Invoke-Operation -FailureMessage "Failed to clean addon." -Operation {
            Remove-Item -Recurse -Force -ErrorAction Stop $TargetPath
        }
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
        Exit-Script $LASTEXITCODE
    }
    Write-Host "Coverage complete." -ForegroundColor Green
}
else {
    Write-Host "Unknown action: $Action" -ForegroundColor Red
    Write-Host "Use: .\manage.ps1 -Action [install|link|clean|dist|coverage] -Flavor [retail|classic|classic_era]"
    Exit-Script 1
}

Exit-Script 0
