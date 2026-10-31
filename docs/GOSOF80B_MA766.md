# GOSOF80B: Gottlieb System 80B Soundboard MA-766 (Generation 1)

FPGA-Fassung auf der Platine GOSOF 5.00 (EP4CE6-Core-Board, ROMs aus dem EPCS4), Variante
`hw5x_80b_cyclone_IV`, Board-ID 8. Quellen: Schaltplan `..\Gosof80B\schematics\MA-766-schematic.jpg`
(E-24711), PinMAME `src\wpc\gts80s.c` und `src\sound\sp0250.c`, ROM-Analyse und Simulation.

**Stand 31.10.2026: gebaut und simuliert, nicht auf Hardware getestet und noch nicht abgehört.**

## Aufbau (`top/GOSOF80B.vhd`)

Eigener Kern `gosof80b_core`, Platinenhülle `top/board_hw5x_80b.vhd`. Gemeinsam mit GOSOF80 sind T65, `dac`, `soundtest`
und der Flash-Lader.

| Teil | Original | Hier |
|---|---|---|
| Takte | 4 MHz über 74161 S1 | `clk_50` / 50 = CPU 1 MHz (Register, keine PLL), 2-MHz-Enable für die AY, NMI-Zähler im CPU-Takt |
| CPUs | 2 × 6502 (R6502-13) | 2 × T65 |
| Y-Sektion | 8 + 8 KB ROM, 2 KB RAM, 2 × AY-3-8913, SP0250 | `rom`, `ram`, 2 × `ym2149_audio`, `sp0250` (`rtl/hw5x_80b/`) |
| D-Sektion | 8 KB ROM, 2 KB RAM, AD7528 | `rom`, `ram`, Multiplikation Lautstärke × Daten |

### Memory Map

| Y-CPU | | D-CPU | |
|---|---|---|---|
| `$0000` | RAM 2 KB | `$0000` | RAM 2 KB |
| `$2000` | SP0250-Latch (schreiben) | `$4000` | DAC-Lautstärke (A0 = 0) |
| `$4000` | Steuerregister G3 (schreiben) | `$4001` | DAC-Daten (A0 = 1) |
| `$6000` | Eingänge (lesen) | `$8000` | Sound-Latch lesen, löscht den IRQ |
| `$8000` | AY-Latch (schreiben) | `$C000`/`$E000` | drom |
| `$A000` | NMI-Rate (schreiben) | | |
| `$A800` | Sound-Latch lesen, löscht den IRQ | | |
| `$B000` | lesen oder schreiben: NMI der D-CPU | | |
| `$C000` | yrom2 | | |
| `$E000` | yrom1 (Vektoren) | | |

Dekodiert wie auf der Platine über Adressbereiche (T4 A15..A13, S2 A12/A11), also mit Spiegelungen.

**`$4000`:** Bit 0 NMI-Freigabe, Bit 1 LED (aktiv-low), Bit 2 BDIR, Bit 3 AY-Auswahl, Bit 4 BC1, Bit 5 SP0250 DIRECT DATA TEST, Bit 6 SP0250 DATA PRESENT, Bit 7 SP0250 RESET.

**`$6000`:** D7 SP0250 DATA REQUEST, D6 Testschalter, D5/D4 DIP 1/2, D3..D0 nur Pull-ups.

## Bedienung

| Element | Funktion |
|---|---|
| S2 (6-pol.) | Spiel: binär, ON = 1 |
| S1 DIP 1, 2 | DIP-Positionen 1, 2 des Originals (`$6000` D5, D4). Original: aus |
| S1 DIP 3 | ON: S16 löst auch einen Sound aus (SW3 des Originals). Original: aus |
| S1 DIP 4–8, S3 | ohne Funktion |
| `Gottlieb_Test` | SW1 des Originals |
| `Gosof_Test` | Soundtest: spielt 1..31, je 5 s. Sound 16 bleibt stumm, solange S16 nicht auslöst |
| D1 | Soundleitung aktiv, blinkt bei leerem Flash-Slot |
| D2 | LED des Originals, von der Y-CPU gesteuert |

| S2 binär | Spiel | S2 binär | Spiel |
|---|---|---|---|
| 0 | Rock | 5 | Gold Wings |
| 1 | Raven | 6 | Monte Carlo |
| 2 | Rock Encore | 7 | Spring Break |
| 3 | Hollywood Heat | 8 | Arena |
| 4 | Genesis | | |

## ROMs ins Flash

24 KB je Spiel ab `FLASH_BASE` = 0x40000: `+0000` yrom1, `+2000` yrom2 (FF, wenn das Spiel keins hat), `+4000` drom. Es passen 10 Slots, 9 sind belegt.

```powershell
scripts\build.ps1 hw5x_80b_cyclone_IV        # output_files\GOSOF80.jic, ohne ROMs
scripts\make_flash_hex_80b.ps1               # liest ..\Gosof80B\roms\*.zip
cd variants\hw5x_80b_cyclone_IV ; quartus_cpf -c gosof80_roms.cof   # output_files\gosof80_roms.jic
```

Die Release-`.jic` bleibt ROM-frei, `gosof80_roms.jic` wird nicht committet.

## Befunde

**Prototyp `HW 3.x GOSOF80B - Multi SD` korrigiert:** yrom1 liegt auf `$E000`, nicht `$C000` (bei 3-ROM-Spielen stehen die Vektoren am
Ende von yrom1 und zeigen in yrom2). CPU-Takt 1 MHz, nicht 2 MHz.

**Das SP0250 wird benutzt.** PinMAME schreibt „none features speech from it“, das heißt aber nicht „kein Klang“: Alle 9 Spiele senden im Betrieb LPC-Frames mit Pegel
(25–65 Frames in den 1,2 s der Simulation). Der erste Plan, den Chip wegzulassen, war falsch.
`sp0250.vhd` ist eine Portierung des PinMAME-Modells, Vergleich Sample für Sample: `sim\gosof80b\run_sp0250.ps1` (5.998 Samples, 0 Abweichungen).

**NMI-Rate abweichend von PinMAME:** N5 und T5 sind kaskadiert und laden gemeinsam, also Periode = (256 − Rate) × 1024 µs. PinMAME rechnet (16 − lo) × (16 − hi). Bei den Raten der Spiele
(246 Rock, 248, 242) ergibt das 10 bzw. 8 bzw. 14 Ticks, in beiden Formeln gleich.

**S16 löst nichts aus:** SW3 aus, SW4 an (PinWiki: DIP 1–3 aus, 4 an) trennt S16 vom Trigger A2. Passt zu PinMAME.

**NMI vier Takte low:** Die T65 kann eine kürzere Flanke während eines genommenen Branches verlieren, die Idle-Schleifen sind Branches.

**Marcos Test-EPROM** (`roms\Marco\edgeconn_soundtest.zip`) ist nicht im Flash. Es meldet über LEDs an Adressleitung 8 der CPUs, die es hier nicht gibt, und macht keinen Ton.

## Prüfung

| Prüfung | Ergebnis |
|---|---|
| `sim\gosof80b\run_sim.ps1` (GHDL, echte ROMs, 9 Spiele, je 1,22 s) | PASS: beide CPUs lesen alle 30 Kommandos, Kommando 16 löst nichts aus, NMI-Periode stimmt, AY, DAC, SP0250 aktiv. WAV je Spiel in `sim\gosof80b\build\run_<n>\audio.wav` (Dauer je Spiel ca. 25 min) |
| `sim\gosof80b\run_sp0250.ps1` | PASS gegen den C-Code |
| `sim\flash\run_sim.ps1` | PASS mit 4 KB und 24 KB je Slot |
| Quartus | siehe `VARIANTEN.md` |

Die Simulation ersetzt den echten Lader durch `sim_models.vhd` und vergleicht nicht gegen PinMAME-Audio.

## Offen, nur auf Hardware oder per Gehör zu klären

1. **Noch nicht abgehört.** Mischung DAC 50 : SP0250 50 : AY 25 + 25 aus PinMAME. Auf der Platine liegen andere Widerstände (AY 3 kΩ, SP0250 1,2 kΩ, DAC 10 kΩ, jeweils auf 10 kΩ), das kann eine andere Balance ergeben. Beim Hörtest in `Audio_Mixer` nachstellen.
2. **Testschalter:** In der Simulation führte ein 200 ms langer Druck am Ende des Laufs zu keinem Ton. Laut Original gibt SW1 einen Blip. Möglicherweise wertet die Firmware ihn nur in bestimmten Zuständen aus, das ist nicht geklärt.
3. **Adapter nötig:** Die GOSOF 5.00 passt nicht in den MA-766-Steckplatz. Belegung:

| Signal | MA-766 A6P1 | GOSOF P2 |
|---|---|---|
| S0 (= S1) / S1 (= S2) | 5 / 3 | 8 / 9 |
| S2 (= S4) / S3 (= S8) | 2 / 1 | 11 / 12 |
| S4 (= S16) | 8 | 2 |
| +5 V | 15, 16 | 5 |
| GND | 11, 12 | 6 |
| +12 V | 14 | 1 |
| Audio | 18 | 7 |

4. **Audiopegel:** Das Original gibt an Pin 18 Line-Pegel an die Aux-Endstufe, die GOSOF den Ausgang ihrer TDA7267. Vor dem Anschluss an die Aux-Platine prüfen, sonst droht Übersteuerung.
5. **MPU-Reset** (A6P1-9) ist auf der GOSOF nicht angeschlossen, die Karte startet selbstständig.

**Hardwareprüfung:** Rock (2 ROMs) und ein 3-ROM-Spiel, zuerst `Gottlieb_Test` und D2 (blinkt?), dann `Gosof_Test` und zuletzt am Automaten.

MA-886 (Nachfolger): siehe `MA-886_Evaluierung.md`.
