-- variant_pkg.vhd - what this board is, as VHDL constants.
-- Variant: hw2x_cyclone_10
--
-- First entry in the generated .qsf (scripts/files_common.tcl). Everything else in
-- the design is shared; the top level reads these constants.
library ieee;
use ieee.std_logic_1164.all;

package variant_pkg is
	-- Votrax SC-01 emulation available (selected per game with DIP 2 on MA-216 boards).
	constant HAS_VOTRAX : boolean := true;
end package variant_pkg;
