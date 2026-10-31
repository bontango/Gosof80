-- Board shell of GOSOF80B on the HW 5.x board (GOSOF 5.00, EP4CE6E22C8N core board):
-- pin names of the board, mapped onto the core gosof80b_core (top\GOSOF80B.vhd).
-- Same pins as top\board_hw5x.vhd. Not used: DFPlayer, option DIPs S3, SB_Opt 4..8.
-- BOARD_ID / SW_MINOR come from the generated .qsf (set_parameter), nothing reads them here.

library ieee;
use ieee.std_logic_1164.all;

entity gosof80b is
	generic(
		BOARD_ID : natural := 0;
		SW_MINOR : natural := 0
	);
	port(
		clk_50	: in std_logic;
		reset_sw	: in std_logic;               -- reset button of the core board
		Audio_O	: buffer std_logic;
		Gottlieb_Test		: in std_logic := '1';  -- SW1 of the original board
		Gosof_Test		: in std_logic := '1';     -- GOSOF sound test
		Sound :	in 	std_logic_vector(4 downto 0);
		SB_Opt :	in 	std_logic_vector(1 to 3);
		LED_trigger 	: out STD_LOGIC;     -- D1, active high; also blinks with LED1 (core board is mounted upside down, LED1 hidden)
		LED_sound 	: out STD_LOGIC;        -- D2, active high: LED D1 of the original, blinks when the Y CPU runs
		LED_Flash_Error	: out STD_LOGIC;  -- LED1 of the core board, active low, blinks = empty slot
		game_sel	:	in 	std_logic_vector(5 downto 0);
		-- configuration flash, dual purpose pins (released in device.tcl)
		FLASH_DCLK  : buffer std_logic;
		FLASH_NCS   : buffer std_logic;
		FLASH_ASDO  : buffer std_logic;  -- data into the flash
		FLASH_DATA0 : in std_logic       -- data out of the flash
		);
end gosof80b;

architecture rtl of gosof80b is
	signal trigger : std_logic;
	signal flash_err_n : std_logic;  -- '0' = LED1 on
begin
	LED_trigger <= trigger or not flash_err_n;
	LED_Flash_Error <= flash_err_n;

	core: entity work.gosof80b_core
	port map(
		clk_50 => clk_50, reset_sw => reset_sw,
		test_sw => Gottlieb_Test, gosof_test => Gosof_Test,
		Audio_O => Audio_O,
		Sound => Sound, SB_Opt => SB_Opt, game_sel => game_sel,
		trigger_o => trigger, diag_led_o => LED_sound, flash_error_o => flash_err_n,
		FLASH_CS => FLASH_NCS, FLASH_MISO => FLASH_DATA0, FLASH_MOSI => FLASH_ASDO, FLASH_CLK => FLASH_DCLK
	);
end rtl;
