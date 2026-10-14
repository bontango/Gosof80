-- tb_votrax_nco.vhd - checks the main clock NCO of votrax_sc01 (G_TICK_DIV = 0).
-- Counts ticks over 10 ms for a few $3000 latch values and compares with
-- f = max(5750 * d - 4500, 1) Hz (gts80s.c). Tolerance: +-1 tick.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_votrax_nco is
end tb_votrax_nco;

architecture sim of tb_votrax_nco is
	signal clk      : std_logic := '0';
	signal rst_n    : std_logic := '0';
	signal clk_ctrl : std_logic_vector(7 downto 0) := x"7E";
	signal tick     : std_logic;
	signal ticks    : natural := 0;
	signal finished : boolean := false;
	type list_t is array (natural range <>) of natural;
	constant VALUES : list_t := (16#7E#, 16#46#, 16#A0#, 16#FF#, 16#01#);
begin
	clk <= not clk after 10 ns when not finished;

	dut : entity work.votrax_sc01
		generic map (G_TICK_DIV => 0)
		port map (clk => clk, rst_n => rst_n, stb => '0', data => x"00", mute_stb => '0',
		          clk_ctrl => clk_ctrl, ar => open, audio => open, audio_stb => open, tick_o => tick);

	process(clk)
	begin
		if rising_edge(clk) and tick = '1' then ticks <= ticks + 1; end if;
	end process;

	process
		variable t0, got, want : integer;
		variable bad : boolean := false;
	begin
		rst_n <= '0'; wait for 100 ns; rst_n <= '1';
		for i in VALUES'range loop
			clk_ctrl <= std_logic_vector(to_unsigned(VALUES(i), 8));
			wait for 1 us;                              -- NCO increment settles
			t0 := ticks;
			wait for 10 ms;
			got := ticks - t0;
			want := (5750 * VALUES(i) - 4500) / 100;    -- ticks in 10 ms
			report "clk_ctrl=" & integer'image(VALUES(i)) & " ticks/10ms=" & integer'image(got)
			       & " expected " & integer'image(want);
			if abs (got - want) > 1 then bad := true; end if;
		end loop;
		assert not bad report "NCO frequency wrong" severity failure;
		report "NCO ok";
		finished <= true;
		wait;
	end process;
end sim;
