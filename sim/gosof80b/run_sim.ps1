<#
.SYNOPSIS
  GHDL check of GOSOF80B (MA-766): runs the real ROMs on top\GOSOF80B.vhd.
.DESCRIPTION
  scripts\make_flash_hex_80b.ps1 packs the ROMs into sim\gosof80b\build\slot_<n>.bin (git
  ignored, copyrighted). One GHDL process per slot, in parallel, each in build\run_<n>\ with
  its own slot.bin, log and audio.wav. tb_gosof80b.vhd: see its header.
.PARAMETER Slots
  Which slots (0..8). Default all.
.PARAMETER BootMs
  Milliseconds before the first sound command.
.PARAMETER GapMs
  Milliseconds per sound command.
.PARAMETER Jobs
  How many GHDL processes at the same time.
.EXAMPLE
  .\run_sim.ps1 -Slots 0
#>
param(
    [int[]]$Slots = (0..8),
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
& (Join-Path $Repo 'scripts\make_flash_hex_80b.ps1') -BinDir $Build -Out (Join-Path $Build 'gosof80_roms.hex') 6>$null

Push-Location $Build
try {
    Remove-Item -ErrorAction SilentlyContinue 'work-obj08.cf'
    $src = @(
        "$Rtl\common\T65\T65_Pack.vhd", "$Rtl\common\T65\T65_MCode.vhd", "$Rtl\common\T65\T65_ALU.vhd", "$Rtl\common\T65\T65.vhd",
        "$Rtl\common\dac.vhd", "$Rtl\common\soundtest.vhd", "$Rtl\common\uart_clk_gen.vhd", "$Rtl\common\slow_to_fast_clock_bus.vhd",
        "$Rtl\hw5x_80b\ym2149_audio.vhd", "$Rtl\hw5x_80b\sp0250.vhd", (Join-Path $Here 'sim_models.vhd'), (Join-Path $Repo 'top\GOSOF80B.vhd'), (Join-Path $Here 'tb_gosof80b.vhd')
    )
    & $Ghdl -a --std=08 -frelaxed -fsynopsys -Wno-hide $src
    if ($LASTEXITCODE -ne 0) { throw 'ghdl -a failed' }
    & $Ghdl -e --std=08 -frelaxed -fsynopsys tb_gosof80b
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
$Slots | ForEach-Object { $pending.Enqueue($_) }
$t0 = Get-Date
while ($pending.Count -gt 0 -or $running.Count -gt 0) {
    while ($pending.Count -gt 0 -and $running.Count -lt $Jobs) {
        $n = $pending.Dequeue()
        $dir = Join-Path $Build "run_$n"
        New-Item -ItemType Directory -Force $dir | Out-Null
        Copy-Item (Join-Path $Build "slot_$n.bin") (Join-Path $dir 'slot.bin') -Force
        $a = @('-r', '--std=08', '-frelaxed', '-fsynopsys', '--workdir=..', 'tb_gosof80b', '--ieee-asserts=disable-at-0', "-gBoot_ms=$BootMs", "-gGap_ms=$GapMs")
        $running[$n] = Start-Process -FilePath $Ghdl -ArgumentList $a -WorkingDirectory $dir -NoNewWindow -PassThru `
            -RedirectStandardOutput (Join-Path $dir 'stdout.log') -RedirectStandardError (Join-Path $dir 'stderr.log')
    }
    Start-Sleep -Seconds 2
    foreach ($n in @($running.Keys)) {
        if ($running[$n].HasExited) {
            $running.Remove($n)
            Write-Host ("slot {0} finished after {1:n0} s" -f $n, ((Get-Date) - $t0).TotalSeconds)
        }
    }
}

$fail = $false
foreach ($n in $Slots) {
    $dir = Join-Path $Build "run_$n"
    $log = @(Get-Content (Join-Path $dir 'stdout.log'))
    $res = $log | Where-Object { $_ -cmatch 'RESULT' }
    if (-not $res) { Write-Host "slot $n`: no result" -ForegroundColor Red; Get-Content (Join-Path $dir 'stderr.log') | Select-Object -First 5; $log | Select-Object -Last 5; $fail = $true; continue }
    Write-Host ("slot {0}: {1}" -f $n, ($res -replace '^.*RESULT ', ''))
    if ($res -notmatch 'bad_cmds=0 ') { $fail = $true }
    Write-Wav (Join-Path $dir 'audio.raw') (Join-Path $dir 'audio.wav')
}
if ($fail) { Write-Host 'FAIL' -ForegroundColor Red; exit 1 }
Write-Host 'PASS' -ForegroundColor Green
