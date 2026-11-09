# Gottlieb System 3 mit GOSOF80B: Evaluierung

Stand 09.11.2026: nur bewertet, nichts umgesetzt. Quellen: PinWiki „Gottlieb System 3“, PinMAME
`src/wpc/gts3.c`, `gts3games.c`, `gts80s.c`, `gts80s.h` (lokal in `N:\Projekte\my_PINMAME\pinmame-master`).
Hintergrund zu MA-886, SRAM und Platzbedarf: `MA-886_Evaluierung.md`.

## Ergebnis

**Neun frühe System-3-Spiele lassen sich mit wenig Aufwand über die vorhandenen Bitstreams Gen 2 und Gen 3
abdecken. Die Spiele mit OKI MSM6295 (ab Cactus Jack's) sind ein eigenes Projekt und passen nicht auf den E6.**

PinWiki: *„Gottlieb carried over the same basic sound architecture from System 80B to System 3. In fact the base PCB
is the same for late 80B sound boards and System 3. How the boards are populated is what distinguishes them.“*
PinMAME bestätigt das: Die frühen System-3-Spiele laufen dort mit genau den Soundtreibern der 80B
(`mGTS3S80B2` → `gts80s_b2`, `mGTS3S80B3` → `gts80s_b3`).

## Gruppe 1: ohne OKI (MA-886-XXX)

| Spiel | ROM-Satz | Jahr | Board (PinWiki) | PinMAME | GOSOF80B |
|---|---|---|---|---|---|
| Lights, Camera, Action | `lca` | 1989 | MA-886-720 + MA-1033 | `mGTS3S80B3` | Gen 3 |
| Bell Ringer | `bellring` | 1990 | MA-886-xxx + MA-1294 | `mGTS3S80B3` | Gen 3 |
| Silver Slugger | `silvslug` | 1990 | MA-886-722 + MA-1294 | `mGTS3S80B3` | Gen 3 |
| Vegas | `vegas` | 1990 | MA-886-723 + MA-1294 | `mGTS3S80B3` | Gen 3 |
| Deadly Weapon | `deadweap` | 1990 | MA-886-xxx + MA-1294 | `mGTS3S80B3` | Gen 3 |
| Title Fight | `tfight` | 1990 | MA-886-726 + MA-1294 | `mGTS3S80B3` | Gen 3 |
| Car Hop | `carhop` | 1991 | MA-886-xxx + MA-1294 | `mGTS3S80B3` | Gen 3 |
| Hoops | `hoops` | 1991 | MA-886-xxx + MA-1294 | `mGTS3S80B3` | Gen 3 |
| Nudge It | `nudgeit` | 1990 | MA-886 voll bestückt (2 × AY) | `mGTS3S80B2` | Gen 2 |

- **ROMs:** `GTS3SOUND3232`, also yrom und drom zu je 32 KB, genau das Format der MA-886-Spiele (64 KB je Slot).
- **Memory Map:** wie Gen 3 (`gts80s_b3`). Die zusätzlichen Adressen von `GTS3_ywritemem` (`$7800` U2-Latch,
  `$8000` NOP, Bits 2–6 von `$A000`) gehören zum OKI-Teil und werden in Gruppe 1 nicht gebraucht. Der Schreibzugriff auf `$7000`
  (D-NMI) ist im Kern schon abgedeckt, `y_dnmi_cs` reagiert auf Lesen und Schreiben.
- **YM2151 auf MA-1294:** Digitalteil wie A20/MA-1033, siehe `MA-886_Evaluierung.md`. Analog etwas mehr Bass und weniger Höhen.

### Was zu ändern wäre

1. **Soundbefehl mit 8 Bit.** Die System-3-MPU schreibt ein ganzes Byte (VIA PA0–7, SD0–7, in PinMAME
   invertiert: `sound_data = data ^ 0xff`). Befehle über 31 kommen also vor. PinMAME (`s80bs_sh_w`, Zweig `test1`)
   übernimmt alle 8 Bit und löst bei allem außer `$FF` den IRQ aus. Der Kern liest bisher nur 5 Leitungen:
   `sound_latch <= "111" & not sound_in` in `top/GOSOF80B_886.vhd`, der Trigger nimmt S1–S8 und S16 über DIP 3.
   - Auf der Platine liegen S32/S64/S128 schon an FPGA-Pins (74, 80, 84, siehe Kommentar in `pins.tcl`), sie sind nur nicht zugewiesen.
   - Auf 80B-Automaten sind diese Leitungen offen. Der ULN2803 schaltet dann nicht, der Kern liest 1, genau wie heute
     mit `"111"`. Die Erweiterung ist also **rückwärtskompatibel**, ein Bitstream je Generation reicht für 80B und System 3.
   - Trigger wie auf dem Original (A2, 7430 als 8-fach-NAND): jede der 8 Leitungen aktiv löst aus. Bei S16 bleibt die Option JP8 bzw. DIP 3.
     Ob der Jumper auf System-3-Boards anders steht, ist am Schaltplan zu prüfen.
2. **Spielelisten** in `scripts/make_flash_hex_886.ps1` ergänzen. Gen 3 hätte dann 12 Spiele, Gen 2 sechs. Es passen 24 Slots zu 64 KB hinter `FLASH_BASE`.
3. **Handbuch** (`GOSOF80B_Bedienungsanleitung.html`): Spieletabellen, System 3 in der Einleitung.

LE-Bedarf: einige zusätzliche Register und Eingänge, für Gen 3 (90 %) unkritisch.

### Offen, vor der Umsetzung zu klären

1. **Stecker:** Gleiche Grundplatine heißt gleiche Stecker am Soundboard (A6). Ob Kabelbaum und Belegung der MPU-Seite
   bei System 3 dieselben Signale auf dieselben Pins legen, ist ungeprüft. Dafür braucht es einen System-3-Schaltplan (z. B. Handbuch Hoops oder Vegas).
2. **Audio:** Bei System 3 verstärkt die Zusatz-Stromversorgung (±12 V) den Ton. PinWiki: „not much different from the
   System 80B auxiliary power supply“. Ob der direkte Ausgang der Platine über den TDA7267 auf A5P1 dort passt, ist offen.
3. **R58:** PinWiki: R58 auf einer MA-886-XXX entfernen, dann geht sie in Spielen ab Cactus Jack's; R58 auf einer MA-1629 bestücken, dann geht sie in
   Spielen bis Hoops. R58 (10 kΩ) führt laut MA-886-Plan den YM2151-Ausgang in den Summierer. Für Gruppe 1 bleibt die Mischung damit wie bei Gen 3.
4. **ROM-Sätze:** `lca`, `bellring`, `silvslug`, `vegas`, `deadweap`, `tfight`, `carhop`, `hoops`, `nudgeit` liegen nicht in `Gosof80B\roms`.
5. **Reihenfolge:** zuerst Gen 3 auf der 80B-Hardware zum Laufen bringen, dann System 3.

## Gruppe 2: mit OKI MSM6295 (MA-1629)

Cactus Jack's (1991) bis Barb Wire (1996), darunter alle DMD-Spiele. Grundplatine MA-1629, Zusatzplatinen MA-1604 (Cactus Jack's, Class of 1812),
MA-1712 (Operation Thunder, Surf 'n Safari) und MA-1770 (Super Mario Bros. bis Barb Wire). YM2151 für Effekte,
OKI für Sprache und Musik (8 kHz ADPCM). PinMAME: `gts80s_s3`, ROM-Makros `GTS3SOUND32128` … `GTS3SOUND32512`.

| Hürde | Einschätzung |
|---|---|
| **Logik** | Gen 3 belegt 90 % des E6 (5.646 LE), dazu kämen OKI-Nachbau (z. B. jt6295) und U2/U3-Logik. Passt nicht. Mindestens EP4CE10E22 (10.320 LE, TQFP144 und pinkompatibel zum E6E22), also anderes Core-Board oder Chiptausch. LE-Bedarf des OKI ungemessen. |
| **Speicher** | Sprach-ROMs (AROM1/2, U4/U5): 2 × 128 KB (Cactus Jack's) bis 2 × 512 KB (Waterworld), typisch 512 + 256 KB. SRAM U1 (128 KB, AS6C4008 512 KB) reicht nicht. EPCS16: nach `FLASH_BASE` 1,5 MB, für die großen Spiele also **ein Spiel je Flash**. |
| **ROM-Zugriff** | Der OKI müsste direkt aus dem EPCS lesen, nachdem der Lader die CPU-ROMs ins SRAM kopiert hat. Grob 4 Stimmen × 7,6 kHz ≈ 30.000 Zugriffe/s, zu je ca. 2 µs bei 20 MHz SPI ≈ 6 % Auslastung. Gerechnet, nicht gebaut. Jede Stimme liest fortlaufend, ein kleiner Puffer je Stimme würde das weiter entschärfen. |
| **Steuerlogik** | `$7800` U2-Latch, `$A000` Bit 5 (U3 übernehmen) und Bit 6 (/WR des OKI). U3: Chip-Select, ROM-Bank (Bit 3 und Bit 6), Samplerate SS (Bit 4), LED. Siehe `sound_control_w` in `gts80s.c`. |
| **Mischung** | Anders als in Gruppe 1 (R58), Gewichte aus PinMAME: DAC 50, OKI 50, YM2151 75. |

Nicht dabei: **Strikes 'N Spares** (MA-2112, nur OKI, kein YM2151) und **Caribbean Cruise** (International Concepts, Board MA-1712).

## Nächste Schritte

1. 80B Gen 3 auf der Hardware testen.
2. System-3-Schaltplan beschaffen, Stecker und Audioweg prüfen (Offen 1–3).
3. Gruppe 1 umsetzen: 8-Bit-Befehl im Kern, `pins.tcl` (S32/S64/S128) für Gen 2 und Gen 3, Spielelisten, Simulation mit den ROM-Sätzen, Handbuch.
4. Gruppe 2 erst, wenn eine Platine mit E10 oder größerem FPGA ansteht.
