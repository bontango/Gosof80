# Varianten – Ressourcen, Eigenheiten, Hardware-Teststand

Stand 14.10.2026, erster Bau des gemeinsamen Baums. Zahlen aus `scripts\check.ps1 -Fit`.

## Hardware-Teststand

| Variante | Release im Feld | Neuer Baum auf Hardware getestet? |
|---|---|---|
| `hw2x_cyclone_II` | v0.97 (aus altem Baum) | **nein** |
| `hw2x_cyclone_IV_v3` | v2.97 (aus altem Baum) | **nein** |
| `hw2x_cyclone_IV_v4` | v3.97 (aus altem Baum) | **nein** |
| `hw2x_cyclone_10` | v4.97 (aus altem Baum) | **nein** |

Die Releases in `bin/` sind byte-gleich mit den Build-Ausgaben des alten Baums
(md5 geprüft 14.10.2026), also der tatsächlich ausgelieferte Stand.
Was der neue Baum erzeugt, ist bisher nur gebaut. **Zuerst testen:** Sound und Sprache
an einem MA-216-Spiel (Black Hole, Mars), SD-Laden, Attract-Sprache, DIP-Optionen.
Bei den 22.1-Varianten unterscheidet sich die Netzliste leicht vom Release (siehe unten).

## Ressourcen

| Variante | Comb | Reg | Mem (Bit) | LE (Fitter) | Setup-Slack | Hold-Slack |
|---|---|---|---|---|---|---|
| `hw2x_cyclone_II` | 2161 | 791 | 33792 | 2265 / 4608 | 3,853 ns | **−1,857 ns** |
| `hw2x_cyclone_IV_v3` | 2188 | 793 | 33792 | 2310 / 6272 | 4,348 ns | 0,452 ns |
| `hw2x_cyclone_IV_v4` | 2188 | 793 | 33792 | 2315 / 6272 | 5,323 ns | 0,452 ns |
| `hw2x_cyclone_10` | 2188 | 793 | 33792 | 2313 / 6272 | 5,051 ns | 0,452 ns |

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
5. **Hold-Verletzung auf Cyclone II (Altbestand, nicht behoben).** `uart_clk_out` −1,857 ns,
   `cpu_clk_out` −1,014 ns. Beide Takte sind registergeteilt (`cpu_clk_gen`, `uart_clk_gen`).
   `check.ps1` vergleicht nur den Setup-Slack.
6. **Board-ID 4 doppelt belegt:** HW2.x/Cyclone 10 = v4.97, das HW-4.x-Board zählt
   ebenfalls v4.xx (v4.98, v4.01). Das muss gelöst werden, bevor HW 4.x in diesen Baum kommt.

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
- Cyclone II zusätzlich: 332148 ×2 (die Hold-Verletzung oben)
