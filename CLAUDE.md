# GOSOF80 – Kontext für Claude

FPGA-Ersatz des Gottlieb-System-80-Soundboards, gemeinsamer Sourcebaum für die
HW-2.x-Platinen, HW 3.x (Board-ID 6) und HW 4.x (Board-ID 5), beide seit 15.10.2026, sowie HW 5.x (Board-ID 7,
EP4CE6-Core-Board, ROMs aus dem EPCS4) seit 18.10.2026. Aufbau nach Skill `fpga-varianten-sourcebaum` (Vorlage AtariFA).
Repo: `github.com/bontango/Gosof80` (privat), direkt auf `main` committen.

## Architektur (top/GOSOF80.vhd = Kern `gosof80_core`)

- Platinenhüllen `top/board_hw2x.vhd` / `board_hw3x.vhd` / `board_hw4x.vhd` / `board_hw5x.vhd` (Entity `gosof80`, Pinnamen der Platine)
  instanziieren den Kern als `core`. ROM-Lader je Platinenfamilie als Entity `sd_reader`:
  `rtl/common/sd_reader_hw2x.vhd` (4 KB/Spiel), `rtl/hw4x/sd_reader_hw4x.vhd` (64 KB/Spiel, CRC) bzw.
  `rtl/hw5x/sd_reader_hw5x.vhd` (keine SD-Karte: 4 KB/Spiel aus dem Konfigurationsflash, `Flash_ROM.vhd`).
  Welche Dateien, entscheidet `Options` in `variant.psd1` (`files_hw2x.tcl` / `files_hw3x.tcl` / `files_hw4x.tcl` / `files_hw5x.tcl`).
- Options-DIPs (ON = '0'): DIP1 CPU-Takt 1020/892 kHz, DIP2 ON = MP3-Sprache / OFF = Votrax,
  DIP3 ON = Testschalter wie Original / OFF = Versionsansage, DIP4 ON = Testmodus (Zahlen, MP3-Ordner 64).
- T65 (6502) mit 892 kHz bzw. 1020 kHz (`Gosof_PLL`: ALTPLL auf Cyclone IV/10, Teiler auf Cyclone II und HW 5.x), RIOT R6532, 128 B RAM, zwei 2-KB-ROMs
  (`SB_ROM`), die `SD_Card` beim Start von der SD-Karte füllt (Spielauswahl über `game_sel`).
- Soundboard-Typ aus `game_sel(5 downto 3)`: MA-216, MA-309, MA-55, MA-490, System 1, special.
  Adressdekodierung und RIOT-Belegung hängen davon ab.
- Ton: 8-Bit-Latch (MA-216/309) bzw. RIOT PA (andere) → `dac` (Delta-Sigma) → `Audio_O`.
- Sprache, zwei Wege:
  - MP3 (Options-DIP 2 ON, und immer auf Cyclone II): `Votrax-SC01.vhd` bildet nur A/R-Timing nach, der
    DFPlayer spielt die Sprache (`speech_ctrl`-Tabelle je Spiel, Ordner in `DFcmd_par1`),
    Attract-Sprache über `attract`.
  - Emulation (ab x.98, MA-216 mit Options-DIP 2 OFF, `HAS_VOTRAX` in `variant_pkg.vhd`):
    `rtl/common/votrax/votrax_sc01.vhd`, PinMAMEs SC-01-Modell. $3000 = SC-01-Takt, $7000 = Mute,
    Mischer auf 10-Bit-DAC. Details: `docs/Votrax_SC01_Implementierung.md`.
  - Versionsansage (`rtl/common/votrax/vtx_announce.vhd`): Testschalter bei Options-DIP 3 OFF,
    Phonemtabellen aus `sim/votrax/tools/gen_announce.py`, Version aus den Generics `BOARD_ID`/`SW_MINOR`
    (`gen_qsf.ps1` schreibt sie als `set_parameter`). Prüfung: `sim/votrax/run_announce_tb.ps1`.
- Hintergrundmusik bei System 1 und MA-55 (alle Platinen) über `background_sound`.
- HW 4.x zusätzlich: Soundtest (`soundtest`, Schalter Gosof_Test), CRC-LED. HW 5.x wie HW 4.x, aber ohne SD/CRC.

## HW 5.x: ROMs aus dem Konfigurationsflash (`hw5x_cyclone_IV`, seit 18.10.2026)

Platine GOSOF 5.00 (`..\Target\GOSOF\v5.x`) mit gestecktem EP4CE6E22C8N-Core-Board
(`N:\Projekte\FPGA\EP4CE6E22C8N_Core_Board`), keine SD-Karte. `Flash_ROM.vhd` (aus WillFA7) liest die
4 KB des gewählten Spiels per READ 03h aus dem **EPCS4**, dem Konfigurationsflash (Pins DCLK 12, DATA0 13,
nCSO 8, ASDO 6, in `device.tcl` nach der Konfiguration als I/O freigegeben).

```
EPCS4    0x000000 - 0x028668          komprimierter Bitstream (Stand 18.10.2026)
         FLASH_BASE + n*0x1000        Spiel n (= not game_sel), 4 KB wie die Datei von make_sd.bat
```

- `FLASH_BASE` steht in `variants/hw5x_cyclone_IV/variant_pkg.vhd`, `make_flash_hex.ps1` liest ihn von dort.
  Unkomprimiert belegt der Bitstream 368 KB (bis 0x59D8A) des 512-KB-Flash – ohne Kompression passen die
  Slots nicht. **Die Kompression der `.jic` macht die `.cof`**: `<compress_bitstream>1</compress_bitstream>`
  steht *innerhalb* von `<sof_filename>` (als eigenes Element daneben scheitert `quartus_cpf` ohne Meldung;
  `ON_CHIP_BITSTREAM_DECOMPRESSION` in `device.tcl` wirkt nur auf die `.pof` des Assemblers). Wächst das
  Design, nach dem Build die `.map` der `.jic` gegen `FLASH_BASE` prüfen.
- Der **W25Q64** des Core-Boards hängt an normalen I/O-Pins (74/75/84/87) und ist per `.jic` nicht
  beschreibbar. Er wird nicht benutzt.
- Keine CRC. Ist der Slot komplett FF (leer), bleibt die CPU im Reset und Core-LED1 blinkt.
- **Die Release-`.jic` bleibt ROM-frei** (Urheberrecht). ROMs ins Flash, lokal:
  `scripts\make_flash_hex.ps1 -Image ..\..\Gosof_Image_v1.21.img` (oder `-SlotFiles`), dann in
  `variants\hw5x_cyclone_IV` `quartus_cpf -c gosof80_roms.cof` → `output_files\gosof80_roms.jic`. Beides
  liegt unter `output_files\` (git-ignoriert). Eine Kopie liegt lokal als
  `bin\HW5x_Cyclone_IV\GOSOF80_HW5.x_v7.98_roms.jic`; `.gitignore` schließt `bin/*/*_roms.jic` aus, sie
  wird **nie committet**.
- `reset_sw` liegt auf PIN_88 (Takteingang CLK7, kein interner Pull-up möglich). `pins.tcl` schaltet den
  Pull-up aus `common_header.tcl` dort wieder ab.
- LEDs: D1 = Trigger, D2 = Sound (aktiv-high, auf v4 invertiert), Core-LED1 = Flash-Fehler (aktiv-low).
  Das Core-Board steckt **kopfüber** auf der Platine, LED1 ist dann nicht zu sehen. Deshalb blinkt D1 bei einem
  Flash-Fehler mit (seit 28.10.2026, `board_hw5x.vhd`).
- Kopfüber gesteckt tauschen die beiden Stiftreihen: FPGA1-Pad n der Netzliste trifft Core-Pin n±1. `pins.tcl` folgt
  `pins_Gosof_v5.xlsx` und ist so richtig (gemessen 28.10.2026: Pad 3 = 3,3 V, nicht 2,5 V). Die Nummern
  der Netzliste also nie direkt mit dem Core-Schaltplan (J5/J6) verbinden.
- Prüfung des Laders: `sim/flash/run_sim.ps1` (GHDL, SPI-Flash-Modell).
- **CPU-Takt ohne PLL** (seit 28.10.2026): `RtlFamily = 'cyclone_IV_div'` → `scripts/files_cyclone_IV_div.tcl`
  (Cyclone-IV-Megafunctions, aber `Gosof_PLL` = Teiler aus `rtl/cyclone_II/`). Anlass: Die PLL eines
  Core-Boards war defekt, der Rest des Chips lief. Symptom: Lader und Soundtest laufen (auf `clk_50`/`uart_clk`),
  aber kein Ton und keine Reaktion auf Eingänge. Gleiche Frequenzen, Hold knapp (0,090 ns), `OPTIMIZE_HOLD_TIMING "ALL PATHS"`.

## Was ändern → wo

| Änderung | Ort |
|---|---|
| Logik, neue Module | `top/GOSOF80.vhd`, `rtl/common/` + Eintrag in `scripts/files_common.tcl` |
| Pins einer Platine | `variants/<n>/pins.tcl` |
| Chip / Quartus-Version / EDA | `variants/<n>/device.tcl` |
| globale Quartus-Optionen | `scripts/common_header.tcl` |
| Megafunction neu erzeugen | in **jedem** `rtl/cyclone_*`-Ordner, gleiche Entity-Namen; Cyclone II mit 13.0sp1 |
| Version | `scripts/version.psd1` (`SwMinor`), Board-ID in `variant.psd1` |
| Timing | `rtl/common/GOSOF80.sdc` (gemeinsam, nennt nur Hierarchienamen) |
| Konstante je Platine (z. B. `HAS_VOTRAX`) | `variants/<n>/variant_pkg.vhd` |
| Votrax-Rechenweg / Formate | **zuerst** `sim/votrax/model/vmodel.c` (die Spezifikation), dann VHDL, dann `sim/votrax/run_sim.ps1` – VHDL muss bitgleich zum Modell bleiben |
| Text der Versionsansage | `sim/votrax/tools/gen_announce.py`, dann `run_announce_tb.ps1` (rendert WAV) |
| Pins/Unterschiede einer Platinenfamilie | `top/board_*.vhd`, `scripts/files_hw2x.tcl` / `files_hw4x.tcl` / `files_hw5x.tcl` |
| Flash-Layout HW 5.x | `FLASH_BASE` in `variants/hw5x_cyclone_IV/variant_pkg.vhd`, dann `sim/flash/run_sim.ps1` |
| Votrax-Tabellen | `sim/votrax/tools/gen_votrax_tables.py` ausführen, nie `votrax_tables_pkg.vhd` von Hand ändern |

Danach `scripts\gen_qsf.ps1` und `scripts\check.ps1 -Fit`. Abnahme sind die Synthesezahlen
(comb/reg/mem) aus `map.rpt` gegen `scripts/baseline.csv`, **nicht** die LE-Zahl des Fitters.
Ändern sich die Zahlen gewollt: `baseline.csv` mit Begründung in der Note-Spalte nachziehen.

## Regeln und Fallstricke

- Die `.qsf` ist **generiert**, nie von Hand ändern. Wer das Projekt in der Quartus-IDE öffnet, sollte
  danach `gen_qsf.ps1 -Check` laufen lassen.
- Pfade sind relativ zu `variants/<n>/` (`../../rtl/...`). Die `.qip` sind ortsunabhängig.
- Quartus: Cyclone II → `C:\altera\13.0sp1\quartus\bin64`, sonst `C:\intelFPGA_lite\22.1std\quartus\bin64`.
  In PowerShell 5.1 nie `2>&1` auf `quartus_*.exe`, maßgeblich ist `$LASTEXITCODE`.
- `VIRTUAL_PIN` geht unter Quartus 13.0 (Cyclone II) nicht. Braucht ein neuer optionaler Port das,
  muss eine Platinenhülle (`TopEntity`) her.
- `else generate` gibt es in VHDL-93 nicht, deshalb paarweise `if … generate` schreiben.
- Textersetzungen nicht mit `sed -i` aus der Git-Bash machen, das zerstört CRLF. Stattdessen PowerShell mit
  `[System.IO.File]::WriteAllText` und `UTF8Encoding($false)` nehmen.
- `.cof` mit relativen Pfaden. Gegenprobe ist die `.jic`-Größe: EP4CE6 2.097.375 B, 10CL006Y 2.097.377 B.
- `VARIANTEN.md` hält fest, was auf Hardware getestet ist. Ein sauberer Build beweist das nicht.
- GHDL liegt portabel in `C:\Users\bonta\tools\ghdl` (6.0.0, mcode). `numeric_std`-Multiplikationen
  rechnet es bitweise: im VHDL nur dann multiplizieren, wenn das Ergebnis gebraucht wird, sonst wird
  die Simulation 100-mal langsamer.
- PowerShell: `R` und `Rp` sind Aliase (`Invoke-History`, `Remove-ItemProperty`), nicht als Funktionsnamen nehmen.

## Offene Punkte

- Registergeteilte Takte (Cyclone II und HW 5.x: CPU-Takt aus `Gosof_PLL`-Teiler; alle: `uart_clk_out`): Hold auf Cyclone II
  nur per Fitter-Einstellung erfüllt (`OPTIMIZE_HOLD_TIMING "ALL PATHS"`). Saubere Lösung: Clock-Enables auf `clk_50`.
- GOSOF80B liegt noch in `..\FPGA_source_alt` und soll als weitere Variante hierher.
- Warnungsbereinigung (10036, 10920 an der T65-Adressleitung).
- Votrax: Hörtest der angehobenen Sprachlautstärke (Sprache ×2, Töne ×3/4 bei aktiver Emulation, seit 15.10.2026), Inflection-Verdrahtung (I1/I2 an D6/D7?)
  gegen den MA-216-Schaltplan prüfen.
