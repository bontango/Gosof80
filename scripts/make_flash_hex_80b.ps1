<#
.SYNOPSIS
  Builds the Intel HEX file with the game ROMs of GOSOF80B (MA-766) for the configuration
  flash, from the PinMAME ROM sets in ..\Gosof80B\roms. Sister of make_flash_hex.ps1.

.DESCRIPTION
  Layout in the flash, 24 KB per game:

      FLASH_BASE + n * 6000h   + 0000h  yrom1   Y CPU $E000 (has the vectors)
                               + 2000h  yrom2   Y CPU $C000 (FF where the game has none)
                               + 4000h  drom    D CPU $E000

  FLASH_BASE is read from variants\80B_dev_open\variant_pkg.vhd. 64 slots fit into the
  EPCS16, 9 are used. Slot n is selected with S1 = binary n, ON = '1' (not game_sel).

  THE RESULT CONTAINS COPYRIGHTED GAME ROMS. Write it below output_files\ (ignored by git)
  and never into bin\. variants\80B_dev_open\gosof80_roms.cof expects it at
  output_files\gosof80_roms.hex, which is the default of -Out.

.PARAMETER RomDir
  Folder with the ROM .zip files. Default ..\Gosof80B\roms next to FPGA_Source.

.PARAMETER Out
  The .hex file to write. Default variants\80B_dev_open\output_files\gosof80_roms.hex.

.PARAMETER BinDir
  Also write every slot as slot_<n>.bin into this folder, for sim\gosof80b\run_sim.ps1.

.EXAMPLE
  .\make_flash_hex_80b.ps1
  cd ..\variants\80B_dev_open ; quartus_cpf -c gosof80_roms.cof
#>
param(
    [string]$RomDir,
    [string]$Out,
    [string]$BinDir
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir
$VarDir    = Join-Path $RepoRoot 'variants\80B_dev_open'
if (-not $RomDir) { $RomDir = Join-Path (Split-Path -Parent $RepoRoot) 'Gosof80B\roms' }
if (-not $Out)    { $Out = Join-Path $VarDir 'output_files\gosof80_roms.hex' }

$RomBytes  = 8192
$SlotBytes = 3 * $RomBytes
$FlashEnd  = 0x200000    # EPCS16, 2 MB
$pkg = Get-Content (Join-Path $VarDir 'variant_pkg.vhd') -Raw
if ($pkg -notmatch 'FLASH_BASE\s*:\s*integer\s*:=\s*16#([0-9A-Fa-f_]+)#') { throw "no FLASH_BASE in $VarDir\variant_pkg.vhd" }
$FlashBase = [Convert]::ToInt32(($Matches[1] -replace '_', ''), 16)

# Slot order = docs\GOSOF80B_games.xlsx. Marco Albus's test EPROM is not here: it reports on LEDs
# at address line 8 of the CPUs, which do not exist on an FPGA, and makes no sound.
$Slots = @(
    @{ Name = 'Rock';           Zip = 'rock.zip';     Y1 = '^yrom1'; Y2 = '^yrom2'; D = '^drom' }
    @{ Name = 'Raven';          Zip = 'raven.zip';    Y1 = '^yrom1'; Y2 = '^yrom2'; D = '^drom' }
    @{ Name = 'Rock Encore';    Zip = 'rock_enc.zip'; Y1 = '^yrom1'; Y2 = '^yrom2'; D = '^drom' }
    @{ Name = 'Hollywood Heat'; Zip = 'hlywoodh.zip'; Y1 = '^yrom1'; Y2 = '^yrom2'; D = '^drom' }
    @{ Name = 'Genesis';        Zip = 'genesis.zip';  Y1 = '^yrom1'; Y2 = '^yrom2'; D = '^drom' }
    @{ Name = 'Gold Wings';     Zip = 'goldwing.zip'; Y1 = '^yrom1'; Y2 = '^yrom2'; D = '^drom' }
    @{ Name = 'Monte Carlo';    Zip = 'mntecrlo.zip'; Y1 = '^yrom1'; Y2 = '^yrom2'; D = '^drom' }
    @{ Name = 'Spring Break';   Zip = 'sprbreak.zip'; Y1 = '^yrom1'; Y2 = '^yrom2'; D = '^drom' }
    @{ Name = 'Arena';          Zip = 'arena.zip';    Y1 = '^yrom1'; Y2 = '^yrom2'; D = '^drom' }
)
if ($FlashBase + $Slots.Count * $SlotBytes -gt $FlashEnd) { throw "$($Slots.Count) slots do not fit behind FLASH_BASE" }

Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -TypeDefinition @"
using System;
using System.Text;
public static class GosofFlash80B {
    static void Rec(StringBuilder sb, int type, int addr, byte[] d, int off, int len) {
        int sum = len + ((addr >> 8) & 0xFF) + (addr & 0xFF) + type;
        sb.AppendFormat(":{0:X2}{1:X4}{2:X2}", len, addr & 0xFFFF, type);
        for (int i = 0; i < len; i++) { sb.AppendFormat("{0:X2}", d[off + i]); sum += d[off + i]; }
        sb.AppendFormat("{0:X2}\r\n", (-sum) & 0xFF);
    }
    // Intel HEX with type 04 records for the upper address half, absolute addresses.
    public static void Data(StringBuilder sb, int addr, byte[] d, int off, int len) {
        int upper = -1;
        for (int p = 0; p < len; p += 16) {
            int a = addr + p;
            if ((a >> 16) != upper) {
                upper = a >> 16;
                Rec(sb, 4, 0, new byte[] { (byte)(upper >> 8), (byte)upper }, 0, 2);
            }
            Rec(sb, 0, a, d, off + p, Math.Min(16, len - p));
        }
    }
    public static void End(StringBuilder sb) { Rec(sb, 1, 0, new byte[0], 0, 0); }
}
"@

# One ROM of a zip, $null when the set does not have it.
function Read-Rom($Zip, [string]$Pattern, [string]$What) {
    $hits = @($Zip.Entries | Where-Object { $_.Name -match $Pattern })
    if ($hits.Count -gt 1) { throw "$What`: more than one file matches $Pattern" }
    if ($hits.Count -eq 0) { return $null }
    $ms = New-Object System.IO.MemoryStream
    $s = $hits[0].Open()
    $s.CopyTo($ms)
    $s.Close()
    $b = $ms.ToArray()
    if ($b.Length -ne $RomBytes) { throw "$What`: $($hits[0].Name) is $($b.Length) bytes, expected $RomBytes" }
    return ,$b
}

$sb = New-Object System.Text.StringBuilder
if ($BinDir -and -not (Test-Path $BinDir)) { $null = New-Item -ItemType Directory -Path $BinDir }
for ($n = 0; $n -lt $Slots.Count; $n++) {
    $g = $Slots[$n]
    $zip = [System.IO.Compression.ZipFile]::OpenRead((Join-Path $RomDir $g.Zip))
    try {
        $y1 = Read-Rom $zip $g.Y1 $g.Name
        $y2 = Read-Rom $zip $g.Y2 $g.Name
        $d  = Read-Rom $zip $g.D  $g.Name
    } finally { $zip.Dispose() }
    if ($null -eq $y1 -or $null -eq $d) { throw "$($g.Name): yrom1 or drom missing in $($g.Zip)" }

    # Both CPUs start at their vectors. The reset vector has to point into a ROM of the slot.
    $rstY = [int]$y1[$RomBytes - 3] * 256 + $y1[$RomBytes - 4]
    $rstD = [int]$d[$RomBytes - 3] * 256 + $d[$RomBytes - 4]
    if ($rstY -lt 0xC000 -or ($rstY -lt 0xE000 -and $null -eq $y2)) { throw ('{0}: Y reset vector {1:X4} points to nothing' -f $g.Name, $rstY) }
    if ($rstD -lt 0xE000) { throw ('{0}: D reset vector {1:X4} is not in drom' -f $g.Name, $rstD) }

    $slot = New-Object byte[] $SlotBytes
    for ($i = $RomBytes; $i -lt 2 * $RomBytes; $i++) { $slot[$i] = 0xFF }
    [Array]::Copy($y1, 0, $slot, 0, $RomBytes)
    if ($null -ne $y2) { [Array]::Copy($y2, 0, $slot, $RomBytes, $RomBytes) }
    [Array]::Copy($d, 0, $slot, 2 * $RomBytes, $RomBytes)

    $addr = $FlashBase + $n * $SlotBytes
    [GosofFlash80B]::Data($sb, $addr, $slot, 0, $SlotBytes)
    if ($BinDir) { [System.IO.File]::WriteAllBytes((Join-Path $BinDir "slot_$n.bin"), $slot) }
    Write-Host ('slot {0}: {1:X6} {2,-15} RST Y {3:X4} D {4:X4}{5}' -f $n, $addr, $g.Name, $rstY, $rstD, $(if ($null -eq $y2) { '  (no yrom2)' } else { '' }))
}
[GosofFlash80B]::End($sb)

if ([System.IO.Path]::IsPathRooted($Out)) { $outFull = $Out }
else { $outFull = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Out)) }
$dir = Split-Path $outFull
if (-not (Test-Path $dir)) { $null = New-Item -ItemType Directory -Path $dir }
[System.IO.File]::WriteAllText($outFull, $sb.ToString(), (New-Object System.Text.ASCIIEncoding))
Write-Host ('{0} slots written to {1}' -f $Slots.Count, $outFull)
