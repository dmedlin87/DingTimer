param(
    [string]$LuaExe = "$env:LOCALAPPDATA\Programs\Lua\bin\lua.exe",
    [string]$LuaRocksExe = "$env:LOCALAPPDATA\Programs\Lua\bin\luarocks.exe",
    [string]$TestsPattern = "tests/test_*.lua",
    [switch]$Clean
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

function Resolve-ToolPath {
    param(
        [string]$candidate,
        [string[]]$fallbacks
    )

    if ($candidate -and (Test-Path $candidate)) {
        return (Resolve-Path $candidate).Path
    }

    foreach ($path in $fallbacks) {
        if ($path -and (Test-Path $path)) {
            return (Resolve-Path $path).Path
        }
    }

    return $null
}

function Apply-LuaRocksPath {
    param([string]$LuaRocksPath)

    if (-not $LuaRocksPath) { return }

    $lines = & $LuaRocksPath path 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $lines) { return }

    foreach ($line in $lines) {
        if ($line -match '^SET\s+([A-Z_]+)=(.*)$') {
            $name = $matches[1]
            $value = $matches[2]
            Set-Item -Path "Env:$name" -Value $value
        }
    }
}

$lua = Resolve-ToolPath $LuaExe @(
    "$env:LOCALAPPDATA\Programs\Lua\bin\lua.exe",
    "$env:LOCALAPPDATA\Programs\LuaJIT\bin\luajit.exe"
)

if (-not $lua) {
    throw "Lua runtime not found. Install Lua and re-run."
}

$luaRocks = Resolve-ToolPath $LuaRocksExe @(
    "$env:LOCALAPPDATA\Programs\Lua\bin\luarocks.exe",
    "$env:LOCALAPPDATA\Programs\LuaJIT\bin\luarocks.exe"
)
Apply-LuaRocksPath $luaRocks

if ($Clean) {
    Remove-Item -Force -ErrorAction SilentlyContinue "luacov.stats.out", "luacov.report.out"
}

$null = & $lua -e "require('luacov')"
$hasLuacov = ($LASTEXITCODE -eq 0)

if (-not $hasLuacov) {
    if (-not $luaRocks) {
        throw "luacov is not installed and LuaRocks was not found."
    }
    Write-Host "Installing luacov with LuaRocks..." -ForegroundColor Cyan
    & $luaRocks install --local luacov
    if ($LASTEXITCODE -ne 0) {
        & $luaRocks install luacov
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install luacov with LuaRocks."
        }
    }

    Apply-LuaRocksPath $luaRocks
    $null = & $lua -e "require('luacov')"
    if ($LASTEXITCODE -ne 0) {
        throw "luacov installation completed but the module is still not loadable by Lua."
    }
}

$tests = Get-ChildItem -Path $TestsPattern -File | Sort-Object FullName
if (-not $tests) {
    throw "No tests found matching '$TestsPattern'."
}

Write-Host "Running coverage over $($tests.Count) test files..." -ForegroundColor Cyan
$failed = 0
foreach ($test in $tests) {
    Write-Host " -> $($test.FullName)"
    & $lua -lluacov $test.FullName
    if ($LASTEXITCODE -ne 0) {
        $failed++
    }
}

$luacovReporter = Resolve-ToolPath "" @(
    "$env:LOCALAPPDATA\Programs\Lua\bin\luacov.bat",
    "$env:LOCALAPPDATA\Programs\LuaJIT\bin\luacov.bat",
    "$env:APPDATA\luarocks\bin\luacov.bat",
    "$env:APPDATA\luarocks\bin\luacov"
)
if (-not $luacovReporter) {
    $cmd = Get-Command luacov.bat -ErrorAction SilentlyContinue
    if ($cmd) {
        $luacovReporter = $cmd.Source
    }
}

if ($luacovReporter) {
    if ([System.IO.Path]::GetExtension($luacovReporter).ToLowerInvariant() -eq ".bat") {
        & $luacovReporter
    }
    else {
        & $lua $luacovReporter
    }
    if ($LASTEXITCODE -ne 0) {
        throw "luacov reporter failed with exit code $LASTEXITCODE."
    }
}
else {
    throw "Could not locate a luacov reporter executable."
}

if (Test-Path "luacov.report.out") {
    Write-Host "Coverage report generated: $repoRoot\luacov.report.out" -ForegroundColor Green
}
else {
    Write-Warning "luacov completed but report file was not found."
}

if ($failed -gt 0) {
    throw "$failed test file(s) failed during coverage run."
}
