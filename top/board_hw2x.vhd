-- Board shell of the HW 2.x boards (Cyclone II, Cyclone IV v3/v4, Cyclone 10):
-- the pin names of the old top level, mapped onto the shared core gosof80_core
-- (top\GOSOF80.vhd). BOARD_ID / SW_MINOR come from the generated .qsf (set_parameter).

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
		SB_Opt :	in 	std_logic_vector(1 to 6);
	   LED_0 	: out STD_LOGIC;   -- SD card error
		LED_1 	: out STD_LOGIC;   -- audio
		LED_2 	: out STD_LOGIC;   -- RIOT PA7 (sound strobe)
		game_sel	:	in 	std_logic_vector(5 downto 0);
		option   :	in 	std_logic_vector(3 downto 0);
		DFP_Busy	   : in STD_LOGIC;  -- not used
		DFP_tx	   : out STD_LOGIC; -- to the DFPlayer RX
		SD_CS : buffer 	std_logic;
		SD_MISO : in 	std_logic;
		SD_MOSI : buffer 	std_logic;
		SD_CLK : buffer 	std_logic
		);
end gosof80;

architecture rtl of gosof80 is
begin
	LED_1 <= not Audio_O;

	core: entity work.gosof80_core
	generic map(BOARD_ID => BOARD_ID, SW_MINOR => SW_MINOR)
	port map(
		clk_50 => clk_50, reset_sw => reset_sw,
		test_sw => test, gosof_test => '1',
		Audio_O => Audio_O,
		Sound => Sound, SB_Opt => SB_Opt, game_sel => game_sel, option => option,
		trigger_o => open, pa7_o => LED_2, sd_error_o => LED_0, crc_error_o => open,
		DFP_txd => DFP_tx,
		SD_CS => SD_CS, SD_MISO => SD_MISO, SD_MOSI => SD_MOSI, SD_CLK => SD_CLK
	);
end rtl;