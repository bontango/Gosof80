# GOSOF80 – Kontext für Claude

FPGA-Ersatz des Gottlieb-System-80-Soundboards, gemeinsamer Sourcebaum für die
HW-2.x-Platinen. Aufbau nach Skill `fpga-varianten-sourcebaum` (Vorlage AtariFA).
Repo: `github.com/bontango/Gosof80` (privat), direkt auf `main` committen.

## Architektur (top/GOSOF80.vhd)

- T65 (6502) mit 892 kHz bzw. 1042 kHz (`cpu_clk_gen`), RIOT R6532, 128 B RAM, zwei 2-KB-ROMs
  (`SB_ROM`), die `SD_Card` beim Start von der SD-Karte füllt (Spielauswahl über `game_sel`).
- Soundboard-Typ aus `game_sel(5 downto 3)`: MA-216, MA-309, MA-55, MA-490, System 1, special.
  Adressdekodierung und RIOT-Belegung hängen davon ab.
- Ton: 8-Bit-Latch (MA-216/309) bzw. RIOT PA (andere) → `dac` (Delta-Sigma) → `Audio_O`.
- Sprache, zwei Wege:
  - MP3 (DIP 2 OFF, und immer auf Cyclone II): `Votrax-SC01.vhd` bildet nur A/R-Timing nach, der
    DFPlayer spielt die Sprache (`speech_ctrl`-Tabelle je Spiel, Ordner in `DFcmd_par1`),
    Attract-Sprache über `attract`.
  - Emulation (ab x.98, MA-216 mit DIP 2 ON, `HAS_VOTRAX` in `variant_pkg.vhd`):
    `rtl/common/votrax/votrax_sc01.vhd`, PinMAMEs SC-01-Modell. $3000 = SC-01-Takt, $7000 = Mute,
    Mischer auf 10-Bit-DAC. Details: `docs/Votrax_SC01_Implementierung.md`.
- Hintergrundmusik bei System 1 über `background_sound`.

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

- Registergeteilte Takte `cpu_clk_out`/`uart_clk_out`: Hold auf Cyclone II nur per Fitter-Einstellung erfüllt
  (`OPTIMIZE_HOLD_TIMING "ALL PATHS"`). Saubere Lösung: Clock-Enables auf `clk_50`.
- Board-ID 4 kollidiert mit der HW-4.x-Nummerierung. Das vor der Aufnahme von HW 4.x klären.
- HW 3.x, HW 4.x, GOSOF80B liegen noch in `..\FPGA_source_alt` und sollen als weitere Varianten
  hierher (dafür erst angleichen: HW 4.x hat CRC-Check, Testmodus, eigenes SD_Card, PLL).
- Warnungsbereinigung (10036, 10920 an der T65-Adressleitung).
- Votrax: Hardwaretest, Lautstärkeverhältnis Sprache/Ton, Inflection-Verdrahtung (I1/I2 an D6/D7?)
  gegen den MA-216-Schaltplan prüfen.
