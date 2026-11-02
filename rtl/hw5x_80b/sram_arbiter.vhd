-- sram_arbiter.vhd - game ROMs of the MA-886 in the external SRAM AS6C1008-55 (128 K x 8, 55 ns).
--
-- While the CPUs are in reset the flash loader writes the slot. Afterwards the SRAM is only read:
-- one fixed slot per CPU in every bus cycle, 4 clk_50 each (80 ns), so the timing does not depend
-- on what the CPUs do. Bytes behind the T65, like the M9K ROMs of the MA-766 core.
--
-- phase = 0..24 is the divider of the 2 MHz CPU clock. The core raises cpu_clk one clock after
-- phase 12, the T65 address is stable well before phase 15. The data has to be there at the next
-- rising edge of cpu_clk, the latest slot ends at phase 23.
--
-- Layout: A15 = 0 Y CPU, A15 = 1 D CPU, A14..A0 = address of the CPU (ROM at $8000-$FFFF). A16 stays
-- 0, it is only needed for the third CPU of Bone Busters, which does not fit into the EP4CE6.

library ieee;
use ieee.std_logic_1164.all;

entity sram_arbiter is
	port(
		clk      : in  std_logic;
		phase    : in  integer range 0 to 24;
		run      : in  std_logic;                      -- '0' loader, '1' CPUs
		-- flash loader: one clock of wr, at least 8 clocks apart (Flash_ROM: 34)
		wr       : in  std_logic;
		wr_addr  : in  std_logic_vector(15 downto 0);
		wr_data  : in  std_logic_vector(7 downto 0);
		-- CPUs
		y_addr   : in  std_logic_vector(14 downto 0);
		d_addr   : in  std_logic_vector(14 downto 0);
		y_q      : out std_logic_vector(7 downto 0);
		d_q      : out std_logic_vector(7 downto 0);
		-- SRAM, the data bus has its tri-state in the board shell
		sram_a   : out std_logic_vector(16 downto 0);
		sram_di  : in  std_logic_vector(7 downto 0);
		sram_do  : out std_logic_vector(7 downto 0);
		sram_oe_d : out std_logic;                     -- '1' = FPGA drives the data bus
		sram_we_n : out std_logic;
		sram_oe_n : out std_logic
	);
end sram_arbiter;

architecture rtl of sram_arbiter is
	signal wr_cnt : integer range 0 to 5 := 0;
	signal we_n   : std_logic := '1';
	signal oe_n   : std_logic := '1';
	signal drive  : std_logic := '0';
begin
	sram_we_n <= we_n;
	sram_oe_n <= oe_n;
	sram_oe_d <= drive;

	process(clk)
	begin
		if rising_edge(clk) then
			if run = '0' then
				-- address and data first, /WE low for 3 clocks = 60 ns (tWP 45 ns), then one clock
				-- of hold before the bus is released
				oe_n <= '1';
				if wr = '1' then
					sram_a <= '0' & wr_addr;
					sram_do <= wr_data;
					drive <= '1';
					wr_cnt <= 5;
				elsif wr_cnt /= 0 then
					wr_cnt <= wr_cnt - 1;
					if wr_cnt = 4 then we_n <= '0'; end if;
					if wr_cnt = 1 then we_n <= '1'; end if;
				else
					drive <= '0';
					we_n <= '1';
				end if;
			else
				we_n <= '1';
				drive <= '0';
				oe_n <= '0';
				wr_cnt <= 0;
				case phase is
					when 15 =>
						sram_a <= "00" & y_addr;
					when 19 =>
						y_q <= sram_di;
						sram_a <= "01" & d_addr;
					when 23 =>
						d_q <= sram_di;
					when others =>
						null;
				end case;
			end if;
		end if;
	end process;
end rtl;
