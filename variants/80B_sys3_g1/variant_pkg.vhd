-- variant_pkg.vhd - what this board is, as VHDL constants.
-- Variant: 80B_sys3_g1
--
-- First entry in the generated .qsf. The board shell and the flash loader read these constants.
library ieee;
use ieee.std_logic_1164.all;

package variant_pkg is
	-- Where game 0 starts in the configuration flash (EPCS16, 2 MB); game n at
	-- FLASH_BASE + n * 10000h. Behind the uncompressed bitstream (368 KB). 24 slots fit.
	constant FLASH_BASE : integer := 16#080000#;
	-- Generation of the MA-886: YM2151 (jt51) on the MA-1294
	constant MA886_GEN : natural := 3;
	-- System 3: the MPU sends 8 bit sound commands, S32..S128 are read and trigger
	constant MA886_SYS3 : boolean := true;
end package variant_pkg;
