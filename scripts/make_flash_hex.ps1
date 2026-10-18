<#
.SYNOPSIS
  Builds the Intel HEX file with the game ROMs for the configuration flash of HW 5.x
  (rtl/hw5x/Flash_ROM.vhd). Taken over from WillFA7 scripts/make_flash_hex.ps1.

.DESCRIPTION
  The SD card image stays the one source of the game data. This script takes it in the
  HW 2.x layout (written by "SD image (roms)\make_sd.bat") - either an image of the whole
  card or the 4 KB files that make_sd.bat writes - and lays it out in the flash:

      card    sector 660 + n * 8          game n, 4 KB
      flash   FLASH_BASE + n * 1000h      game n, 4 KB

  FLASH_BASE is read from variants\<Variant>\variant_pkg.vhd, so the VHDL and the
  .hex cannot disagree. The EPCS4 ends at 80000h, which limits the number of slots.

  Games that are completely FF or 00 (the gaps of make_sd.bat) are left out, so that part
  of the flash stays erased - Flash_ROM.vhd then blinks the error LED for that game
  instead of running it.

  THE RESULT CONTAINS COPYRIGHTED GAME ROMS. Write it below output_files\ (ignored by
  git) and never into bin\. variants\<Variant>\gosof80_roms.cof expects it at
  output_files\gosof80_roms.hex, which is the default of -Out.

.PARAMETER Image
  Image of a GOSOF HW 2.x SD card (raw sectors), e.g. ..\Gosof_Image_v1.21.img.

.PARAMETER SlotFiles
  The 4 KB game files in game order, game 0 first, as make_sd.bat writes them.
  Instead of -Image.

.PARAMETER Variant
  Variant folder that holds variant_pkg.vhd (FLASH_BASE). Default hw5x_cyclone_IV.

.PARAMETER Games
  How many slots to take from -Image. Default 55 = games 0..54, the last one make_sd.bat
  writes (System 1, Astro Annie); behind it the card image holds other files (text),
  which must not end up as game code. Those slots stay erased.

.PARAMETER Out
  The .hex file to write. Default variants\<Variant>\output_files\gosof80_roms.hex.

.EXAMPLE
  .\make_flash_hex.ps1 -Image ..\..\Gosof_Image_v1.21.img
  cd ..\variants\hw5x_cyclone_IV ; quartus_cpf -c gosof80_roms.cof
#>
param(
    [string]$Image,
    [string[]]$SlotFiles,
    [string]$Variant = 'hw5x_cyclone_IV',
    [int]$Games = 55,
    [string]$Out
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VarDir    = Join-Path (Join-Path (Split-Path -Parent $ScriptDir) 'variants') $Variant

# card layout, see rtl/common/SD_Card.vhd (HW 2.x: 8 sectors per game from 660 on)
$FirstSector = 660
$SlotBytes   = 4096
# flash layout, see rtl/hw5x/Flash_ROM.vhd
$FlashEnd    = 0x80000     # EPCS4, 512 KB
$pkg = Get-Content (Join-Path $VarDir 'variant_pkg.vhd') -Raw
if ($pkg -notmatch 'FLASH_BASE\s*:\s*integer\s*:=\s*16#([0-9A-Fa-f_]+)#') { throw "no FLASH_BASE in $VarDir\variant_pkg.vhd" }
$FlashBase = [Convert]::ToInt32(($Matches[1] -replace '_', ''), 16)
$Room      = [Math]::Min(64, ($FlashEnd - $FlashBase) / $SlotBytes)   # game_sel has 6 bits
$Games     = [Math]::Min($Games, $Room)
if (-not $Out) { $Out = Join-Path $VarDir 'output_files\gosof80_roms.hex' }

if ((-not $Image) -and (-not $SlotFiles)) { throw 'Give -Image or -SlotFiles.' }
if ($Image -and $SlotFiles) { throw 'Give -Image or -SlotFiles, not both.' }

Add-Type -TypeDefinition @"
using System;
using System.Text;
public static class GosofFlash {
    public static bool Blank(byte[] d, int off, int len) {
        byte f = d[off];
        if (f != 0xFF && f != 0x00) return false;
        for (int i = 1; i < len; i++) if (d[off + i] != f) return false;
        return true;
    }
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

$slots = New-Object System.Collections.Generic.List[byte[]]
if ($Image) {
    $img = [System.IO.File]::ReadAllBytes((Resolve-Path $Image))
    for ($n = 0; $n -lt $Games; $n++) {
        $off = ($FirstSector * 512) + ($n * $SlotBytes)
        if ($off + $SlotBytes -gt $img.Length) { break }
        $s = New-Object byte[] $SlotBytes
        [Array]::Copy($img, $off, $s, 0, $SlotBytes)
        $slots.Add($s)
    }
} else {
    if ($SlotFiles.Count -gt $Room) { throw "$($SlotFiles.Count) files, but only $Room slots fit behind FLASH_BASE." }
    foreach ($f in $SlotFiles) {
        $s = [System.IO.File]::ReadAllBytes((Resolve-Path $f))
        if ($s.Length -ne $SlotBytes) { throw "$f is $($s.Length) bytes, a game is $SlotBytes." }
        $slots.Add($s)
    }
}
if ($slots.Count -eq 0) { throw 'No game found.' }

Write-Host ('FLASH_BASE {0:X6}, room for {1} games, {2} slots read' -f $FlashBase, $Room, $slots.Count)
$sb = New-Object System.Text.StringBuilder
$written = 0
for ($n = 0; $n -lt $slots.Count; $n++) {
    $addr = $FlashBase + $n * $SlotBytes
    if ([GosofFlash]::Blank($slots[$n], 0, $SlotBytes)) {
        Write-Host ('game {0,2}: empty, left out' -f $n) -ForegroundColor DarkGray
        continue
    }
    Write-Host ('game {0,2}: {1:X6}' -f $n, $addr)
    [GosofFlash]::Data($sb, $addr, $slots[$n], 0, $SlotBytes)
    $written++
}
[GosofFlash]::End($sb)

if ([System.IO.Path]::IsPathRooted($Out)) { $outFull = $Out }
else { $outFull = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Out)) }
$dir = Split-Path $outFull
if (-not (Test-Path $dir)) { $null = New-Item -ItemType Directory -Path $dir }
[System.IO.File]::WriteAllText($outFull, $sb.ToString(), (New-Object System.Text.ASCIIEncoding))
Write-Host ('{0} games written to {1}' -f $written, $outFull)