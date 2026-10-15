<#
.SYNOPSIS
  Version announcement: tables, reference rendering, sequencer check.
.DESCRIPTION
  1. tools\gen_announce.py    rtl\common\votrax\vtx_announce_pkg.vhd + stimuli\t6_version.txt
  2. ref\ref_votrax           renders t6_version.txt with PinMAME's votrax.c
                              -> build\ref_t6_version.wav (to listen to)
  3. GHDL                     tb\tb_vtx_announce.vhd: the sequencer writes exactly those bytes
  Needs python, GHDL (C:\Users\bonta\tools\ghdl) and build\ref_votrax.exe (run_sim.ps1 builds it).
.PARAMETER Board
  Board id for the rendering and the check (default 3 = hw2x_cyclone_IV_v4).
.PARAMETER Minor
  SwMinor (default 98).
#>
param([int]$Board = 3, [int]$Minor = 98)
$ErrorActionPreference = 'Stop'
$Here  = Split-Path -Parent $MyInvocation.MyCommand.Path
$Build = Join-Path $Here 'build'
$Rtl   = Join-Path (Split-Path -Parent (Split-Path -Parent $Here)) 'rtl\common\votrax'
$Ghdl  = 'C:\Users\bonta\tools\ghdl\bin\ghdl.exe'

python (Join-Path $Here 'tools\gen_announce.py') $Board $Minor
if ($LASTEXITCODE -ne 0) { throw 'gen_announce.py failed' }

Push-Location $Build
try {
    & .\ref_votrax.exe (Join-Path $Here 'stimuli\t6_version.txt') 'ref_t6_version'
    if ($LASTEXITCODE -ne 0) { throw 'ref_votrax failed' }
    New-Item -ItemType Directory -Force 'ann' | Out-Null
    Push-Location 'ann'
    try {
        Remove-Item -ErrorAction SilentlyContinue 'work-obj08.cf'
        Copy-Item (Join-Path $Here 'stimuli\t6_version.txt') .
        & $Ghdl -a --std=08 "$Rtl\vtx_announce_pkg.vhd" "$Rtl\vtx_announce.vhd" (Join-Path $Here 'tb\tb_vtx_announce.vhd')
        & $Ghdl -e --std=08 tb_vtx_announce
        & $Ghdl -r --std=08 tb_vtx_announce "-gBOARD_ID=$Board" "-gSW_MINOR=$Minor"
        if ($LASTEXITCODE -ne 0) { throw 'tb_vtx_announce failed' }
    }
    finally { Pop-Location }
}
finally { Pop-Location }
Write-Host "listen: $Build\ref_t6_version.wav"
