-- variant_pkg.vhd - what this board is, as VHDL constants.
-- Variant: hw2x_cyclone_II
--
-- First entry in the generated .qsf (scripts/files_common.tcl). Everything else in
-- the design is shared; the top level reads these constants.
library ieee;
use ieee.std_logic_1164.all;

package variant_pkg is
	-- No Votrax on Cyclone II: the EP2C5 lacks the memory for the coefficient ROMs (decided 10.2026).
	constant HAS_VOTRAX : boolean := false;
end package variant_pkg;
