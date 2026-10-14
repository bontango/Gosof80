# Warum der Baum so aussieht

## Ausgangslage (bis 10.2026)

`FPGA_source/` enthielt je Platine einen vollständigen Quartus-Ordner (`GOSOF80_HW2x_CycloneII`,
`_CycloneIV_v3`, `_CycloneIV_v4`, `_Cyclone10`, dazu HW 3.x, HW 4.x, GOSOF80B, debug, Archiv).
Geteilt waren nur `lib_common/` und `lib_cyclone_*/`, das Top-Level `GOSOF80.vhd` war je Ordner kopiert.
Die vier HW-2.x-Kopien waren bis auf Kommentarzeilen identisch. Das ist der günstigste Fall: umbauen,
solange die Kopien noch gleich sind, ein Angleichen vorab war nicht nötig.

## Entscheidungen

- **Nur HW 2.x zuerst.** HW 3.x/4.x sind inhaltlich weiter (CRC, Testmodus, PLL, eigenes SD_Card)
  und müssen vor der Aufnahme erst angeglichen werden.
- **Kein `variant_pkg.vhd`/`version_pkg.vhd`.** Das Design kennt weder Board-ID noch Version, ein
  unbenutztes Package wäre nur Ballast. Die Version steht einmal in `scripts/version.psd1`, die
  Board-ID in `variant.psd1`. `release.ps1` setzt daraus den gewohnten Dateinamen zusammen.
- **Kein `generate`, kein `VIRTUAL_PIN`.** Alle vier Platinen haben dieselben 34 Ports. Der
  Unterschied liegt nur in Chip, Pins und Megafunction-Familie.
- **`.sdc` gemeinsam** in `rtl/common/`, weil sie nur Hierarchienamen nennt, die in allen Varianten gleich sind.
- **Drei Megafunction-Ordner.** `cyclone_10` und `cyclone_IV` unterscheiden sich nur im
  Family-String. `cyclone_II` ist mit 13.0 erzeugt (eigene Komponentendeklaration).
- **CLAUDE.md, VARIANTEN.md, PLAN_Zielstruktur.md sind eingecheckt**, weil das Repo privat ist.
- **Projektname überall `GOSOF80`**, unterschieden wird über den Ordner.

## Was anders kam als geplant

- Die Synthese der 22.1-Varianten blieb **nicht** byte-gleich (−9 bzw. −4 comb, −1 reg). Ursache war
  nicht der Umbau, sondern die im Altbestand fehlende `.sdc`. Ohne SDC-Zeile reproduziert der neue Baum
  die alten Zahlen exakt. Neue Baseline: Stand mit SDC.
- Die `.cof` des Cyclone-10-Ordners war nicht die, mit der das Release entstanden ist (EP4CE6 statt 10CL006Y).
  Aufgefallen ist das an der `.jic`-Größe.
- `FPGA_source` ließ sich während der Session nicht umbenennen (die Rechteprüfung hat das Umbenennen abgelehnt). Der Baum
  entstand deshalb als `FPGA_Source_neu`. Die Umbenennung in `FPGA_source_alt` / `FPGA_Source` macht Ralf
  selbst. Alle Pfade im Baum sind relativ, daher ist der Ordnername egal.

## Schritte, wie ausgeführt (14.10.2026)

1. md5 der Releases gegen die Build-Ausgaben des alten Baums: alle vier gleich.
2. Baseline: alle vier alten Varianten voll neu gebaut (13.0sp1 bzw. 22.1std), Zahlen = alte Reports.
3. Dateien kopiert (nicht verschoben), Fragmente aus den alten `.qsf` abgeleitet (Schnittmenge →
   `common_header.tcl`, Rest → `device.tcl`, Pins → `pins.tcl`).
4. Generierte `.qsf` gegen die alten verglichen, sortiert und nach Pfadumschreibung: 0 Unterschiede.
5. Vollbau, `check.ps1 -Fit` grün, `.jic`-Größen geräterichtig, `release.ps1 -DryRun` ergibt die alten Namen.
