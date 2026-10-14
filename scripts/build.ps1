<#
.SYNOPSIS
  Full compile of one GOSOF80 variant, plus the .jic for the serial configuration device.

.DESCRIPTION
  Runs quartus_sh --flow compile in variants\<name>\ with the Quartus version that
  matches the FAMILY in device.tcl (Cyclone II -> 13.0sp1, everything else 22.1std),
  and then, for ReleaseArtifact = 'jic', quartus_cpf against the variant's GOSOF80.cof.
  The .sof and .pof come out of the flow, the .jic does NOT - it has to be converted,
  which is what the .cof describes.

  quartus_cpf runs with the variant folder as its working directory, so the paths
  inside the .cof must be relative to it (output_files/GOSOF80.sof). Do not let Quartus
  write them back as absolute paths - a copied .cof would then flash another board.

.PARAMETER Variant
  Folder name below variants\, e.g. hw2x_cyclone_10.

.PARAMETER NoGen
  Do not regenerate the .qsf first.

.PARAMETER NoJic
  Stop after the compile, do not run quartus_cpf.

.EXAMPLE
  .\build.ps1 hw2x_cyclone_10
#>
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string] $Variant,
    [switch] $NoGen,
    [switch] $NoJic
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir
$VarDir    = Join-Path (Join-Path $RepoRoot 'variants') $Variant
if (-not (Test-Path $VarDir)) { throw "unknown variant: $Variant (looked in $RepoRoot\variants)" }

$project = 'GOSOF80'

# Same table as in check.ps1. Never use 2>&1 on the quartus_*.exe calls in Windows
# PowerShell 5.1: every stderr line becomes an ErrorRecord and $? goes false even on
# exit code 0. $LASTEXITCODE is the reliable answer.
$QuartusBin = [ordered]@{
    'Cyclone II' = 'C:\altera\13.0sp1\quartus\bin64'
    'DEFAULT'    = 'C:\intelFPGA_lite\22.1std\quartus\bin64'
}

if (-not $NoGen) { & (Join-Path $ScriptDir 'gen_qsf.ps1') -Variants $Variant -Quiet }

$meta = Import-PowerShellDataFile (Join-Path $VarDir 'variant.psd1')
Write-Host "Building $($meta.Name) - $($meta.Title)" -ForegroundColor Cyan

$family = ''
$fLine = Select-String -Path (Join-Path $VarDir 'device.tcl') -Pattern '-name FAMILY\s+"?([^"\r\n]+)"?' -List
if ($fLine) { $family = $fLine.Matches[0].Groups[1].Value.Trim().Trim('"') }
$bin = $QuartusBin['DEFAULT']
foreach ($key in $QuartusBin.Keys) {
    if ($key -ne 'DEFAULT' -and $family -like "*$key*") { $bin = $QuartusBin[$key] }
}

Push-Location $VarDir
try {
    $sh = Join-Path $bin 'quartus_sh.exe'
    if (-not (Test-Path $sh)) { throw "quartus_sh not found: $sh" }
    & $sh --flow compile $project
    if ($LASTEXITCODE -ne 0) { throw "compile failed for $Variant (exit $LASTEXITCODE)" }

    $sof = Join-Path $VarDir "output_files\$project.sof"
    if (-not (Test-Path $sof)) { throw "compile reported success but $sof is missing" }
    Write-Host "  .sof ok" -ForegroundColor Green

    if (-not $NoJic -and $meta.ReleaseArtifact -eq 'jic') {
        $cpf = Join-Path $bin 'quartus_cpf.exe'
        if (-not (Test-Path $cpf)) { throw "quartus_cpf not found: $cpf" }
        & $cpf -c "$project.cof"
        if ($LASTEXITCODE -ne 0) { throw "quartus_cpf failed for $Variant (exit $LASTEXITCODE)" }
        Write-Host "  .jic ok" -ForegroundColor Green
    }
}
finally { Pop-Location }

Write-Host "Done: variants\$Variant\output_files\" -ForegroundColor Green
