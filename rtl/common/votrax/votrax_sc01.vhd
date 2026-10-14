-- votrax_sc01.vhd - Votrax SC-01 speech synthesizer for GOSOF80
-- by bontango www.lisy.dev, 10.2026
--
-- An implementation of PinMAME's SC-01 emulation (src/sound/votrax.c, the core by
-- Olivier Galibert) for the FPGA. The specification this file follows exactly is the
-- C model sim/votrax/model/vmodel.c - same control logic, same order of operations,
-- same fixed point arithmetic; the testbench sim/votrax/tb compares both bit by bit.
--
-- Structure
--   * main clock: an NCO on clk (50 MHz) produces one "tick" per SC-01 main clock
--     period. Frequency from the $3000 latch as on the MA-216 (gts80s.c):
--     f = max(5750 * clk_ctrl - 4500, 1) Hz, 0x7E = 720 kHz.
--   * every tick, in four clk cycles (phase A..D):
--       A  pending bus events: phoneme write, mute, clock change
--       B  the one timer of votrax.c (commit 72 ticks after the write, end of phone)
--       C  every 18th tick a sample: sample_count++, chip_update on odd counts
--       D  start of the sample computation (snapshot of the filter parameters)
--   * the sample computation (analog_calc) is a short micro program of 14 MAC
--     operations on one 27x24 bit multiplier: ~110 clk cycles, available are at
--     least 600 (18 ticks at the highest clock, 0xFF = 1.46 MHz).
--   * all filter coefficients come precomputed from votrax_tables_pkg (they do not
--     depend on the main clock, see gen_votrax_tables.py).
--
-- Bus side (MA-216): stb = write to $2000 (bus byte, P0..P5 inverted on the board,
-- inflection on D6/D7), mute_stb = write to $7000 (PinMAME: mutes until the next
-- $2000 write), clk_ctrl = value of the $3000 latch, ar = A/R, '1' = ready.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.votrax_tables_pkg.all;

entity votrax_sc01 is
	generic (
		-- 0: tick from the NCO (hardware). > 0: one tick every G_TICK_DIV clk cycles,
		-- independent of clk_ctrl - only for the testbench, which counts ticks anyway.
		G_TICK_DIV : natural := 0
	);
	port (
		clk       : in  std_logic;                       -- 50 MHz
		rst_n     : in  std_logic;
		stb       : in  std_logic;                       -- write strobe $2000, active high
		data      : in  std_logic_vector(7 downto 0);    -- bus byte, valid while stb = '1'
		mute_stb  : in  std_logic;                       -- write strobe $7000, active high
		clk_ctrl  : in  std_logic_vector(7 downto 0);    -- $3000 latch
		ar        : out std_logic;                       -- A/R, '1' = ready for the next phoneme
		audio     : out signed(15 downto 0);             -- 1.0 = 8192
		audio_stb : out std_logic;                       -- one clk pulse per new sample
		tick_o    : out std_logic                        -- one clk pulse per main clock tick
	);
end votrax_sc01;

architecture rtl of votrax_sc01 is

	constant DW : natural := 24;                         -- data word
	constant CW : natural := VT_COEF_BITS;               -- coefficient word (27)
	constant CF : natural := VT_COEF_FRAC;               -- 24
	constant AW : natural := 56;                         -- accumulator

	subtype data_t is signed(DW - 1 downto 0);
	subtype u8_t is unsigned(7 downto 0);

	-- ---- bus side -----------------------------------------------------------------
	signal stb_s, mute_s       : std_logic_vector(4 downto 0) := (others => '0');
	signal pend_wr, pend_mute  : std_logic := '0';
	signal wr_data             : std_logic_vector(7 downto 0) := (others => '0');
	signal clk_ctrl_prev       : std_logic_vector(7 downto 0) := x"7E";

	-- ---- tick generation ----------------------------------------------------------
	signal nco_acc   : unsigned(31 downto 0) := (others => '0');
	signal nco_inc   : unsigned(31 downto 0) := (others => '0');
	signal nco_ctrl  : std_logic_vector(7 downto 0) := (others => '0');
	signal nco_valid : std_logic := '0';
	signal div_cnt   : natural range 0 to 65535 := 0;
	signal tick      : std_logic := '0';
	signal phase     : std_logic_vector(3 downto 0) := (others => '0');   -- A..D, one hot shift
	signal t_mod18   : natural range 0 to 17 := 0;
	signal do_sample : std_logic := '0';

	-- ---- chip state (names as in votrax.c) ------------------------------------------
	signal inflection   : unsigned(1 downto 0) := "00";
	signal phone        : natural range 0 to 63 := 63;
	signal ar_state     : std_logic := '1';
	signal rom_f1, rom_va, rom_f2, rom_fc, rom_f2q, rom_f3, rom_fa : natural range 0 to 15 := 0;
	signal rom_cld, rom_vd : natural range 0 to 15 := 0;
	signal rom_closure, rom_pause : std_logic := '0';
	signal rom_duration : natural range 0 to 127 := 0;
	signal cur_fa, cur_fc, cur_va, cur_f1, cur_f2, cur_f2q, cur_f3 : u8_t := (others => '0');
	signal filt_fa, filt_fc, filt_va, filt_f1, filt_f2q, filt_f3 : natural range 0 to 15 := 0;
	signal filt_f2      : natural range 0 to 31 := 0;
	signal phonetick    : unsigned(8 downto 0) := (others => '0');
	signal ticks        : natural range 0 to 16 := 0;
	signal pitch        : u8_t := (others => '0');
	signal closure      : natural range 0 to 28 := 0;
	signal update_cnt   : natural range 0 to 47 := 0;
	signal cur_closure  : std_logic := '1';
	signal noise        : unsigned(14 downto 0) := (others => '0');
	signal cur_noise    : std_logic := '0';
	signal sample_cnt   : std_logic := '0';                 -- only the parity matters
	signal muted        : std_logic := '0';

	type timer_t is (T_NONE, T_COMMIT_PHONE, T_END_OF_PHONE);
	signal timer_kind   : timer_t := T_NONE;
	signal timer_left   : natural range 0 to 2**19 - 1 := 0;

	-- ---- sample computation -----------------------------------------------------------
	-- snapshot of what analog_calc reads, taken in phase D
	signal s_va, s_fa, s_fc, s_f1, s_f3, s_cl : natural range 0 to 15 := 0;
	signal s_f2i  : natural range 0 to 511 := 0;
	signal s_gi   : natural range 0 to 8 := 0;
	signal s_npos : std_logic := '0';
	signal s_mute : std_logic := '0';

	-- filter histories: x0 newest input, y0 last output
	type hist5_t is array (0 to 4) of data_t;               -- x0, x1, x2, y0, y1
	signal h_f1, h_f2v, h_fn, h_f3, h_f4 : hist5_t := (others => (others => '0'));
	signal h_f2n : hist5_t := (others => (others => '0'));  -- x0, x1, -, y0, -
	signal r_v, r_n, r_n2, r_vn, r_fxy : data_t := (others => '0');

	-- micro program
	constant NOPS : natural := 14;
	signal op       : natural range 0 to NOPS := NOPS;      -- NOPS = idle
	type seq_t is (S_IDLE, S_START, S_ISSUE, S_DRAIN, S_WB);
	signal seq      : seq_t := S_IDLE;
	signal term     : natural range 0 to 5 := 0;
	signal drain    : natural range 0 to 3 := 0;

	-- MAC pipeline, one term per cycle:
	--   issue (address, data operand) -> ROM read -> coef/data register -> product -> accumulate
	signal a_f2             : natural range 0 to 4095 := 0;
	signal a_misc           : natural range 0 to 511 := 0;
	signal q_f2, q_misc     : integer range -2**(CW - 1) to 2**(CW - 1) - 1 := 0;
	signal p1_sel_f2, pb_sel_f2 : std_logic := '0';
	signal p1_d, pb_d, p2_d : data_t := (others => '0');
	signal p1_valid, pb_valid, p2_valid, p3_valid : std_logic := '0';
	signal p2_c             : signed(CW - 1 downto 0) := (others => '0');
	signal p3_prod          : signed(CW + DW - 1 downto 0) := (others => '0');
	signal acc              : signed(AW - 1 downto 0) := (others => '0');

	signal audio_r   : signed(15 downto 0) := (others => '0');
	signal audio_stb_r : std_logic := '0';

	-- ------------------------------------------------------------------------------
	function interp(reg : u8_t; target : natural) return u8_t is
	begin
		-- reg - (reg >> 3) + (target << 1), 8 bit wrap
		return reg - shift_right(reg, 3) + to_unsigned(target * 2, 8);
	end function;

	function sat_round(a : signed(AW - 1 downto 0)) return data_t is
		variable r : signed(AW - 1 downto 0);
	begin
		r := shift_right(a + to_signed(2**(CF - 1), AW), CF);
		if r > to_signed(2**(DW - 1) - 1, AW) then
			return to_signed(2**(DW - 1) - 1, DW);
		elsif r < to_signed(-2**(DW - 1), AW) then
			return to_signed(-2**(DW - 1), DW);
		else
			return r(DW - 1 downto 0);
		end if;
	end function;

	function nterms(o : natural) return natural is
	begin
		case o is
			when 1 | 2 | 4 | 8 | 10 => return 5;   -- biquads
			when 6                  => return 3;   -- F2 noise injection
			when 7 | 9 | 12         => return 2;
			when others             => return 1;
		end case;
	end function;

	function is_biquad(o : natural) return boolean is
	begin
		return o = 1 or o = 2 or o = 4 or o = 8 or o = 10;
	end function;

begin

	ar        <= ar_state;
	audio     <= audio_r;
	audio_stb <= audio_stb_r;
	tick_o    <= tick;

	-- ---- tick generation ----------------------------------------------------------
	-- f = 5750 * d - 4500 (d >= 1), d = 0 -> 1 Hz;  inc = f * 2^32 / 50e6 = (f * 2814750) / 2^15
	-- recomputed only when the latch changes (also keeps the simulation fast)
	nco_calc : process(clk)
		variable d : natural range 0 to 255;
		variable f : natural range 0 to 2**21 - 1;
		variable p : unsigned(44 downto 0);
	begin
		if rising_edge(clk) then
			nco_valid <= '1';
			if clk_ctrl /= nco_ctrl or nco_valid = '0' then
				nco_ctrl <= clk_ctrl;
				d := to_integer(unsigned(clk_ctrl));
				if d = 0 then f := 1; else f := 5750 * d - 4500; end if;
				p := to_unsigned(f, 22) * to_unsigned(2814750, 23);
				nco_inc <= resize(p(44 downto 15), 32);
			end if;
		end if;
	end process;

	tickgen : process(clk)
		variable s : unsigned(32 downto 0);
	begin
		if rising_edge(clk) then
			tick <= '0';
			if rst_n = '0' then
				nco_acc <= (others => '0'); div_cnt <= 0;
			elsif G_TICK_DIV > 0 then
				if div_cnt = G_TICK_DIV - 1 then div_cnt <= 0; tick <= '1';
				else div_cnt <= div_cnt + 1; end if;
			else
				s := ('0' & nco_acc) + ('0' & nco_inc);
				nco_acc <= s(31 downto 0);
				tick <= s(32);
			end if;
		end if;
	end process;

	-- ---- control: bus events, timer, chip_update (phases A..C) -----------------------
	control : process(clk)
		variable v_ticks      : natural range 0 to 16;
		variable v_phonetick  : unsigned(8 downto 0);
		variable v_cur_closure: std_logic;
		variable v_upd        : natural range 0 to 47;
		variable t625, t208   : boolean;
		variable v_closure    : natural range 0 to 28;
		variable v_pitch      : u8_t;
		variable v_noise      : unsigned(14 downto 0);
		variable v_inp        : std_logic;
		variable v_data       : std_logic_vector(7 downto 0);
		variable target       : natural range 0 to 511;
		variable cfa, cfc, cva, cf1, cf2, cf2q, cf3 : u8_t;
		variable p            : vt_phone_t;

		procedure filters_commit_from(fa, fc, va, f1, f2, f2q, f3 : u8_t) is
		begin
			filt_fa  <= to_integer(fa(7 downto 4));
			filt_fc  <= to_integer(fc(7 downto 4));
			filt_va  <= to_integer(va(7 downto 4));
			filt_f1  <= to_integer(f1(7 downto 4));
			filt_f2  <= to_integer(f2(7 downto 3));
			filt_f2q <= to_integer(f2q(7 downto 4));
			filt_f3  <= to_integer(f3(7 downto 4));
		end procedure;
	begin
		if rising_edge(clk) then
			-- bus strobes into the clk domain (2 synchroniser stages), then a rising edge
			-- counts only when the strobe has been high for 3 clk cycles: the strobes are
			-- combinational in the top level (address, R/W, cpu_clk), a 1 cycle glitch
			-- must not become a write. The real strobe lasts about 28 cycles.
			stb_s  <= stb_s(3 downto 0) & stb;
			mute_s <= mute_s(3 downto 0) & mute_stb;
			if stb_s(4 downto 1) = "0111" then pend_wr <= '1'; wr_data <= data; end if;
			if mute_s(4 downto 1) = "0111" then pend_mute <= '1'; end if;

			phase <= phase(2 downto 0) & tick;
			do_sample <= '0';

			if rst_n = '0' then
				pend_wr <= '0'; pend_mute <= '0'; phase <= (others => '0');
				clk_ctrl_prev <= x"7E";
				-- VOTRAXSC01_sh_start
				phone <= 63; inflection <= "00"; ar_state <= '1'; sample_cnt <= '0'; muted <= '0';
				p := VT_PHONE(63);
				rom_f1 <= p.f1; rom_va <= p.va; rom_f2 <= p.f2; rom_fc <= p.fc; rom_f2q <= p.f2q;
				rom_f3 <= p.f3; rom_fa <= p.fa; rom_cld <= p.cld; rom_vd <= p.vd;
				rom_duration <= p.duration;
				if p.closure = 1 then rom_closure <= '1'; else rom_closure <= '0'; end if;
				if p.pause = 1 then rom_pause <= '1'; else rom_pause <= '0'; end if;
				phonetick <= (others => '0'); ticks <= 0;
				cur_fa <= (others => '0'); cur_fc <= (others => '0'); cur_va <= (others => '0');
				cur_f1 <= (others => '0'); cur_f2 <= (others => '0'); cur_f2q <= (others => '0');
				cur_f3 <= (others => '0');
				filt_fa <= 0; filt_fc <= 0; filt_va <= 0; filt_f1 <= 0; filt_f2 <= 0; filt_f2q <= 0; filt_f3 <= 0;
				pitch <= (others => '0'); closure <= 0; update_cnt <= 0; cur_closure <= '1';
				noise <= (others => '0'); cur_noise <= '0';
				timer_kind <= T_NONE; timer_left <= 0;
				t_mod18 <= 0;

			-- phase A: bus events of this tick (votraxsc01_w, mute, set_clock)
			elsif phase(0) = '1' then
				if clk_ctrl /= clk_ctrl_prev then
					-- votraxsc01_set_clock -> filters_commit(0) on a real change
					clk_ctrl_prev <= clk_ctrl;
					filters_commit_from(cur_fa, cur_fc, cur_va, cur_f1, cur_f2, cur_f2q, cur_f3);
				end if;
				if pend_mute = '1' then
					pend_mute <= '0'; muted <= '1';
				end if;
				if pend_wr = '1' then
					pend_wr <= '0';
					muted <= '0';                                 -- a $2000 write unmutes
					v_data := wr_data xor "00111111";             -- board inverts P0..P5
					inflection <= unsigned(v_data(7 downto 6));
					phone <= to_integer(unsigned(v_data(5 downto 0)));
					ar_state <= '0';
					if timer_kind /= T_COMMIT_PHONE then
						timer_kind <= T_COMMIT_PHONE; timer_left <= 72;
					end if;
				end if;

			-- phase B: the timer
			elsif phase(1) = '1' then
				if timer_kind /= T_NONE then
					if timer_left = 0 then
						if timer_kind = T_COMMIT_PHONE then
							-- phone_commit
							p := VT_PHONE(phone);
							phonetick <= (others => '0'); ticks <= 0;
							rom_f1 <= p.f1; rom_va <= p.va; rom_f2 <= p.f2; rom_fc <= p.fc; rom_f2q <= p.f2q;
							rom_f3 <= p.f3; rom_fa <= p.fa; rom_cld <= p.cld; rom_vd <= p.vd;
							rom_duration <= p.duration;
							if p.closure = 1 then rom_closure <= '1'; else rom_closure <= '0'; end if;
							if p.pause = 1 then rom_pause <= '1'; else rom_pause <= '0'; end if;
							if p.cld = 0 then
								if p.closure = 1 then cur_closure <= '1'; else cur_closure <= '0'; end if;
							end if;
							-- end of phone after 16 * (duration * 4 + 1) * 4 * 9 + 2 ticks;
							-- -1 because this counter is first looked at in the next tick
							timer_kind <= T_END_OF_PHONE;
							timer_left <= 16 * (p.duration * 4 + 1) * 36 + 2 - 1;
						else
							timer_kind <= T_NONE;
							ar_state <= '1';
						end if;
					else
						timer_left <= timer_left - 1;
					end if;
				end if;

			-- phase C: sample tick -> sample_count++, chip_update on odd counts
			elsif phase(2) = '1' then
				if t_mod18 = 0 then
					do_sample <= '1';
					sample_cnt <= not sample_cnt;
					if sample_cnt = '0' then                   -- becomes odd: chip_update
						v_ticks := ticks; v_phonetick := phonetick; v_cur_closure := cur_closure;
						if v_ticks /= 16 then
							v_phonetick := v_phonetick + 1;
							if v_phonetick = to_unsigned(rom_duration * 4 + 1, 9) then
								v_phonetick := (others => '0');
								v_ticks := v_ticks + 1;
								if v_ticks = rom_cld then v_cur_closure := rom_closure; end if;
							end if;
						end if;
						if update_cnt = 47 then v_upd := 0; else v_upd := update_cnt + 1; end if;
						t625 := (v_upd mod 16) = 0;
						t208 := v_upd = 40;
						cfa := cur_fa; cfc := cur_fc; cva := cur_va; cf1 := cur_f1; cf2 := cur_f2;
						cf2q := cur_f2q; cf3 := cur_f3;
						if t208 and (rom_pause = '0' or (filt_fa = 0 and filt_va = 0)) then
							cfc := interp(cfc, rom_fc); cf1 := interp(cf1, rom_f1); cf2 := interp(cf2, rom_f2);
							cf2q := interp(cf2q, rom_f2q); cf3 := interp(cf3, rom_f3);
						end if;
						if t625 then
							if v_ticks >= rom_vd  then cfa := interp(cfa, rom_fa); end if;
							if v_ticks >= rom_cld then cva := interp(cva, rom_va); end if;
						end if;
						v_closure := closure;
						if v_cur_closure = '0' and (filt_fa /= 0 or filt_va /= 0) then
							v_closure := 0;
						elsif v_closure /= 28 then
							v_closure := v_closure + 1;
						end if;
						v_pitch := pitch + 1;
						target := to_integer(to_unsigned(16#E0#, 8) xor ('0' & inflection & "00000")
						          xor to_unsigned(filt_f1 * 2, 8)) + 2;
						if to_integer(v_pitch) = target then v_pitch := (others => '0'); end if;
						if (v_pitch and x"F9") = x"08" then
							filters_commit_from(cfa, cfc, cva, cf1, cf2, cf2q, cf3);
						end if;
						v_noise := noise;
						if cur_noise = '1' and v_noise /= "111111111111111" then v_inp := '1'; else v_inp := '0'; end if;
						v_noise := v_noise(13 downto 0) & v_inp;
						v_noise(0) := v_inp;
						cur_noise <= not (v_noise(14) xor v_noise(13));
						noise <= v_noise;
						ticks <= v_ticks; phonetick <= v_phonetick; cur_closure <= v_cur_closure;
						update_cnt <= v_upd; closure <= v_closure; pitch <= v_pitch;
						cur_fa <= cfa; cur_fc <= cfc; cur_va <= cva; cur_f1 <= cf1; cur_f2 <= cf2;
						cur_f2q <= cf2q; cur_f3 <= cf3;
					end if;
				end if;
				if t_mod18 = 17 then t_mod18 <= 0; else t_mod18 <= t_mod18 + 1; end if;
			end if;
		end if;
	end process;

	-- ---- coefficient ROMs (inferred, registered) -------------------------------------
	rom_f2_p : process(clk)
	begin
		if rising_edge(clk) then q_f2 <= VT_ROM_F2(a_f2); end if;
	end process;
	rom_misc_p : process(clk)
	begin
		if rising_edge(clk) then q_misc <= VT_ROM_MISC(a_misc); end if;
	end process;

	-- ---- sample computation: analog_calc as 14 MAC operations ------------------------
	--  op  what                         coefficients         data
	--   0  v  = glot * va/15            G15[va]              glottal wave
	--   1  v  = F1(v)                   F1[f1]               biquad history
	--   2  v  = F2voice(v)              ROM_F2[f2i] 0..4     biquad history
	--   3  n  = +-1 * fa/15             G15[fa]              +-1.0
	--   4  n  = FN(n)                   FN (x 1e4)           biquad history
	--   5  n2 = n * fc/15               G15[fc]              n
	--   6  n2 = F2noise(n2)             ROM_F2[f2i] 5..7     x0, x1, y0
	--   7  vn = v + n2                  1.0, 1.0             v, n2
	--   8  vn = F3(vn)                  F3[f3]               biquad history
	--   9  vn = vn + n*(5+(15^fc))/20   1.0, GN2[fc]         vn, n
	--  10  vn = F4(vn)                  F4                   biquad history
	--  11  vn = vn * (7^cl)/7           GCL[cl]              vn
	--  12  fx = a0*vn - b1*fx           FX                   vn, fx
	--  13  out = fx / 2.4               GOUT                 fx
	sequencer : process(clk)
		variable n    : natural range 0 to 5;
		variable din  : data_t;
		variable res  : data_t;
		variable cpos : data_t;
		variable s16  : signed(DW - 1 downto 0);
	begin
		if rising_edge(clk) then
			audio_stb_r <= '0';
			p1_valid <= '0';

			-- pipeline stages run every cycle
			-- (b) the ROMs read the address issued in the previous cycle; the data waits
			pb_valid  <= p1_valid;
			pb_d      <= p1_d;
			pb_sel_f2 <= p1_sel_f2;
			-- (2) coefficient and data side by side
			p2_valid <= pb_valid;
			p2_d     <= pb_d;
			if pb_sel_f2 = '1' then p2_c <= to_signed(q_f2, CW); else p2_c <= to_signed(q_misc, CW); end if;
			-- (3) product, (4) accumulate
			p3_valid <= p2_valid;
			if p2_valid = '1' then p3_prod <= p2_c * p2_d; end if;
			if p3_valid = '1' then acc <= acc + resize(p3_prod, AW); end if;

			if rst_n = '0' then
				seq <= S_IDLE; op <= NOPS;
				h_f1 <= (others => (others => '0')); h_f2v <= (others => (others => '0'));
				h_fn <= (others => (others => '0')); h_f3 <= (others => (others => '0'));
				h_f4 <= (others => (others => '0')); h_f2n <= (others => (others => '0'));
				r_v <= (others => '0'); r_n <= (others => '0'); r_n2 <= (others => '0');
				r_vn <= (others => '0'); r_fxy <= (others => '0');
				audio_r <= (others => '0');
			else
				case seq is
				when S_IDLE =>
					if do_sample = '1' then
						-- phase D: snapshot (chip_update has just run in phase C)
						s_va <= filt_va; s_fa <= filt_fa; s_fc <= filt_fc; s_f1 <= filt_f1; s_f3 <= filt_f3;
						s_f2i <= filt_f2 * 16 + filt_f2q;
						s_cl <= closure / 4;
						if to_integer(pitch) >= 72 then s_gi <= 0; else s_gi <= to_integer(pitch(7 downto 3)); end if;
						if pitch(6) = '1' then s_npos <= cur_noise; else s_npos <= '0'; end if;
						s_mute <= muted;
						op <= 0; seq <= S_START;
					end if;

				when S_START =>
					-- shift the input history of the filter this op runs
					case op is
					when 1  => h_f1  <= (r_v,  h_f1(0),  h_f1(1),  h_f1(3),  h_f1(4));
					when 2  => h_f2v <= (r_v,  h_f2v(0), h_f2v(1), h_f2v(3), h_f2v(4));
					when 4  => h_fn  <= (r_n,  h_fn(0),  h_fn(1),  h_fn(3),  h_fn(4));
					when 6  => h_f2n <= (r_n2, h_f2n(0), h_f2n(1), h_f2n(3), h_f2n(4));
					when 8  => h_f3  <= (r_vn, h_f3(0),  h_f3(1),  h_f3(3),  h_f3(4));
					when 10 => h_f4  <= (r_vn, h_f4(0),  h_f4(1),  h_f4(3),  h_f4(4));
					when others => null;
					end case;
					acc <= (others => '0');
					term <= 0; seq <= S_ISSUE;

				when S_ISSUE =>
					-- one term per cycle: coefficient address + data operand
					n := term;
					p1_sel_f2 <= '0';
					a_misc <= 0; a_f2 <= 0;
					cpos := to_signed(2**VT_DATA_FRAC, DW);
					case op is
					when 0  => a_misc <= VT_MISC_G15 + s_va; din := to_signed(VT_GLOT(s_gi), DW);
					when 1  => a_misc <= VT_MISC_F1 + s_f1 * 8 + n; din := h_f1(n);
					when 2  => a_f2 <= s_f2i * 8 + n; p1_sel_f2 <= '1'; din := h_f2v(n);
					when 3  => a_misc <= VT_MISC_G15 + s_fa;
					           if s_npos = '1' then din := cpos; else din := -cpos; end if;
					when 4  => a_misc <= VT_MISC_FN + n; din := h_fn(n);
					when 5  => a_misc <= VT_MISC_G15 + s_fc; din := r_n;
					when 6  => a_f2 <= s_f2i * 8 + 5 + n; p1_sel_f2 <= '1';
					           if n = 2 then din := h_f2n(3); else din := h_f2n(n); end if;
					when 7  => a_misc <= VT_MISC_ONE;
					           if n = 0 then din := r_v; else din := r_n2; end if;
					when 8  => a_misc <= VT_MISC_F3 + s_f3 * 8 + n; din := h_f3(n);
					when 9  => if n = 0 then a_misc <= VT_MISC_ONE; din := r_vn;
					           else a_misc <= VT_MISC_GN2 + s_fc; din := r_n; end if;
					when 10 => a_misc <= VT_MISC_F4 + n; din := h_f4(n);
					when 11 => a_misc <= VT_MISC_GCL + s_cl; din := r_vn;
					when 12 => a_misc <= VT_MISC_FX + n;
					           if n = 0 then din := r_vn; else din := r_fxy; end if;
					when others => a_misc <= VT_MISC_GOUT; din := r_fxy;
					end case;
					p1_d <= din;
					p1_valid <= '1';
					if term = nterms(op) - 1 then
						seq <= S_DRAIN; drain <= 0;
					else
						term <= term + 1;
					end if;

				when S_DRAIN =>
					-- the last term still needs: ROM read, register, product, accumulate
					if drain = 3 then seq <= S_WB; else drain <= drain + 1; end if;

				when S_WB =>
					res := sat_round(acc);
					case op is
					when 0 | 1 | 2 => r_v <= res;
					when 3 | 4     => r_n <= res;
					when 5 | 6     => r_n2 <= res;
					when 7 | 8 | 9 | 10 | 11 => r_vn <= res;
					when 12        => r_fxy <= res;
					when others    => null;
					end case;
					-- output history of the filters
					case op is
					when 1  => h_f1(4)  <= h_f1(3);  h_f1(3)  <= res;
					when 2  => h_f2v(4) <= h_f2v(3); h_f2v(3) <= res;
					when 4  => h_fn(4)  <= h_fn(3);  h_fn(3)  <= res;
					when 6  => h_f2n(3) <= res;
					when 8  => h_f3(4)  <= h_f3(3);  h_f3(3)  <= res;
					when 10 => h_f4(4)  <= h_f4(3);  h_f4(3)  <= res;
					when others => null;
					end case;
					if op = NOPS - 1 then
						-- output: 1.0 = 8192 (>> DATA_FRAC - 13), clamp to 16 bit
						s16 := shift_right(res, VT_DATA_FRAC - 13);
						if s_mute = '1' then
							audio_r <= (others => '0');
						elsif s16 > 32767 then
							audio_r <= to_signed(32767, 16);
						elsif s16 < -32768 then
							audio_r <= to_signed(-32768, 16);
						else
							audio_r <= s16(15 downto 0);
						end if;
						audio_stb_r <= '1';
						op <= NOPS; seq <= S_IDLE;
					else
						op <= op + 1; seq <= S_START;
					end if;
				end case;
			end if;
		end if;
	end process;

	-- synthesis translate_off
	overrun_check : process(clk)
	begin
		if rising_edge(clk) then
			assert not (do_sample = '1' and seq /= S_IDLE)
				report "votrax_sc01: sample computation overrun" severity failure;
		end if;
	end process;
	-- synthesis translate_on

end rtl;
