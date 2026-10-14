# Votrax SC-01 im FPGA – Implementierung (ab x.98)

Stand 14.10.2026. Vorgeschichte und Machbarkeit: `Votrax_SC01_Evaluierung.md`.

## Was es ist

`rtl/common/votrax/votrax_sc01.vhd` bildet die SC-01-Emulation von PinMAME nach
(`src/sound/votrax.c`, Kern von Olivier Galibert, Stand PinMAME-Commit `0e489b2` vom 04.09.2026,
lokale Kopie in `sim/votrax/pinmame/`). Das Modul erzeugt die Sprache selbst, statt sie als MP3
abzuspielen.

- **Varianten:** `hw2x_cyclone_IV_v3`, `hw2x_cyclone_IV_v4`, `hw2x_cyclone_10` (`HAS_VOTRAX = true`
  in `variant_pkg.vhd`). **Nicht** `hw2x_cyclone_II`, dort bleibt alles wie in x.97 (Ausnahme: der
  10-Bit-Mischer, siehe unten).
- **Einschalten:** bei MA-216-Spielen **DIP 2 (SB_Opt 2) = ON**. DIP 2 OFF bedeutet MP3-Sprache wie
  bisher. Auf dem MA-216 ist DIP 2 die J1-Position und wird vom Spielprogramm nicht gelesen. Bei MA-55
  und MA-490 behält DIP 2 seine bisherige Bedeutung.
- Mit eingeschalteter Emulation sind die MP3-Sprache **und** die Attract-MP3 aus. Die Attract-Sprache
  erzeugt dann das Spielprogramm selbst (Sound-DIPs S3/S4 wie beim Original).

## Anbindung (top/GOSOF80.vhd)

| Adresse | Funktion | Quelle |
|---|---|---|
| $2000 | Phonem-Latch: P0–P5 = D0–D5 **invertiert** (`data ^ 0x3f`), Inflection = D7/D6 | gts80s.c `GTS80SS_vs_latch_w` |
| $3000 | SC-01-Takt: `f = max(5750·d − 4500, 1)` Hz, $7E = 720 kHz, $46 ≈ 398 kHz (TILT) | `GTS80SS_da2_latch_w` |
| $7000–$7FFF | Schreibzugriff schaltet die Sprache stumm, der nächste $2000-Zugriff wieder ein | `empty_w` |
| RIOT PB7, NMI | A/R, wie bisher `not sc01_AR` | unverändert |

**Mischer:** Sound-DAC (8 Bit) und Sprache werden zu 10 Bit addiert und gesättigt, `dac` läuft mit
`msbi_g => 9`. Ohne Sprache ist der 10-Bit-Wert genau `audio_dat & "00"`, das Ausgangsniveau ist also
dasselbe wie mit dem alten 8-Bit-DAC. Sprachpegel: PinMAMEs 1,0 entspricht 256, das ist halber Vollausschlag
des Sound-DACs. Ob das Verhältnis zum Original passt, zeigt erst der Hörtest.

## Aufbau des Moduls

```
clk_ctrl ──► NCO (32 Bit, 50 MHz) ──► tick = SC-01-Haupttakt
                                        │
   tick: Phase A  Bus-Ereignisse ($2000-Schreiben, Mute, Taktwechsel)
         Phase B  Timer (Übernahme 72 Ticks nach dem Schreiben, Phonemende)
         Phase C  alle 18 Ticks ein Abtastwert: sample_count++, chip_update bei ungerade
         Phase D  Start der Abtastberechnung
                                        │
   Sequenzer: 14 MAC-Operationen (analog_calc), 1 Multiplizierer 27×24 Bit,
              ~123 Takte je Abtastwert (verfügbar: ≥ 616 bei $FF, 1250 bei $7E)
                                        │
   audio (16 Bit, 1,0 = 8192) ──► Mischer ──► dac
```

**Zwei Befunde aus `votrax.c`, die das möglich machen:**
1. **Die Filter sind Biquads.** Die „Filter 3. Ordnung“ aus `build_standard_filter` haben in Zähler
   und Nenner den gemeinsamen Faktor (1 + z⁻¹), weil die bilineare Transformation eines H(s) 2. Ordnung
   ausmultipliziert wurde. Der Divisionsrest liegt bei 10⁻¹⁶. Statt 7 braucht jedes Filter also 5 Koeffizienten.
2. **Die Koeffizienten hängen nicht vom Takt ab.** k0, k1 ∝ 1/cclock, k2 ∝ 1/cclock², w0 ∝ cclock,
   zc ∝ sclock heben sich auf. Alle Koeffizienten stehen deshalb fertig im ROM, und die Abtastrate folgt
   dem NCO von selbst (TILT). Die einzige Ausnahme ist der Rauschformer: Seine Formeln sind dimensional
   inkonsistent, er wird in PinMAME aber nur einmal beim Start mit 720 kHz gebaut
   (`filters_commit(force=1)`) und ist damit faktisch konstant, hier ebenso.

**Formate:** Koeffizienten 27 Bit (24 Nachkommabits), Daten 24 Bit (18 Nachkommabits, Bereich ±32,
gemessene Spitzen ±5,5), Akkumulator 56 Bit, Rundung beim Zurückschreiben, Sättigung. b-Koeffizienten
liegen negiert im ROM, deshalb addiert der MAC nur. ROM-Layout: `ROM_F2` (4096 Wörter, 8 je
f2/f2q-Kombination: F2-Stimme a0..−b2, F2-Rauschen a0, a1, −b1) und `ROM_MISC` (F1, F3, F4,
Rauschformer, Tiefpass, Verstärkungstabellen). Erzeugt wird beides von `sim/votrax/tools/gen_votrax_tables.py`.

**Bus-Eingang:** `stb` und `mute_stb` laufen über zwei Synchronisierstufen. Ein Schreibzugriff zählt
erst, wenn der Strobe drei Takte stabil high war. Die Strobes sind im Top-Level kombinatorisch
(Adresse, R/W, `cpu_clk`), ein Glitch darf kein Phonem auslösen. Der echte Strobe dauert ~28 Takte.

**Bewusst nachgebildete PinMAME-Eigenheiten:**
- Ein Taktwechsel auf $3000 löst ein `filters_commit` aus (`votraxsc01_set_clock` → `filters_commit(0)`).
- Die Mute-Logik von gts80s.c.
- Die Datenleitungen sind invertiert, die Inflection-Bits nicht.

## Prüfung (`sim/votrax/run_sim.ps1`)

Kette: PinMAME-`votrax.c` (unverändert, mit Stubs für den MAME-Kern) → Festkommamodell in C
(`model/vmodel.c`, die Spezifikation des VHDL) → GHDL-Testbench. Alle drei sehen jede Bus-Aktion auf
demselben Haupttakt-Tick (`.writes`-Datei aus der Referenz).

| Test | Inhalt | double-Modell vs. PinMAME | Festkomma vs. PinMAME | VHDL vs. Festkomma |
|---|---|---|---|---|
| t1_allphones | alle 64 Phoneme | 65,3 dB | 62,2 dB | bitgleich (286.105 Werte) |
| t2_inflection | Vokale mit Inflection 0–3 | 89,9 dB | 69,8 dB | bitgleich (145.979 Werte) |
| t3_sentence | Satz zum Anhören | 64,9 dB | 61,1 dB | bitgleich (120.507 Werte) |
| t4_clock | TILT: Takt $A0 → $46 in Schritten von $0A | 70,4 dB | 62,4 dB | bitgleich (200.449 Werte) |
| t5_mute | Stummschalten mitten im Wort | 80,0 dB | 68,9 dB | bitgleich (57.844 Werte) |

(SNR unterhalb 8 kHz. Das double-Modell weicht nur durch die zeitvariante Umschaltung der
Filter von PinMAME ab: PinMAMEs Form 3. Ordnung trägt einen ungedämpften Pol bei z = −1, die Biquads nicht.)

NCO: 0x7E/0x46/0xA0/0xFF/0x01 ergeben auf den Tick genau 720.000 / 398.000 / 915.500 / 1.461.750 / 1.250 Hz.

Die WAV-Dateien der Referenz (`build/ref_t*.wav`) und des Festkommamodells (`build/fix_t*.f32`)
lassen sich anhören bzw. vergleichen.

## Ressourcen (Cyclone 10 LP, 10CL006)

| | x.97 | x.98 mit Votrax |
|---|---|---|
| Logikelemente | 2.313 (37 %) | 4.798 (76 %) |
| Register (Synthese) | 793 | 2.239 |
| Speicherbits | 33.792 | 153.600 (56 %) |
| 9-Bit-Multiplizierer | 0 | 14 von 30 |
| Setup-Slack clk_50 | 5,05 ns | 2,56 ns |

Cyclone IV v3/v4 liegen gleichauf (4.772 / 4.782 LE, Slack 2,3 ns).

## Offen

- **Hardwaretest:** Black Hole, Mars, Volcano (Sprache, TILT-Verlangsamung, Attract-Sprache mit S3/S4).
- **Lautstärke** Sprache gegen Ton.
- **Inflection:** Ob I1/I2 auf dem MA-216 wirklich an D6/D7 hängen, ist nicht gegen den Schaltplan geprüft
  (PinMAME nimmt es an).
- **Alte Attrappe `Votrax-SC01.vhd`** (für den MP3-Betrieb): Sie indiziert ihre Dauertabelle mit
  `signed(cpu_data)` und ohne die Invertierung. Die exakten Dauern liefert jetzt `VT_PHONE().duration`;
  die Attrappe ließe sich damit korrigieren, sie ist aber hardwaregetestet und bleibt deshalb vorerst unverändert.
