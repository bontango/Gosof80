-- Core of GOSOF80B for the Gottlieb System 80B sound board MA-886 (generations 2 and 3)
-- by bontango www.lisy.dev
--
-- This is free software: you can redistribute
-- it and/or modify it under the terms of the GNU General
-- Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your
-- option) any later version.
--
-- This is distributed in the hope that it will
-- be useful, but WITHOUT ANY WARRANTY; without even the
-- implied warranty of MERCHANTABILITY or FITNESS FOR A
-- PARTICULAR PURPOSE. See the GNU General Public License
-- for more details.
--
-- GEN = 2: Victory, Diamond Lady, TX-Sector, Robo-War, Excalibur. 2 x AY-3-8913 + filter MF-4.
-- GEN = 3: Bad Girls, Big House, Hot Shots, Night Moves. YM2151 (jt51), right channel only.
-- One bitstream per generation, both together do not fit into the EP4CE6. Bone Busters (third CPU)
-- does not fit at all. Sources: schematics E-26146 and E-25549 (Gosof80B\schematics), PinMAME
-- src\wpc\gts80s.c. Details: docs\MA-886_Evaluierung.md. The MA-766 has its own core GOSOF80B.vhd.
--
-- Clocks as on the board, 4 MHz crystal through the 74161 S1: CPU 2 MHz (JP5), AY 2 MHz, NMI
-- counters 250 kHz. Here from clk_50 with a divider, no PLL. 25 clk_50 per bus cycle.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gosof80b_886_core is
	generic(
		GEN : natural := 2   -- 2 or 3
	);
	port(
		clk_50	: in std_logic;
		reset_sw	: in std_logic;
		gosof_test	: in std_logic;  -- GOSOF sound test, '0' = pressed
		Audio_O	: buffer std_logic;

		-- Sound input S1,S2,S4,S8,S16: '1' = line of the MPU low (ULN2803 on the board)
		Sound :	in 	std_logic_vector(4 downto 0);

		-- SB_Opt(3): JP8 of the original, ON ('0') = S16 also triggers a sound
		SB_Opt :	in 	std_logic_vector(1 to 3);
		game_sel	:	in 	std_logic_vector(5 downto 0);

		-- signals for the board LEDs
		trigger_o	: out std_logic;  -- a sound line is active
		diag_led_o	: out std_logic;  -- LED D1 of the original, driven by the Y CPU, '1' = on
		flash_error_o	: out std_logic;  -- '0' = flash slot empty (blinks)

		-- configuration flash with the game ROMs
		FLASH_CS : buffer 	std_logic;
		FLASH_MISO : in 	std_logic;
		FLASH_MOSI : buffer 	std_logic;
		FLASH_CLK : buffer 	std_logic;

		-- SRAM with the game ROMs at run time
		sram_a    : out std_logic_vector(16 downto 0);
		sram_di   : in  std_logic_vector(7 downto 0);
		sram_do   : out std_logic_vector(7 downto 0);
		sram_oe_d : out std_logic;
		sram_we_n : out std_logic;
		sram_oe_n : out std_logic
	);
end gosof80b_886_core;

architecture rtl of gosof80b_886_core is

	component jt51 is
	port(
		rst, clk, cen, cen_p1, cs_n, wr_n, a0 : in std_logic;
		din : in std_logic_vector(7 downto 0);
		dout : out std_logic_vector(7 downto 0);
		ct1, ct2, irq_n, sample : out std_logic;
		left, right, xleft, xright : out std_logic_vector(15 downto 0)
	);
	end component;

	-- 64 KB per game in the flash: +0000 yrom, +8000 drom
	constant SLOT_BYTES : integer := 65536;

	signal div_cnt		: integer range 0 to 24 := 0;
	signal cpu_clk		: std_logic := '0'; -- 2 MHz
	signal ay_en		: std_logic := '0'; -- 2 MHz, one clk_50 wide
	signal uart_clk	: std_logic;        -- sound test only
	signal reset_l		: std_logic;        -- controlled by the flash loader

	-- flash loader
	signal address_rom	: std_logic_vector(15 downto 0);
	signal data_rom		: std_logic_vector(7 downto 0);
	signal wr_rom			: std_logic;

	-- Y CPU
	signal y_a24		: std_logic_vector(23 downto 0);  -- the T65 has 24 address bits
	signal y_addr		: std_logic_vector(15 downto 0);
	signal y_din		: std_logic_vector(7 downto 0);
	signal y_dout		: std_logic_vector(7 downto 0);
	signal y_rw_n		: std_logic;
	signal y_irq_n		: std_logic := '1';
	signal y_nmi_n		: std_logic := '1';
	signal yram_dout	: std_logic_vector(7 downto 0);
	signal yram_wr		: std_logic;
	signal yrom_dout	: std_logic_vector(7 downto 0);
	signal y_rd_latch	: std_logic;
	signal y_dnmi_cs	: std_logic;

	-- D CPU
	signal d_a24		: std_logic_vector(23 downto 0);
	signal d_addr		: std_logic_vector(15 downto 0);
	signal d_din		: std_logic_vector(7 downto 0);
	signal d_dout		: std_logic_vector(7 downto 0);
	signal d_rw_n		: std_logic;
	signal d_irq_n		: std_logic := '1';
	signal d_nmi_n		: std_logic := '1';
	signal d_nmi_cnt	: integer range 0 to 3 := 0;
	signal dram_dout	: std_logic_vector(7 downto 0);
	signal dram_wr		: std_logic;
	signal drom_dout	: std_logic_vector(7 downto 0);
	signal d_rd_latch	: std_logic;

	-- sound command: Sound -> A2 (trigger) / A3 (latch) / A4 (IRQ flip-flops)
	signal test_activ	: std_logic;
	signal test_sound	: std_logic_vector(4 downto 0);
	signal sound_mux	: std_logic_vector(4 downto 0);
	signal sound_in	: std_logic_vector(4 downto 0);
	signal trigger		: std_logic;
	signal trigger_d	: std_logic := '0';
	signal strobe_cnt	: integer range 0 to 8 := 0;
	signal sound_latch : std_logic_vector(7 downto 0) := x"FF";

	-- Y CPU I/O
	signal ctrl			: std_logic_vector(7 downto 0) := x"00"; -- $A000, LS377 G3
	signal ay_latch	: std_logic_vector(7 downto 0) := x"00"; -- $8000, LS377 N4 (generation 2)
	signal mf4_n		: std_logic_vector(7 downto 0) := x"00"; -- $2000, E3 (generation 2)
	signal ym_data		: std_logic_vector(7 downto 0) := x"00"; -- $4000 (generation 3)
	signal ym_wr_n		: std_logic := '1';
	signal nmi_rate	: unsigned(7 downto 0) := x"00";         -- $6000, LS374 S5
	signal nmi_pre		: unsigned(10 downto 0) := (others => '0'); -- 2 MHz /8 = S1 QD, H5 + K5 /256
	signal nmi_cnt		: unsigned(7 downto 0) := x"00";         -- N5 + T5
	signal nmi_rco		: std_logic;

	-- sound
	signal dac_vol		: unsigned(7 downto 0) := x"00"; -- $8000 D CPU, second DAC of E2 = reference
	signal dac_data	: unsigned(7 downto 0) := x"00"; -- $8001 D CPU
	signal dac_prod	: unsigned(15 downto 0) := (others => '0');
	signal lp_cnt		: unsigned(9 downto 0) := (others => '0');
	signal lp1, lp2, lp3 : signed(22 downto 0) := (others => '0');
	signal dac_filt	: unsigned(15 downto 0);
	signal synth_mix	: unsigned(16 downto 0) := (others => '0'); -- generation dependent part of the mixer
	signal audio_mix	: unsigned(16 downto 0) := (others => '0');

begin

trigger_o <= trigger;
diag_led_o <= not ctrl(1);  -- LED D1 hangs between +5V and G3 Q2

-- CPU clock 2 MHz (register) and enable for the AY-3-8913 2 MHz
Clocks: process(clk_50) is
begin
	if rising_edge(clk_50) then
		if div_cnt = 24 then div_cnt <= 0; else div_cnt <= div_cnt + 1; end if;
		if div_cnt < 12 then cpu_clk <= '0'; else cpu_clk <= '1'; end if;
		if div_cnt = 0 then ay_en <= '1'; else ay_en <= '0'; end if;
	end if;
end process;

-- 9600 baud clock, here only the time base of the sound test
uart_gen: entity work.uart_clk_gen
port map(
	clk_in => clk_50,
	uart_clk_out	=> uart_clk
);

-- sound test (switch Gosof_Test): plays sound 1..31, 5 s each
STEST: entity work.soundtest
port map(
	i_Rst_L	=> reset_l,
	clk_in	=> uart_clk,
	start 	=> gosof_test,
	test_activ => test_activ,
	sound => test_sound
);

sound_mux <= Sound when test_activ = '0' else test_sound;

META1: entity work.Cross_Slow_To_Fast_Clock_Bus
port map(
	i_D => sound_mux,
	o_Q => sound_in,
	i_Fast_Clk => cpu_clk
);

-- A2 (7430): any line low triggers. S16 only over JP8, as SW3 on the MA-766.
trigger <= sound_in(0) or sound_in(1) or sound_in(2) or sound_in(3) or (sound_in(4) and not SB_Opt(3));

-- As on the MA-766: the rising edge of A2 pin 8, delayed by the .01 uF, clocks the latch A3 and the
-- IRQ flip-flops A4. Same 4 us delay as there. Reading the latch clears the IRQ of that CPU.
Sound_Command: process(cpu_clk) is
begin
	if rising_edge(cpu_clk) then
		trigger_d <= trigger;
		if reset_l = '0' then
			y_irq_n <= '1';
			d_irq_n <= '1';
			strobe_cnt <= 0;
			sound_latch <= x"FF";
		else
			if y_rd_latch = '1' then y_irq_n <= '1'; end if;
			if d_rd_latch = '1' then d_irq_n <= '1'; end if;
			if trigger = '1' and trigger_d = '0' then
				strobe_cnt <= 8;
			elsif strobe_cnt /= 0 then
				strobe_cnt <= strobe_cnt - 1;
				if strobe_cnt = 1 then
					sound_latch <= "111" & not sound_in;
					y_irq_n <= '0';
					d_irq_n <= '0';
				end if;
			end if;
		end if;
	end if;
end process;

----------------------------------------------------------------------
-- Y section. T4 (LS138) decodes A15..A13, S2 (LS139) inside $6000-$7FFF A12, A11.
-- Reads of $8000-$FFFF go to the ROM, writes to the registers.
----------------------------------------------------------------------
y_addr <= y_a24(15 downto 0);
yram_wr <= '1' when y_addr(15 downto 13) = "000" and y_rw_n = '0' else '0';
y_rd_latch <= '1' when y_addr(15 downto 11) = "01101" and y_rw_n = '1' else '0';  -- $6800
y_dnmi_cs <= '1' when y_addr(15 downto 11) = "01110" else '0';                    -- $7000, read or write

-- $4000 has no input register on these boards, open bus. Only Victory reads it, once.
y_din <=
	yram_dout when y_addr(15 downto 13) = "000" else
	sound_latch when y_addr(15 downto 11) = "01101" else
	yrom_dout when y_addr(15) = '1' else
	x"FF";

Y_Registers: process(cpu_clk) is
begin
	if rising_edge(cpu_clk) then
		ym_wr_n <= '1';
		if reset_l = '0' then
			ctrl <= x"00";
		elsif y_rw_n = '0' then
			case y_addr(15 downto 13) is
				when "101" => ctrl <= y_dout;      -- $A000
				when "001" => mf4_n <= y_dout;     -- $2000
				when "100" => ay_latch <= y_dout;  -- $8000
				when "010" =>                      -- $4000: /CS and /WR of the YM2151
					ym_data <= y_dout;
					ym_wr_n <= '0';
				when "011" =>
					if y_addr(12 downto 11) = "00" then  -- $6000
						nmi_rate <= unsigned(y_dout);
					end if;
				when others => null;
			end case;
		end if;
	end if;
end process;

-- NMI of the Y CPU, as on the MA-766: S1 QD (250 kHz), H5 + K5 give one tick per 1024 us, on it
-- N5 + T5 count up and reload the rate, so period = (256 - rate) * 1024 us. Here counted in 2 MHz.
nmi_rco <= '1' when nmi_pre(10 downto 3) = x"FF" and nmi_cnt = x"FF" else '0';
y_nmi_n <= not (nmi_rco and ctrl(0));

NMI_Timer: process(cpu_clk) is
begin
	if rising_edge(cpu_clk) then
		nmi_pre <= nmi_pre + 1;
		if nmi_pre = "11111111111" then
			if nmi_cnt = x"FF" then
				nmi_cnt <= nmi_rate;
			else
				nmi_cnt <= nmi_cnt + 1;
			end if;
		end if;
	end if;
end process;

-- NMI of the D CPU, any access to $7000. Four clocks low: the T65 can miss a shorter edge during
-- a taken branch.
D_NMI: process(cpu_clk) is
begin
	if rising_edge(cpu_clk) then
		if reset_l = '0' then
			d_nmi_cnt <= 0;
			d_nmi_n <= '1';
		elsif y_dnmi_cs = '1' then
			d_nmi_cnt <= 3;
			d_nmi_n <= '0';
		elsif d_nmi_cnt /= 0 then
			d_nmi_cnt <= d_nmi_cnt - 1;
		else
			d_nmi_n <= '1';
		end if;
	end if;
end process;

YCPU: entity work.T65
port map(
	Enable => '1',
	Mode => "00",
	Res_n => reset_l,
	Clk => cpu_clk,
	Rdy => '1',
	Abort_n => '1',
	IRQ_n => y_irq_n,
	NMI_n => y_nmi_n,
	SO_n => '1',
	R_W_n => y_rw_n,
	A => y_a24,
	DI => y_din,
	DO => y_dout
);

YRAM: entity work.RAM -- 2 KByte
port map(
	address	=> y_addr(10 downto 0),
	clock		=> clk_50,
	data		=> y_dout,
	wren 		=> yram_wr,
	q			=> yram_dout
);

----------------------------------------------------------------------
-- Generation 2: 2 x AY-3-8913, K4 additionally through the MF-4.
-- $A000 bit 2 = BDIR, bit 3 selects the chip (1 = K4), bit 4 = BC1, data from the latch $8000.
-- Weights: PinMAME AY 25 + 25 against DAC 50. Filter path from the schematic: K4 reaches the
-- summer directly over R13 3k, behind H1 (gain 3.7) and the MF-4 over R15 18k, so 3.7 * 3 / 18 = 0.62
-- of the direct path. Read from a coarse scan, to be checked by ear.
----------------------------------------------------------------------
GEN2: if GEN = 2 generate
	signal k4_mix, h4_mix : unsigned(13 downto 0);
	signal mf4_in, mf4_out : signed(15 downto 0);
begin
	K4: entity work.ym2149_audio
	port map(
		clk_i => clk_50,
		en_clk_psg_i => ay_en,
		sel_n_i => '1',
		reset_n_i => reset_l,
		bc_i => ctrl(4),
		bdir_i => ctrl(2) and ctrl(3),
		data_i => ay_latch,
		data_r_o => open,
		ch_a_o => open,
		ch_b_o => open,
		ch_c_o => open,
		mix_audio_o => k4_mix,
		pcm14s_o => open
	);
	H4: entity work.ym2149_audio
	port map(
		clk_i => clk_50,
		en_clk_psg_i => ay_en,
		sel_n_i => '1',
		reset_n_i => reset_l,
		bc_i => ctrl(4),
		bdir_i => ctrl(2) and not ctrl(3),
		data_i => ay_latch,
		data_r_o => open,
		ch_a_o => open,
		ch_b_o => open,
		ch_c_o => open,
		mix_audio_o => h4_mix,
		pcm14s_o => open
	);

	-- C7 takes the DC away, half of the range of an AY (3 * 4095) as a fixed offset does the same here
	mf4_in <= signed("00" & k4_mix) - 6144;
	MF4: entity work.mf4_filter
	port map(clk => clk_50, n => mf4_n, audio_in => mf4_in, audio_out => mf4_out);

	process(clk_50) is
		variable filt : signed(16 downto 0);
	begin
		if rising_edge(clk_50) then
			-- 5/8 of the filter output, centred at 8192. Peak about +-7000 * 5/8.
			filt := resize(shift_right(mf4_out, 1), 17) + resize(shift_right(mf4_out, 3), 17) + 8192;
			synth_mix <= ("000" & k4_mix) + ("000" & h4_mix) + unsigned(filt);
		end if;
	end process;
end generate;

----------------------------------------------------------------------
-- Generation 3: YM2151 on the auxiliary board A20 / MA-1294. 4 MHz, /CS and /WR from $4000, A0 from
-- $A000 bit 7, /RD high, IRQ and CT not connected. Only SH2 of the YM3014 is connected, so right
-- channel only. Weight: PinMAME YM 75 against DAC 50.
----------------------------------------------------------------------
GEN3: if GEN = 3 generate
	signal ym_acc : unsigned(4 downto 0) := (others => '0');
	signal ym_cen, ym_cen_p1, ym_phase : std_logic := '0';
	signal ym_rst : std_logic;
	signal ym_right : std_logic_vector(15 downto 0);
	signal ym_u : unsigned(15 downto 0);
begin
	-- 4 MHz = 50 MHz * 2 / 25, cen_p1 at half of it
	process(clk_50) is
		variable a : unsigned(5 downto 0);
	begin
		if rising_edge(clk_50) then
			a := ('0' & ym_acc) + 2;
			if a >= 25 then
				ym_acc <= resize(a - 25, 5);
				ym_cen <= '1';
				ym_phase <= not ym_phase;
				ym_cen_p1 <= ym_phase;
			else
				ym_acc <= a(4 downto 0);
				ym_cen <= '0';
				ym_cen_p1 <= '0';
			end if;
		end if;
	end process;

	ym_rst <= not reset_l;
	YM: jt51
	port map(
		rst => ym_rst, clk => clk_50, cen => ym_cen, cen_p1 => ym_cen_p1,
		cs_n => ym_wr_n, wr_n => ym_wr_n, a0 => ctrl(7), din => ym_data,
		dout => open, ct1 => open, ct2 => open, irq_n => open, sample => open,
		left => open, right => ym_right, xleft => open, xright => open
	);

	ym_u <= unsigned(not ym_right(15) & ym_right(14 downto 0));  -- offset binary

	process(clk_50) is
	begin
		if rising_edge(clk_50) then
			synth_mix <= ("00" & ym_u(15 downto 1)) + ("000" & ym_u(15 downto 2));
		end if;
	end process;
end generate;

----------------------------------------------------------------------
-- D section. S2 (LS139) decodes A15, A14: $4000 latch, $8000 DAC (write), ROM at $8000-$FFFF (read)
----------------------------------------------------------------------
d_addr <= d_a24(15 downto 0);
dram_wr <= '1' when d_addr(15 downto 14) = "00" and d_rw_n = '0' else '0';
d_rd_latch <= '1' when d_addr(15 downto 14) = "01" and d_rw_n = '1' else '0';  -- $4000

d_din <=
	dram_dout when d_addr(15 downto 14) = "00" else
	sound_latch when d_addr(15 downto 14) = "01" else
	drom_dout when d_addr(15) = '1' else
	x"FF";

D_Registers: process(cpu_clk) is
begin
	if rising_edge(cpu_clk) then
		if reset_l = '0' then
			dac_vol <= x"00";
			dac_data <= x"00";
		elsif d_rw_n = '0' and d_addr(15 downto 14) = "10" then
			if d_addr(0) = '0' then
				dac_vol <= unsigned(d_dout);
			else
				dac_data <= unsigned(d_dout);
			end if;
		end if;
	end if;
end process;

DCPU: entity work.T65
port map(
	Enable => '1',
	Mode => "00",
	Res_n => reset_l,
	Clk => cpu_clk,
	Rdy => '1',
	Abort_n => '1',
	IRQ_n => d_irq_n,
	NMI_n => d_nmi_n,
	SO_n => '1',
	R_W_n => d_rw_n,
	A => d_a24,
	DI => d_din,
	DO => d_dout
);

DRAM: entity work.RAM -- 2 KByte
port map(
	address	=> d_addr(10 downto 0),
	clock		=> clk_50,
	data		=> d_dout,
	wren 		=> dram_wr,
	q			=> dram_dout
);

----------------------------------------------------------------------
-- Low pass of the DAC, op amps A5 of the schematic: 2nd order 3.25 kHz (R61, R62, C35, C36), 1st
-- order 1.46 kHz (R64, C38). Here three first order stages at 50 MHz / 1024, shifts only:
-- 5/16 is 3 kHz, 3/16 is 1.6 kHz. The Q of 0.74 of the first filter is not modelled.
----------------------------------------------------------------------
dac_filt <= unsigned(std_logic_vector(lp3(21 downto 6)));

DAC_Lowpass: process(clk_50) is
	variable d : signed(22 downto 0);
begin
	if rising_edge(clk_50) then
		dac_prod <= dac_vol * dac_data;
		lp_cnt <= lp_cnt + 1;
		if lp_cnt = 0 then
			d := signed("0" & dac_prod & "000000") - lp1;
			lp1 <= lp1 + shift_right(d, 2) + shift_right(d, 4);
			d := lp1 - lp2;
			lp2 <= lp2 + shift_right(d, 2) + shift_right(d, 4);
			d := lp2 - lp3;
			lp3 <= lp3 + shift_right(d, 3) + shift_right(d, 4);
		end if;
	end if;
end process;

----------------------------------------------------------------------
-- Mixer and output. DAC / 2 is at most 32512, generation 2 at most 12285 * 2 + 12600, generation 3
-- at most 49151: no overflow in 17 bit.
----------------------------------------------------------------------
Audio_Mixer: process(clk_50) is
begin
	if rising_edge(clk_50) then
		audio_mix <= ("00" & dac_filt(15 downto 1)) + synth_mix;
	end if;
end process;

Audio_DAC : entity work.dac
generic map(
  msbi_g => 16)
port  map(
   clk_i   => clk_50,
   res_n_i => reset_l,
   dac_i   => std_logic_vector(audio_mix),
   dac_o   => Audio_O
);

----------------------------------------------------------------------
-- ROMs: the flash loader fills the SRAM before reset_l goes high
----------------------------------------------------------------------
FLASH: entity work.sd_reader
generic map(Read_Bytes => SLOT_BYTES, Slot_Bytes => SLOT_BYTES)
port map(
	clk		=> clk_50,
	rst_l		=> reset_sw,
	spi_clk	=> FLASH_CLK,
	spi_miso	=> FLASH_MISO,
	spi_mosi	=> FLASH_MOSI,
	spi_cs_n	=> FLASH_CS,
	selection => "00" & not game_sel,
	address_sd_card => address_rom,
	data_sd_card => data_rom,
	wr_rom => wr_rom,
	cpu_reset_l => reset_l,
	sd_error => flash_error_o,
	crc_error => open
);

SRAM: entity work.sram_arbiter
port map(
	clk => clk_50,
	phase => div_cnt,
	run => reset_l,
	wr => wr_rom,
	wr_addr => address_rom,
	wr_data => data_rom,
	y_addr => y_addr(14 downto 0),
	d_addr => d_addr(14 downto 0),
	y_q => yrom_dout,
	d_q => drom_dout,
	sram_a => sram_a,
	sram_di => sram_di,
	sram_do => sram_do,
	sram_oe_d => sram_oe_d,
	sram_we_n => sram_we_n,
	sram_oe_n => sram_oe_n
);

end rtl;
