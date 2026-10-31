# MA-886 (System 80B, Generation 2 und 3): Evaluierung

Stand 31.10.2026. Keine Umsetzung, nur Machbarkeit und Empfehlung. Quellen: Schaltplan
`Gosof80B\schematics\MA-886-schematic.jpg` (E-26146, 20.9.88), PinMAME `gts80s.c`/`gts80games.c`,
die ROM-Sätze in `Gosof80B\roms`, Probesynthese von jt51 mit Quartus 22.1.

## Ergebnis

**Ein EPCS16 passt, ein E10 allein reicht aber nicht.** Das Problem ist der ROM-Speicher, nicht die Logik:
Die Spiele belegen 64 KB ROM (Bone Busters 96 KB), der E10 hat intern nur 46 KB.

**Empfehlung:** E10 + EPCS16 + **ein externes SRAM 128 K × 8** auf einer neuen Platine. Das FPGA lädt die ROMs beim
Start aus dem Flash ins SRAM, genau wie heute in die M9K. Der Kern von GOSOF80B lässt sich dafür weitgehend
weiterverwenden. Das MA-766 läuft auf derselben Platine mit.

## Warum der E10 nicht reicht

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

**LE (Abschätzung, Basis sind die Messwerte von GOSOF80B):**

| Fassung | comb ca. | E6 (6.272) | E10 (10.320) |
|---|---|---|---|
| Gen 2 (GOSOF80B ohne SP0250) | 3.300 | passt | passt |
| Gen 3 (ohne AY, mit jt51: gemessen 2.765 comb, 916 reg) | 5.300 | eng | passt |
| Bone Busters (+ T65, + DAC) | 6.200 | nein | passt |

Für Gen 3 ist der E10 also die richtige Wahl.

**Flash:** Der EP4CE10 hat denselben Rohbitstream wie der E6 (368 KB). Der EPCS16 fasst nach
`FLASH_BASE` = 0x80000 noch 1,5 MB: 24 Slots zu 64 KB. Die 10 Spiele, Bone Busters mit 96 KB und die 9 MA-766-Spiele passen
zusammen. Der EPCS4 der jetzigen Core-Boards reicht nur für etwa 4 Spiele.

## Geprüfte Alternativen

| Weg | Bewertung |
|---|---|
| **Externes SRAM** (empfohlen), z. B. AS6C1008-55: 128 K × 8, 55 ns, SOP32, 28 Pins | Einfach und deterministisch. Bei 500 ns Buszyklus reichen beide CPUs locker im Zeitschlitz (3 Takte bei 50 MHz je Zugriff). Bone Busters passt auch. |
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
- **Im FPGA:** vier Tiefpass-Stufen als digitale Biquads auf dem K4-Signal, Koeffizienten nach N aus einer Tabelle. Geschätzt 400–600 LE, 1 Multiplikator, 1 M9K. Am Bedarf an externem Speicher ändert das nichts.

**Die Gen-2-Fassung ist damit: MA-766-Kern mit neuer Memory Map, ohne SP0250, mit MF-4.** Das ist weiterhin der kleinste Schritt, der Aufwand liegt nur im Filter.

## Spiele

| Gen | Spiele | ROM | Klang |
|---|---|---|---|
| 2 | Victory, Diamond Lady, TX-Sector, Robo-War, Excalibur | 2 × 32 KB | 2 × AY |
| 3 | Bad Girls, Big House, Hot Shots, Night Moves | 2 × 32 KB | YM2151 (jt51) |
| 3a | Bone Busters | 3 × 32 KB | YM2151, 3. CPU mit 2. DAC |

Lokal fehlt nur der Originalsatz `excaliba.zip`, vorhanden ist `excalibr.zip`. `nmoves` nennt seine ROMs anders (`nmovyrom.256`, `nmovdrom.256`), sonst
wie die anderen.

## Offene Punkte und Risiken

1. **Bone Busters:** Die Zusatzplatine MA-1294 ist geklärt (siehe oben), **die 3. CPU mit dem 2. DAC aber nicht**: Sie sitzt nicht auf der Zusatzplatine,
   dafür fehlt der Plan der Grundplatine MA-886-719A.
2. **MF-4-Pegel:** Der Scan des Gen-2-Plans ist zu grob, um den Audioweg hinter dem Filter sicher zu lesen (siehe Gen-2-Abschnitt). Das Verhältnis gefiltert zu ungefiltert entscheidet der Hörtest, einen Vergleich mit PinMAME gibt es dafür nicht.
3. **YM2151-Treue:** jt51 ist praxiserprobt, auf der GOSOF aber nicht getestet. Die Spiele nutzen es für die Musik, das muss der Hörtest zeigen.
4. **Tiefpass am DAC:** Für den Originalklang gehört ein digitales Filter in den Mischer. Die Eckfrequenz habe ich nur grob aus dem Schaltplan abgeschätzt.
5. **Die M9K-Zahl von jt51 ist eine Schätzung** (5.599 bit aus gut 7 Speicherblöcken). Beim empfohlenen Weg spielt das keine Rolle.
6. **Das Test-EPROM** `ma886_testeprom.zip` meldet wie beim MA-766 über LEDs an A8 und taugt nicht für das FPGA.
7. **GOSOF80B-Hardwaretest zuerst:** Das MA-766 ist noch nicht auf Hardware getestet. Erst danach lohnt sich der MA-886-Aufbau, denn die meiste Logik wäre dieselbe.

## Vorgehen, wenn es umgesetzt wird

1. GOSOF80B (MA-766) auf der vorhandenen Hardware testen.
2. Platine festlegen und mit `pins`/Netzliste entwerfen: Core-Board E10 + EPCS16 + AS6C1008. Der Sockel des EP4CE6-Core-Boards bleibt nutzbar, wenn die Pinbelegung des E10-Boards passt.
3. Gen 2 zuerst, weil am wenigsten neu ist: Kern um Generation-Generic erweitern, SRAM-Zeitschlitz statt M9K-ROM, ROM-Packer für 64 KB, Simulation wie `sim/gosof80b` mit den echten ROMs. Das MF-4 als Letztes in diesem Schritt, die Spiele laufen auch ohne.
4. Dann Gen 3 mit jt51 und Tiefpass, zuletzt Bone Busters.
