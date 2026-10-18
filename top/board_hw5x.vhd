-- Board shell of the HW 5.x board (GOSOF 5.00, EP4CE6E22C8N core board, no SD card):
-- pin names of the board, mapped onto the shared core gosof80_core (top\GOSOF80.vhd).
-- The core's SD port goes to the configuration flash (EPCS4), from which
-- rtl\hw5x\sd_reader_hw5x.vhd reads the game ROMs.
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
		reset_sw	: in std_logic;               -- reset button of the core board
		Audio_O	: buffer std_logic;
		Gottlieb_Test		: in std_logic := '1';  -- test switch of the original board
		Gosof_Test		: in std_logic := '1';     -- GOSOF sound test
		Sound :	in 	std_logic_vector(4 downto 0);
		SB_Opt :	in 	std_logic_vector(1 to 8);  -- DIP 7/8 not wired to the CPU
		LED_trigger 	: out STD_LOGIC;     -- D1, active high
		LED_sound 	: out STD_LOGIC;        -- D2, active high
		LED_Flash_Error	: out STD_LOGIC;  -- LED1 of the core board, active low, blinks = empty slot
		game_sel	:	in 	std_logic_vector(5 downto 0);
		option   :	in 	std_logic_vector(3 downto 0);
		DFP_tx	   : in STD_LOGIC;   -- from the DFPlayer TX, not used
		DFP_rx	   : out STD_LOGIC;  -- to the DFPlayer RX
		-- configuration flash, dual purpose pins (released in device.tcl)
		FLASH_DCLK  : buffer std_logic;
		FLASH_NCS   : buffer std_logic;
		FLASH_ASDO  : buffer std_logic;  -- data into the flash
		FLASH_DATA0 : in std_logic       -- data out of the flash
		);
end gosof80;

architecture rtl of gosof80 is
	signal trigger : std_logic;
begin
	LED_trigger <= trigger;
	LED_sound <= Audio_O;

	core: entity work.gosof80_core
	generic map(BOARD_ID => BOARD_ID, SW_MINOR => SW_MINOR)
	port map(
		clk_50 => clk_50, reset_sw => reset_sw,
		test_sw => Gottlieb_Test, gosof_test => Gosof_Test,
		Audio_O => Audio_O,
		Sound => Sound, SB_Opt => SB_Opt(1 to 6), game_sel => game_sel, option => option,
		trigger_o => trigger, pa7_o => open, sd_error_o => LED_Flash_Error, crc_error_o => open,
		DFP_txd => DFP_rx,
		SD_CS => FLASH_NCS, SD_MISO => FLASH_DATA0, SD_MOSI => FLASH_ASDO, SD_CLK => FLASH_DCLK
	);
end rtl;
