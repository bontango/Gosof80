# Platine für MA-766 und MA-886: Vorgaben für die Hardware

Eine Platine mit EP4CE6 und SRAM deckt MA-766 und MA-886 ab, je Boardtyp mit eigenem Bitstream. Herleitung und Messwerte stehen in `MA-886_Evaluierung.md`.

**Stand 02.11.2026: Der E10 ist vom Tisch, geplant ist der E6. Gebaut und simuliert, nicht auf Hardware getestet. Die Netzliste der Final-Fassung ist noch nicht gegen die Pins geprüft.**

## Bitstreams

| Boardtyp | Variante | Spiele | SRAM nötig |
|---|---|---|---|
| MA-766 | `80B_ma766` | 9 | nein, U1 kann entfallen |
| MA-886 Gen 2 | `80B_ma886_gen2` | Victory, Diamond Lady, TX-Sector, Robo-War, Excalibur | ja |
| MA-886 Gen 3 | `80B_ma886_gen3` | Bad Girls, Big House, Hot Shots, Night Moves | ja |

Bone Busters wird nicht unterstützt, es passt nicht auf den E6.

## SRAM: 28 IOs

AS6C1008 (128 K × 8), U1 im DIL32-Sockel.

| Signal | IOs |
|---|---|
| A0–A16 | 17 |
| D0–D7 (bidirektional) | 8 |
| /CE1, /OE, /WE | 3 |
| **Summe** | **28** |

CE2 liegt fest auf VCC und kostet keinen IO. Das FPGA hält /CE1 dauerhaft auf Low und steuert über /OE und /WE.

**AS6C4008 statt AS6C1008:** Geht ohne Änderung am Design, die Spiele nutzen nur 128 KB. Pin 1 (A18) ist laut `Gosof80B_01.NET` offen und muss fest gelegt werden, z. B. über 10 kΩ oder eine Brücke im Sockel. Pin 30 (A17) auf +3,3 V ist unproblematisch. Die Belegung ist noch gegen das Datenblatt zu prüfen.

## Für die Netzliste

- **Spannung:** SRAM mit 3,3 V aus derselben Schiene wie die VCCIO der genutzten Bank versorgen, nicht mit 5 V. Die FPGA-IOs vertragen keine 5 V.
- **Pins:** Belegung in `variants/80B_ma886_gen2/pins.tcl`, Quelle `Gosof80B_01.NET`. Vor dem Aufbau mit einer aus `Gosof80B_Final.T3001` exportierten Netzliste vergleichen.

## Timing

Das SRAM hat feste Zeitschlitze im 500-ns-Buszyklus (25 Takte bei 50 MHz, Phasen 15, 19 und 23), je 4 Takte. In der Simulation liest das Modell mit 55 ns ohne Fehler. Im Betrieb schreibt nur der Lader beim Start ins SRAM.

## Keine zusätzlichen IOs

| Teil | Begründung |
|---|---|
| Integrierte A20 | YM2151 und YM3014 laufen im FPGA, der Mix geht über den vorhandenen Delta-Sigma-Ausgang |
| MF-4 (Gen 2) | digitales Filter im FPGA |
