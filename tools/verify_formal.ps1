param(
    [string]$SbyPath = "D:\tools\oss-cad-suite\bin\sby.exe",
    [string]$LogPath = "output\formal\verify_formal.log"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$resolvedLogPath = if ([System.IO.Path]::IsPathRooted($LogPath)) {
    $LogPath
} else {
    Join-Path $repoRoot $LogPath
}
$logDirectory = Split-Path -Parent $resolvedLogPath
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
"[FORMAL-RUN] $(Get-Date -Format o)" | Set-Content -LiteralPath $resolvedLogPath -Encoding utf8

if (-not (Test-Path -LiteralPath $SbyPath)) {
    $resolvedSby = Get-Command sby.exe -ErrorAction SilentlyContinue
    if ($null -eq $resolvedSby) {
        throw "SymbiYosys was not found. Pass -SbyPath with the path to sby.exe."
    }
    $SbyPath = $resolvedSby.Source
}

$formalSuites = @(
    "formal\fw_hdc.sby",
    "formal\fw_mtd.sby",
    "formal\fw_mtd_prove.sby",
    "formal\fw_closed.sby",
    "formal\fw_hdc_cover.sby",
    "formal\fw_axi_contract.sby",
    "formal\fw_honeypot_contract.sby",
    "formal\fw_drain_contract.sby",
    "formal\fw_stream_contract.sby"
)

$passed = 0
foreach ($suite in $formalSuites) {
    $suitePath = Join-Path $repoRoot $suite
    if (-not (Test-Path -LiteralPath $suitePath)) {
        throw "Formal suite not found: $suitePath"
    }

    $suiteMessage = "[FORMAL] $suite"
    Write-Host $suiteMessage
    Add-Content -LiteralPath $resolvedLogPath -Value $suiteMessage -Encoding utf8
    # Tee-Object appends UTF-16LE under Windows PowerShell and would corrupt the
    # UTF-8 evidence log. Stream each line explicitly to keep one encoding.
    & $SbyPath -f $suitePath 2>&1 | ForEach-Object {
        Write-Output $_
        Add-Content -LiteralPath $resolvedLogPath -Value $_ -Encoding utf8
    }
    $suiteExitCode = $LASTEXITCODE
    if ($suiteExitCode -ne 0) {
        throw "Formal suite failed: $suite"
    }
    $passed++
}

$summary = "[FORMAL-PASS] $passed/$($formalSuites.Count) suites passed"
Write-Host $summary
Add-Content -LiteralPath $resolvedLogPath -Value $summary -Encoding utf8
