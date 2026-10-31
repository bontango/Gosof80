-- sd_reader for the HW 5.x board (EP4CE6 core board): no SD card, the 4 KB of the
-- selected game come from the configuration flash (EPCS4), see Flash_ROM.vhd. The spi_*
-- ports are the flash pins (DCLK, DATA0, ASDO, nCSO) - the board shell maps them.
-- Same entity in rtl\common\sd_reader_hw2x.vhd / rtl\hw4x\sd_reader_hw4x.vhd - the file
-- list of the board family (scripts\files_hw5x.tcl) decides which one.
-- FLASH_BASE comes from variants\hw5x_cyclone_IV\variant_pkg.vhd.

library ieee;
use ieee.std_logic_1164.all;
use work.variant_pkg.all;
entity sd_reader is
	generic(
		-- bytes per game; 4 KB for GOSOF80, 24 KB for GOSOF80B (MA-766)
		Read_Bytes : integer := 4096;
		Slot_Bytes : integer := 4096
	);
	port(
		clk		: in  std_logic;
		rst_l		: in  std_logic;
		spi_clk	: out std_logic;
		spi_miso	: in  std_logic;
		spi_mosi	: out std_logic;
		spi_cs_n	: out std_logic;
		selection	: in  std_logic_vector(7 downto 0);   -- game number = flash slot
		address_sd_card	: out std_logic_vector(15 downto 0);
		data_sd_card	: out std_logic_vector(7 downto 0);
		wr_rom		: out std_logic;
		cpu_reset_l	: out std_logic;                      -- '0' until the ROMs are loaded
		sd_error		: out std_logic;                      -- '0' = flash slot empty (blinks)
		crc_error	: out std_logic                       -- no CRC here, always '1'
	);
end sd_reader;
architecture rtl of sd_reader is
	signal addr : std_logic_vector(15 downto 0);
	signal data : std_logic_vector(7 downto 0);
	signal wr   : std_logic;
	-- reset button (PIN_88) synchronised to clk: it is the synchronous reset of the whole
	-- loader, a release between two clock edges must reach all its registers in the same cycle
	signal rst_meta, rst_sync : std_logic := '1';
begin
	process(clk)
	begin
		if rising_edge(clk) then
			rst_meta <= rst_l;
			rst_sync <= rst_meta;
		end if;
	end process;

	address_sd_card <= addr;
	data_sd_card <= data;
	wr_rom <= wr;
	crc_error <= '1';

	FLASH: entity work.Flash_ROM
	generic map(
		Read_Bytes => Read_Bytes,
		Base_Addr  => FLASH_BASE,
		Slot_Bytes => Slot_Bytes
	)
	port map(
		i_Clk		=> clk,
		i_Rst_L	=> rst_sync,
		o_Flash_Clk  => spi_clk,
		o_Flash_CS_n => spi_cs_n,
		o_Flash_MOSI => spi_mosi,
		i_Flash_MISO => spi_miso,
		selection	=> selection,
		address_rom => addr,
		data_rom		=> data,
		wr_rom		=> wr,
		cpu_reset_l	=> cpu_reset_l,
		Flash_error	=> sd_error
	);
end rtl;
