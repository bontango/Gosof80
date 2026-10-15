-- Version announcement through the Votrax SC-01 emulation:
-- "This is Gosof version <BOARD_ID> dot <SW_MINOR/10> <SW_MINOR mod 10> from lisy dot dev".
-- bontango www.lisy.dev, 10.2026
--
-- start (one clk pulse) begins the sentence, busy is '1' until the STOP phoneme has been
-- taken. While busy the sequencer owns the bus of votrax_sc01: it puts one phoneme on
-- data, holds stb for 8 clocks (votrax_sc01 needs >= 3), waits until A/R drops (the chip
-- took it) and rises again (phoneme done), then the next one.
-- data is the BUS byte as the MA-216 CPU writes it: P0..P5 inverted, inflection 0.
-- The word tables come from vtx_announce_pkg.vhd (sim/votrax/tools/gen_announce.py).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.vtx_announce_pkg.all;

entity vtx_announce is
	generic (
		BOARD_ID : natural := 0;
		SW_MINOR : natural := 0
	);
	port (
		clk   : in  std_logic;                       -- 50 MHz
		rst_n : in  std_logic;
		start : in  std_logic;                       -- one clk pulse
		ar    : in  std_logic;                       -- A/R of votrax_sc01, '1' = ready
		busy  : out std_logic;
		stb   : out std_logic;                       -- to votrax_sc01 stb
		data  : out std_logic_vector(7 downto 0)     -- to votrax_sc01 data
	);
end vtx_announce;

architecture rtl of vtx_announce is

	constant SEQ_MAX : natural := ANN_PRE'length + ANN_DOT'length + ANN_GAP'length
	                              + ANN_POST'length + 3 * DIGIT_MAX;

	-- the whole sentence, folded to a constant by synthesis
	function build_seq return phon_list_t is
		variable s : phon_list_t(0 to SEQ_MAX - 1) := (others => PHON_STOP);
		variable n : natural := 0;
		procedure add(l : phon_list_t; len : natural) is
		begin
			for i in 0 to len - 1 loop
				s(n) := l(l'low + i);
				n := n + 1;
			end loop;
		end procedure;
	begin
		add(ANN_PRE, ANN_PRE'length);
		add(ANN_DIGIT(BOARD_ID mod 10), ANN_DIGIT_LEN(BOARD_ID mod 10));
		add(ANN_DOT, ANN_DOT'length);
		add(ANN_DIGIT((SW_MINOR / 10) mod 10), ANN_DIGIT_LEN((SW_MINOR / 10) mod 10));
		add(ANN_GAP, ANN_GAP'length);
		add(ANN_DIGIT(SW_MINOR mod 10), ANN_DIGIT_LEN(SW_MINOR mod 10));
		add(ANN_POST, ANN_POST'length);              -- ends with STOP
		return s;
	end function;

	constant SEQ : phon_list_t(0 to SEQ_MAX - 1) := build_seq;

	type state_t is (S_IDLE, S_STROBE, S_WAIT_TAKEN, S_WAIT_DONE);
	signal state  : state_t := S_IDLE;
	signal idx    : natural range 0 to SEQ_MAX - 1 := 0;
	signal cnt    : unsigned(16 downto 0) := (others => '0');
	signal ar_s   : std_logic_vector(1 downto 0) := "11";

begin

	busy <= '0' when state = S_IDLE else '1';
	stb  <= '1' when state = S_STROBE else '0';
	data <= "00" & std_logic_vector(to_unsigned(SEQ(idx), 6) xor "111111");

	process(clk)
	begin
		if rising_edge(clk) then
			ar_s <= ar_s(0) & ar;
			if rst_n = '0' then
				state <= S_IDLE; idx <= 0; cnt <= (others => '0');
			else
				case state is
					when S_IDLE =>
						idx <= 0;
						if start = '1' then
							cnt <= (others => '0');
							state <= S_STROBE;
						end if;
					when S_STROBE =>
						cnt <= cnt + 1;
						if cnt = 7 then
							cnt <= (others => '0');
							state <= S_WAIT_TAKEN;
						end if;
					when S_WAIT_TAKEN =>
						-- A/R drops within a few main clock ticks (~1.4 us each); 2.6 ms
						-- without that means the write got lost - go on anyway
						cnt <= cnt + 1;
						if ar_s(1) = '0' or cnt(cnt'high) = '1' then
							state <= S_WAIT_DONE;
						end if;
					when S_WAIT_DONE =>
						cnt <= (others => '0');
						if ar_s(1) = '1' then
							if SEQ(idx) = PHON_STOP or idx = SEQ_MAX - 1 then
								state <= S_IDLE;
							else
								idx <= idx + 1;
								state <= S_STROBE;
							end if;
						end if;
				end case;
			end if;
		end if;
	end process;

end rtl;
