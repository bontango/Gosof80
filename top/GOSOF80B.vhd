-- Core of GOSOF80B: FPGA version of the Gottlieb System 80B sound board MA-766 (generation 1)
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
-- Games: Rock, Raven, Rock Encore, Hollywood Heat, Genesis, Gold Wings, Monte Carlo,
-- Spring Break, Arena. Sources: schematic E-24711 (Gosof80B\schematics) and PinMAME
-- src\wpc\gts80s.c. Details and differences: docs\GOSOF80B_MA766.md.
--
-- Y section: 6502, 2 KB RAM, yrom2 at $C000, yrom1 at $E000 (the vectors), 2 x AY-3-8913,
--            SP0250 (no speech, but all games make sound effects with it).
-- D section: 6502, 2 KB RAM, drom at $E000, AD7528 (one DAC is the reference of the other,
--            so the output is volume * data).
--
-- Clocks as on the board, 4 MHz crystal through the 74161 S1: CPU 1 MHz, AY 2 MHz, NMI
-- counters 250 kHz. Here from clk_50 with a divider, no PLL (PLL of one core board was dead).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gosof80b_core is
	port(
		clk_50	: in std_logic;
		reset_sw	: in std_logic;
		test_sw	: in std_logic;  -- SW1 of the original board, '0' = pressed
		gosof_test	: in std_logic;  -- GOSOF sound test, '0' = pressed
		Audio_O	: buffer std_logic;

		-- Sound input S1,S2,S4,S8,S16: '1' = line of the MPU low (ULN2803 on the board)
		Sound :	in 	std_logic_vector(4 downto 0);

		-- SB_Opt(1), (2): DIP positions 1 and 2 of the original, read at $6000 D5, D4
		-- SB_Opt(3): DIP position 3 (SW3) of the original, ON ('0') = S16 also triggers a sound
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
		FLASH_CLK : buffer 	std_logic
	);
end gosof80b_core;

architecture rtl of gosof80b_core is

	-- 24 KB per game in the flash: +0000 yrom1, +2000 yrom2, +4000 drom
	constant SLOT_BYTES : integer := 24576;

	signal div_cnt		: integer range 0 to 49 := 0;
	signal cpu_clk		: std_logic := '0'; -- 1 MHz
	signal ay_en		: std_logic := '0'; -- 2 MHz, one clk_50 wide
	signal uart_clk	: std_logic;        -- sound test only
	signal reset_l		: std_logic;        -- controlled by the flash loader

	-- flash loader
	signal address_rom	: std_logic_vector(15 downto 0);
	signal data_rom		: std_logic_vector(7 downto 0);
	signal wr_rom			: std_logic;
	signal wr_yrom1		: std_logic;
	signal wr_yrom2		: std_logic;
	signal wr_drom			: std_logic;
	signal yrom1_addr		: std_logic_vector(12 downto 0);
	signal yrom2_addr		: std_logic_vector(12 downto 0);
	signal drom_addr		: std_logic_vector(12 downto 0);

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
	signal yrom1_dout	: std_logic_vector(7 downto 0);
	signal yrom2_dout	: std_logic_vector(7 downto 0);
	signal y_inputs	: std_logic_vector(7 downto 0);
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
	signal strobe_cnt	: integer range 0 to 4 := 0;
	signal sound_latch : std_logic_vector(7 downto 0) := x"FF";
	signal test_meta	: std_logic := '1';
	signal test_sync	: std_logic := '1';

	-- Y CPU I/O
	signal ctrl			: std_logic_vector(7 downto 0) := x"00"; -- $4000, LS374 G3
	signal ay_latch	: std_logic_vector(7 downto 0) := x"00"; -- $8000, LS374 N4
	signal sp_latch	: std_logic_vector(7 downto 0) := x"00"; -- $2000, LS374 E3
	signal nmi_rate	: unsigned(7 downto 0) := x"00";         -- $A000, LS374 S5
	signal nmi_pre		: unsigned(9 downto 0) := (others => '0'); -- S1 /4, H5 + K5 /256
	signal nmi_cnt		: unsigned(7 downto 0) := x"00";         -- N5 + T5
	signal nmi_rco		: std_logic;

	-- sound
	signal ay0_mix		: unsigned(13 downto 0);
	signal ay1_mix		: unsigned(13 downto 0);
	signal sp_drq		: std_logic;
	signal sp_audio	: signed(15 downto 0);
	signal dac_vol		: unsigned(7 downto 0) := x"00"; -- $4000 D CPU, second DAC of E2 = reference
	signal dac_data	: unsigned(7 downto 0) := x"00"; -- $4001 D CPU
	signal dac_prod	: unsigned(15 downto 0) := (others => '0');
	signal audio_mix	: unsigned(16 downto 0) := (others => '0');

begin

trigger_o <= trigger;
diag_led_o <= not ctrl(1);  -- LED D1 hangs between +5V and G3 Q2

-- CPU clock 1 MHz (register, as Gosof_PLL on Cyclone II) and enable for the AY-3-8913 2 MHz
Clocks: process(clk_50) is
begin
	if rising_edge(clk_50) then
		if div_cnt = 49 then div_cnt <= 0; else div_cnt <= div_cnt + 1; end if;
		if div_cnt < 25 then cpu_clk <= '0'; else cpu_clk <= '1'; end if;
		if div_cnt = 0 or div_cnt = 25 then ay_en <= '1'; else ay_en <= '0'; end if;
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

-- A2 (7430): any line low triggers. S16 only over SW3, on the original SW3 is off and
-- SW4 on (PinWiki: DIP 1-3 off, 4 on). S32..S128 are not wired on the MPU side.
trigger <= sound_in(0) or sound_in(1) or sound_in(2) or sound_in(3) or (sound_in(4) and not SB_Opt(3));

-- The rising edge of A2 pin 8 clocks the latch A3 and the IRQ flip-flops A4, delayed by the
-- .01 uF at the output. The latch holds the levels of the lines, S32..S128 are pulled up.
-- Reading the latch clears the IRQ of that CPU, both CPUs read the same latch.
Sound_Command: process(cpu_clk) is
begin
	if rising_edge(cpu_clk) then
		test_meta <= test_sw;
		test_sync <= test_meta;
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
				strobe_cnt <= 4;
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
-- Y section. T4 (LS138) decodes A15..A13, S2 (LS139) inside $A000-$BFFF A12, A11
----------------------------------------------------------------------
y_addr <= y_a24(15 downto 0);
yram_wr <= '1' when y_addr(15 downto 13) = "000" and y_rw_n = '0' else '0';
y_rd_latch <= '1' when y_addr(15 downto 11) = "10101" and y_rw_n = '1' else '0';  -- $A800
y_dnmi_cs <= '1' when y_addr(15 downto 11) = "10110" else '0';                    -- $B000, read or write

-- $6000: B3 (LS244). D7 = DATA REQUEST of the SP0250, D6 = SW1, D5, D4 = DIP positions 1, 2,
-- D3..D0 only pull-ups
y_inputs <= sp_drq & test_sync & SB_Opt(1) & SB_Opt(2) & "1111";

y_din <=
	yram_dout when y_addr(15 downto 13) = "000" else
	y_inputs when y_addr(15 downto 13) = "011" else
	sound_latch when y_addr(15 downto 11) = "10101" else
	yrom2_dout when y_addr(15 downto 13) = "110" else
	yrom1_dout when y_addr(15 downto 13) = "111" else
	x"FF";

Y_Registers: process(cpu_clk) is
begin
	if rising_edge(cpu_clk) then
		if reset_l = '0' then
			ctrl <= x"00";
		elsif y_rw_n = '0' then
			case y_addr(15 downto 13) is
				when "010" => ctrl <= y_dout;      -- $4000
				when "001" => sp_latch <= y_dout;  -- $2000
				when "100" => ay_latch <= y_dout;  -- $8000
				when "101" =>
					if y_addr(12 downto 11) = "00" then  -- $A000
						nmi_rate <= unsigned(y_dout);
					end if;
				when others => null;
			end case;
		end if;
	end if;
end process;

-- NMI of the Y CPU. H5 + K5 give one tick per 1024 us, on it N5 + T5 count up and reload the
-- rate behind 255 (carry of T5 -> LOAD of both), so period = (256 - rate) * 1024 us.
-- PinMAME has 16-lo * 16-hi here, the schematic says otherwise. Equal for lo = 0.
-- The carry is high for one 250 kHz clock, G5 gates it with $4000 bit 0.
nmi_rco <= '1' when nmi_pre(9 downto 2) = x"FF" and nmi_cnt = x"FF" else '0';
y_nmi_n <= not (nmi_rco and ctrl(0));

NMI_Timer: process(cpu_clk) is
begin
	if rising_edge(cpu_clk) then
		nmi_pre <= nmi_pre + 1;
		if nmi_pre = "1111111111" then
			if nmi_cnt = x"FF" then
				nmi_cnt <= nmi_rate;
			else
				nmi_cnt <= nmi_cnt + 1;
			end if;
		end if;
	end if;
end process;

-- NMI of the D CPU, any access to $B000. Four clocks low like the Y NMI: the T65 can miss an
-- edge during a taken branch, the idle loops of the games are branches.
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

-- $4000 bit 2 = BDIR, bit 3 selects the chip, bit 4 = BC1, data from the latch $8000.
-- BC2 is high on the board. Level on the chip, as on the board.
AY0: entity work.ym2149_audio
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
	mix_audio_o => ay0_mix,
	pcm14s_o => open
);
AY1: entity work.ym2149_audio
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
	mix_audio_o => ay1_mix,
	pcm14s_o => open
);

-- $4000 bit 6 = DATA PRESENT of the SP0250, data from the latch $2000. The other two bits there,
-- 5 = DIRECT DATA TEST and 7 = RESET, have no function in the model, as in PinMAME.
SP: entity work.sp0250
port map(
	clk => clk_50,
	rst_n => reset_l,
	data => sp_latch,
	stb => ctrl(6),
	drq => sp_drq,
	audio => sp_audio
);

----------------------------------------------------------------------
-- D section. S2 (LS139) decodes A15, A14
----------------------------------------------------------------------
d_addr <= d_a24(15 downto 0);
dram_wr <= '1' when d_addr(15 downto 14) = "00" and d_rw_n = '0' else '0';
d_rd_latch <= '1' when d_addr(15 downto 14) = "10" and d_rw_n = '1' else '0';  -- $8000

d_din <=
	dram_dout when d_addr(15 downto 14) = "00" else
	sound_latch when d_addr(15 downto 14) = "10" else
	drom_dout when d_addr(15 downto 14) = "11" else
	x"FF";

D_Registers: process(cpu_clk) is
begin
	if rising_edge(cpu_clk) then
		if reset_l = '0' then
			dac_vol <= x"00";
			dac_data <= x"00";
		elsif d_rw_n = '0' and d_addr(15 downto 14) = "01" then
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
-- Mixer and output. Weights as PinMAME: DAC 50, SP0250 50, AY 25 + 25. dac_prod / 2 is at most
-- 32512, the SP0250 / 2 at most 32767 with its offset, an AY at most 3 * 4095: 89849 in 17 bit,
-- so the sum cannot overflow. Coupled by the capacitors of the board.
----------------------------------------------------------------------
Audio_Mixer: process(clk_50) is
begin
	if rising_edge(clk_50) then
		dac_prod <= dac_vol * dac_data;
		audio_mix <= ("00" & dac_prod(15 downto 1)) + ("000" & ay0_mix) + ("000" & ay1_mix)
		             + ("00" & unsigned(not sp_audio(15) & sp_audio(14 downto 1)));
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
-- ROMs, filled by the flash loader before reset_l goes high
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

wr_yrom1 <= '1' when wr_rom = '1' and address_rom(15 downto 13) = "000" else '0';
wr_yrom2 <= '1' when wr_rom = '1' and address_rom(15 downto 13) = "001" else '0';
wr_drom  <= '1' when wr_rom = '1' and address_rom(15 downto 13) = "010" else '0';

yrom1_addr <= address_rom(12 downto 0) when wr_yrom1 = '1' else y_addr(12 downto 0);
yrom2_addr <= address_rom(12 downto 0) when wr_yrom2 = '1' else y_addr(12 downto 0);
drom_addr  <= address_rom(12 downto 0) when wr_drom = '1' else d_addr(12 downto 0);

YROM1: entity work.ROM -- 8 KByte
port map(
	address	=> yrom1_addr,
	clock		=> clk_50,
	data 		=> data_rom,
	wren 		=> wr_yrom1,
	q			=> yrom1_dout
);
YROM2: entity work.ROM -- 8 KByte
port map(
	address	=> yrom2_addr,
	clock		=> clk_50,
	data 		=> data_rom,
	wren 		=> wr_yrom2,
	q			=> yrom2_dout
);
DROM: entity work.ROM -- 8 KByte
port map(
	address	=> drom_addr,
	clock		=> clk_50,
	data 		=> data_rom,
	wren 		=> wr_drom,
	q			=> drom_dout
);

end rtl;
