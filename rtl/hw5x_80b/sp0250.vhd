-- sp0250.vhd - GI SP0250 LPC sound synthesizer for GOSOF80B (MA-766).
-- Port of the model in PinMAME src\sound\sp0250.c (O. Galibert), same arithmetic. The games
-- use it for sound effects, not for speech. sim\gosof80b\run_sp0250.ps1 checks it sample by
-- sample against a copy of the C code.
--
-- A frame is 15 bytes. The CPU writes them into the FIFO while DRQ is high. When the current
-- frame has ended and the FIFO is full, the frame is taken over, DRQ goes high again.
--
-- Sample rate 3.12 MHz / 312 = 10 kHz (PinMAME's divider), so a sample has 5000 clk cycles of
-- 50 MHz. That is far more than the six filter stages need, one multiplier does them one after
-- the other.
--
-- Not modelled, as in PinMAME: RESET and DIRECT DATA TEST pins, 7 bit output of the real chip.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sp0250 is
	generic(
		Tick_Div : integer := 5000  -- clk cycles per sample
	);
	port(
		clk    : in  std_logic;
		rst_n  : in  std_logic;
		data   : in  std_logic_vector(7 downto 0);
		stb    : in  std_logic;  -- DATA PRESENT: the falling edge takes the byte
		drq    : out std_logic;  -- '1' = FIFO not full
		audio  : out signed(15 downto 0)
	);
end sp0250;

architecture rtl of sp0250 is
	type bytes_t is array (0 to 14) of std_logic_vector(7 downto 0);
	type z_t is array (0 to 5) of signed(15 downto 0);
	type coef_t is array (0 to 127) of integer range 0 to 511;
	type index_t is array (0 to 5) of integer range 0 to 14;
	type state_t is (idle, stage_mul1, stage_mul2, stage_sum1, stage_sum2, stage_next, finish);

	-- internal ROM of the chip
	constant COEFS : coef_t := (
		  0,   9,  17,  25,  33,  41,  49,  57,  65,  73,  81,  89,  97, 105, 113, 121,
		129, 137, 145, 153, 161, 169, 177, 185, 193, 201, 203, 217, 225, 233, 241, 249,
		257, 265, 273, 281, 289, 297, 301, 305, 309, 313, 317, 321, 325, 329, 333, 337,
		341, 345, 349, 353, 357, 361, 365, 369, 373, 377, 381, 385, 389, 393, 397, 401,
		405, 409, 413, 417, 421, 425, 427, 429, 431, 433, 435, 437, 439, 441, 443, 445,
		447, 449, 451, 453, 455, 457, 459, 461, 463, 465, 467, 469, 471, 473, 475, 477,
		479, 481, 482, 483, 484, 485, 486, 487, 488, 489, 490, 491, 492, 493, 494, 495,
		496, 497, 498, 499, 500, 501, 502, 503, 504, 505, 506, 507, 508, 509, 510, 511
	);
	-- where the coefficients of the six filters are in the frame
	constant B_POS : index_t := (0, 3, 6, 9, 11, 13);
	constant F_POS : index_t := (1, 4, 7, 10, 12, 14);

	signal fifo     : bytes_t := (others => x"00");
	signal frame    : bytes_t := (others => x"00");
	signal fifo_pos : integer range 0 to 15 := 0;
	signal stb_d    : std_logic := '0';
	signal z1, z2   : z_t := (others => (others => '0'));
	signal playing  : std_logic := '0';
	signal pcount   : unsigned(7 downto 0) := (others => '0');
	signal rcount   : unsigned(6 downto 0) := (others => '0');
	signal rng      : unsigned(16 downto 0) := to_unsigned(1, 17);
	signal tick_cnt : integer range 0 to Tick_Div - 1 := 0;
	signal state    : state_t := idle;
	signal f        : integer range 0 to 5 := 0;
	signal z0       : signed(15 downto 0) := (others => '0');
	signal mul_a    : signed(15 downto 0) := (others => '0');
	signal mul_b    : signed(9 downto 0) := (others => '0');
	signal mul_q    : signed(25 downto 0) := (others => '0');
	signal term1    : signed(25 downto 0) := (others => '0');

	-- sp0250_gc: bit 7 = sign, '0' is negative
	function gc(v : std_logic_vector(7 downto 0)) return signed is
		variable c : integer range 0 to 511;
	begin
		c := COEFS(to_integer(unsigned(v(6 downto 0))));
		if v(7) = '0' then
			return to_signed(-c, 10);
		else
			return to_signed(c, 10);
		end if;
	end function;

	-- sp0250_ga: mantissa << exponent, at most 31 << 7
	function ga(v : std_logic_vector(7 downto 0)) return signed is
	begin
		return signed(shift_left(resize(unsigned(v(4 downto 0)), 16), to_integer(unsigned(v(7 downto 5)))));
	end function;
begin
	drq <= '0' when fifo_pos = 15 else '1';

	process(clk) is
		variable sum   : signed(25 downto 0);
		variable next_p : unsigned(7 downto 0);
		variable next_r : unsigned(6 downto 0);
		variable ended : boolean;
		variable load  : boolean;
	begin
		if rising_edge(clk) then
			mul_q <= mul_a * mul_b;
			stb_d <= stb;
			load := false;
			if rst_n = '0' then
				fifo_pos <= 0;
				playing <= '0';
				state <= idle;
				tick_cnt <= 0;
				rng <= to_unsigned(1, 17);
				audio <= (others => '0');
			else
				if stb_d = '1' and stb = '0' and fifo_pos /= 15 then
					fifo(fifo_pos) <= data;
					fifo_pos <= fifo_pos + 1;
				end if;

				if tick_cnt = Tick_Div - 1 then tick_cnt <= 0; else tick_cnt <= tick_cnt + 1; end if;

				case state is
					when idle =>
						if tick_cnt = 0 then
							if playing = '1' then
								-- excitation: pitch pulse when voiced, else the noise LFSR of the AY
								if frame(8)(6) = '1' then
									if pcount = 0 then z0 <= ga(frame(2)); else z0 <= (others => '0'); end if;
								else
									if rng(0) = '1' then
										z0 <= ga(frame(2));
										rng <= shift_right(rng, 1) xor to_unsigned(16#12000#, 17);  -- C: RNG ^= 0x24000; RNG >>= 1
									else
										z0 <= -ga(frame(2));
										rng <= shift_right(rng, 1);
									end if;
								end if;
								f <= 0;
								state <= stage_mul1;
							else
								audio <= (others => '0');
								load := true;
							end if;
						end if;

					-- z0 += ((z1 * F) >> 8) + ((z2 * B) >> 9), kept to 16 bit like the INT16 in C
					when stage_mul1 =>
						mul_a <= z1(f);
						mul_b <= gc(frame(F_POS(f)));
						state <= stage_mul2;
					when stage_mul2 =>
						mul_a <= z2(f);
						mul_b <= gc(frame(B_POS(f)));
						state <= stage_sum1;
					when stage_sum1 =>
						term1 <= shift_right(mul_q, 8);  -- z1 * F
						state <= stage_sum2;
					when stage_sum2 =>
						sum := resize(z0, 26) + term1 + shift_right(mul_q, 9);  -- z2 * B
						z0 <= sum(15 downto 0);
						z2(f) <= z1(f);
						z1(f) <= sum(15 downto 0);
						state <= stage_next;
					when stage_next =>
						if f = 5 then
							state <= finish;
						else
							f <= f + 1;
							state <= stage_mul1;
						end if;

					when finish =>
						audio <= shift_left(z0, 3);
						ended := false;
						next_p := pcount + 1;
						if next_p >= unsigned(frame(5)) then
							next_p := (others => '0');
							next_r := rcount + 1;
							rcount <= next_r;
							if next_r >= unsigned(frame(8)(5 downto 0)) then
								ended := true;
							end if;
						end if;
						pcount <= next_p;
						if ended then
							playing <= '0';
							load := true;
						end if;
						state <= idle;
				end case;

				-- next frame, once the current one has ended (also at the end of its last sample)
				if load and fifo_pos = 15 then
					frame <= fifo;
					fifo_pos <= 0;
					playing <= '1';
					pcount <= (others => '0');
					rcount <= (others => '0');
					z1 <= (others => (others => '0'));
					z2 <= (others => (others => '0'));
				end if;
			end if;
		end if;
	end process;
end rtl;
