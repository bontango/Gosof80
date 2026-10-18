-- tb_flash_rom.vhd - checks rtl/hw5x/Flash_ROM.vhd against a behavioural SPI flash
-- (READ 03h, mode 0, MSB first). Content of the model: byte at address a =
-- (a(7:0) xor a(15:8) xor a(23:16)) - except the slot of game 5, which is erased (FF).
-- Runs: game 0, game 53 (highest slot in use), game 5 (empty -> Flash_error).
-- Started by sim/flash/run_sim.ps1.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_flash_rom is
end tb_flash_rom;

architecture sim of tb_flash_rom is
	constant BASE : integer := 16#040000#;
	constant SLOT : integer := 4096;

	signal clk     : std_logic := '0';
	signal rst_l   : std_logic := '0';
	signal f_clk, f_cs_n, f_mosi, f_miso : std_logic;
	signal sel     : std_logic_vector(7 downto 0) := (others => '0');
	signal addr    : std_logic_vector(15 downto 0);
	signal data    : std_logic_vector(7 downto 0);
	signal wr      : std_logic;
	signal cpu_rst : std_logic;
	signal err     : std_logic;
	signal done    : boolean := false;

	function content(a : natural) return std_logic_vector is
		variable u : unsigned(23 downto 0);
	begin
		if a >= BASE + 5 * SLOT and a < BASE + 6 * SLOT then
			return x"FF";
		end if;
		u := to_unsigned(a, 24);
		return std_logic_vector(u(7 downto 0) xor u(15 downto 8) xor u(23 downto 16));
	end function;
begin
	clk <= not clk after 10 ns when not done;

	DUT: entity work.Flash_ROM
	generic map(Read_Bytes => SLOT, Base_Addr => BASE, Slot_Bytes => SLOT)
	port map(
		i_Clk => clk, i_Rst_L => rst_l,
		o_Flash_Clk => f_clk, o_Flash_CS_n => f_cs_n, o_Flash_MOSI => f_mosi, i_Flash_MISO => f_miso,
		selection => sel, address_rom => addr, data_rom => data, wr_rom => wr,
		cpu_reset_l => cpu_rst, Flash_error => err);

	-- SPI flash model
	FLASH: process
		variable cmd   : std_logic_vector(31 downto 0);
		variable a     : natural;
		variable byte  : std_logic_vector(7 downto 0);
	begin
		f_miso <= 'Z';
		wait until f_cs_n = '0';
		for i in 31 downto 0 loop
			wait until rising_edge(f_clk) or f_cs_n = '1';
			if f_cs_n = '1' then exit; end if;
			cmd(i) := f_mosi;
		end loop;
		if f_cs_n = '0' then
			assert cmd(31 downto 24) = x"03" report "flash: command is not READ 03h" severity failure;
			a := to_integer(unsigned(cmd(23 downto 0)));
			outer: loop
				byte := content(a);
				for i in 7 downto 0 loop
					wait until falling_edge(f_clk) or f_cs_n = '1';
					exit outer when f_cs_n = '1';
					f_miso <= byte(i);
				end loop;
				a := a + 1;
			end loop;
		end if;
	end process;

	STIM: process
		variable expect : std_logic_vector(7 downto 0);
		variable n      : natural;
		variable errors : natural := 0;
		variable game   : natural;
	begin
		for run in 0 to 2 loop
			if run = 0 then game := 0; elsif run = 1 then game := 53; else game := 5; end if;
			sel <= std_logic_vector(to_unsigned(game, 8));
			rst_l <= '0';
			wait for 100 ns;
			wait until rising_edge(clk);
			rst_l <= '1';
			n := 0;
			while n < SLOT loop
				wait until rising_edge(clk);
				if wr = '1' then
					if game = 5 then
						expect := x"FF";
					else
						expect := content(BASE + game * SLOT + n);
					end if;
					if to_integer(unsigned(addr)) /= n or data /= expect then
						if errors < 10 then
							report "game " & integer'image(game) & " byte " & integer'image(n) &
							       ": addr " & integer'image(to_integer(unsigned(addr))) &
							       " data " & integer'image(to_integer(unsigned(data))) &
							       " expected " & integer'image(to_integer(unsigned(expect))) severity error;
						end if;
						errors := errors + 1;
					end if;
					n := n + 1;
				end if;
			end loop;
			for i in 1 to 20 loop
				wait until rising_edge(clk);
			end loop;
			assert f_cs_n = '1' report "CS still active after the slot" severity error;
			if game = 5 then
				assert err = '0' report "empty slot: Flash_error not active" severity error;
				if err /= '0' then errors := errors + 1; end if;
			else
				assert err = '1' report "Flash_error active on a filled slot" severity error;
				if err /= '1' then errors := errors + 1; end if;
			end if;
			report "game " & integer'image(game) & ": " & integer'image(n) & " bytes checked";
		end loop;
		if errors = 0 then
			report "PASS" severity note;
		else
			report "FAIL, " & integer'image(errors) & " errors" severity failure;
		end if;
		done <= true;
		wait;
	end process;
end sim;
