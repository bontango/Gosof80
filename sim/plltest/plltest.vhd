-- PLL test for the EP4CE6E22C8N core board, standalone.
-- LED1 (PIN_1): Gosof_PLL c0 (892 kHz) / 2^20 -> ~0.85 Hz. Dark or steady = PLL dead.
-- LED2 (PIN_2): clk_50 / 2^25 -> ~1.5 Hz, reference that the design runs.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity plltest is
	port(clk_50 : in std_logic; LED1, LED2 : out std_logic);
end plltest;
architecture rtl of plltest is
	signal c0, c1 : std_logic;
	signal cnt_pll : unsigned(19 downto 0) := (others => '0');
	signal cnt_ref : unsigned(24 downto 0) := (others => '0');
begin
	PLL: entity work.Gosof_PLL port map(inclk0 => clk_50, c0 => c0, c1 => c1);
	process(c0) begin if rising_edge(c0) then cnt_pll <= cnt_pll + 1; end if; end process;
	process(clk_50) begin if rising_edge(clk_50) then cnt_ref <= cnt_ref + 1; end if; end process;
	LED1 <= cnt_pll(19);
	LED2 <= cnt_ref(24);
end rtl;
