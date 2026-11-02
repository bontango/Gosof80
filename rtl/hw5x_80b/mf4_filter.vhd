-- mf4_filter.vhd - the switched capacitor filter MF-4CN-50 of the MA-886 generation 2.
--
-- 4th order Butterworth low pass, corner set by the register $2000: fc = 40 kHz / (256 - N),
-- table in mf4_table_pkg.vhd (scripts\gen_mf4_table.ps1). The games change it while a sound plays.
-- Two state variable stages (Chamberlin), damping 2 cos(pi/8) and 2 cos(3 pi/8), at
-- fs = 50 MHz / 128, sharing one multiplier. Stable up to N = 255 (f = 0.635).
-- Check against the theoretical response: sim\gosof886\run_mf4.ps1.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mf4_table_pkg.all;

entity mf4_filter is
	port(
		clk   : in  std_logic;
		n     : in  std_logic_vector(7 downto 0);
		audio_in  : in  signed(15 downto 0);
		audio_out : out signed(15 downto 0)
	);
end mf4_filter;

architecture rtl of mf4_filter is
	constant Q1 : signed(17 downto 0) := to_signed(121094, 18);  -- 1.8478 * 65536
	constant Q2 : signed(17 downto 0) := to_signed(50159, 18);   -- 0.7654 * 65536

	signal step  : unsigned(6 downto 0) := (others => '0');
	signal f     : signed(17 downto 0) := (others => '0');
	signal a     : signed(23 downto 0) := (others => '0');
	signal b     : signed(17 downto 0) := (others => '0');
	signal p     : signed(41 downto 0) := (others => '0');
	signal x     : signed(23 downto 0) := (others => '0');
	signal low1, band1, low2, band2 : signed(23 downto 0) := (others => '0');
	signal table_q : integer range 0 to 65535 := 0;

	-- the product scaled back by 65536
	function scaled(v : signed(41 downto 0)) return signed is
	begin
		return v(39 downto 16);
	end function;
begin
	audio_out <= low2(23 downto 8);

	process(clk)
		variable high : signed(23 downto 0);
	begin
		if rising_edge(clk) then
			step <= step + 1;
			table_q <= MF4_TABLE(to_integer(unsigned(n)));
			f <= to_signed(table_q, 18);
			-- every second clock: only when a result is needed, also keeps the GHDL run short
			if step(0) = '1' then
				p <= a * b;
			end if;
			case to_integer(step) is
				-- first stage
				when 0 =>
					x <= resize(audio_in, 16) & x"00";
					a <= band1; b <= f;
				when 2 =>
					low1 <= low1 + scaled(p);
					a <= band1; b <= Q1;
				when 4 =>
					high := x - low1 - scaled(p);
					a <= high; b <= f;
				when 6 =>
					band1 <= band1 + scaled(p);
					-- second stage, input = low pass of the first
					x <= low1;
					a <= band2; b <= f;
				when 8 =>
					low2 <= low2 + scaled(p);
					a <= band2; b <= Q2;
				when 10 =>
					high := x - low2 - scaled(p);
					a <= high; b <= f;
				when 12 =>
					band2 <= band2 + scaled(p);
				when others =>
					null;
			end case;
		end if;
	end process;
end rtl;
