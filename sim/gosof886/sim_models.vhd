-- sim_models.vhd - behavioural stand-ins for GHDL: the RAM megafunction, the flash loader and, since
-- GHDL has no Verilog, the jt51. sd_reader here reads slot.bin (64 KB) from the current directory
-- at the pace of the real loader (34 clocks per byte) into the SRAM; the real loader has its own
-- check, sim\flash\run_sim.ps1.
-- jt51 here is NOT the synthesizer: it counts the writes, its output stays silent. The sound of
-- generation 3 from the YM2151 is therefore not simulated, only the DAC part.

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
			for i in 1 to 32 loop
				wait until rising_edge(clk);
			end loop;
			a := a + 1;
		end loop;
		file_close(f);
		wait until rising_edge(clk);
		cpu_reset_l <= '1';
		wait;
	end process;
end sim;

library ieee;
use ieee.std_logic_1164.all;

entity jt51 is
	port(
		rst, clk, cen, cen_p1, cs_n, wr_n, a0 : in std_logic;
		din : in std_logic_vector(7 downto 0);
		dout : out std_logic_vector(7 downto 0);
		ct1, ct2, irq_n, sample : out std_logic;
		left, right, xleft, xright : out std_logic_vector(15 downto 0)
	);
end jt51;
architecture sim of jt51 is
begin
	dout <= x"00"; ct1 <= '0'; ct2 <= '0'; irq_n <= '1'; sample <= '0';
	left <= x"0000"; right <= x"0000"; xleft <= x"0000"; xright <= x"0000";
end sim;

-- AS6C1008-55 with its read timing: after a change of the address or of /OE the data is unknown for
-- 55 ns. Checks the write pulse (tWP 45 ns, tDW 25 ns). Memory is a variable, GHDL stays fast.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sram_model is
	port(
		a    : in std_logic_vector(16 downto 0);
		dq   : inout std_logic_vector(7 downto 0);
		ce_n : in std_logic;
		oe_n : in std_logic;
		we_n : in std_logic
	);
end sram_model;
architecture sim of sram_model is
begin
	process(a, oe_n, we_n, ce_n, dq)
		type mem_t is array (0 to 131071) of std_logic_vector(7 downto 0);
		variable mem : mem_t := (others => x"FF");
		variable we_fall : time := 0 ns;
		variable d_change : time := 0 ns;
	begin
		if dq'event then d_change := now; end if;
		if we_n'event and we_n = '0' then we_fall := now; end if;
		if we_n'event and we_n = '1' and we_n'last_value = '0' and ce_n = '0' then
			assert now - we_fall >= 45 ns report "SRAM: /WE pulse too short" severity error;
			assert now - d_change >= 25 ns report "SRAM: data setup too short" severity error;
			mem(to_integer(unsigned(a))) := dq;
		end if;
		if ce_n = '0' and oe_n = '0' and we_n = '1' then
			if a'event or oe_n'event or we_n'event then
				dq <= (others => 'X'), mem(to_integer(unsigned(a))) after 55 ns;
			end if;
		else
			dq <= (others => 'Z');
		end if;
	end process;
end sim;
