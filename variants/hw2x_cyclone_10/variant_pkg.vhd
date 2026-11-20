-- variant_pkg.vhd - what this board is, as VHDL constants.
-- Variant: hw2x_cyclone_10
--
-- First entry in the generated .qsf (scripts/files_common.tcl). Everything else in
-- the design is shared; the top level reads these constants.
library ieee;
use ieee.std_logic_1164.all;

package variant_pkg is
	-- Votrax SC-01 emulation available (MA-216 games with option DIP 2 OFF; version announcement with DIP 3 OFF).
	constant HAS_VOTRAX : boolean := true;
	-- HW 4.x board: sound test (Gosof_Test).
	constant IS_HW4 : boolean := false;
	-- Votrax speech level in the mixer, in 1/8: 8 = speech 1.0 -> 512 (DAC full scale), 12 = 768.
	constant VTX_SPEECH_GAIN : natural := 12;
	-- Votrax speech bass shelf: low pass corner 2^SHIFT samples at 40 kHz (5 = 199 Hz, 6 = 99 Hz),
	-- added BOOST times (0 = off, 1 = +6 dB, 2 = +9.5 dB).
	constant VTX_BASS_SHIFT : natural := 6;
	constant VTX_BASS_BOOST : natural := 1;
end package variant_pkg;
