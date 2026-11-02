<#
.SYNOPSIS
  Builds the Intel HEX file with the game ROMs of the MA-886 for the configuration flash, from the
  PinMAME ROM sets in ..\Gosof80B\roms. Sister of make_flash_hex_80b.ps1.

.DESCRIPTION
  One file per generation, the bitstream of a generation only knows its own games. 64 KB per game:

      FLASH_BASE + n * 10000h   + 0000h  yrom   Y CPU $8000-$FFFF
                                + 8000h  drom   D CPU $8000-$FFFF

  Slot n is selected with S1 = binary n, ON = '1'.

  THE RESULT CONTAINS COPYRIGHTED GAME ROMS. Write it below output_files\ (ignored by git)
  and never into bin\. The variant's gosof80_roms.cof expects it at output_files\gosof80_roms.hex,
  which is the default of -Out.

.PARAMETER Gen
  2 or 3.

.PARAMETER RomDir
  Folder with the ROM .zip files. Default ..\Gosof80B\roms next to FPGA_Source.

.PARAMETER Out
  The .hex file to write.

.PARAMETER BinDir
  Also write every slot as slot_<n>.bin into this folder, for sim\gosof886\run_sim.ps1.

.EXAMPLE
  .\make_flash_hex_886.ps1 -Gen 2
  cd ..\variants\80B_ma886_gen2 ; quartus_cpf -c gosof80_roms.cof
#>
param(
    [Parameter(Mandatory = $true)][ValidateSet(2, 3)][int]$Gen,
    [string]$RomDir,
    [string]$Out,
    [string]$BinDir
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir
$VarDir    = Join-Path $RepoRoot "variants\80B_ma886_gen$Gen"
if (-not $RomDir) { $RomDir = Join-Path (Split-Path -Parent $RepoRoot) 'Gosof80B\roms' }
if (-not $Out)    { $Out = Join-Path $VarDir 'output_files\gosof80_roms.hex' }

$RomBytes  = 32768
$SlotBytes = 2 * $RomBytes
$FlashEnd  = 0x200000    # EPCS16, 2 MB
$pkg = Get-Content (Join-Path $VarDir 'variant_pkg.vhd') -Raw
if ($pkg -notmatch 'FLASH_BASE\s*:\s*integer\s*:=\s*16#([0-9A-Fa-f_]+)#') { throw "no FLASH_BASE in $VarDir\variant_pkg.vhd" }
$FlashBase = [Convert]::ToInt32(($Matches[1] -replace '_', ''), 16)

# Original set excaliba.zip is not here, excalibr.zip is. Bone Busters is not on the list: its third
# CPU does not fit into the EP4CE6.
if ($Gen -eq 2) {
    $Slots = @(
        @{ Name = 'Victory';      Zip = 'victory.zip';  Y = '^yrom1'; D = '^drom1' }
        @{ Name = 'Diamond Lady'; Zip = 'diamond.zip';  Y = '^yrom1'; D = '^drom1' }
        @{ Name = 'TX-Sector';    Zip = 'txsector.zip'; Y = '^yrom1'; D = '^drom1' }
        @{ Name = 'Robo-War';     Zip = 'robowars.zip'; Y = '^yrom1'; D = '^drom1' }
        @{ Name = 'Excalibur';    Zip = 'excalibr.zip'; Y = '^yrom1'; D = '^drom1' }
    )
} else {
    $Slots = @(
        @{ Name = 'Bad Girls';   Zip = 'badgirls.zip'; Y = '^yrom1';    D = '^drom1' }
        @{ Name = 'Big House';   Zip = 'bighouse.zip'; Y = '^yrom1';    D = '^drom1' }
        @{ Name = 'Hot Shots';   Zip = 'hotshots.zip'; Y = '^yrom1';    D = '^drom1' }
        @{ Name = 'Night Moves'; Zip = 'nmoves.zip';   Y = '^nmovyrom'; D = '^nmovdrom' }
    )
}
if ($FlashBase + $Slots.Count * $SlotBytes -gt $FlashEnd) { throw "$($Slots.Count) slots do not fit behind FLASH_BASE" }

Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -TypeDefinition @"
using System;
using System.Text;
public static class GosofFlash886 {
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

function Read-Rom($Zip, [string]$Pattern, [string]$What) {
    $hits = @($Zip.Entries | Where-Object { $_.Name -match $Pattern })
    if ($hits.Count -ne 1) { throw "$What`: $($hits.Count) files match $Pattern" }
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
        $y = Read-Rom $zip $g.Y $g.Name
        $d = Read-Rom $zip $g.D $g.Name
    } finally { $zip.Dispose() }

    # Both CPUs start at their vectors, which have to point into the ROM of the slot.
    $rstY = [int]$y[$RomBytes - 3] * 256 + $y[$RomBytes - 4]
    $rstD = [int]$d[$RomBytes - 3] * 256 + $d[$RomBytes - 4]
    if ($rstY -lt 0x8000) { throw ('{0}: Y reset vector {1:X4} is not in yrom' -f $g.Name, $rstY) }
    if ($rstD -lt 0x8000) { throw ('{0}: D reset vector {1:X4} is not in drom' -f $g.Name, $rstD) }

    $slot = New-Object byte[] $SlotBytes
    [Array]::Copy($y, 0, $slot, 0, $RomBytes)
    [Array]::Copy($d, 0, $slot, $RomBytes, $RomBytes)

    $addr = $FlashBase + $n * $SlotBytes
    [GosofFlash886]::Data($sb, $addr, $slot, 0, $SlotBytes)
    if ($BinDir) { [System.IO.File]::WriteAllBytes((Join-Path $BinDir "slot_$n.bin"), $slot) }
    Write-Host ('slot {0}: {1:X6} {2,-13} RST Y {3:X4} D {4:X4}' -f $n, $addr, $g.Name, $rstY, $rstD)
}
[GosofFlash886]::End($sb)

if ([System.IO.Path]::IsPathRooted($Out)) { $outFull = $Out }
else { $outFull = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Out)) }
$dir = Split-Path $outFull
if (-not (Test-Path $dir)) { $null = New-Item -ItemType Directory -Path $dir }
[System.IO.File]::WriteAllText($outFull, $sb.ToString(), (New-Object System.Text.ASCIIEncoding))
Write-Host ('{0} slots written to {1}' -f $Slots.Count, $outFull)
