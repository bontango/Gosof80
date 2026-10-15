-- sd_reader for the HW 2.x boards: SD image with 4 KB per game (8 sectors from
-- sector 660 on), no CRC. Same entity in rtl\hw4x\sd_reader_hw4x.vhd - the file list
-- of the board family (scripts\files_hw2x.tcl / files_hw4x.tcl) decides which one.

library ieee;
use ieee.std_logic_1164.all;
entity sd_reader is
	port(
		clk		: in  std_logic;
		rst_l		: in  std_logic;
		spi_clk	: out std_logic;
		spi_miso	: in  std_logic;
		spi_mosi	: out std_logic;
		spi_cs_n	: out std_logic;
		selection	: in  std_logic_vector(7 downto 0);   -- game number on the SD card
		address_sd_card	: out std_logic_vector(15 downto 0);
		data_sd_card	: out std_logic_vector(7 downto 0);
		wr_rom		: out std_logic;
		cpu_reset_l	: out std_logic;                      -- '0' until the ROMs are loaded
		sd_error		: out std_logic;
		crc_error	: out std_logic                       -- '0' = CRC error
	);
end sd_reader;
architecture rtl of sd_reader is
	signal addr : std_logic_vector(13 downto 0);
begin
	address_sd_card <= "00" & addr;
	crc_error <= '1';

	SD: entity work.SD_Card
	port map(
		i_clk		=> clk,
		i_Rst_L	=> rst_l,
		o_SPI_Clk	=> spi_clk,
		i_SPI_MISO	=> spi_miso,
		o_SPI_MOSI	=> spi_mosi,
		o_SPI_CS_n	=> spi_cs_n,
		selection	=> selection,
		address_sd_card => addr,
		data_sd_card	=> data_sd_card,
		wr_rom		=> wr_rom,
		cpu_reset_l	=> cpu_reset_l,
		SDcard_error	=> sd_error
	);
end rtl;