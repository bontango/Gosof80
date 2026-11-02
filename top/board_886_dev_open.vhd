-- Board shell of GOSOF80B MA-886 on the Gosof80B PCB with the 'dev_open' board DEV190806036
-- (EP4CE6E22C8): pin names of the board, mapped onto the core gosof80b_886_core
-- (top\GOSOF80B_886.vhd). Generation from variant_pkg.vhd. The SRAM U1 is needed here.
-- Not used: Gottlieb_Test (these boards read no switch), S32..S128, options S2 4..6.
-- BOARD_ID / SW_MINOR come from the generated .qsf (set_parameter), nothing reads them here.

library ieee;
use ieee.std_logic_1164.all;
use work.variant_pkg.all;

entity gosof80b is
	generic(
		BOARD_ID : natural := 0;
		SW_MINOR : natural := 0
	);
	port(
		clk_50	: in std_logic;
		reset_sw	: in std_logic;               -- SW1 of the board, ACTIVE HIGH (1k to GND, button to +3.3V)
		Audio_O	: buffer std_logic;
		Gosof_Test		: in std_logic := '1';     -- SW3 of the board = GOSOF sound test, active low
		Sound :	in 	std_logic_vector(4 downto 0);
		SB_Opt :	in 	std_logic_vector(1 to 3);
		LED_trigger 	: out STD_LOGIC;     -- LED1 of the board, active low
		LED_sound 	: out STD_LOGIC;        -- LED2 of the board, active low: LED D1 of the original
		LED_Flash_Error	: out STD_LOGIC;  -- LED3 of the board, active low, blinks = empty slot
		game_sel	:	in 	std_logic_vector(5 downto 0);
		-- configuration flash, dual purpose pins (released in device.tcl)
		FLASH_DCLK  : buffer std_logic;
		FLASH_NCS   : buffer std_logic;
		FLASH_ASDO  : buffer std_logic;  -- data into the flash
		FLASH_DATA0 : in std_logic;      -- data out of the flash
		-- SRAM U1, AS6C1008-55. CE2 is tied high on the PCB.
		SRAM_A    : out std_logic_vector(16 downto 0);
		SRAM_DQ   : inout std_logic_vector(7 downto 0);
		SRAM_WE_n : out std_logic;
		SRAM_OE_n : out std_logic;
		SRAM_CE_n : out std_logic
		);
end gosof80b;

architecture rtl of gosof80b is
	signal reset_n : std_logic;
	signal trigger : std_logic;
	signal diag_led : std_logic;
	signal sram_do : std_logic_vector(7 downto 0);
	signal sram_oe_d : std_logic;
begin
	reset_n <= not reset_sw;
	LED_trigger <= not trigger;
	LED_sound <= not diag_led;

	SRAM_CE_n <= '0';
	SRAM_DQ <= sram_do when sram_oe_d = '1' else (others => 'Z');

	core: entity work.gosof80b_886_core
	generic map(GEN => MA886_GEN)
	port map(
		clk_50 => clk_50, reset_sw => reset_n, gosof_test => Gosof_Test,
		Audio_O => Audio_O,
		Sound => Sound, SB_Opt => SB_Opt, game_sel => game_sel,
		trigger_o => trigger, diag_led_o => diag_led, flash_error_o => LED_Flash_Error,
		FLASH_CS => FLASH_NCS, FLASH_MISO => FLASH_DATA0, FLASH_MOSI => FLASH_ASDO, FLASH_CLK => FLASH_DCLK,
		sram_a => SRAM_A, sram_di => SRAM_DQ, sram_do => sram_do, sram_oe_d => sram_oe_d,
		sram_we_n => SRAM_WE_n, sram_oe_n => SRAM_OE_n
	);
end rtl;
