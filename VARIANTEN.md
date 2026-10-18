# Varianten – Ressourcen, Eigenheiten, Hardware-Teststand

Stand 15.10.2026. Zahlen aus `scripts\check.ps1` (Synthese) bzw. `-Fit`.

## Options-DIPs (ab x.98-Kern, alle Platinen gleich; ON = Schalter zu = '0')

| DIP | ON | OFF |
|---|---|---|
| 1 | CPU 1020 kHz | CPU 892 kHz |
| 2 | Sprache vom MP3-Player | Votrax-Emulation (MA-216; Cyclone II immer MP3) |
| 3 | Testschalter = Testschalter der Originalplatine | Testschalter sagt „This is Gosof version x.98 from lisy dot dev“ (nicht Cyclone II) |
| 4 | Testmodus: jeder Sound als Zahl aus MP3-Ordner 64 | normal |

Gegenüber HW 2.x x.97 entfallen: Taktverstellung in 7 Stufen über DIP 1–3 (Grundtakt jetzt
892,9 statt 877 kHz), DIP 4 „ROM aus Sektor 660“, Testmodus über Spielauswahl `000000`
(000000 ist wieder ein normales System-1-Spiel), Votrax-Wahl über Sound-DIP 2 (SB_Opt 2).
Auf HW 4.x ist der Testschalter `Gottlieb_Test`; `Gosof_Test` startet weiter den Soundtest.

## Hardware-Teststand

| Variante | x.97 bzw. v4.01 | x.98 Mischer | x.98-Kern (DIPs, PLL, Ansage) |
|---|---|---|---|
| `hw2x_cyclone_II` | **ok** (Ralf, 14.10.2026) | nicht getestet (ohne Votrax) | gebaut 15.10.2026, nicht getestet |
| `hw2x_cyclone_IV_v3` | **ok** (Ralf, 14.10.2026) | nicht getestet | gebaut 15.10.2026, nicht getestet |
| `hw2x_cyclone_IV_v4` | **ok** (Ralf, 14.10.2026) | **ok** (Ralf, 15.10.2026): Sprache/TILT/Attract, Sprache ×2 + Töne ×3/4 | **ok** (Ralf, 15.10.2026: „funktioniert“) |
| `hw2x_cyclone_10` | **ok** (Ralf, 14.10.2026) | nicht getestet | gebaut 15.10.2026, nicht getestet |
| `hw3x_cyclone_IV` | HW3.x v4.97 aus dem Altbaum (Release) | – | gebaut 15.10.2026, nicht getestet |
| `hw4x_cyclone_10` | v4.01 aus dem Altbaum (Release) | – | gebaut 15.10.2026, nicht getestet |
| `hw5x_cyclone_IV` | – (neu) | – | gebaut 18.10.2026, nicht getestet (Prüfliste HW 5.x unten) |

x.97: Die Releases in `bin/` sind byte-gleich mit den Build-Ausgaben des alten Baums (md5,
14.10.2026). Ralf meldet für die x.97-Varianten Funktion auf der Hardware.

x.98 Mischer, Hardwaretest 15.10.2026 (Ralf, `hw2x_cyclone_IV_v4`): Votrax-Sprache, TILT-Sound und
Attract-Sprache ok. Sprache mit 1,0 = 256 viel zu leise, ×3 laut genug aber kratziger, Sprache ×2 und
Töne ×3/4 (nur bei Emulation) „hört sich gut an“.

HW 4.x (`hw4x_cyclone_10`, Board-ID 5) kam am 15.10.2026 aus `..\FPGA_source_alt\HW 4.x GOSOF80 - Multi SD`
in diesen Baum. Erst unverändert (Synthese 2234/854/33792 = Altprojekt v4.01), dann in den gemeinsamen
Kern. Sie bekommt dadurch die Votrax-Emulation und die Ansage, behält SD-Format mit CRC, Soundtest
und LEDs. Hintergrundmusik seit 15.10.2026 auf allen Platinen bei System 1 und MA-55 (v4.01 hatte MA-55 weggelassen).

**Prüfliste x.98-Kern (`hw2x_cyclone_IV_v4`), Rückmeldung Ralf 15.10.2026: „funktioniert“**
1. DIP 1 ON/OFF: Spiele laufen mit beiden Takten.
2. MA-216-Spiel, DIP 2 OFF: Sprache aus der Emulation wie beim Mischer-Test; DIP 2 ON: Sprache vom MP3.
3. DIP 3 OFF + Testschalter: Ansage „…version three dot nine eight from lisy dot dev“, auch bei
   Nicht-MA-216-Spielen und mit DIP 2 ON. DIP 3 ON: Testschalter wirkt wie auf der Originalplatine.
4. DIP 4 ON: Testmodus mit Zahlen vom MP3-Player.

Die übrigen Varianten sind am 15.10.2026 voll gebaut, aber nicht auf Hardware getestet.

| Variante | Comb | Reg | Mem (Bit) | LE (Fitter) | Setup-Slack | Hold-Slack |
|---|---|---|---|---|---|---|
| `hw2x_cyclone_II` | 2161 | 791 | 33792 | 2264 / 4608 | 4,359 ns | 0,215 ns |
| `hw2x_cyclone_IV_v3` | 2188 | 793 | 33792 | 2310 / 6272 | 4,348 ns | 0,452 ns |
| `hw2x_cyclone_IV_v4` | 2188 | 793 | 33792 | 2315 / 6272 | 5,323 ns | 0,452 ns |
| `hw2x_cyclone_10` | 2188 | 793 | 33792 | 2313 / 6272 | 5,051 ns | 0,452 ns |

## Ressourcen x.98-Kern (15.10.2026)

| Variante | Comb | Reg | Mem (Bit) | LE (Fitter) | Setup-Slack | Hold-Slack |
|---|---|---|---|---|---|---|
| `hw2x_cyclone_II` (ohne Votrax) | 2131 | 805 | 33792 | 2239 / 4608 (49 %) | ≥ 1,77 ns | ≥ 0 |
| `hw2x_cyclone_IV_v3` | 4633 | 2287 | 153600 | 4849 / 6272 (77 %) | 1,636 ns | ≥ 0 |
| `hw2x_cyclone_IV_v4` | 4636 | 2287 | 153600 | 4864 / 6272 (78 %) | 1,811 ns (clk_50) | 0,426 ns |
| `hw2x_cyclone_10` | 4635 | 2287 | 153600 | 4861 / 6272 (78 %) | 1,721 ns | ≥ 0 |
| `hw3x_cyclone_IV` | 4633 | 2287 | 153600 | 4864 / 6272 (78 %) | 1,546 ns | ≥ 0 |
| `hw4x_cyclone_10` | 4738 | 2357 | 153600 | 4980 / 6272 (79 %) | 1,392 ns | ≥ 0 |
| `hw5x_cyclone_IV` (18.10.2026) | 4441 | 2080 | 153600 | 4617 / 6272 (74 %) | 2,098 ns (clk_50) | 0,337 ns |

Alle Varianten am 15.10.2026 voll gebaut (`.jic`/`.pof`), keine negative Slack, keine Critical Warning. Ansage plus
Entprellung kosten ~62 comb / 47 reg. Die beiden CPU-Takte sind in `GOSOF80.sdc` logisch exklusiv
(Takt-Mux), sonst meldet TimeQuest Scheinpfade 1020 kHz → 892 kHz (Hold −0,009 ns, Fast-Modell).
## Ressourcen x.98

| Variante | Comb | Reg | Mem (Bit) | LE (Fitter) | 9-Bit-Mult. | Setup-Slack | Hold-Slack |
|---|---|---|---|---|---|---|---|
| `hw2x_cyclone_II` (ohne Votrax) | 2156 | 799 | 33792 | 2271 / 4608 | 0 | 3,887 ns | 0,499 ns |
| `hw2x_cyclone_IV_v3` | 4538 | 2239 | 153600 | 4772 / 6272 (76 %) | 14 / 30 | 2,309 ns | 0,438 ns |
| `hw2x_cyclone_IV_v4` | 4538 | 2239 | 153600 | 4782 / 6272 (76 %) | 14 / 30 | 2,321 ns | 0,434 ns |
| `hw2x_cyclone_10` | 4537 | 2239 | 153600 | 4798 / 6272 (76 %) | 14 / 30 | 2,563 ns | 0,452 ns |

Die Votrax-Emulation kostet ~2.350 LE, ~1.450 Register und 120 kbit ROM. Danach sind auf
Cyclone IV/10 noch ~1.500 LE frei – für HW 4.x (CRC, Testmodus) reicht das, für viel mehr nicht.

Alle Varianten belegen dieselben 34 Ports, `VIRTUAL_PIN` wird nicht gebraucht.

## Befunde beim Umbau

1. **Drei Varianten ohne Timing-Constraints gebaut.** `GOSOF80_HW2x_Cyclone10`, `_CycloneIV_v3`
   und `_CycloneIV_v4` nannten `GOSOF80.sdc` in der `.qsf`, die Datei fehlte aber
   (`Critical Warning 332012`, außerdem 332148 „Timing requirements not met“ gegen den
   1-GHz-Default). Die Releases v2.97/v3.97/v4.97 sind also unconstrained entstanden.
   Jetzt teilen sich alle Varianten `rtl/common/GOSOF80.sdc` (vorher nur in CycloneII).
2. **Deshalb ändert sich die Synthese der 22.1-Varianten:** alt 2197/794 (IV) bzw. 2192/794 (10),
   neu 2188/793. Nachgewiesen ist, dass die Ursache allein die SDC ist: Der neue Baum
   **ohne** SDC-Zeile synthetisiert exakt 2197/794/33792 (gemessen an `hw2x_cyclone_IV_v4`).
   Die Synthese von 22.1 arbeitet timing-getrieben. CycloneII (13.0, hatte die SDC schon) ist in allen
   Zahlen identisch, auch LE und Slack.
3. **Falsche `.cof` bei Cyclone 10.** Die `.cof` im alten Cyclone10-Ordner nannte den Flash-Loader
   `EP4CE6`. Das Release v4.97 trägt im Kopf aber `10CL006Y` (2.097.377 B), wurde also anders
   erzeugt. Die `.cof` ist jetzt die mit 10CL006Y (aus HW 4.x), Gegenprobe: 2.097.377 B.
   EP4CE6-Varianten: 2.097.375 B.
4. **IV_v3 hatte keine `.cof`.** Sie ist jetzt eine Kopie der v4-`.cof` (EP4CE6, EPCS16).
5. **Hold-Verletzung auf Cyclone II (Altbestand, über Fitter-Einstellung behoben).** Mit der 13.0-Voreinstellung
   für `OPTIMIZE_HOLD_TIMING` (nur I/O-Pfade) war Hold verletzt: `uart_clk_out` −1,857 ns
   (`attract|sound_seen` → `reset_flag`/`counter`), `cpu_clk_out` −1,014 ns (`SD_Card|cpu_reset_l` →
   RIOT-Register). Ursache im Design: beide Takte sind registergeteilt (`cpu_clk_gen`, `uart_clk_gen`),
   ihre Flanken liegen ~3 ns hinter `clk_50`. Seit 14.10.2026 steht `OPTIMIZE_HOLD_TIMING "ALL PATHS"` in
   `variants/hw2x_cyclone_II/device.tcl`: Hold +0,499 ns (slow) / +0,215 ns (fast), Setup 3,853 → 4,359 ns,
   Synthese unverändert. Auch das alte Release v0.97 hat diese Verletzung. Die Ursache selbst (Taktübergänge)
   bleibt bestehen; die saubere Lösung wären Clock-Enables statt abgeleiteter Takte.
6. **Board-ID 4 doppelt belegt:** HW2.x/Cyclone 10 = v4.97, das HW-4.x-Board zählt
   ebenfalls v4.xx (v4.98, v4.01). Das muss gelöst werden, bevor HW 4.x in diesen Baum kommt.

## HW 5.x (`hw5x_cyclone_IV`, Board-ID 7, seit 18.10.2026)

GOSOF 5.00 (`..\Target\GOSOF\v5.x`): Funktion wie HW 4.x (Gottlieb_Test, Gosof_Test mit Soundtest),
aber EP4CE6E22C8N-Core-Board gesteckt und **keine SD-Karte**. Die 4 KB je Spiel kommen aus dem
EPCS4 (Konfigurationsflash) ab `FLASH_BASE` = 0x40000. Der komprimierte Bitstream endet bei 0x28668
(unkomprimiert 0x59D8A, das hätte nicht gepasst). Kern unverändert, andere Varianten bitgleich
(`gen_qsf.ps1 -Check`). Gegenüber HW 4.x −297 comb / −277 reg (kein SD_Card/SPI_Master/CRC).

Gegenprobe 18.10.2026: `sim/flash/run_sim.ps1` PASS (Spiel 0 und 53 byte-genau, leerer Slot → Fehler).
`make_flash_hex.ps1 -Image Gosof_Image_v1.21.img` → Slots 0–54 (0x40000–0x76FFF). Slot 0/32/48/54
sind byte-gleich mit den ROM-Dateien von `make_sd.bat`. `gosof80_roms.jic` ohne Überlappung.

Pins (aus `pins_Gosof_v5.xlsx` + `GOSOF_5_00.NET`): S2 (6-pol.) = `game_sel`, S3 (4-pol.) = `option`,
S1 (8-pol.) = `SB_Opt`, wie auf HW 4.x. Takt PIN_24, Reset = Taster des Core-Boards PIN_88 (ohne
internen Pull-up, CLK7), Audio PIN_111, DFPlayer RX/TX 144/143, D1 Trigger 135, D2 Sound 137
(aktiv-high), Core-LED1 (PIN_1) Flash-Fehler. Flash: DCLK 12, DATA0 13, nCSO 8, ASDO 6.

**Prüfliste HW 5.x (Hardware, offen)**
1. Core-Board-Jumper VIOB/VIOC auf 3,3 V.
2. Nur `GOSOF80.jic` (Release, ohne ROMs) brennen: Core-LED1 blinkt, kein Ton.
3. `gosof80_roms.jic` brennen (Programmer „Verify“ ohne Fehler). Mindestens zwei Spielnummern,
   eine davon > 0 (z. B. ein MA-216- und ein System-1-Spiel), laufen mit Ton und Sprache.
   Startet nichts, obwohl ROMs drin sind: Bit-Reihenfolge je Byte prüfen und in `Flash_ROM.vhd`
   `data_rom` gespiegelt übernehmen (wie in WillFA7 VARIANTEN.md beschrieben).
4. Spielauswahl > 54 (leerer Slot): Core-LED1 blinkt.
5. Options-DIPs 1–4 wie bei den anderen Platinen; Gottlieb_Test, Gosof_Test (Soundtest), Reset-Taster.
6. LEDs D1 (Trigger) / D2 (Sound) leuchten richtig herum.
7. Der W25Q64 des Core-Boards bleibt unbenutzt (normale I/O-Pins, per `.jic` nicht beschreibbar).

## Pinunterschiede

- `hw2x_cyclone_10` und `hw2x_cyclone_IV_v4`: gleiche Pinlagen (E144-Gehäuse), einzige
  Ausnahme `SD_MOSI` = PIN_32 (Cyclone 10) bzw. PIN_30 (IV v4).
- `hw2x_cyclone_IV_v3`: FBGA256, eigene Pinliste.
- `hw2x_cyclone_II`: EP2C5T144, eigene Pinliste.

## Erwartete Warnungen (alle Varianten, Altbestand)

- 10036 ×4 (`DAC_latch_speech`, `bg_DFcmd_par1`, T65 `D`, SD_Card `SS_R` nie gelesen)
- 10492 ×2 (T65 Sensitivity-Listen)
- Critical 10920 ×1 (T65-Port `A` teilweise assoziiert, 8 von 24 Bit offen)
- 332060 (`SB_Opt[1]` wird als Takt erkannt, siehe U10-Prozess im Top-Level)
- Cyclone II: 332148 ist seit `OPTIMIZE_HOLD_TIMING "ALL PATHS"` weg
