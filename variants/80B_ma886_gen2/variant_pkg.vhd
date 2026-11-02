-- variant_pkg.vhd - what this board is, as VHDL constants.
-- Variant: 80B_ma886_gen2
--
-- First entry in the generated .qsf. The board shell and the flash loader read these constants.
library ieee;
use ieee.std_logic_1164.all;

package variant_pkg is
	-- Where game 0 starts in the configuration flash (EPCS16, 2 MB); game n at
	-- FLASH_BASE + n * 10000h. Behind the uncompressed bitstream (368 KB). 24 slots fit.
	constant FLASH_BASE : integer := 16#080000#;
	-- Generation of the MA-886: 2 x AY-3-8913, filter MF-4
	constant MA886_GEN : natural := 2;
end package variant_pkg;
