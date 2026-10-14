# Varianten – Ressourcen, Eigenheiten, Hardware-Teststand

Stand 14.10.2026. Zahlen aus `scripts\check.ps1 -Fit`.

## Hardware-Teststand

| Variante | x.97 | x.98 (Votrax) |
|---|---|---|
| `hw2x_cyclone_II` | **ok** (Ralf, 14.10.2026) | **nicht getestet** (ohne Votrax) |
| `hw2x_cyclone_IV_v3` | **ok** (Ralf, 14.10.2026) | **nicht getestet** |
| `hw2x_cyclone_IV_v4` | **ok** (Ralf, 14.10.2026) | **nicht getestet** |
| `hw2x_cyclone_10` | **ok** (Ralf, 14.10.2026) | **nicht getestet** |

x.97: Die Releases in `bin/` sind byte-gleich mit den Build-Ausgaben des alten Baums (md5,
14.10.2026). Ralf meldet für die x.97-Varianten Funktion auf der Hardware.

x.98 ist nur gebaut und simuliert (Votrax bitgleich zum C-Modell, siehe
`docs/Votrax_SC01_Implementierung.md`). **Zuerst testen:**
1. DIP 2 OFF: alles wie x.97 (MP3-Sprache, Attract-MP3), Lautstärke unverändert.
2. DIP 2 ON an einem MA-216-Spiel (Black Hole, Mars, Volcano): Sprache aus der Emulation, kein MP3,
   TILT-Verlangsamung, Attract-Sprache (Sound-DIPs S3/S4), Lautstärkeverhältnis Sprache/Ton.
3. Cyclone II: wie x.97 (der Mischer ist neu, sonst nichts).

## Ressourcen x.97

| Variante | Comb | Reg | Mem (Bit) | LE (Fitter) | Setup-Slack | Hold-Slack |
|---|---|---|---|---|---|---|
| `hw2x_cyclone_II` | 2161 | 791 | 33792 | 2264 / 4608 | 4,359 ns | 0,215 ns |
| `hw2x_cyclone_IV_v3` | 2188 | 793 | 33792 | 2310 / 6272 | 4,348 ns | 0,452 ns |
| `hw2x_cyclone_IV_v4` | 2188 | 793 | 33792 | 2315 / 6272 | 5,323 ns | 0,452 ns |
| `hw2x_cyclone_10` | 2188 | 793 | 33792 | 2313 / 6272 | 5,051 ns | 0,452 ns |

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
