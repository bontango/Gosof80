<#
.SYNOPSIS
  Builds the core board PLL test (plltest.vhd) and writes output_files\plltest.sof and .jic.
.DESCRIPTION
  See README.md. Uses Quartus 22.1std (Cyclone IV E). In PowerShell 5.1 no 2>&1 on
  quartus_*.exe, $LASTEXITCODE decides.
#>
$ErrorActionPreference = 'Stop'
$q = 'C:\intelFPGA_lite\22.1std\quartus\bin64'
Push-Location $PSScriptRoot
try {
	& "$q\quartus_sh.exe" --flow compile plltest | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "quartus_sh failed ($LASTEXITCODE), see output_files\plltest.flow.rpt" }
	& "$q\quartus_cpf.exe" -c -d EPCS4 -s EP4CE6 output_files\plltest.sof output_files\plltest.jic | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "quartus_cpf failed ($LASTEXITCODE)" }
	Get-ChildItem output_files\plltest.sof, output_files\plltest.jic | Select-Object FullName, Length
}
finally { Pop-Location }
