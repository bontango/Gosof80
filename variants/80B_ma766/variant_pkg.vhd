-- variant_pkg.vhd - what this board is, as VHDL constants.
-- Variant: 80B_ma766
--
-- First entry in the generated .qsf (scripts/files_80b_common.tcl). The top level and the
-- flash loader read these constants.
library ieee;
use ieee.std_logic_1164.all;

package variant_pkg is
	-- Where game 0 starts in the configuration flash (EPCS16, 2 MB); game n at
	-- FLASH_BASE + n * 6000h. Behind the uncompressed bitstream (368 KB). All 64 game numbers
	-- fit, the last slot ends exactly at 200000h. See rtl/hw5x/Flash_ROM.vhd.
	constant FLASH_BASE : integer := 16#080000#;
end package variant_pkg;
