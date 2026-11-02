<#
.SYNOPSIS
  GHDL check of GOSOF80B MA-886: runs the real ROMs on top\GOSOF80B_886.vhd with an SRAM model.
.DESCRIPTION
  scripts\make_flash_hex_886.ps1 packs the ROMs into sim\gosof886\build\gen<g>\slot_<n>.bin (git
  ignored, copyrighted). One GHDL process per game, in parallel, each in its own run_<g>_<n>\ with
  slot.bin, log and audio.wav. GHDL has no Verilog: for generation 3 sim_models.vhd stands in for the
  jt51, so the YM2151 writes are counted but its sound is not simulated.
.PARAMETER Games
  Which games, as gen.slot in quotes, e.g. '2.0','3.1'. Default all 9.
.PARAMETER BootMs
  Milliseconds before the first sound command.
.PARAMETER GapMs
  Milliseconds per sound command.
.PARAMETER Jobs
  How many GHDL processes at the same time.
.EXAMPLE
  .\run_sim.ps1 -Games '2.1','3.0'
#>
param(
    [string[]]$Games = @('2.0','2.1','2.2','2.3','2.4','3.0','3.1','3.2','3.3'),
    [int]$BootMs = 300,
    [int]$GapMs = 40,
    [int]$Jobs = 4
)
$ErrorActionPreference = 'Stop'
$Here  = Split-Path -Parent $MyInvocation.MyCommand.Path
$Repo  = Split-Path -Parent (Split-Path -Parent $Here)
$Build = Join-Path $Here 'build'
$Rtl   = Join-Path $Repo 'rtl'
$Ghdl  = 'C:\Users\bonta\tools\ghdl\bin\ghdl.exe'

New-Item -ItemType Directory -Force $Build | Out-Null
foreach ($g in 2, 3) {
    $b = Join-Path $Build "gen$g"
    & (Join-Path $Repo 'scripts\make_flash_hex_886.ps1') -Gen $g -BinDir $b -Out (Join-Path $b 'gosof80_roms.hex') 6>$null
}

Push-Location $Build
try {
    Remove-Item -ErrorAction SilentlyContinue 'work-obj08.cf'
    $src = @(
        "$Rtl\common\T65\T65_Pack.vhd", "$Rtl\common\T65\T65_MCode.vhd", "$Rtl\common\T65\T65_ALU.vhd", "$Rtl\common\T65\T65.vhd",
        "$Rtl\common\dac.vhd", "$Rtl\common\soundtest.vhd", "$Rtl\common\uart_clk_gen.vhd", "$Rtl\common\slow_to_fast_clock_bus.vhd",
        "$Rtl\hw5x_80b\ym2149_audio.vhd", "$Rtl\hw5x_80b\mf4_table_pkg.vhd", "$Rtl\hw5x_80b\mf4_filter.vhd", "$Rtl\hw5x_80b\sram_arbiter.vhd",
        (Join-Path $Here 'sim_models.vhd'), (Join-Path $Repo 'top\GOSOF80B_886.vhd'), (Join-Path $Here 'tb_gosof886.vhd')
    )
    & $Ghdl -a --std=08 -frelaxed -fsynopsys -Wno-hide $src
    if ($LASTEXITCODE -ne 0) { throw 'ghdl -a failed' }
    & $Ghdl -e --std=08 -frelaxed -fsynopsys tb_gosof886
    if ($LASTEXITCODE -ne 0) { throw 'ghdl -e failed' }
}
finally { Pop-Location }

# audio.raw -> audio.wav, 16 bit mono 44.09 kHz, offset binary to signed
function Write-Wav([string]$Raw, [string]$Wav) {
    $d = [System.IO.File]::ReadAllBytes($Raw)
    $rate = 44092
    $ms = New-Object System.IO.MemoryStream
    $w = New-Object System.IO.BinaryWriter($ms)
    $w.Write([Text.Encoding]::ASCII.GetBytes('RIFF')); $w.Write([int](36 + $d.Length)); $w.Write([Text.Encoding]::ASCII.GetBytes('WAVEfmt '))
    $w.Write([int]16); $w.Write([int16]1); $w.Write([int16]1); $w.Write([int]$rate); $w.Write([int]($rate * 2)); $w.Write([int16]2); $w.Write([int16]16)
    $w.Write([Text.Encoding]::ASCII.GetBytes('data')); $w.Write([int]$d.Length)
    for ($i = 1; $i -lt $d.Length; $i += 2) { $d[$i] = $d[$i] -bxor 0x80 }
    $w.Write($d)
    $w.Flush()
    [System.IO.File]::WriteAllBytes($Wav, $ms.ToArray())
}

$running = @{}
$pending = New-Object System.Collections.Queue
$Games | ForEach-Object { $pending.Enqueue($_) }
$t0 = Get-Date
while ($pending.Count -gt 0 -or $running.Count -gt 0) {
    while ($pending.Count -gt 0 -and $running.Count -lt $Jobs) {
        $id = $pending.Dequeue()
        $g, $n = $id -split '\.'
        $dir = Join-Path $Build "run_${g}_$n"
        New-Item -ItemType Directory -Force $dir | Out-Null
        Copy-Item (Join-Path $Build "gen$g\slot_$n.bin") (Join-Path $dir 'slot.bin') -Force
        $a = @('-r', '--std=08', '-frelaxed', '-fsynopsys', '--workdir=..', 'tb_gosof886', '--ieee-asserts=disable-at-0', "-gGEN=$g", "-gBoot_ms=$BootMs", "-gGap_ms=$GapMs")
        $running[$id] = Start-Process -FilePath $Ghdl -ArgumentList $a -WorkingDirectory $dir -NoNewWindow -PassThru `
            -RedirectStandardOutput (Join-Path $dir 'stdout.log') -RedirectStandardError (Join-Path $dir 'stderr.log')
    }
    Start-Sleep -Seconds 2
    foreach ($id in @($running.Keys)) {
        if ($running[$id].HasExited) {
            $running.Remove($id)
            Write-Host ("game {0} finished after {1:n0} s" -f $id, ((Get-Date) - $t0).TotalSeconds)
        }
    }
}

$fail = $false
foreach ($id in $Games) {
    $g, $n = $id -split '\.'
    $dir = Join-Path $Build "run_${g}_$n"
    $log = @(Get-Content (Join-Path $dir 'stdout.log'))
    $res = $log | Where-Object { $_ -cmatch 'RESULT' }
    if (-not $res) { Write-Host "game $id`: no result" -ForegroundColor Red; Get-Content (Join-Path $dir 'stderr.log') | Select-Object -First 5; $log | Select-Object -Last 5; $fail = $true; continue }
    Write-Host ("game {0}: {1}" -f $id, ($res -replace '^.*RESULT ', ''))
    if ($res -notmatch 'bad_cmds=0 bad_rom=0 ' -or $res -notmatch 'nmi_bad=0 ') { $fail = $true }
    Write-Wav (Join-Path $dir 'audio.raw') (Join-Path $dir 'audio.wav')
}
if ($fail) { Write-Host 'FAIL' -ForegroundColor Red; exit 1 }
Write-Host 'PASS' -ForegroundColor Green
