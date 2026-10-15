-- Gosof_PLL for Cyclone II - NOT a PLL.
--
-- Same entity and ports as the ALTPLL megafunction Gosof_PLL in rtl\cyclone_10\ and
-- rtl\cyclone_IV\ (c0 = 50 MHz / 56 = 892.9 kHz, c1 = 50 MHz / 49 = 1020.4 kHz), so the
-- top level does not know the family. The Cyclone II PLL cannot go that low: its
-- post-scale counters end at 32, the lowest output is ~10 MHz. Here the two clocks are
-- register outputs of plain dividers, the same technique as the old cpu_clk_gen
-- (GOSOF80.sdc declares them as generated clocks; hold timing on this family needs
-- OPTIMIZE_HOLD_TIMING "ALL PATHS", see variants\hw2x_cyclone_II\device.tcl).

library ieee;
use ieee.std_logic_1164.all;

entity Gosof_PLL is
	port (
		inclk0 : in  std_logic := '0';
		c0     : out std_logic;
		c1     : out std_logic
	);
end Gosof_PLL;

architecture rtl of Gosof_PLL is
	signal cnt0 : integer range 0 to 55 := 0;
	signal cnt1 : integer range 0 to 48 := 0;
	signal c0_r : std_logic := '0';
	signal c1_r : std_logic := '0';
begin
	process(inclk0)
	begin
		if rising_edge(inclk0) then
			if cnt0 = 55 then cnt0 <= 0; else cnt0 <= cnt0 + 1; end if;
			if cnt0 < 28 then c0_r <= '0'; else c0_r <= '1'; end if;   -- 28 low / 28 high
			if cnt1 = 48 then cnt1 <= 0; else cnt1 <= cnt1 + 1; end if;
			if cnt1 < 25 then c1_r <= '0'; else c1_r <= '1'; end if;   -- 25 low / 24 high
		end if;
	end process;
	c0 <= c0_r;
	c1 <= c1_r;
end rtl;