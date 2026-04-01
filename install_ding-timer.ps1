param(
    [Parameter(Mandatory = $false)]
    [string]$Action = "install", # install, link, clean, dist, coverage

    [Parameter(Mandatory = $false)]
    [string]$WowPath = "C:\Program Files\Ascension Launcher\resources\client",

    [Parameter(Mandatory = $false)]
    [string]$Flavor = "retail" # retail, classic, classic_era, ptr

    ,
    [Parameter(Mandatory = $false)]
    [switch]$PauseOnExit
)

if ($Flavor -eq "ptr" -and -not $PSBoundParameters.ContainsKey("WowPath")) {
    $WowPath = "C:\Program Files\Ascension PTR"
}

$sharedHelperPath = Join-Path $PSScriptRoot "scripts\AddonDevManager.ps1"
if (-not (Test-Path -LiteralPath $sharedHelperPath -PathType Leaf)) {
    throw "Shared addon helper was not found at '$sharedHelperPath'."
}

. $sharedHelperPath

$config = [AddonDevConfig]::new()
$config.Action = $Action
$config.AddonName = "DingTimer"
$config.AddonFolder = "DingTimer"
$config.ProjectRoot = $PSScriptRoot
$config.EntryScriptPath = $MyInvocation.PSCommandPath
$config.WowPath = $WowPath
$config.Flavor = $Flavor
$config.PauseOnExit = [bool]$PauseOnExit
$config.InstallSourcePath = Join-Path $PSScriptRoot "DingTimer"
$config.LinkSourcePath = Join-Path $PSScriptRoot "DingTimer"
$config.TocPath = Join-Path $PSScriptRoot "DingTimer\DingTimer.toc"
$config.TocContentRoot = Join-Path $PSScriptRoot "DingTimer"
$config.CoverageScriptPath = Join-Path $PSScriptRoot "coverage.ps1"

Invoke-AddonDevCommand -Config $config
