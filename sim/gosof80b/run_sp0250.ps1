<#
.SYNOPSIS
  GHDL check of rtl\hw5x_80b\sp0250.vhd, sample by sample against the PinMAME C code.
.DESCRIPTION
  Sp0250Ref below is sp0250_update() + sp0250_load_values() from PinMAME src\sound\sp0250.c,
  copied as they are, compiled by PowerShell (C#, INT16 wraps as in C). Frames: pseudo random, voiced and noise, with a
  bias to small pitch and repeat so that many frames fit. The first samples until the first
  frame runs are skipped, the VHDL starts a few ticks later than the C code.
#>
param([int]$Frames = 200, [int]$Samples = 6000)
$ErrorActionPreference = 'Stop'
$Here  = Split-Path -Parent $MyInvocation.MyCommand.Path
$Repo  = Split-Path -Parent (Split-Path -Parent $Here)
$Build = Join-Path $Here 'build\sp0250'
$Ghdl  = 'C:\Users\bonta\tools\ghdl\bin\ghdl.exe'
New-Item -ItemType Directory -Force $Build | Out-Null

Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
public class Sp0250Ref {
    static ushort[] coefs = {
          0,   9,  17,  25,  33,  41,  49,  57,  65,  73,  81,  89,  97, 105, 113, 121,
        129, 137, 145, 153, 161, 169, 177, 185, 193, 201, 203, 217, 225, 233, 241, 249,
        257, 265, 273, 281, 289, 297, 301, 305, 309, 313, 317, 321, 325, 329, 333, 337,
        341, 345, 349, 353, 357, 361, 365, 369, 373, 377, 381, 385, 389, 393, 397, 401,
        405, 409, 413, 417, 421, 425, 427, 429, 431, 433, 435, 437, 439, 441, 443, 445,
        447, 449, 451, 453, 455, 457, 459, 461, 463, 465, 467, 469, 471, 473, 475, 477,
        479, 481, 482, 483, 484, 485, 486, 487, 488, 489, 490, 491, 492, 493, 494, 495,
        496, 497, 498, 499, 500, 501, 502, 503, 504, 505, 506, 507, 508, 509, 510, 511 };
    static ushort ga(byte v) { return (ushort)((v & 0x1f) << (v >> 5)); }
    static short gc(byte v) { short r = (short)coefs[v & 0x7f]; if ((v & 0x80) == 0) r = (short)(-r); return r; }
    short amp; byte pitch, repeat; int pcount, rcount, playing; uint RNG = 1; int voiced;
    byte[] fifo = new byte[15]; int fifo_pos = 0;
    short[] F = new short[6], B = new short[6], z1 = new short[6], z2 = new short[6];
    void load() {
        B[0] = gc(fifo[0]); F[0] = gc(fifo[1]); amp = (short)ga(fifo[2]);
        B[1] = gc(fifo[3]); F[1] = gc(fifo[4]); pitch = fifo[5];
        B[2] = gc(fifo[6]); F[2] = gc(fifo[7]); repeat = (byte)(fifo[8] & 0x3f); voiced = fifo[8] & 0x40;
        B[3] = gc(fifo[9]); F[3] = gc(fifo[10]); B[4] = gc(fifo[11]); F[4] = gc(fifo[12]);
        B[5] = gc(fifo[13]); F[5] = gc(fifo[14]);
        fifo_pos = 0; pcount = 0; rcount = 0;
        for (int f = 0; f < 6; f++) z1[f] = z2[f] = 0;
        playing = 1;
    }
    public short[] Run(byte[] frames, int samples) {
        short[] o = new short[samples]; int fp = 0;
        for (int i = 0; i < samples; i++) {
            // the FIFO is refilled whenever it has room, between two samples
            if (fifo_pos != 15 && fp + 15 <= frames.Length) { Array.Copy(frames, fp, fifo, 0, 15); fp += 15; fifo_pos = 15; }
            if (playing != 0) {
                short z0;
                if (voiced != 0) { z0 = (pcount == 0) ? amp : (short)0; }
                else {
                    if ((RNG & 1) != 0) { z0 = amp; RNG ^= 0x24000; } else z0 = (short)(-amp);
                    RNG >>= 1;
                }
                for (int f = 0; f < 6; f++) {
                    z0 = unchecked((short)(z0 + ((z1[f] * F[f]) >> 8) + ((z2[f] * B[f]) >> 9)));
                    z2[f] = z1[f]; z1[f] = z0;
                }
                o[i] = unchecked((short)(z0 << 3));
                pcount++;
                if (pcount >= pitch) { pcount = 0; rcount++; if (rcount >= repeat) playing = 0; }
            } else o[i] = 0;
            if (playing == 0 && fifo_pos == 15) load();
        }
        return o;
    }
}
"@

$rnd = New-Object System.Random 80766
$bytes = New-Object byte[] (15 * $Frames)
$rnd.NextBytes($bytes)
for ($i = 0; $i -lt $Frames; $i++) {
    $p = $i * 15
    $bytes[$p + 2] = [byte]($bytes[$p + 2] -band 0xBF)      # amplitude up to 31 << 5, no wild overflows all the time
    $bytes[$p + 5] = [byte]($bytes[$p + 5] -band 0x1F)      # pitch
    $bytes[$p + 8] = [byte]($bytes[$p + 8] -band 0x43)      # voiced, repeat 0..3
}
Set-Content -Path (Join-Path $Build 'frames.txt') -Value ($bytes | ForEach-Object { [string]$_ }) -Encoding Ascii
$expect = (New-Object Sp0250Ref).Run($bytes, $Samples)

Push-Location $Build
try {
    Remove-Item -ErrorAction SilentlyContinue 'work-obj08.cf'
    & $Ghdl -a --std=08 (Join-Path $Repo 'rtl\hw5x_80b\sp0250.vhd') (Join-Path $Here 'tb_sp0250.vhd')
    if ($LASTEXITCODE -ne 0) { throw 'ghdl -a failed' }
    & $Ghdl -e --std=08 tb_sp0250
    if ($LASTEXITCODE -ne 0) { throw 'ghdl -e failed' }
    & $Ghdl -r --std=08 tb_sp0250 --ieee-asserts=disable-at-0 "-gSamples=$Samples"
    if ($LASTEXITCODE -ne 0) { throw 'tb_sp0250 failed' }
}
finally { Pop-Location }

$got = @(Get-Content (Join-Path $Build 'out.txt') | ForEach-Object { [int]$_ })
# Align on the first non-zero sample, then the streams must be identical.
$e0 = 0; while ($e0 -lt $expect.Length -and $expect[$e0] -eq 0) { $e0++ }
$g0 = 0; while ($g0 -lt $got.Count -and $got[$g0] -eq 0) { $g0++ }
$n = [Math]::Min($expect.Length - $e0, $got.Count - $g0)
$bad = 0; $first = -1; $nonzero = 0
for ($i = 0; $i -lt $n; $i++) {
    if ($expect[$e0 + $i] -ne 0) { $nonzero++ }
    if ($expect[$e0 + $i] -ne $got[$g0 + $i]) { if ($first -lt 0) { $first = $i }; $bad++ }
}
"aligned at C {0} / VHDL {1}, compared {2} samples, {3} non-zero, {4} differ" -f $e0, $g0, $n, $nonzero, $bad
if ($bad -ne 0) {
    "first difference at {0}: C {1}, VHDL {2}" -f $first, $expect[$e0 + $first], $got[$g0 + $first]
    throw 'FAIL'
}
if ($nonzero -lt 100) { throw 'FAIL: hardly any sound in the comparison' }
'PASS'
