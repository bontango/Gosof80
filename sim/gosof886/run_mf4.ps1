<#
.SYNOPSIS
  GHDL check of rtl\hw5x_80b\mf4_filter.vhd against the theoretical response, see tb_mf4.vhd.
#>
$ErrorActionPreference = 'Stop'
$Here  = Split-Path -Parent $MyInvocation.MyCommand.Path
$Repo  = Split-Path -Parent (Split-Path -Parent $Here)
$Build = Join-Path $Here 'build\mf4'
$Rtl   = Join-Path $Repo 'rtl\hw5x_80b'
$Ghdl  = 'C:\Users\bonta\tools\ghdl\bin\ghdl.exe'
New-Item -ItemType Directory -Force $Build | Out-Null
Push-Location $Build
try {
    Remove-Item -ErrorAction SilentlyContinue 'work-obj08.cf'
    & $Ghdl -a --std=08 -frelaxed "$Rtl\mf4_table_pkg.vhd" "$Rtl\mf4_filter.vhd" (Join-Path $Here 'tb_mf4.vhd')
    if ($LASTEXITCODE -ne 0) { throw 'ghdl -a failed' }
    & $Ghdl -e --std=08 -frelaxed tb_mf4
    if ($LASTEXITCODE -ne 0) { throw 'ghdl -e failed' }
    & $Ghdl -r --std=08 -frelaxed tb_mf4 --ieee-asserts=disable-at-0
    if ($LASTEXITCODE -ne 0) { throw 'tb_mf4 failed' }
}
finally { Pop-Location }
