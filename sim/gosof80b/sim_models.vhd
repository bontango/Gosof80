-- sim_models.vhd - behavioural stand-ins for what GHDL does not have or would take too long:
-- the altsyncram megafunctions rom/ram (rtl\hw5x_80b) and the flash loader. sd_reader here reads
-- slot.bin (24 KB) from the current directory straight into the ROMs, instead of the serial
-- flash plus 500 ms wait; the real loader has its own check, sim\flash\run_sim.ps1.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rom is
	port(
		address : in std_logic_vector(12 downto 0);
		clock   : in std_logic := '1';
		data    : in std_logic_vector(7 downto 0);
		wren    : in std_logic;
		q       : out std_logic_vector(7 downto 0)
	);
end rom;
architecture sim of rom is
	type mem_t is array (0 to 8191) of std_logic_vector(7 downto 0);
	signal mem : mem_t := (others => x"FF");
begin
	process(clock)
	begin
		if rising_edge(clock) then
			if wren = '1' then
				mem(to_integer(unsigned(address))) <= data;
				q <= data;
			else
				q <= mem(to_integer(unsigned(address)));
			end if;
		end if;
	end process;
end sim;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ram is
	port(
		address : in std_logic_vector(10 downto 0);
		clock   : in std_logic := '1';
		data    : in std_logic_vector(7 downto 0);
		wren    : in std_logic;
		q       : out std_logic_vector(7 downto 0)
	);
end ram;
architecture sim of ram is
	type mem_t is array (0 to 2047) of std_logic_vector(7 downto 0);
	signal mem : mem_t := (others => x"00");
begin
	process(clock)
	begin
		if rising_edge(clock) then
			if wren = '1' then
				mem(to_integer(unsigned(address))) <= data;
				q <= data;
			else
				q <= mem(to_integer(unsigned(address)));
			end if;
		end if;
	end process;
end sim;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sd_reader is
	generic(
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
		selection	: in  std_logic_vector(7 downto 0);
		address_sd_card	: out std_logic_vector(15 downto 0);
		data_sd_card	: out std_logic_vector(7 downto 0);
		wr_rom		: out std_logic;
		cpu_reset_l	: out std_logic;
		sd_error		: out std_logic;
		crc_error	: out std_logic
	);
end sd_reader;
architecture sim of sd_reader is
begin
	spi_clk <= '0'; spi_mosi <= '0'; spi_cs_n <= '1';
	sd_error <= '1'; crc_error <= '1';
	process
		type byte_file is file of character;
		file f : byte_file;
		variable c : character;
		variable a : natural := 0;
	begin
		cpu_reset_l <= '0';
		wr_rom <= '0';
		file_open(f, "slot.bin", read_mode);
		while a < Read_Bytes loop
			assert not endfile(f) report "slot.bin too short" severity failure;
			read(f, c);
			address_sd_card <= std_logic_vector(to_unsigned(a, 16));
			data_sd_card <= std_logic_vector(to_unsigned(character'pos(c), 8));
			wait until rising_edge(clk);
			wr_rom <= '1';
			wait until rising_edge(clk);
			wr_rom <= '0';
			a := a + 1;
		end loop;
		file_close(f);
		wait until rising_edge(clk);
		cpu_reset_l <= '1';
		wait;
	end process;
end sim;
