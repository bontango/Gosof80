# Votrax SC-01 im FPGA – Evaluierung

Stand 14.10.2026. Frage: Lässt sich der Votrax SC-01 auf Grundlage der PinMAME-Emulation
(`src/sound/votrax.c`, Kern von Olivier Galibert) als VHDL-Modul nachbilden, sodass GOSOF80
die Sprache selbst erzeugt statt sie als MP3 abzuspielen?

**Ergebnis: ja.** Auf Cyclone IV E / Cyclone 10 LP passt es mit Reserve. Auf Cyclone II
wird der Speicher knapp, dort geht es nur mit der Speichersparvariante (Abschnitt 4). Umgesetzt
wird erst nach dem Hardwaretest des gemeinsamen Sourcebaums.

## 1. Ist-Zustand

- `rtl/common/Votrax-SC01.vhd` ist nur eine Timing-Attrappe. Nach dem Strobe geht A/R für eine
  Phonemdauer aus einer Tabelle auf 0 (Datenblattwerte + 20 %). Klang erzeugt sie nicht.
- Die Sprache spielt der DFPlayer: `speech_ctrl` legt je Spiel fest, welche Soundnummern Sprache
  sind, `DFcmd_par1` wählt den Ordner. Jede Sprachausgabe muss also als MP3 vorliegen.
- **Zwei Auffälligkeiten an der Attrappe:**
  - `time_map(to_integer(signed(cpu_data)))` ergibt für Codes ≥ 32 negative Indizes
    (Bereich des Arrays ist 0..63).
  - PinMAME schreibt `data ^ 0x3f` in den Chip, die Datenleitungen sind auf dem Board also invertiert.
    Die Attrappe invertiert nicht, sucht die Dauer demnach vermutlich in der falschen Tabellenzeile.
    Gegen den MA-216-Schaltplan bzw. `votrax/BH trace SC-01.txt` prüfen.

## 2. Anbindung auf dem MA-216 (aus `votrax/gts80s_latest.c`)

| Adresse | Funktion | im Top-Level |
|---|---|---|
| $2000 | Phonem-Latch: P0–P5 = D0–D5 xor $3F, Inflection I1/I2 = D7..D6 | `SC01_cs` / `sc01_strobe` |
| $3000 | DAC für den Votrax-Takt: `f = max(5750·d − 4500, 1)` Hz; $7E ≈ 720 kHz (normal), $46 ≈ 398 kHz (TILT, langsam und tief) | `DAC_latch_speech`, dekodiert, aber ungenutzt (Warnung 10036) |
| $7000 | Schreibzugriff schaltet die Sprache stumm, der nächste $2000-Zugriff wieder ein | – |
| RIOT PB7, NMI | A/R (busy = PB7 high, NMI aktiv bei A/R = 1) | `not sc01_AR` |

Chiptyp in PinMAME: SC-01 (nicht SC-01-A), Grundtakt 720 kHz.

## 3. Was die C-Emulation tut

Steuerteil, alles ganzzahlig und direkt in VHDL übertragbar:
- `phone_commit`: 64×64-Bit-Phonem-ROM `sc01_bin` (512 Byte), Bit-Swizzle in die Parameter
  f1, va, f2, fc, f2q, f3, fa (je 4 Bit), cld, vd, closure, duration (7 Bit), pause.
- `chip_update` bei main/36 (20 kHz): Phonem-Tick-Zähler, 625-Hz- und 208-Hz-Takt für die
  Interpolation `r = r − r>>3 + t<<1`, Closure-Zähler, Pitch-Zähler (Vergleich mit
  `0xE0 ^ inflection<<5 ^ f1<<1`), 15-Bit-Rauschgenerator (LFSR).
- A/R: Übernahme 72 Haupttakte nach dem Strobe, Phonemende nach `16·(dur·4+1)·4·9+2` Haupttakten.

Analogteil (`analog_calc`, pro Abtastwert bei main/18 ≈ 40 kHz, in double):
Glottis-Tabelle (9 Werte) × va → F1 → F2 (Stimmanteil); Rauschen × fa → Rauschformer → × fc →
F2 (Rauschanteil); Summe → F3 → + Rauschen → F4 → × Closure → Tiefpass → ×1/2,4.
F1, F2v, F3, F4 sind IIR-Filter 3. Ordnung (4+3 Koeffizienten), Rauschformer 2. Ordnung,
F2n und der Tiefpass 1. Ordnung. Die Koeffizienten berechnet `filters_commit` aus Kapazitätswerten
(Switched-Capacitor-Modell) per Bilinear-Transformation mit `tan()`.

## 4. Kernbefund: Die Filterkoeffizienten hängen nicht vom Takt ab

In die Filterformeln gehen `cclock = main/36` und `sclock = main/18` ein:
k0, k1 ∝ 1/cclock, k2 ∝ 1/cclock², w0 ∝ cclock, zc ∝ sclock. Daraus folgt: m0 = zc·k0,
m1 = zc·k1, m2 = zc²·k2 sind **taktunabhängig**, ebenso alle a/b-Koeffizienten (auch beim
Tiefpass mit seinem Korrekturfaktor und bei der Phasenbegrenzung `wdMax`).

Folgen für das FPGA:
- Alle Koeffizienten werden **einmal offline** in double berechnet (Python-Skript, bildet die
  `build_*_filter`-Funktionen 1:1 nach) und als ROM abgelegt. Auf dem Chip braucht es kein
  Gleitkomma, kein `tan()` und keine Division.
- Wird die Abtastrate aus einem NCO bei main/18 abgeleitet, folgen Tonhöhe und Tempo dem
  $3000-Latch von selbst. Damit funktioniert der TILT-Effekt ohne Zusatzaufwand.

Tabellengröße: f1 16 Sätze, f3 16 Sätze, f2 32 (f2) × 16 (f2q) = 512 Sätze mit 7 (F2v) + 3 (F2n)
Koeffizienten, F4/Tiefpass/Rauschformer fest.
- **Variante A**, alle Koeffizienten fertig: 512 × 10 Wörter ≈ 140 kbit (bei ~27 Bit).
- **Variante B**, Speicher sparen: je Satz nur m0, m1, m2 und 1/b0 ablegen, die 7 Koeffizienten
  zur Laufzeit mit derselben MAC ausrechnen (a0 = (1+m0)/b0 usw.). Ergibt ≈ 512 × 7 Wörter ≈ 100 kbit,
  mit kürzeren Wörtern weniger.

## 5. Ressourcen je Chip

Rechenbedarf: ~45 Multiplikationen/Akkumulationen pro Abtastwert. Bei 40 kHz (max. ~80 kHz bei
$3000 = $FF) bleiben @50 MHz ≥ 600 Takte je Abtastwert, **eine** sequenzielle MAC reicht
(Koeffizient ~28 Bit × Zustand 32 Bit).

| Chip | LE frei | Speicher frei | Multiplizierer | Urteil |
|---|---|---|---|---|
| EP4CE6 / 10CL006 | ~3.950 von 6.272 | ~242 kbit (30 M9K, davon ~4 belegt) | 15 × 18×18 frei | passt, Variante A möglich |
| EP2C5 (Cyclone II) | ~2.340 von 4.608 | ~86 kbit (26 M4K, 119.808 Bit) | 13 × 18×18 frei | eng: nur Variante B mit kurzen Wörtern, oder ohne Votrax |

Geschätzter Bedarf des Moduls: 1.000–1.500 LE (Steuerung, Sequenzer, MAC, Zustände), 4 kbit Phonem-ROM,
dazu die Koeffizienten-ROMs.

## 6. Risiken

- **Festkomma:** Direktform 3. Ordnung mit Polen nahe 1 (F1 um 300 Hz bei 40 kHz Abtastrate)
  reagiert empfindlich auf Rundung. Die Wortbreite wird mit einem bitgenauen C-Modell gegen die
  double-Referenz festgelegt (Ziel > 40 dB SNR, kein Grenzzyklus).
- **Polarität/Inflection:** Ob die Inflection-Pins auf dem MA-216 beschaltet sind und ob die
  Datenleitungen invertiert sind, am Schaltplan prüfen. Beides wird im Modul per Generic umschaltbar.
- **Mischung:** Ton-DAC (8 Bit) und Sprache müssen gemeinsam auf den einen Delta-Sigma-Ausgang,
  dafür den DAC auf 10 Bit verbreitern und mit Sättigung addieren. Das Lautstärkeverhältnis klärt der Hörtest.
- **MP3-Pfad:** Mit eingeschalteter Emulation muss die MP3-Sprache aus sein (`speech_ctrl`, Attract),
  sonst kommt die Sprache doppelt.

## 7. Vorschlag für die Umsetzung (nach dem Hardwaretest des Baums)

1. `rtl/common/votrax/tools/gen_votrax_tables.py`: liest `sc01_bin` aus einer lokalen Kopie von
   `votrax.c` und erzeugt `votrax_tables_pkg.vhd` (Phonem-ROM, Glottis, Koeffizienten) plus ein Header
   für das C-Modell.
2. `rtl/common/votrax/votrax_sc01.vhd`: Ports `clk`, `rst_n`, `stb`, `data(7:0)`, `clk_ctrl(7:0)`,
   `mute`, `ar`, `audio(15:0)`. NCO für main/18 und main/36 als Clock-Enable (kein neuer Taktbereich),
   Steuer-FSM, `chip_update`-Prozess, Mikrosequenzer mit einer MAC.
3. Prüfung: PinMAME-`votrax.c` mit Minimal-Stubs als Kommandozeilenprogramm (gcc), daneben ein bitgenaues
   Festkommamodell. GHDL-Testbench (portabel installieren) muss bitgleich zum Festkommamodell sein.
   Testsätze: Phonemfolge aus `votrax/BH trace SC-01.txt`, normal ($7E) und TILT ($46).
4. Einbau ins Top-Level, zuschaltbar über einen freien DIP (`option(1)`). Ist er aus, bleibt alles beim
   MP3-Verhalten. Mit eingeschalteter Emulation: $3000-Latch, Mute auf $7000, Mischer, MP3-Sprache aus.
   Für Cyclone II per Generic abschaltbar, falls es nicht passt.
5. Hörtest an Black Hole, Mars, Volcano (Sprache, TILT, Attract), danach `VARIANTEN.md` nachziehen.

Quellen: PinMAME `src/sound/votrax.c` (BSD-3-Clause), `votrax/gts80s_latest.c`,
`votrax/Votrax_SC-01_Phoneme_Speech_Synthesizer_Data_Sheet_1980.pdf`, Galiberts Die-Analyse (`votrax/votrax-schem.*`).
