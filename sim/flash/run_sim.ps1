<#
.SYNOPSIS
  GHDL check of rtl\hw5x\Flash_ROM.vhd (HW 5.x, game ROMs from the EPCS4).
.DESCRIPTION
  tb_flash_rom.vhd: behavioural SPI flash, games 0 and 53 must arrive byte for byte at
  the ROM write port (slot address = base + n * slot size, 4 KB, 24 KB and 64 KB), game 5 is an erased slot and
  must end in Flash_error. Output and GHDL library in sim\flash\build\ (git ignored).
#>
$ErrorActionPreference = 'Stop'
$Here  = Split-Path -Parent $MyInvocation.MyCommand.Path
$Build = Join-Path $Here 'build'
$Rtl   = Join-Path (Split-Path -Parent (Split-Path -Parent $Here)) 'rtl\hw5x'
$Ghdl  = 'C:\Users\bonta\tools\ghdl\bin\ghdl.exe'

New-Item -ItemType Directory -Force $Build | Out-Null
Push-Location $Build
try {
    Remove-Item -ErrorAction SilentlyContinue 'work-obj08.cf'
    & $Ghdl -a --std=08 "$Rtl\Flash_ROM.vhd" (Join-Path $Here 'tb_flash_rom.vhd')
    if ($LASTEXITCODE -ne 0) { throw 'ghdl -a failed' }
    & $Ghdl -e --std=08 tb_flash_rom
    if ($LASTEXITCODE -ne 0) { throw 'ghdl -e failed' }
    foreach ($slot in 4096, 24576, 65536) {   # GOSOF80, GOSOF80B MA-766, MA-886
        & $Ghdl -r --std=08 tb_flash_rom "-gSLOT=$slot"
        if ($LASTEXITCODE -ne 0) { throw "tb_flash_rom failed, slot $slot" }
    }
}
finally { Pop-Location }