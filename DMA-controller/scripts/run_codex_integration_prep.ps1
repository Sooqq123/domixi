param(
    [string]$EvidencePath = ""
)

$ErrorActionPreference = 'Stop'
$dmaRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $dmaRoot
$runRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'domixi-codex-integration-prep'
$evidenceDir = Join-Path $dmaRoot 'docs/integration/evidence'
if ([string]::IsNullOrWhiteSpace($EvidencePath)) {
    $EvidencePath = Join-Path $evidenceDir 'codex_prep_regression.log'
}

New-Item -ItemType Directory -Force -Path $runRoot | Out-Null
New-Item -ItemType Directory -Force -Path $evidenceDir | Out-Null
$logLines = [System.Collections.Generic.List[string]]::new()

function Add-LogLine {
    param([string]$Line)
    $logLines.Add($Line)
}

function Save-Evidence {
    $encoding = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllLines($EvidencePath, $logLines, $encoding)
}

function Invoke-External {
    param(
        [string]$Name,
        [string]$Executable,
        [string[]]$Arguments,
        [string]$WorkingDirectory,
        [string]$PassPattern = '',
        [switch]$RejectWarnings
    )

    Add-LogLine ""
    Add-LogLine "=== $Name ==="
    Add-LogLine "cwd: $WorkingDirectory"
    Add-LogLine "command: $Executable $($Arguments -join ' ')"
    Push-Location $WorkingDirectory
    $savedErrorPreference = $ErrorActionPreference
    try {
        # Windows PowerShell wraps native stderr as ErrorRecord. Tools such as
        # unittest and iverilog legitimately write progress/version text there,
        # so command success is determined from the native exit code below.
        $ErrorActionPreference = 'Continue'
        $output = @(& $Executable @Arguments 2>&1 | ForEach-Object {
            $line = $_.ToString()
            if ($line -ne 'System.Management.Automation.RemoteException') { $line }
        })
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $savedErrorPreference
        Pop-Location
    }
    foreach ($line in $output) {
        Write-Host $line
        Add-LogLine $line
    }
    Add-LogLine "exit_code: $exitCode"
    if ($exitCode -ne 0) {
        throw "$Name failed with exit code $exitCode"
    }
    $joined = $output -join "`n"
    if ($RejectWarnings -and $joined -match '(?im)\bwarning:') {
        throw "$Name emitted a compiler warning"
    }
    if (-not [string]::IsNullOrWhiteSpace($PassPattern) -and $joined -notmatch $PassPattern) {
        throw "$Name did not emit required marker: $PassPattern"
    }
}

function Compile-And-Run {
    param(
        [string]$Name,
        [string]$Top,
        [string[]]$Sources,
        [string]$PassPattern
    )
    $outputFile = Join-Path $runRoot "$Name.vvp"
    $compileArgs = @('-g2012', '-Wall', '-Wimplicit', '-s', $Top, '-o', $outputFile) + $Sources
    Invoke-External -Name "$Name compile" -Executable 'iverilog' -Arguments $compileArgs -WorkingDirectory $runRoot -RejectWarnings
    Invoke-External -Name "$Name run" -Executable 'vvp' -Arguments @($outputFile) -WorkingDirectory $runRoot -PassPattern $PassPattern
}

Add-LogLine 'Codex Firewall integration preparation regression'
Add-LogLine "executed_local: $([DateTimeOffset]::Now.ToString('o'))"
Add-LogLine "repo_root: $repoRoot"
Add-LogLine 'scope: specification consistency, existing DMA regression, structural wrapper, and mock-backed boundary readiness'
Add-LogLine 'limitation: mocks are simulation-only and do not establish Firewall G2/G3, formal, coverage, synthesis, STA, PPA, or SoC trust closure'

try {
    Invoke-External -Name 'Contract checker' -Executable 'python' `
        -Arguments @('-B', (Join-Path $dmaRoot 'scripts/check_firewall_contract.py')) `
        -WorkingDirectory $repoRoot -PassPattern 'CONTRACT CHECK PASSED'

    Invoke-External -Name 'Canonical specification lint' -Executable 'python' `
        -Arguments @('-B', (Join-Path $dmaRoot 'docs/architecture/tools/spec_lint.py')) `
        -WorkingDirectory $dmaRoot -PassPattern 'LINT PASSED'

    Invoke-External -Name 'Python model regression' -Executable 'python' `
        -Arguments @('-B', '-m', 'unittest', 'discover', '-s', 'model', '-p', 'test*.py', '-v') `
        -WorkingDirectory $dmaRoot -PassPattern '(?m)^OK$'

    Compile-And-Run -Name 'tb_dma_fifo_latch' -Top 'tb_dma_fifo_latch' `
        -Sources @(
            (Join-Path $dmaRoot 'rtl/dma_fifo_latch.v'),
            (Join-Path $dmaRoot 'tb/tb_dma_fifo_latch.v')
        ) -PassPattern '\[PASS\] tb_dma_fifo_latch completed'

    Compile-And-Run -Name 'tb_dma_apb_slave' -Top 'tb_dma_apb_slave' `
        -Sources @(
            (Join-Path $dmaRoot 'rtl/dma_apb_slave.v'),
            (Join-Path $dmaRoot 'tb/tb_dma_apb_slave.v')
        ) -PassPattern '\[PASS\] tb_dma_apb_slave completed'

    Compile-And-Run -Name 'tb_dma_axi_master' -Top 'tb_dma_axi_master' `
        -Sources @(
            (Join-Path $dmaRoot 'rtl/dma_axi_master.v'),
            (Join-Path $dmaRoot 'tb/tb_dma_axi_master.v')
        ) -PassPattern '\[PASS\] tb_dma_axi_master'

    Compile-And-Run -Name 'tb_dma_controller' -Top 'tb_dma_controller' `
        -Sources @(
            (Join-Path $dmaRoot 'rtl/dma_apb_slave.v'),
            (Join-Path $dmaRoot 'rtl/dma_fifo_latch.v'),
            (Join-Path $dmaRoot 'rtl/dma_axi_master.v'),
            (Join-Path $dmaRoot 'rtl/dma_controller.v'),
            (Join-Path $dmaRoot 'tb/tb_dma_controller.v')
        ) -PassPattern '\[PASS\] dma_controller regression'

    Compile-And-Run -Name 'tb_fw_drain_fsm' -Top 'tb_fw_drain_fsm' `
        -Sources @(
            (Join-Path $dmaRoot 'rtl/fw_drain_fsm.v'),
            (Join-Path $dmaRoot 'tb/integration/mocks/fw_write_drain_mock.v'),
            (Join-Path $dmaRoot 'tb/integration/mocks/fw_read_drain_mock.v'),
            (Join-Path $dmaRoot 'tb/integration/tb_fw_drain_fsm.v')
        ) -PassPattern 'PASS: tb_fw_drain_fsm'

    Compile-And-Run -Name 'tb_soc_dma_firewall_contract' -Top 'tb_soc_dma_firewall_contract' `
        -Sources @(
            (Join-Path $dmaRoot 'rtl/dma_apb_slave.v'),
            (Join-Path $dmaRoot 'rtl/dma_fifo_latch.v'),
            (Join-Path $dmaRoot 'rtl/dma_axi_master.v'),
            (Join-Path $dmaRoot 'rtl/dma_controller.v'),
            (Join-Path $dmaRoot 'tb/integration/mocks/dma_bus_firewall_stub.v'),
            (Join-Path $dmaRoot 'tb/integration/tb_soc_dma_firewall_contract.v')
        ) -PassPattern 'PASS: tb_soc_dma_firewall_contract \(SIMULATION-ONLY FIREWALL STUB\)'

    Invoke-External -Name 'Changed-file whitespace check' -Executable 'git' `
        -Arguments @('-c', 'core.autocrlf=false', '-c', 'core.safecrlf=false', 'diff', '--check', '--',
            'DMA-controller/docs/architecture',
            'DMA-controller/docs/integration',
            'DMA-controller/rtl/fw_drain_fsm.v',
            'DMA-controller/scripts',
            'DMA-controller/tb/integration',
            'docs/superpowers/plans/2026-09-06-codex-integration-readiness.md') `
        -WorkingDirectory $repoRoot

    Add-LogLine ''
    Add-LogLine '=== Source SHA256 ==='
    $evidenceFiles = @(
        (Join-Path $dmaRoot 'rtl/fw_drain_fsm.v'),
        (Join-Path $dmaRoot 'scripts/check_firewall_contract.py'),
        (Join-Path $dmaRoot 'tb/integration/tb_fw_drain_fsm.v'),
        (Join-Path $dmaRoot 'tb/integration/tb_soc_dma_firewall_contract.v')
    )
    foreach ($file in $evidenceFiles) {
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash
        Add-LogLine "$hash  $file"
    }
    Add-LogLine ''
    Add-LogLine 'PASS: run_codex_integration_prep'
    Save-Evidence
    Write-Host "PASS: run_codex_integration_prep"
    Write-Host "Evidence: $EvidencePath"
    exit 0
} catch {
    Add-LogLine ''
    Add-LogLine "FAIL: $($_.Exception.Message)"
    Save-Evidence
    Write-Error $_
    exit 1
}
