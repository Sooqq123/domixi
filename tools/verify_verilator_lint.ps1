param(
    [string]$Top = "dma_bus_firewall"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$candidateBins = @($env:VERILATOR_BIN)
if ($env:OSS_CAD_SUITE) {
    $candidateBins += Join-Path $env:OSS_CAD_SUITE "bin\verilator_bin.exe"
}
$candidateBins += "D:\tools\oss-cad-suite\bin\verilator_bin.exe"
$candidateBins = @($candidateBins | Where-Object { $_ -and (Test-Path -LiteralPath $_) })

if (-not $candidateBins) {
    throw "Verilator binary not found. Set VERILATOR_BIN or install OSS CAD Suite."
}

$verilatorBin = $candidateBins[0]
$verilatorRoot = Join-Path (Split-Path -Parent $verilatorBin) "..\share\verilator"
$verilatorRoot = [System.IO.Path]::GetFullPath($verilatorRoot)

if (-not (Test-Path -LiteralPath (Join-Path $verilatorRoot "include\verilated_std.sv"))) {
    throw "Verilator runtime is incomplete: verilated_std.sv not found under $verilatorRoot."
}

$env:VERILATOR_ROOT = $verilatorRoot
$rtlFiles = Get-ChildItem -LiteralPath (Join-Path $repoRoot "rtl") -Filter "*.v" -File |
    Sort-Object Name |
    ForEach-Object { $_.FullName }

$picoFile = Join-Path $repoRoot "picorv32-main\picorv32-main\picorv32.v"
if (Test-Path -LiteralPath $picoFile) {
    $rtlFiles += $picoFile
}

$rtlInc = Join-Path $repoRoot "rtl"
$genInc = Join-Path $rtlInc "generated"
$waiverFile = Join-Path $repoRoot "tools\lint\verilator_waivers.vlt"
$extraArgs = @()
if (Test-Path -LiteralPath $waiverFile) {
    $extraArgs += $waiverFile
}
& $verilatorBin --lint-only -Wall -Wno-fatal "-I$rtlInc" "-I$genInc" @extraArgs --top-module $Top $rtlFiles
exit $LASTEXITCODE
