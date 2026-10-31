-- variant_pkg.vhd - what this board is, as VHDL constants.
-- Variant: hw5x_80b_cyclone_IV
--
-- First entry in the generated .qsf (scripts/files_80b_common.tcl). The top level and the
-- flash loader read these constants.
library ieee;
use ieee.std_logic_1164.all;

package variant_pkg is
	-- Where game 0 starts in the configuration flash (EPCS4, 512 KB); game n at
	-- FLASH_BASE + n * 6000h. Behind the compressed bitstream, see rtl/hw5x/Flash_ROM.vhd.
	constant FLASH_BASE : integer := 16#040000#;
end package variant_pkg;