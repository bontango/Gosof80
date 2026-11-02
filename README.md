# GOSOF80 – FPGA-Soundboard für Gottlieb System 80

FPGA-Nachbau des Gottlieb-System-80-Soundboards (MA-216, MA-309, MA-55, MA-490, dazu
System 1 „Multisound“) von bontango, [lisy.dev](https://lisy.dev/). Eine T65 (6502) führt
die originalen Sound-ROMs aus, die von SD-Karte geladen werden. R6532 RIOT, ein
Delta-Sigma-DAC und ein DFPlayer für Sprache und Hintergrundmusik ergänzen das.
Die Sprache kommt wahlweise als MP3 oder – ab x.98, bei MA-216-Spielen mit **DIP 2 ON** – aus
einer Emulation des Votrax SC-01 nach PinMAME (`docs/Votrax_SC01_Implementierung.md`;
nicht auf Cyclone II).

Dieser Baum enthält **eine** Quelle für alle Platinenvarianten der Hardware 2.x.

| Variante | Chip | Quartus | Votrax | Release |
|---|---|---|---|---|
| `hw2x_cyclone_II` | EP2C5T144C8 | 13.0sp1 Web Edition | – | `bin/Cyclone_II/GOSOF80_HW2.x_v0.98.pof` |
| `hw2x_cyclone_IV_v3` | EP4CE6F17C8 | 22.1std Lite | ja | `bin/Cyclone_IV_v3/GOSOF80_HW2.x_v2.98.jic` |
| `hw2x_cyclone_IV_v4` | EP4CE6E22C8 | 22.1std Lite | ja | `bin/Cyclone_IV_v4/GOSOF80_HW2.x_v3.98.jic` |
| `hw2x_cyclone_10` | 10CL006YE144C8G | 22.1std Lite | ja | `bin/Cyclone_10/GOSOF80_HW2.x_v4.98.jic` |

Versionsschema: `<BoardId>.<SwMinor>`. Die Board-ID steht in `variants/<name>/variant.psd1`,
`SwMinor` (derzeit `98`) einmal in `scripts/version.psd1`. Ältere Stände liegen daneben in `bin/`.

## Aufbau

```
top/GOSOF80.vhd        das eine Top-Level
rtl/common/            alle Module, T65, RIOT, GOSOF80.sdc
rtl/common/votrax/     SC-01-Emulation (Tabellen erzeugt von sim/votrax/tools/gen_votrax_tables.py)
rtl/cyclone_II|IV|10/  Megafunctions (SB_ROM, RAM) je FPGA-Familie, gleiche Entity-Namen
variants/<name>/       device.tcl, pins.tcl, variant.psd1, GOSOF80.qpf/.cof, GOSOF80.qsf (generiert)
scripts/               gen_qsf.ps1, check.ps1, build.ps1, release.ps1, baseline.csv, version.psd1
bin/                   ausgelieferte .jic/.pof + changelog.txt
docs/                  Hintergrund (Votrax: Evaluierung, Implementierung)
sim/votrax/            PinMAME-Referenz, C-Modell, GHDL-Testbenches: run_sim.ps1
```

## Bauen

```powershell
scripts\check.ps1 -Fit              # alle Varianten: Synthese + Fit + Timing gegen baseline.csv
scripts\build.ps1 hw2x_cyclone_10   # eine Variante voll bauen, inkl. .jic
scripts\release.ps1 -DryRun         # zeigt, welche Dateien ein Release erzeugen würde
sim\votrax\run_sim.ps1              # Votrax: PinMAME vs. C-Modell vs. VHDL (GHDL), ~25 min
```

Die `.qsf` wird erzeugt: Änderungen gehören in `device.tcl`, `pins.tcl` oder
`scripts/files_*.tcl`, danach `scripts\gen_qsf.ps1`. Quartus schreibt beim Öffnen in der
IDE in die `.qsf`; `check.ps1` und `build.ps1` erzeugen sie deshalb vor jedem Lauf neu.

## Herkunft

Bis 10.2026 lag jede Variante als eigener Quartus-Ordner `GOSOF80_HW2x_*` neben den
Bibliotheken `lib_common`, `lib_cyclone_*` (jetzt `FPGA_source_alt`). Die weiteren Platinen kamen später als Varianten dazu.
GOSOF80B (MA-766, System 80B): Variante `80B_dev_open`, siehe `docs/GOSOF80B_MA766.md`. MA-886: Varianten `80B_ma886_gen2` und `80B_ma886_gen3`, siehe `docs/MA-886_Evaluierung.md`.
Lizenz: GPL v3 (siehe Kopf von `top/GOSOF80.vhd`); T65 und dac.vhd stehen unter ihren eigenen Lizenzen.
