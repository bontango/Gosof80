<#
.SYNOPSIS
  Puts game ROMs into a released GOSOF HW 5.x .jic file - no Quartus, no source code.

.DESCRIPTION
  GOSOF HW 5.x has no SD card for the game ROMs. They live in the configuration flash
  (EPCS4) next to the FPGA program, 4 KB per game:

      flash   FLASH_BASE + n * 1000h      game n (slot n), n = 0..63

  The .jic from lisy.dev carries no ROMs (copyright), the slots are erased (FF). This
  script copies the 4 KB game files into the flash image inside the .jic and writes a
  new .jic that the Quartus Programmer burns like the released one.

  What it does with the file (format of Quartus Prime 22.1 "Convert Programming Files"):
    - the .jic is a list of packets (16-bit tag, 32-bit length, data); packet 28 holds
      the complete flash image behind a 12-byte header
    - every byte goes into the flash image bit-reversed (bit 0 <-> bit 7), as quartus_cpf
      writes it
    - the last packet (tag 8) holds a CRC-16 (X.25) over the file; it is recalculated

  Safety checks: the input must be a .jic for an EPCS4, its CRC must be right, and the
  4 KB below FLASH_BASE must be erased - otherwise the FPGA program could reach into the
  slots, and the script stops instead of overwriting it.

  The SLOT NUMBER DECIDES THE SOUNDBOARD the FPGA emulates (it is the setting of DIP bank
  S2, switch 1 = 1, switch 2 = 2, ... switch 6 = 32, ON counts):

      slot  0 ..  7   MA-216 (System 80, speech)
      slot  8 .. 15   MA-309 (System 80)
      slot 16 .. 31   MA-55  (System 80)
      slot 32 .. 47   MA-490 (System 80A)
      slot 48 .. 63   System 1

  How a 4 KB slot file is put together for each soundboard: user manual, appendix B.
  The script follows the 6502 reset vector of every slot the way the FPGA maps the ROMs
  for the soundboard of that slot, and warns if it does not lead to a program start -
  usually a file in the wrong slot or put together in the wrong order.

  THE RESULT CONTAINS COPYRIGHTED GAME ROMS. Use it for your own board, do not pass it on.

.PARAMETER Jic
  The released .jic, e.g. GOSOF80_HW5.x_v7.98.jic.

.PARAMETER RomDir
  Folder with one 4 KB file per game. The file name starts with the slot number,
  followed by '_', '-', ' ' or '.':  00_mars.bin, 24_pinkpanther.bin, 55-mygame.bin.
  Other files in the folder are ignored.

.PARAMETER Image
  Image of a GOSOF HW 2.x SD card (raw sectors, written by make_sd.bat), e.g.
  Gosof_Image_v1.21.img. Game n is read from sector 660 + n * 8; the gaps that
  make_sd.bat fills with the file '4K' stay empty. Can be combined with
  -RomDir; then the files of -RomDir replace the games of the image.

.PARAMETER Games
  How many slots to take from -Image. Default 55 (games 0..54, as make_sd.bat writes
  them; behind them the card holds other files).

.PARAMETER Out
  The .jic to write. Default: <Jic without .jic>_roms.jic in the same folder.

.PARAMETER FlashBase
  Where slot 0 starts in the flash. Default 0x40000 (all releases up to now). Only
  change it if the release notes say so.

.PARAMETER List
  Write nothing, only show which slots of -Jic hold a game.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File add_roms_to_jic.ps1 -Jic GOSOF80_HW5.x_v7.98.jic -RomDir roms

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File add_roms_to_jic.ps1 -Jic GOSOF80_HW5.x_v7.98.jic -Image Gosof_Image_v1.21.img

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File add_roms_to_jic.ps1 -Jic GOSOF80_HW5.x_v7.98_roms.jic -List
#>
param(
    [Parameter(Mandatory = $true)][string]$Jic,
    [string]$RomDir,
    [string]$Image,
    [int]$Games = 55,
    [string]$Out,
    [int]$FlashBase = 0x40000,
    [switch]$List
)

$ErrorActionPreference = 'Stop'
trap { Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
$SlotBytes   = 4096
$MaxSlots    = 64            # DIP bank S2 has 6 switches
$FirstSector = 660           # HW 2.x SD card: game n at sector 660 + n * 8

Add-Type -TypeDefinition @"
using System;
public static class GosofJic {
    public static byte Rev(byte b) {
        int r = 0;
        for (int i = 0; i < 8; i++) if ((b & (1 << i)) != 0) r |= 0x80 >> i;
        return (byte)r;
    }
    // CRC-16/X.25 (reflected 0x1021, init FFFF, inverted), as in the last packet of a .jic
    public static int Crc(byte[] d, int len) {
        int c = 0xFFFF;
        for (int p = 0; p < len; p++) {
            c ^= d[p];
            for (int i = 0; i < 8; i++) c = ((c & 1) != 0) ? ((c >> 1) ^ 0x8408) : (c >> 1);
        }
        return (~c) & 0xFFFF;
    }
    public static bool AllFF(byte[] d, int off, int len) {
        for (int i = 0; i < len; i++) if (d[off + i] != 0xFF) return false;
        return true;
    }
    public static bool Blank(byte[] d, int off, int len) {
        byte f = d[off];
        if (f != 0xFF && f != 0x00) return false;
        for (int i = 1; i < len; i++) if (d[off + i] != f) return false;
        return true;
    }
}
"@

function Get-Board([int]$n) {
    if ($n -lt 8)  { return 'MA-216' }
    if ($n -lt 16) { return 'MA-309' }
    if ($n -lt 32) { return 'MA-55' }
    if ($n -lt 48) { return 'MA-490' }
    return 'System 1'
}

# Reset vector of the 6502 ($FFFC) as the FPGA sees it for this soundboard, and whether
# it points into a ROM (top/GOSOF80.vhd, soundrom1_cs / soundrom2_cs).
function Test-Vector([byte[]]$s, [int]$n) {
    $b = Get-Board $n
    switch ($b) {
        'MA-216'   { $o = 0xFFC }   # ROM 2 (2nd 2 KB) at $7800, $FFFC -> offset 7FCh
        'MA-309'   { $o = 0xFFC }
        'MA-490'   { $o = 0x7FC }   # one 2 KB ROM (1st 2 KB) at $0800
        default    { $o = 0xBFC }   # MA-55 / System 1: 6530 ROM (3rd KB) at $0C00
    }
    $v = $s[$o] + 256 * $s[$o + 1]
    switch ($b) {
        'MA-216' { $ok = (($v -band 0x7000) -eq 0x7000) }
        'MA-309' { $ok = (($v -band 0x7000) -eq 0x7000) }
        'MA-490' { $ok = (($v -band 0x0800) -ne 0) }
        default  { $ok = (($v -band 0x0C00) -ne 0) }
    }
    if ($v -eq 0xFFFF -or $v -eq 0) { $ok = $false }   # erased or filler, no program
    # where the vector lands in the slot file, and the first instruction there: all
    # Gottlieb sound ROMs start with SEI, CLD, LDA, LDX or LDY
    switch ($b) {
        'MA-490' { $t = $v -band 0x7FF }
        'MA-216' { $t = $v -band 0xFFF }
        'MA-309' { $t = $v -band 0xFFF }
        default  { if ((($v -shr 10) -band 3) -eq 3) { $t = 0x800 + ($v -band 0x3FF) } else { $t = $v -band 0x3FF } }
    }
    if ($ok -and (@(0x78, 0xD8, 0xA9, 0xA2, 0xA0, 0xAD, 0xAE, 0x4C) -notcontains $s[$t])) { $ok = $false }

    return @($v, $ok)
}

# ---- read and check the .jic --------------------------------------------------------
$jicFull = (Resolve-Path $Jic).Path
$d = [System.IO.File]::ReadAllBytes($jicFull)
if ($d.Length -lt 32 -or [System.Text.Encoding]::ASCII.GetString($d, 0, 3) -ne 'JIC') { throw "$Jic is not a .jic file." }

$flashOff = -1; $flashLen = 0; $crcPos = -1; $eprom = ''; $device = ''
$p = 12
while ($p + 6 -le $d.Length) {
    $tag = [BitConverter]::ToUInt16($d, $p)
    $len = [BitConverter]::ToUInt32($d, $p + 2)
    $dat = $p + 6
    if ($dat + $len -gt $d.Length) { throw "$Jic is damaged (packet at $p runs past the end)." }
    switch ($tag) {
        2  { $device = [System.Text.Encoding]::ASCII.GetString($d, $dat, $len).TrimEnd([char]0) }
        27 { $eprom  = [System.Text.Encoding]::ASCII.GetString($d, $dat, $len).TrimEnd([char]0) }
        28 { $flashOff = $dat + 12; $flashLen = $len - 12 }
        8  { if ($len -eq 2) { $crcPos = $dat } }
    }
    $p = $dat + $len
}
if ($flashOff -lt 0 -or $crcPos -lt 0) { throw "$Jic has no flash image or no CRC - not a .jic from GOSOF?" }
if ($crcPos + 2 -ne $d.Length) { throw "${Jic}: the CRC is not at the end of the file." }
$crcOld = [BitConverter]::ToUInt16($d, $crcPos)
if ([GosofJic]::Crc($d, $crcPos) -ne $crcOld) { throw "$Jic is damaged (CRC wrong). Download it again." }
if ($eprom -ne 'EPCS4' -or $device -ne 'EP4CE6') {
    throw "$Jic is for $device / $eprom, GOSOF HW 5.x needs EP4CE6 / EPCS4."
}
$room = [Math]::Min($MaxSlots, [int](($flashLen - $FlashBase) / $SlotBytes))
if ($room -lt 1) { throw ('FlashBase {0:X} lies outside the {1} KB flash.' -f $FlashBase, ($flashLen / 1024)) }

# the FPGA program starts at flash address 0; the 4 KB below slot 0 must still be free
if (-not [GosofJic]::AllFF($d, $flashOff + $FlashBase - $SlotBytes, $SlotBytes)) {
    throw ('The FPGA program in {0} reaches up to the ROM slots at {1:X6}. This script does not fit this release - use the instructions that come with it.' -f $Jic, $FlashBase)
}
$last = $FlashBase - 1
while ($last -ge 0 -and $d[$flashOff + $last] -eq 0xFF) { $last-- }
Write-Host ('{0}: {1}, {2}, FPGA program up to {3:X6}, slot 0 at {4:X6}, {5} slots' -f `
    (Split-Path -Leaf $jicFull), $device, $eprom, $last, $FlashBase, $room)

function Read-Slot([int]$n) {
    $s = New-Object byte[] $SlotBytes
    $o = $flashOff + $FlashBase + $n * $SlotBytes
    for ($i = 0; $i -lt $SlotBytes; $i++) { $s[$i] = [GosofJic]::Rev($d[$o + $i]) }
    return ,$s
}

if ($List) {
    $found = 0
    for ($n = 0; $n -lt $room; $n++) {
        $o = $flashOff + $FlashBase + $n * $SlotBytes
        if ([GosofJic]::AllFF($d, $o, $SlotBytes)) { continue }
        $s = Read-Slot $n
        $r = Test-Vector $s $n
        $note = ''; if (-not $r[1]) { $note = '  <- no program start found for this soundboard' }
        Write-Host ('slot {0,2}  {1,-8}  reset {2:X4}{3}' -f $n, (Get-Board $n), $r[0], $note)
        $found++
    }
    Write-Host "$found slots hold a game, the others are empty (D1 blinks when one of them is selected)."
    exit 0
}

# ---- collect the games ----------------------------------------------------------------
if ((-not $Image) -and (-not $RomDir)) { throw 'Give -RomDir and/or -Image (or -List).' }
$slots = @{}
$from  = @{}
if ($Image) {
    $img = [System.IO.File]::ReadAllBytes((Resolve-Path $Image).Path)
    $n0 = [Math]::Min($Games, $room)
    for ($n = 0; $n -lt $n0; $n++) {
        $off = $FirstSector * 512 + $n * $SlotBytes
        if ($off + $SlotBytes -gt $img.Length) { break }
        if ([GosofJic]::Blank($img, $off, $SlotBytes)) { continue }
        $s = New-Object byte[] $SlotBytes
        [Array]::Copy($img, $off, $s, 0, $SlotBytes)
        # make_sd.bat fills unused games with the file '4K' (no program): leave them erased,
        # so that D1 blinks instead of the CPU running filler
        if (-not (Test-Vector $s $n)[1]) { Write-Host ('slot {0,2}  {1,-8}  no game in the image, left empty' -f $n, (Get-Board $n)) -ForegroundColor DarkGray; continue }
        $slots[$n] = $s; $from[$n] = 'image'
    }
}
if ($RomDir) {
    $dirFull = (Resolve-Path $RomDir).Path
    foreach ($f in (Get-ChildItem -LiteralPath $dirFull -File | Sort-Object Name)) {
        if ($f.Name -notmatch '^(\d{1,2})[_\-. ]') { continue }
        $n = [int]$Matches[1]
        if ($n -ge $room) { throw "$($f.Name): slot $n does not exist (0..$($room - 1))." }
        if ($from.ContainsKey($n) -and $from[$n] -ne 'image') { throw "$($f.Name): slot $n is already taken by $($from[$n])." }
        $s = [System.IO.File]::ReadAllBytes($f.FullName)
        if ($s.Length -ne $SlotBytes) { throw "$($f.Name) has $($s.Length) bytes, a slot file must have exactly $SlotBytes (see appendix B of the user manual)." }
        if ([GosofJic]::Blank($s, 0, $SlotBytes)) { throw "$($f.Name) is empty (all FF or 00)." }
        $slots[$n] = $s; $from[$n] = $f.Name
    }
}
if ($slots.Count -eq 0) { throw 'No game found.' }

# ---- write ----------------------------------------------------------------------------
$warn = 0
foreach ($n in ($slots.Keys | Sort-Object)) {
    $s = $slots[$n]
    $o = $flashOff + $FlashBase + $n * $SlotBytes
    $was = ''
    if (-not [GosofJic]::AllFF($d, $o, $SlotBytes)) { $was = '  (replaces the game that was there)' }
    for ($i = 0; $i -lt $SlotBytes; $i++) { $d[$o + $i] = [GosofJic]::Rev($s[$i]) }
    $r = Test-Vector $s $n
    Write-Host ('slot {0,2}  {1,-8}  reset {2:X4}  {3}{4}' -f $n, (Get-Board $n), $r[0], $from[$n], $was)
    if (-not $r[1]) {
        Write-Host ('          WARNING: no program start found for a {0} (reset vector {1:X4}) - wrong slot, or file put together wrongly? See appendix B.' -f (Get-Board $n), $r[0]) -ForegroundColor Yellow
        $warn++
    }
}
$crc = [GosofJic]::Crc($d, $crcPos)
$d[$crcPos] = [byte]($crc -band 0xFF); $d[$crcPos + 1] = [byte]($crc -shr 8)

if (-not $Out) { $Out = [System.IO.Path]::Combine((Split-Path $jicFull), [System.IO.Path]::GetFileNameWithoutExtension($jicFull) + '_roms.jic') }
if ([System.IO.Path]::IsPathRooted($Out)) { $outFull = $Out }
else { $outFull = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Out)) }
if ($outFull -eq $jicFull) { throw '-Out must not be the input file - keep the released .jic as it is.' }
[System.IO.File]::WriteAllBytes($outFull, $d)
Write-Host ('{0} games written to {1}' -f $slots.Count, $outFull)
if ($warn -gt 0) { Write-Host "$warn warning(s), see above." -ForegroundColor Yellow }
Write-Host 'Program this file with the Quartus Programmer (JTAG mode). It contains game ROMs: do not pass it on.'
exit 0
