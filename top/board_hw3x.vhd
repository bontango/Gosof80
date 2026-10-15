-- Board shell of the HW 3.x board (Cyclone IV E board v6): the pin names of the old
-- HW 3.x top level, mapped onto the shared core gosof80_core (top\GOSOF80.vhd).
-- Differences to HW 2.x: SB_Opt 1..8 (7/8 not wired to the CPU), own SD_Error pin,
-- LED_0 off, DFP_rx is an input (not used). BOARD_ID / SW_MINOR from the .qsf.

library ieee;
use ieee.std_logic_1164.all;

entity gosof80 is
	generic(
		BOARD_ID : natural := 0;
		SW_MINOR : natural := 0
	);
	port(
		clk_50	: in std_logic;
		reset_sw	: in std_logic;
		test		: in std_logic := '1';
		Audio_O	: buffer std_logic;
		Sound :	in 	std_logic_vector(4 downto 0);
		SB_Opt :	in 	std_logic_vector(1 to 8);
	   LED_0 	: out STD_LOGIC;   -- off
		LED_1 	: out STD_LOGIC;   -- audio
		LED_2 	: out STD_LOGIC;   -- RIOT PA7 (sound strobe)
		SD_Error	: out STD_LOGIC;
		game_sel	:	in 	std_logic_vector(5 downto 0);
		option   :	in 	std_logic_vector(3 downto 0);
		DFP_tx	   : out STD_LOGIC; -- to the DFPlayer RX
		DFP_rx	   : in STD_LOGIC;  -- not used
		SD_CS : buffer 	std_logic;
		SD_MISO : in 	std_logic;
		SD_MOSI : buffer 	std_logic;
		SD_CLK : buffer 	std_logic
		);
end gosof80;

architecture rtl of gosof80 is
begin
	LED_0 <= '1';
	LED_1 <= not Audio_O;

	core: entity work.gosof80_core
	generic map(BOARD_ID => BOARD_ID, SW_MINOR => SW_MINOR)
	port map(
		clk_50 => clk_50, reset_sw => reset_sw,
		test_sw => test, gosof_test => '1',
		Audio_O => Audio_O,
		Sound => Sound, SB_Opt => SB_Opt(1 to 6), game_sel => game_sel, option => option,
		trigger_o => open, pa7_o => LED_2, sd_error_o => SD_Error, crc_error_o => open,
		DFP_txd => DFP_tx,
		SD_CS => SD_CS, SD_MISO => SD_MISO, SD_MOSI => SD_MOSI, SD_CLK => SD_CLK
	);
end rtl;