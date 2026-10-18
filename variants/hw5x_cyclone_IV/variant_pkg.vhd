-- variant_pkg.vhd - what this board is, as VHDL constants.
-- Variant: hw5x_cyclone_IV
--
-- First entry in the generated .qsf (scripts/files_common.tcl). Everything else in
-- the design is shared; the top level reads these constants.
library ieee;
use ieee.std_logic_1164.all;

package variant_pkg is
	-- Votrax SC-01 emulation available (MA-216 games with option DIP 2 OFF; version announcement with DIP 3 OFF).
	constant HAS_VOTRAX : boolean := true;
	-- HW 4.x / 5.x board: sound test (Gosof_Test).
	constant IS_HW4 : boolean := true;
	-- Where game 0 starts in the configuration flash (EPCS4, 512 KB); game n at
	-- FLASH_BASE + n * 1000h. Behind the compressed bitstream, see rtl/hw5x/Flash_ROM.vhd.
	constant FLASH_BASE : integer := 16#040000#;
end package variant_pkg;