-- Board shell of the HW 4.x board (integrated Cyclone 10): the pin names of the v4.01
-- top level, mapped onto the shared core gosof80_core (top\GOSOF80.vhd).
-- BOARD_ID / SW_MINOR come from the generated .qsf (set_parameter).

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
		Audio_O	: buffer std_logic;
		Gottlieb_Test		: in std_logic := '1';  -- test switch of the original board
		Gosof_Test		: in std_logic := '1';     -- GOSOF sound test
		Sound :	in 	std_logic_vector(4 downto 0);
		SB_Opt :	in 	std_logic_vector(1 to 8);  -- DIP 7/8 not wired to the CPU
	   LED_trigger 	: out STD_LOGIC;
		LED_sound 	: out STD_LOGIC;
		LED_CRC_Error 	: out STD_LOGIC;
		LED_SD_Error	: out STD_LOGIC;
		game_sel	:	in 	std_logic_vector(5 downto 0);
		option   :	in 	std_logic_vector(3 downto 0);
		DFP_tx	   : in STD_LOGIC;   -- from the DFPlayer TX, not used
		DFP_rx	   : out STD_LOGIC;  -- to the DFPlayer RX
		SD_CS : buffer 	std_logic;
		SD_MISO : in 	std_logic;
		SD_MOSI : buffer 	std_logic;
		SD_CLK : buffer 	std_logic
		);
end gosof80;

architecture rtl of gosof80 is
	signal trigger : std_logic;
begin
	LED_trigger <= not trigger;
	LED_sound <= not Audio_O;

	core: entity work.gosof80_core
	generic map(BOARD_ID => BOARD_ID, SW_MINOR => SW_MINOR)
	port map(
		clk_50 => clk_50, reset_sw => reset_sw,
		test_sw => Gottlieb_Test, gosof_test => Gosof_Test,
		Audio_O => Audio_O,
		Sound => Sound, SB_Opt => SB_Opt(1 to 6), game_sel => game_sel, option => option,
		trigger_o => trigger, pa7_o => open, sd_error_o => LED_SD_Error, crc_error_o => LED_CRC_Error,
		DFP_txd => DFP_rx,
		SD_CS => SD_CS, SD_MISO => SD_MISO, SD_MOSI => SD_MOSI, SD_CLK => SD_CLK
	);
end rtl;