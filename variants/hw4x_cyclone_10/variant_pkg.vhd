-- variant_pkg.vhd - what this board is, as VHDL constants.
-- Variant: hw4x_cyclone_10
--
-- First entry in the generated .qsf (scripts/files_common.tcl). Everything else in
-- the design is shared; the top level reads these constants.
library ieee;
use ieee.std_logic_1164.all;

package variant_pkg is
	-- Votrax SC-01 emulation available (MA-216 games with option DIP 2 OFF; version announcement with DIP 3 OFF).
	constant HAS_VOTRAX : boolean := true;
	-- HW 4.x board: sound test (Gosof_Test).
	constant IS_HW4 : boolean := true;
end package variant_pkg;
