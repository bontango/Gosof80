<#
.SYNOPSIS
  Votrax SC-01: reference, C model and VHDL against each other, end to end.

.DESCRIPTION
  1. stimuli\gen_stimuli.py      writes the test scripts t*.txt
  2. ref\ref_votrax              PinMAME's votrax.c (unmodified) -> ref_<t>.f32/.wav/.writes
  3. tools\gen_votrax_tables.py  tables for model and VHDL (rtl\common\votrax\votrax_tables_pkg.vhd)
  4. model\vmodel                double build (vs. reference) and fixed point build (golden)
  5. GHDL                        tb\tb_votrax_sc01.vhd, every test, bit exact against the golden

  Results land in build\ (ignored by git). Pass criteria:
    fixed point model vs. PinMAME  > 55 dB below 8 kHz
    VHDL vs. fixed point model     bit exact, every sample

  Needs gcc (C:\mingw64), python and GHDL (C:\Users\bonta\tools\ghdl, portable).
  Runtime: ~25 min for all five tests, the VHDL simulation is the slow part.

.PARAMETER Tests
  Subset, e.g. -Tests t5_mute. Default: all.

.PARAMETER NoVhdl
  Skip the GHDL runs (reference and models only, takes seconds).
#>
param(
    [string[]]$Tests = @('t1_allphones', 't2_inflection', 't3_sentence', 't4_clock', 't5_mute'),
    [switch]  $NoVhdl
)

$ErrorActionPreference = 'Stop'
$Here  = Split-Path -Parent $MyInvocation.MyCommand.Path
$Build = Join-Path $Here 'build'
$Rtl   = Join-Path (Split-Path -Parent (Split-Path -Parent $Here)) 'rtl\common\votrax'
$Ghdl  = 'C:\Users\bonta\tools\ghdl\bin\ghdl.exe'
$Gcc   = 'gcc'
New-Item -ItemType Directory -Force $Build | Out-Null

function Run([string]$exe, [string[]]$a) {
    & $exe @a
    if ($LASTEXITCODE -ne 0) { throw "$exe $($a -join ' ') failed (exit $LASTEXITCODE)" }
}

Push-Location $Build
try {
    Run python @((Join-Path $Here 'stimuli\gen_stimuli.py'))
    Run python @((Join-Path $Here 'tools\gen_votrax_tables.py'))
    $cf = @('-O2', '-D__USE_MINGW_ANSI_STDIO=1', '-w')
    Run $Gcc ($cf + @('-I', (Join-Path $Here 'ref'), '-o', 'ref_votrax.exe', (Join-Path $Here 'ref\ref_main.c'), '-lm'))
    Run $Gcc ($cf + @('-I', (Join-Path $Here 'model'), '-o', 'vmodel_dbl.exe', (Join-Path $Here 'model\vmodel.c'), '-lm'))
    Run $Gcc ($cf + @('-I', (Join-Path $Here 'model'), '-DVT_FIXED', '-o', 'vmodel_fix.exe', (Join-Path $Here 'model\vmodel.c'), '-lm'))

    if (-not $NoVhdl) {
        # fresh GHDL library: units analysed under another path would clash (-Wlibrary)
        Remove-Item -ErrorAction SilentlyContinue 'work-obj08.cf'
        foreach ($f in @("$Rtl\votrax_tables_pkg.vhd", "$Rtl\votrax_sc01.vhd", (Join-Path $Here 'tb\tb_votrax_sc01.vhd'))) {
            Run $Ghdl @('-a', '--std=08', $f)
        }
        Run $Ghdl @('-e', '--std=08', 'tb_votrax_sc01')
    }

    $fail = $false
    foreach ($t in $Tests) {
        Write-Host "== $t" -ForegroundColor Cyan
        Run ".\ref_votrax.exe" @((Join-Path $Here "stimuli\$t.txt"), "ref_$t")
        $ticks = [int64]((Get-Item "ref_$t.f32").Length / 4) * 18
        Run ".\vmodel_dbl.exe" @("ref_$t.writes", "dbl_$t", "$ticks")
        Run ".\vmodel_fix.exe" @("ref_$t.writes", "fix_$t", "$ticks")
        python (Join-Path $Here 'tools\compare.py') "ref_$t.f32" "dbl_$t.f32"
        $line = python (Join-Path $Here 'tools\compare.py') "ref_$t.f32" "fix_$t.f32"
        Write-Host $line
        if ($line -match 'SNR <8k ([\d.]+) dB' -and [double]$Matches[1] -lt 55) { Write-Host '   fixed point model too far from PinMAME' -ForegroundColor Red; $fail = $true }
        if (-not $NoVhdl) {
            $n = (Get-Content "fix_$t.txt" | Measure-Object -Line).Lines
            & $Ghdl -r --std=08 tb_votrax_sc01 "-gWRITES=ref_$t.writes" "-gOUTFILE=vhdl_$t.txt" "-gNSAMPLES=$n" '-gTICK_DIV=10' | Select-Object -Last 1
            python (Join-Path $Here 'tools\compare.py') --exact "fix_$t.txt" "vhdl_$t.txt"
            if ($LASTEXITCODE -ne 0) { Write-Host '   VHDL differs from the fixed point model' -ForegroundColor Red; $fail = $true }
        }
    }
    if (-not $NoVhdl) {
        # the main clock NCO (the bit exact runs above use the fixed tick divider)
        Write-Host '== NCO' -ForegroundColor Cyan
        New-Item -ItemType Directory -Force 'nco' | Out-Null
        Push-Location 'nco'
        try {
            Remove-Item -ErrorAction SilentlyContinue 'work-obj08.cf'
            Run $Ghdl @('-a', '--std=08', "$Rtl\votrax_tables_pkg.vhd", "$Rtl\votrax_sc01.vhd", (Join-Path $Here 'tb\tb_votrax_nco.vhd'))
            Run $Ghdl @('-e', '--std=08', 'tb_votrax_nco')
            $out = & $Ghdl -r --std=08 tb_votrax_nco
            $out | Select-String 'clk_ctrl|NCO' | ForEach-Object { Write-Host "   $($_.Line -replace '^.*\(report note\): ', '')" }
            if ($LASTEXITCODE -ne 0) { $fail = $true }
        }
        finally { Pop-Location }
    }
    if ($fail) { Write-Host 'FAILED' -ForegroundColor Red; exit 1 }
    Write-Host 'all tests passed' -ForegroundColor Green
}
finally { Pop-Location }
