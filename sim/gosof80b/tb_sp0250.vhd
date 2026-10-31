-- tb_sp0250.vhd - rtl\hw5x_80b\sp0250.vhd against the PinMAME C code. run_sp0250.ps1 makes the
-- frames (frames.txt, one decimal byte per line) and the expected samples from a copy of the
-- C code. Here: fill the FIFO whenever DRQ is high and write one sample per tick to out.txt.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_sp0250 is
	generic(Samples : natural := 1000);
end tb_sp0250;

architecture sim of tb_sp0250 is
	constant TICK : integer := 200;
	signal clk   : std_logic := '0';
	signal rst_n : std_logic := '0';
	signal data  : std_logic_vector(7 downto 0) := x"00";
	signal stb   : std_logic := '0';
	signal drq   : std_logic;
	signal audio : signed(15 downto 0);
	signal done  : boolean := false;
begin
	clk <= not clk after 10 ns when not done;

	DUT: entity work.sp0250
	generic map(Tick_Div => TICK)
	port map(clk => clk, rst_n => rst_n, data => data, stb => stb, drq => drq, audio => audio);

	FEED: process
		file f : text open read_mode is "frames.txt";
		variable l : line;
		variable v : integer;
	begin
		wait for 100 ns;
		wait until rising_edge(clk);
		rst_n <= '1';
		-- first frame before the first tick that counts: the C code starts with it in the FIFO
		while not endfile(f) and not done loop
			for i in 0 to 14 loop
				if drq /= '1' then wait until drq = '1'; end if;
				readline(f, l);
				read(l, v);
				data <= std_logic_vector(to_unsigned(v, 8));
				stb <= '1';
				wait until rising_edge(clk);
				stb <= '0';
				wait until rising_edge(clk);
				wait until rising_edge(clk);
			end loop;
			wait until rising_edge(clk);
			wait for 0 ns;
		end loop;
		wait;
	end process;

	-- one sample per tick, read just before the next one starts
	OUTP: process
		file o : text open write_mode is "out.txt";
		variable l : line;
		variable c : natural := 0;
		variable n : natural := 0;
	begin
		wait until rst_n = '1';
		-- tick_cnt = 0 starts a sample; the first full sample period begins behind the frame load
		loop
			wait until rising_edge(clk);
			c := c + 1;
			if c = TICK then
				c := 0;
				write(l, to_integer(audio));
				writeline(o, l);
				n := n + 1;
				exit when n = Samples;
			end if;
		end loop;
		done <= true;
		wait;
	end process;
end sim;
