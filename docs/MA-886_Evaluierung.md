# MA-886 (System 80B, Generation 2 und 3): Evaluierung

Stand 02.11.2026: umgesetzt als Varianten `80B_ma886_gen2` und `80B_ma886_gen3`, gebaut und simuliert, **nicht auf Hardware getestet und nicht abgehört**.
Die Evaluierung vom 31.10.2026 hatte den E10 empfohlen. Das ist überholt, siehe Ergebnis. Quellen: Schaltplan
`Gosof80B\schematics\MA-886-schematic.jpg` (E-26146, 20.9.88), PinMAME `gts80s.c`/`gts80games.c`,
die ROM-Sätze in `Gosof80B\roms`, Fitterläufe mit Quartus 22.1.

## Ergebnis

**Der E6 reicht mit dem externen SRAM, der teure E10 ist nicht nötig.** Der Preis sind drei getrennte Bitstreams und der Verzicht auf Bone Busters.
Das Problem war der ROM-Speicher: Die Spiele belegen 64 KB ROM, auch der E10 hat intern nur 46 KB. Mit dem SRAM (128 K × 8, auf der Platine Gosof80B als U1 schon vorgesehen) ist es gelöst. Das FPGA
lädt die ROMs beim Start aus dem EPCS16 dorthin.

| Fassung | Spiele | SRAM | LE auf dem E6 (6.272) | Setup clk_50 | Hold (Fast) |
|---|---|---|---|---|---|
| MA-766, `80B_dev_open` (Board-ID 8) | 9 | nein | 4.382 (70 %) | 4,992 ns | 0,169 ns |
| MA-886 Gen 2, `80B_ma886_gen2` (Board-ID 9) | 5 | ja | 4.008 (64 %) | 6,654 ns | 0,186 ns |
| MA-886 Gen 3, `80B_ma886_gen3` (Board-ID 10) | 4 | ja | 5.646 (90 %) | **0,528 ns** | 0,137 ns |
| Gen 2 und Gen 3 in einem Bitstream | 9 | ja | über 6.272 (Schätzung) | – | – |
| Bone Busters (3. CPU) | 1 | ja | ca. 6.700 (Schätzung) | – | – |

Eine Platine bleibt in einem Automaten und bekommt nur die passende `.jic`, im Betrieb stören drei Bitstreams also nicht. Bone Busters ist 1 von 19 Spielen, und der Plan seiner Grundplatine fehlt ohnehin.

**Gen 3 ist die knappe Fassung:** Der jt51 belegt ca. 2.650 LE, und der kritische Pfad liegt in ihm selbst. 0,5 ns Reserve reichen, aber größere Erweiterungen hat diese Fassung nicht mehr frei. Flächenoptimierung hat in der Probesynthese nur 1 Prozentpunkt gebracht (87 % → 86 %).

## Warum auch der E10 ohne SRAM nicht reicht

Ein M9K fasst 1 K × 8. 1 KB Speicher kostet also 1 M9K, die volle Bitzahl (9 kbit) nützt bei 8 Bit Breite nichts.

| Bedarf in M9K | ROM | RAM | YM2151 | Summe |
|---|---|---|---|---|
| Gen 2 (2 CPUs, AY) | 64 | 4 | – | **68** |
| Gen 3 (2 CPUs, YM2151) | 64 | 4 | ca. 8 | **ca. 76** |
| Bone Busters (3 CPUs, YM2151) | 96 | 6 | ca. 8 | **ca. 110** |
| zum Vergleich: MA-766 | 24 | 4 | – | 28 (gemessen) |

| FPGA | M9K | LE | Gen 2 | Gen 3 | Bone Busters |
|---|---|---|---|---|---|
| EP4CE6 / 10CL006 | 30 | 6.272 | nein | nein | nein |
| **EP4CE10 / 10CL010** | 46 | 10.320 | **nein** | **nein** | nein |
| EP4CE15 / 10CL016 | 56 | 15.408 | nein | nein | nein |
| EP4CE22 / 10CL025 | 66 | 22.320 / 24.624 | nein, 2 fehlen | nein | nein |
| EP4CE40 / 10CL040 | 126 | 39.600 / 39.600 | ja | ja | ja, aber nur BGA |

Die ROMs lassen sich nicht einsparen. Der Scan aller lokalen Sätze zeigt, dass sie fast voll sind: 32 von 32 KB genutzt,
einzige Ausnahmen sind `victory` (yrom 19 KB, drom 31 KB). Spiegelungen gibt es nicht. Einzelne Spiele
passen also auch nicht zufällig in einen E22, und ein großer Chip scheidet wegen des BGA-Gehäuses aus.

## Logik und Flash: hier passt Deine Annahme

**LE (gemessen, Fitter):**

| Fassung | comb | reg | Speicher (Bit) | LE auf dem E6 (6.272) |
|---|---|---|---|---|
| Gen 2 (2 × AY, MF-4) | 3.824 | 1.502 | 36.352 | 4.008 (64 %) |
| Gen 3 (jt51, DAC-Tiefpass) | 5.298 | 1.631 | 38.277 | 5.646 (90 %) |

Die Schätzung für Gen 3 lag vor der Messung bei 92–100 %. Bone Busters (+ T65 ca. 1.080 LE) käme auf ca. 6.700 LE und passt nicht.

**Flash:** Der EP4CE6 belegt unkomprimiert bis 0x59D8A. Die ROM-Slots liegen bei Gen 2 in 0x80000–0xCFFFF und bei Gen 3 in 0x80000–0xBFFFF, also ohne Überlappung (geprüft an den `.jic`-Maps). Die `.jic` ist 2.097.375 B groß. Der EPCS16 fasst nach
`FLASH_BASE` = 0x80000 noch 1,5 MB: 24 Slots zu 64 KB. Die 10 Spiele, Bone Busters mit 96 KB und die 9 MA-766-Spiele passen
zusammen. Der EPCS4 der jetzigen Core-Boards reicht nur für etwa 4 Spiele.

## Geprüfte Alternativen

| Weg | Bewertung |
|---|---|
| **Externes SRAM** (umgesetzt), AS6C1008-55: 128 K × 8, 55 ns, 28 Pins, auf Gosof80B als U1 im DIL32-Sockel | Einfach und deterministisch. Im 500-ns-Buszyklus hat jede CPU einen festen Zeitschlitz (`rtl/hw5x_80b/sram_arbiter.vhd`). |
| **QMTECH-Board EP4CE15** (liegt in `N:\Projekte\FPGA`, hat SDRAM) | Keine Zusatzbauteile, aber BGA-Board, SDRAM-Controller und Refresh nötig. Feste Zeitschlitze wären möglich (Y, D, Refresh), aber das ist mehr Entwurf und mehr Risiko als beim SRAM. Flash-Typ des Boards noch nicht geprüft. |
| ROM direkt aus dem Flash lesen (ohne Kopie) | **Nein.** Ein Zufallszugriff braucht 40 SPI-Takte, beim EPCS mit 20 MHz also 2 µs, bei 500 ns Buszyklus und zwei CPUs. Ein Cache würde das Timing unvorhersehbar machen, die DAC-Samples hängen aber direkt daran. |
| ROMs packen, 9. Bit der M9K mitnutzen | **Nein.** Ein E22 käme so gerade auf 74 KB, Gen 3 und Bone Busters blieben draußen, der Aufwand ist hoch. |

Der Speicher könnte statt aus dem Flash auch von SD-Karte kommen: `rtl/hw4x/sd_reader_hw4x.vhd` kann bereits 64 KB je
Spiel mit CRC. Der EPCS16 ist aber einfacher, weil die Platine dann keine Karte braucht.

## Unterschiede zum MA-766

Gegen den Schaltplan und PinMAME geprüft, im ROM-Scan bestätigt:

| Punkt | MA-766 | MA-886 |
|---|---|---|
| CPU | R6502-13, 1 MHz | 6502A, 2 MHz (JP5 2 MHz / JP6 1 MHz) |
| ROM je CPU | 8 KB + 8 KB, `$C000`/`$E000` | 32 KB, `$8000`–`$FFFF` (27256, JP1–JP4) |
| RAM | 2 KB je CPU | **unverändert 2 KB je CPU** (6116 H2, H3) |
| Y-Eingänge | `$6000` | keine (nur Victory liest `$4000`) |
| Sound-Latch lesen | Y `$A800`, D `$8000` | Y `$6800`, D `$4000` |
| NMI der D-CPU | `$B000` | `$7000` |
| NMI-Rate | `$A000` | `$6000` (gleiche Zähler N5/T5, H5/K5, S5) |
| DAC | D `$4000`/`$4001` | D `$8000`/`$8001` (AD7528 wie gehabt) |
| Steuerregister | `$4000` (LS374 G3) | `$A000` (LS377 G3) |
| Klangerzeuger | 2 × AY + SP0250 | Gen 2: 2 × AY (AY-Latch `$8000`) + Filter MF-4 (`$2000`). Gen 3: YM2151 auf `$4000`, A0 aus `$A000` Bit 7 |
| Ausgang | DAC direkt in den Summierer | DAC über JP9 durch ein aktives Tiefpassfilter (A5), Eckfrequenz grob 1,5–3 kHz |

Die Spalte „bigger ram needed?“ in `GOSOF80B_games.xlsx` lässt sich damit beantworten: **Die CPUs brauchen nicht mehr RAM, das
FPGA braucht mehr ROM-Speicher.**

**Der Sound-Eingang bleibt gleich:** gleiche Trigger-, Latch- und IRQ-Schaltung (A2, A3, A4). JP7/JP8 entsprechen SW4/SW3 des MA-766. Die Platine
hat 8 Eingänge, PinMAME treibt für 80B aber nur S1–S16. Die 5 Leitungen der GOSOF-Platine sollten also reichen.

**Stecker:** A6P1 und A6P2 des MA-886 stimmen laut Plan Pin für Pin mit K3/K5 der Platine Gosof80B überein (S1..S128, Reset, Audio, analoge Masse). Nur A5P1 ist nicht abgeglichen.

## Zusatzplatine A20 (MA-1033): YM2151 am Sockel S4

| S4 | Signal | YM2151 / Bedeutung für das FPGA |
|---|---|---|
| 1–8 | D7..D0 | Datenbus der Y-CPU |
| 9 | S1-2, 4 MHz | SCLK. Mit dem 50-MHz-Takt als Enable erzeugen, 4 MHz = 50 / 12,5 |
| 14 | T4-13, `$4000` | /WR und /CS gemeinsam |
| 15 | G3-19 | A0 = `$A000` Bit 7 |
| 16 | T3-40 | /RES = Reset der Y-CPU |
| 17 | Ton | über C9 (1 µF) und R58 (10 kΩ) in den Summierer, gleiches Gewicht wie der DAC (R16) |

Was daraus folgt:

- **Der Ton ist mono, und zwar nur der rechte Kanal.** Am YM3014 hängt nur `SH2`. PinMAME gibt dagegen beide Kanäle als Stereo aus
  (`YM3012_VOL(75, LEFT, 75, RIGHT)`). Im FPGA also nur den rechten Ausgang von jt51 nehmen, nicht die Summe. Ob das hörbar anders ist, hängt davon ab,
  wie die Spiele die Kanäle in Register `$20`–`$27` schalten; das ist noch nicht geprüft.
- **/RD liegt fest auf High** (R6), IRQ und CT1/CT2 sind nicht angeschlossen. Die Software kann den YM2151 also nicht lesen und nicht auf „Busy“ warten, sie schreibt
  nur. Das vereinfacht die Anbindung: `dout`, `irq_n`, `ct1`, `ct2` von jt51 bleiben offen.
- **Analogteil:** Puffer, Hochpass C8/R3, Verstärkung −10 (R2/R3) mit Tiefpass 18,5 kHz (C7/R2). Für den Klang im Hörbereich praktisch neutral, muss nicht nachgebildet werden. Das Gewicht
  gegenüber dem DAC bleibt beim Hörtest einzustellen; PinMAME setzt YM2151 75 zu DAC 50.
- **Kein zusätzlicher Speicher**, die Tabelle oben bleibt gültig.

### MA-1294: dieselbe Schaltung, anderer Analogteil

`MA-1294.jpg` trägt dieselbe Zeichnungsnummer E-26145 (Platine 25690-1, © 1989, Kabel 26778). **Digitalteil und S4-Belegung sind identisch** (alle S4-Signale, YM2151, YM3014 nur an `SH2`, /RD fest High). Im FPGA
ist die Anbindung also dieselbe, das gilt auch für den rechten Kanal.

| Bauteil | A20 (MA-1033) | MA-1294 | Wirkung |
|---|---|---|---|
| U3 | LM324 | MC3403P | anderer Op-Amp |
| R2 / R3 | 22 kΩ / 2,2 kΩ | 10 kΩ (1 %) / 1 kΩ | Verstärkung gleich, −10 |
| C7 | 390 pF | 1500 pF | Tiefpass **18,5 → 10,6 kHz** |
| C8 + R3 | 1 µF + 2,2 kΩ | 4,7 µF + 1 kΩ | Hochpass 72 → 34 Hz |
| C9 | 1 µF | 4,7 µF | mit R58 Hochpass 16 → 3,4 Hz |
| R4 | 12 kΩ | 1,8 kΩ | Offset-Abgleich, kein Klangeinfluss |
| R5 | 10 kΩ nach −12 V | entfällt | vermutlich Vorstrom gegen die Übernahmeverzerrung des LM324 |
| C12 | – | 1000 pF nach −12 V | kein Einfluss im Hörbereich |
| C10 | 3300 pF am Ausgang | optional | |
| C11 | – | 3300 pF am YM3014-Ausgang | Tiefpass mit dem Ausgangswiderstand des YM3014, Grenzfrequenz unbekannt |
| C2, C3 | 10 µF | 0,1 µF | Abblockung |

Für den Klang bleibt ein etwas stärkerer Höhenabfall und mehr Bass als bei der A20. Beides lässt sich bei Bedarf als Filter im Mischer nachbilden, der Datenweg ändert sich nicht.

## Gen 2 gegen Gen 3 (Pläne aus dem Diamond-Lady-Handbuch)

`MA-886-Gen2-Part1..3.jpg`, Baugruppe MA-886, Zeichnung E-25549. **Es ist dieselbe Grundplatine.** Prozessorteil, ROM, RAM, S1, A2/A3/A4, T4/S2, NMI-Zähler, AD7528 und das DAC-Filter
A5 sind gleich, S4 bleibt als „optional circuitry“ drauf. Gen 3 lässt den Klangteil weg und steckt dafür die Zusatzplatine auf S4.

**Nur auf Gen 2 bestückt:**

| Bauteil | Funktion |
|---|---|
| H4, K4 AY-3-8913 | 2 MHz (S1 QA), BDIR/BC1/Auswahl aus G3, wie beim MA-766 |
| N4 LS377 | AY-Latch `$8000` |
| E3 74HC592 | 8-Bit-Zähler mit Eingangsregister, zählt 4 MHz (S1-Eingang) |
| E4 LS74 | Nachladen des Zählers, Teiler /2 |
| Q1 2N4264 | Pegelwandler auf 12 V für den Filtertakt |
| E5 MF-4CN-50 | geschaltetes Tiefpassfilter 4. Ordnung, Eckfrequenz = Takt / 50 |
| H1 LM324 | Mischstufen der AYs |

**Nicht auf Gen 2:** SW1, 4-fach-DIP und LS244. Ein Eingangsregister gibt es auf diesem Plan nicht, und Diamond Lady, TX-Sector, Robo-War und Excalibur lesen `$4000` auch nicht. Victory liest es einmal; dort beim
Bau auf 1 gelegte Bits liefern, wie eine offene Leitung.

### Das Filter ist kein Detail

Die ROMs schreiben `$2000` in **allen 5 Gen-2-Spielen in derselben Routine**, mit einem laufenden Wert (`LDA $2F / CLC / ADC $37 / STA $2F / STA $2000`). Das Filter wird also im laufenden Sound verstellt. PinMAME behandelt
`$2000` als „NOP“ und bildet das nicht nach, **das Original klingt hier also anders als PinMAME**, PinMAME eignet sich dafür nicht als Referenz.

- **Eckfrequenz** (aus dem Plan hergeleitet, ±1 im Zähler ungeprüft): fc ≈ 4 MHz / (256 − N) / 2 / 50 = **40 kHz / (256 − N)**, also von 157 Hz (N = 0) bis 10 kHz (N = 252) und höher.
- **Adresse:** T4 Y1 führt nach `$2000`; den Draht zu E3-RCK kann ich im Scan nicht ganz verfolgen. Dafür spricht, dass `$2000` sonst auf nichts wirkt und E3 ein Register braucht.
- **Signalweg:** Sicher zu lesen ist K4 → H1 → C7 → R37/H1 → C29 → MF-4. H4 geht ungefiltert über R14 in den Summierer. Wahrscheinlich läuft K4 zusätzlich ungefiltert über R13, und der Filterausgang kommt über B1 und R15 (18 kΩ); so nennt es auch PinWiki. Das ist aus dem Scan nicht sicher, siehe Offene Punkte.
- **Im FPGA:** `rtl/hw5x_80b/mf4_filter.vhd`, Butterworth 4. Ordnung aus zwei Chamberlin-SVF auf dem K4-Signal, fs = 50 MHz / 128, Koeffizienten nach N aus `mf4_table_pkg.vhd` (erzeugt von `scripts/gen_mf4_table.ps1`). Der Anteil des Filterausgangs im Mix (5/8) ist aus R13/R15 und der Verstärkung von H1 geschätzt.
- **Prüfung:** `sim/gosof886/run_mf4.ps1` gegen die ideale Kurve, PASS. An der Eckfrequenz bis 0,01 dB genau, bis 10 kHz unter 0,6 dB. Über 15 kHz weicht ein SVF prinzipbedingt ab: 20 kHz bei N = 252 liegt 1,5 dB über dem Soll, dort bei ca. −24 dB.

**Die Gen-2-Fassung ist damit: MA-766-Kern mit neuer Memory Map, ohne SP0250, mit MF-4.** Das ist weiterhin der kleinste Schritt, der Aufwand liegt nur im Filter.

## Spiele

| Gen | Spiele | ROM | Klang |
|---|---|---|---|
| 2 | Victory, Diamond Lady, TX-Sector, Robo-War, Excalibur | 2 × 32 KB | 2 × AY |
| 3 | Bad Girls, Big House, Hot Shots, Night Moves | 2 × 32 KB | YM2151 (jt51) |
| 3a | Bone Busters | 3 × 32 KB | YM2151, 3. CPU mit 2. DAC; **auf dem E6 nicht unterstützt** |

Lokal fehlt nur der Originalsatz `excaliba.zip`, vorhanden ist `excalibr.zip`. `nmoves` nennt seine ROMs anders (`nmovyrom.256`, `nmovdrom.256`), sonst
wie die anderen.

## Offene Punkte und Risiken

1. **Bone Busters:** Entfällt auf dem E6. Die Zusatzplatine MA-1294 ist geklärt (siehe oben), **die 3. CPU mit dem 2. DAC aber nicht**: Sie sitzt nicht auf der Zusatzplatine,
   dafür fehlt der Plan der Grundplatine MA-886-719A.
2. **MF-4-Pegel:** Der Scan des Gen-2-Plans ist zu grob, um den Audioweg hinter dem Filter sicher zu lesen (siehe Gen-2-Abschnitt). Das Verhältnis gefiltert zu ungefiltert entscheidet der Hörtest, einen Vergleich mit PinMAME gibt es dafür nicht.
3. **YM2151-Treue:** jt51 ist praxiserprobt, auf der GOSOF aber nicht getestet. Die Simulation ersetzt ihn durch einen stummen Stub, sein Klang ist also **gar nicht simuliert**. Das muss der Hörtest zeigen.
4. **Tiefpass am DAC (Gen 3):** Umgesetzt als drei einfache Pole im Mischer, die Eckfrequenz ist nur grob aus dem Schaltplan abgeschätzt. Das Gewicht YM 75 : DAC 50 stammt aus PinMAME.
5. **Pins:** `pins.tcl` stammt aus `Gosof80B_01.NET`. `Gosof80B_Final.T3001` ist binär, eine Netzliste dazu fehlt. Vor dem ersten Einschalten aus Target exportieren und vergleichen.
6. **Das Test-EPROM** `ma886_testeprom.zip` meldet wie beim MA-766 über LEDs an A8 und taugt nicht für das FPGA.
7. **GOSOF80B-Hardwaretest zuerst:** Das MA-766 ist noch nicht auf Hardware getestet. Die meiste Logik ist dieselbe, also zuerst dort testen.

## Umsetzung (02.11.2026)

Eigener Kern `top/GOSOF80B_886.vhd` (Generic `GEN` 2 oder 3 aus `variant_pkg.vhd`), Hülle `top/board_886_dev_open.vhd`, damit `80B_dev_open` unverändert bleibt. Das Flash-Layout je Spiel ist `yrom` ab +0 und `drom` ab +0x8000, im SRAM wählt A15 zwischen Y und D. Die ROMs baut `scripts/make_flash_hex_886.ps1 -Gen 2|3`, die `gosof80_roms.jic` wird nicht committet.

**Simulation** (`sim/gosof886/run_sim.ps1`, GHDL, echte ROMs, SRAM-Modell mit 55 ns, Prüfung des Schreibpulses): alle 9 Spiele PASS, je 1,54 s simulierte Zeit und 30 Sound-Kommandos.

| Spiel | Falsche Kommandos | ROM-Fehler | Y-IRQ / D-IRQ | D-NMI | AY-Schreibzugriffe | YM-Schreibzugriffe | DAC-Schreibzugriffe | MF-4-Schreibzugriffe |
|---|---|---|---|---|---|---|---|---|
| Victory | 0 | 0 | 30 / 30 | 131 | 5.486 | – | 15.462 | 166 |
| Diamond Lady | 0 | 0 | 30 / 30 | 239 | 2.182 | – | 17.204 | 99 |
| TX-Sector | 0 | 0 | 30 / 30 | 198 | 6.230 | – | 13.557 | 228 |
| Robo-War | 0 | 0 | 30 / 30 | 151 | 4.258 | – | 13.904 | 167 |
| Excalibur | 0 | 0 | 30 / 30 | 114 | 1.980 | – | 14.961 | 186 |
| Bad Girls | 0 | 0 | 30 / 30 | 43 | – | 8.598 | 9.704 | – |
| Big House | 0 | 0 | 30 / 30 | 3 | – | 10.420 | 14.084 | – |
| Hot Shots | 0 | 0 | 30 / 30 | **0** | – | 8.744 | 7.284 | – |
| Night Moves | 0 | 0 | 30 / 30 | 4 | – | 5.076 | 11.978 | – |

Der Y-NMI lief in allen Spielen ohne falsche Periode. Bei Hot Shots hat der Testlauf den D-NMI nicht ausgelöst, dort ist er also unbelegt. Die Schaltung ist dieselbe wie bei den übrigen acht Spielen.

**Noch nicht geprüft:** Hardware, Platinenhülle (die Simulation deckt nur den Kern ab), Klang.

## Nächste Schritte

1. GOSOF80B (MA-766) auf der vorhandenen Hardware testen.
2. Netzliste der Final-Fassung gegen `pins.tcl` vergleichen.
3. Je ein Spiel Gen 2 und Gen 3 auf der Platine, dann Hörtest: MF-4-Pegel, jt51 gegen das Original, DAC-Tiefpass.
