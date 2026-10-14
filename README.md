# GOSOF80 – FPGA-Soundboard für Gottlieb System 80

FPGA-Nachbau des Gottlieb-System-80-Soundboards (MA-216, MA-309, MA-55, MA-490, dazu
System 1 „Multisound“) von bontango, [lisy.dev](https://lisy.dev/). Eine T65 (6502) führt
die originalen Sound-ROMs aus, die von SD-Karte geladen werden. R6532 RIOT, ein
Delta-Sigma-DAC und ein DFPlayer für Sprache und Hintergrundmusik ergänzen das.
Der Votrax SC-01 ist bisher nur als Timing-Nachbildung vorhanden, die Sprache selbst
kommt als MP3 (siehe `docs/Votrax_SC01_Evaluierung.md`).

Dieser Baum enthält **eine** Quelle für alle Platinenvarianten der Hardware 2.x.

| Variante | Chip | Quartus | Release |
|---|---|---|---|
| `hw2x_cyclone_II` | EP2C5T144C8 | 13.0sp1 Web Edition | `bin/Cyclone_II/GOSOF80_HW2.x_v0.97.pof` |
| `hw2x_cyclone_IV_v3` | EP4CE6F17C8 | 22.1std Lite | `bin/Cyclone_IV_v3/GOSOF80_HW2.x_v2.97.jic` |
| `hw2x_cyclone_IV_v4` | EP4CE6E22C8 | 22.1std Lite | `bin/Cyclone_IV_v4/GOSOF80_HW2.x_v3.97.jic` |
| `hw2x_cyclone_10` | 10CL006YE144C8G | 22.1std Lite | `bin/Cyclone_10/GOSOF80_HW2.x_v4.97.jic` |

Versionsschema: `<BoardId>.<SwMinor>`. Die Board-ID steht in `variants/<name>/variant.psd1`,
`SwMinor` (derzeit `97`) einmal in `scripts/version.psd1`.

## Aufbau

```
top/GOSOF80.vhd        das eine Top-Level
rtl/common/            alle Module, T65, RIOT, GOSOF80.sdc
rtl/cyclone_II|IV|10/  Megafunctions (SB_ROM, RAM) je FPGA-Familie, gleiche Entity-Namen
variants/<name>/       device.tcl, pins.tcl, variant.psd1, GOSOF80.qpf/.cof, GOSOF80.qsf (generiert)
scripts/               gen_qsf.ps1, check.ps1, build.ps1, release.ps1, baseline.csv, version.psd1
bin/                   ausgelieferte .jic/.pof + changelog.txt
docs/                  Hintergrund (Votrax-Evaluierung)
```

## Bauen

```powershell
scripts\check.ps1 -Fit              # alle Varianten: Synthese + Fit + Timing gegen baseline.csv
scripts\build.ps1 hw2x_cyclone_10   # eine Variante voll bauen, inkl. .jic
scripts\release.ps1 -DryRun         # zeigt, welche Dateien ein Release erzeugen würde
```

Die `.qsf` wird erzeugt: Änderungen gehören in `device.tcl`, `pins.tcl` oder
`scripts/files_*.tcl`, danach `scripts\gen_qsf.ps1`. Quartus schreibt beim Öffnen in der
IDE in die `.qsf`; `check.ps1` und `build.ps1` erzeugen sie deshalb vor jedem Lauf neu.

## Herkunft

Bis 10.2026 lag jede Variante als eigener Quartus-Ordner `GOSOF80_HW2x_*` neben den
Bibliotheken `lib_common`, `lib_cyclone_*` (jetzt `FPGA_source_alt`). HW 3.x, HW 4.x und
GOSOF80B werden dort noch gepflegt und kommen später als weitere Varianten dazu.
Lizenz: GPL v3 (siehe Kopf von `top/GOSOF80.vhd`); T65 und dac.vhd stehen unter ihren eigenen Lizenzen.
