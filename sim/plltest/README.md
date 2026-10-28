# PLL-Test für das EP4CE6E22C8N-Core-Board

Eingangstest für jedes neue Core-Board, **bevor** es auf eine GOSOF-5.x-Platine kommt.
Anlass: Am 28.10.2026 lieferte die PLL eines Core-Boards keinen Takt, obwohl der Rest des Chips
lief. Versorgung 2,5 V und 1,2 V waren in Ordnung. Auf der Platine sah das so aus: Der Flash-Lader
und der Soundtest liefen, aber es kam kein Ton und keine Reaktion auf Eingänge (Details in
`VARIANTEN.md`, HW 5.x, Hardwaretest 3).

Seitdem nimmt `hw5x_cyclone_IV` den Teiler statt der PLL und läuft auch auf solchen Boards. Der Test
sortiert solche Boards trotzdem aus oder kennzeichnet sie. Andere Designs mit PLL laufen darauf nicht.

## Ablauf

1. `build.ps1` ausführen (Quartus 22.1std). Ergebnis: `output_files\plltest.sof` und `.jic`.
2. Core-Board **allein** (nicht aufgesteckt) per USB versorgen, USB-Blaster an JTAG.
3. `plltest.sof` per JTAG laden. Der Flash bleibt unberührt, nach Aus/Ein läuft wieder das alte Design.

| LED | Quelle | Erwartung |
|---|---|---|
| LED2 (PIN_2) | `clk_50` / 2^25 | blinkt ca. 1,5 Hz: Design läuft |
| LED1 (PIN_1) | `Gosof_PLL` c0 (892 kHz) / 2^20 | blinkt ca. 0,85 Hz: **PLL in Ordnung** |

Blinkt nur LED2, ist die PLL tot. Dann Pins 35 (VCCA1), 36 (GNDA1) und 37 (VCCD_PLL1) am Chip mit der
Lupe prüfen und nachlöten. Bleibt es dabei, das Board kennzeichnen.

Die PLL ist dieselbe wie im GOSOF-Kern (`rtl/cyclone_IV/Gosof_PLL.qip`, 50 MHz → 892,86 / 1020,4 kHz).
