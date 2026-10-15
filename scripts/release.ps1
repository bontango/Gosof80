<#
.SYNOPSIS
  Builds every active GOSOF80 variant and copies the artefacts to bin\<BinFolder>\.

.DESCRIPTION
  A release is one version across all boards. The software digits live in
  scripts\version.psd1 (SwMinor), the board id in variants\<name>\variant.psd1, and
  the artefact is named the way the releases have always been named:

      bin\<BinFolder>\GOSOF80_<HwName>_v<BoardId>.<SwMinor>.<jic|pof>

  e.g. bin\Cyclone_10\GOSOF80_HW2.x_v4.97.jic. HwName comes from variant.psd1 (default
  HW2.x; hw4x_cyclone_10 has HW4.x). The design itself carries no version,
  so the file name is the only place it shows up.

  Nothing is overwritten silently: an existing file of the same name aborts the run
  unless -Force is given. The changelog is append only and is the place to write down
  what is NOT tested on hardware.

.PARAMETER Note
  One line describing this release. Goes into bin\changelog.txt. Required unless -DryRun.

.PARAMETER Variants
  Limit to these variants. Default: all that are not Dormant.

.PARAMETER DryRun
  Build nothing, copy nothing - only list the file names a release would produce.

.PARAMETER Force
  Overwrite artefacts that already exist in bin\.

.EXAMPLE
  .\release.ps1 -DryRun

.EXAMPLE
  .\release.ps1 -Note "v.98: <what changed>"
#>
param(
    [string]  $Note,
    [string[]]$Variants,
    [switch]  $DryRun,
    [switch]  $Force
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir
$VarRoot   = Join-Path $RepoRoot 'variants'
$BinRoot   = Join-Path $RepoRoot 'bin'
$project   = 'GOSOF80'

if (-not $DryRun -and -not $Note) { throw '-Note is required (or use -DryRun)' }

$version = Import-PowerShellDataFile (Join-Path $ScriptDir 'version.psd1')
$minor   = $version.SwMinor
if ($minor -notmatch '^\d{2}$') { throw "SwMinor in scripts\version.psd1 must be two digits, is '$minor'" }

$folders = Get-ChildItem $VarRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'variant.psd1') }
if ($Variants) { $folders = $folders | Where-Object { $Variants -contains $_.Name } }
else           { $folders = $folders | Where-Object { -not (Import-PowerShellDataFile (Join-Path $_.FullName 'variant.psd1')).Dormant } }
if (-not $folders) { throw "nothing to release below $VarRoot" }

$made = @()

foreach ($dir in $folders) {
    $meta   = Import-PowerShellDataFile (Join-Path $dir.FullName 'variant.psd1')
    $ver    = "$($meta.BoardId).$minor"
    $ext    = $meta.ReleaseArtifact                     # 'jic' or 'pof'
    $outDir = Join-Path $BinRoot $meta.BinFolder
    $hw     = if ($meta.HwName) { $meta.HwName } else { 'HW2.x' }
    $dst    = Join-Path $outDir "$($project)_$($hw)_v$ver.$ext"

    if ($DryRun) {
        $state = if (Test-Path $dst) { 'exists' } else { 'new' }
        $made += [pscustomobject]@{ Variant = $meta.Name; Version = $ver; File = $dst.Substring($RepoRoot.Length + 1); SHA256 = $state }
        continue
    }
    if ((Test-Path $dst) -and -not $Force) { throw "$dst already exists - bump SwMinor in scripts\version.psd1 or use -Force" }

    & (Join-Path $ScriptDir 'build.ps1') $meta.Name
    if (-not $?) { throw "build failed for $($meta.Name)" }

    $src = Join-Path $dir.FullName "output_files\$project.$ext"
    if (-not (Test-Path $src)) { throw "missing artefact: $src" }

    New-Item -ItemType Directory -Force $outDir | Out-Null
    Copy-Item $src $dst -Force

    $hash = (Get-FileHash $dst -Algorithm SHA256).Hash.Substring(0,16)
    $made += [pscustomobject]@{ Variant = $meta.Name; Version = $ver; File = $dst.Substring($RepoRoot.Length + 1); SHA256 = $hash }
}

if (-not $DryRun) {
    $log = Join-Path $BinRoot 'changelog.txt'
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
    $lines = @("", "-- $stamp  version .$minor", "--   $Note")
    foreach ($m in $made) { $lines += ("--   {0,-20} v{1,-6} {2}  sha256:{3}" -f $m.Variant, $m.Version, (Split-Path $m.File -Leaf), $m.SHA256) }
    Add-Content -Path $log -Value $lines -Encoding UTF8
    Write-Host "changelog: $log" -ForegroundColor Green
    Write-Host "Remember to note in VARIANTEN.md which of these has actually been on hardware." -ForegroundColor Yellow
}

$made | Format-Table Variant, Version, File, SHA256 -AutoSize
