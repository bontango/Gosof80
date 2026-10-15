-- variant_pkg.vhd - what this board is, as VHDL constants.
-- Variant: hw2x_cyclone_IV_v4
--
-- First entry in the generated .qsf (scripts/files_common.tcl). Everything else in
-- the design is shared; the top level reads these constants.
library ieee;
use ieee.std_logic_1164.all;

package variant_pkg is
	-- Votrax SC-01 emulation available (MA-216 games with option DIP 2 OFF; version announcement with DIP 3 OFF).
	constant HAS_VOTRAX : boolean := true;
	-- HW 4.x board: sound test (Gosof_Test); no MA-55 background music (as v4.01).
	constant IS_HW4 : boolean := false;
end package variant_pkg;
