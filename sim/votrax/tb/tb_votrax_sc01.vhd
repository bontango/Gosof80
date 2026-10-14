-- tb_votrax_sc01.vhd - bit exact check of votrax_sc01 against the C model.
--
-- Reads the stimulus that ref_votrax wrote (<name>.writes: "tick byte" = write to
-- $2000, "tick Cxx" = $3000 latch, "tick M" = mute) and applies every event so that
-- the DUT processes it on exactly that main clock tick: the DUT takes bus events in
-- phase A of the next tick, so an event for tick T is driven after the DUT has done
-- ticks 0 .. T-1. The ticks come from G_TICK_DIV (fixed divider), so the run does not
-- depend on the NCO; the NCO is checked separately (run_ghdl.ps1 -Nco).
--
-- Output: one 16 bit sample per line, compared with the model's .txt by compare.py.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_votrax_sc01 is
	generic (
		WRITES   : string  := "ref_t3_sentence.writes";
		OUTFILE  : string  := "vhdl_t3_sentence.txt";
		NSAMPLES : natural := 1000;
		TICK_DIV : natural := 20
	);
end tb_votrax_sc01;

architecture sim of tb_votrax_sc01 is
	signal clk       : std_logic := '0';
	signal rst_n     : std_logic := '0';
	signal stb       : std_logic := '0';
	signal data      : std_logic_vector(7 downto 0) := (others => '0');
	signal mute_stb  : std_logic := '0';
	signal clk_ctrl  : std_logic_vector(7 downto 0) := x"7E";
	signal ar        : std_logic;
	signal audio     : signed(15 downto 0);
	signal audio_stb : std_logic;
	signal tick      : std_logic;
	signal ticks_done : natural := 0;
	signal finished  : boolean := false;

	function hexval(c : character) return natural is
	begin
		case c is
			when '0' to '9' => return character'pos(c) - character'pos('0');
			when 'A' to 'F' => return character'pos(c) - character'pos('A') + 10;
			when 'a' to 'f' => return character'pos(c) - character'pos('a') + 10;
			when others => report "bad hex digit " & c severity failure; return 0;
		end case;
	end function;
begin
	clk <= not clk after 10 ns when not finished;           -- 50 MHz

	dut : entity work.votrax_sc01
		generic map (G_TICK_DIV => TICK_DIV)
		port map (clk => clk, rst_n => rst_n, stb => stb, data => data, mute_stb => mute_stb,
		          clk_ctrl => clk_ctrl, ar => ar, audio => audio, audio_stb => audio_stb,
		          tick_o => tick);

	count : process(clk)
	begin
		if rising_edge(clk) then
			if tick = '1' then ticks_done <= ticks_done + 1; end if;
		end if;
	end process;

	stim : process
		file f     : text open read_mode is WRITES;
		variable l : line;
		variable t : integer;
		variable c : character;
		variable ok : boolean;
		variable tok : string(1 to 8);
		variable n : natural;
	begin
		rst_n <= '0';
		for i in 1 to 5 loop wait until rising_edge(clk); end loop;
		rst_n <= '1';
		while not endfile(f) loop
			readline(f, l);
			read(l, t, ok);
			next when not ok;
			n := 0;
			loop
				read(l, c, ok);
				exit when not ok;
				if c /= ' ' and c /= CR then n := n + 1; tok(n) := c; end if;
			end loop;
			-- wait until the DUT has done ticks 0 .. t-1
			while ticks_done < t loop wait until rising_edge(clk); end loop;
			wait until rising_edge(clk);
			if tok(1) = 'C' then
				clk_ctrl <= std_logic_vector(to_unsigned(hexval(tok(2)) * 16 + hexval(tok(3)), 8));
				wait until rising_edge(clk);
			elsif tok(1) = 'M' then
				mute_stb <= '1';
				for i in 1 to 4 loop wait until rising_edge(clk); end loop;
				mute_stb <= '0';
				wait until rising_edge(clk);
			else
				data <= std_logic_vector(to_unsigned(hexval(tok(1)) * 16 + hexval(tok(2)), 8));
				stb <= '1';
				for i in 1 to 4 loop wait until rising_edge(clk); end loop;
				stb <= '0';
				wait until rising_edge(clk);
			end if;
			assert ticks_done = t report "stimulus too late for tick " & integer'image(t) severity failure;
		end loop;
		wait;
	end process;

	sink : process
		file f     : text open write_mode is OUTFILE;
		variable l : line;
		variable k : natural := 0;
	begin
		while k < NSAMPLES loop
			wait until rising_edge(clk) and audio_stb = '1';
			write(l, to_integer(audio));
			writeline(f, l);
			k := k + 1;
		end loop;
		report "done: " & integer'image(k) & " samples, " & integer'image(ticks_done) & " ticks";
		finished <= true;
		wait;
	end process;
end sim;
