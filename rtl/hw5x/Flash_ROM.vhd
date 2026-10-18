--
-- Flash_ROM.vhd
-- HW 5.x (EP4CE6 core board, no SD card): reads the 4 KB of the selected game from the
-- FPGA configuration flash (EPCS4) into the two 2K sound ROMs.
-- Taken over from WillFA7 rtl/common/Flash_ROM.vhd (bontango 10.2026) and cut down to
-- the GOSOF slot: 4 KB, no sound board part, no fallback - here the flash is the only
-- source.
--
-- Flash layout (scripts/make_flash_hex.ps1 writes the .hex, variants/hw5x_cyclone_IV/
-- gosof80_roms.cof puts it next to the bitstream into a local .jic):
--     0x000000 - Base_Addr-1        compressed bitstream
--     Base_Addr + n * Slot_Bytes    game n (n = selection), 4 KB, same content as the
--                                   4 KB file of make_sd.bat / the HW 2.x SD image
--
-- No CRC. The flash has no contacts and no file system, and the programmer verifies
-- it when writing. What is left is the check against an EMPTY slot (the released
-- .jic carries no ROMs, erased = FF): if all 4096 bytes read FF, the CPU is not
-- released and Flash_error blinks. Not the 6502 reset vector as on WillFA7: the
-- MA-55 / System 1 images have 1K of padding there.
--
-- Same output side as SD_Card (address, data, wr_rom, cpu_reset_l, error LED), so the
-- core does not see a difference.
--
-- SPI mode 0, READ (03h) with a 24 bit address, then one continuous stream.
--
-- v02 18.10.2026: idle phase with CS high before the READ (state idle). Without it the
--     loader failed after power on (hardware test: error LED blinks) and worked after the
--     reset button: right after configuration the registers power up as '0', so CS went
--     low with no high phase after the configuration read. The flash never saw a new
--     command and kept streaming the erased area behind the bitstream - 4096 x FF, i.e.
--     "empty slot". CS now powers up '1' and stays high for Idle_Cycles before every READ.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

	entity Flash_ROM is
		generic (
			-- payload bytes per game, from the start of the slot
			Read_Bytes : integer := 4096;
			-- where game 0 starts in the flash, and how far apart the games are
			Base_Addr  : integer := 16#040000#;
			Slot_Bytes : integer := 4096;
			-- SPI clock half period in i_Clk cycles. 2 at 50 MHz = 12.5 MHz, the
			-- EPCS4 allows 20 MHz for READ (03h).
			Half_Period : integer := 2;
			-- CS high (deselect) before the READ, in i_Clk cycles. 50 us at 50 MHz; the
			-- EPCS needs 100 ns, the rest is margin for the end of the configuration.
			Idle_Cycles : integer := 2500
		);
		port(
		i_Clk		: in std_logic;
		i_Rst_L	: in std_logic;     -- '0' holds the loader, '1' starts it
		-- configuration flash, dual purpose pins of the FPGA
		o_Flash_Clk  : out std_logic;   -- DCLK
		o_Flash_CS_n : out std_logic;   -- nCSO
		o_Flash_MOSI : out std_logic;   -- ASDO, data into the flash
		i_Flash_MISO : in std_logic;    -- DATA0, data out of the flash
		-- selection
		selection : in std_logic_vector(7 downto 0);
		-- rom write port, same meaning as at SD_Card
		address_rom	: buffer std_logic_vector(15 downto 0);
		data_rom		: buffer std_logic_vector(7 downto 0);
		wr_rom		: buffer std_logic;
		-- start CPU
		cpu_reset_l : out std_logic;
		-- feedback
		Flash_error : out std_logic     -- active low, blinks when the slot is empty
		);
    end Flash_ROM;

   architecture Behavioral of Flash_ROM is
		type STATE_T is ( idle, start, bit_low, bit_high, write_byte, inc_addr, check_empty,
								all_done, error );
		-- power-up values: after configuration the loader starts without a reset pulse
		signal state : STATE_T := idle;
		signal cs_n  : std_logic := '1';

		signal tx_sr    : std_logic_vector(31 downto 0); -- command and address
		signal rx_sr    : std_logic_vector(7 downto 0);
		signal bit_cnt  : integer range 0 to 31;
		signal in_cmd   : std_logic;                     -- '1' while the 32 command bits go out
		signal div      : integer range 0 to 255;
		signal not_empty : std_logic;                    -- a byte of the slot was not FF
		signal counter  : integer range 0 to 25000000 := 0;
		signal blink    : std_logic;
	begin
		o_Flash_CS_n <= cs_n;

		Flash: process (i_Clk)
		begin
		if rising_edge(i_Clk) then
			if i_Rst_L = '0' then
				o_Flash_Clk <= '0';
				cs_n <= '1';
				o_Flash_MOSI <= '0';
				cpu_reset_l <= '0';
				wr_rom <= '0';
				address_rom <= (others => '0');
				data_rom <= x"FF";
				Flash_error <= '1'; -- active low
				not_empty <= '0';
				div <= 0;
				bit_cnt <= 0;
				in_cmd <= '0';
				counter <= 0;
				blink <= '0';
				state <= idle;
			else
				case state is
				when idle =>
					-- deselected, clock low, then the READ. Sets everything the reset sets:
					-- after configuration the loader starts here without any reset pulse.
					cs_n <= '1';
					o_Flash_Clk <= '0';
					o_Flash_MOSI <= '0';
					cpu_reset_l <= '0';
					wr_rom <= '0';
					address_rom <= (others => '0');
					data_rom <= x"FF";
					Flash_error <= '1'; -- active low
					not_empty <= '0';
					div <= 0;
					bit_cnt <= 0;
					in_cmd <= '0';
					blink <= '0';
					if counter < Idle_Cycles then
						counter <= counter + 1;
					else
						counter <= 0;
						state <= start;
					end if;

				when start =>
					-- READ (03h) plus 24 bit address of the slot
					tx_sr <= x"03" & std_logic_vector( to_unsigned(Base_Addr, 24)
							 + unsigned(selection) * to_unsigned(Slot_Bytes, 16) );
					cs_n <= '0';
					bit_cnt <= 31;
					in_cmd <= '1';
					div <= 0;
					state <= bit_low;

				-- one SPI bit: clock low half, then clock high half. The flash takes
				-- MOSI on the rising edge and shifts its data out on the falling one,
				-- so MISO is sampled together with the rising edge.
				when bit_low =>
					o_Flash_MOSI <= tx_sr(31);
					if div = Half_Period - 1 then
						div <= 0;
						o_Flash_Clk <= '1';
						rx_sr <= rx_sr(6 downto 0) & i_Flash_MISO;
						state <= bit_high;
					else
						div <= div + 1;
					end if;

				when bit_high =>
					if div = Half_Period - 1 then
						div <= 0;
						o_Flash_Clk <= '0';
						tx_sr <= tx_sr(30 downto 0) & '0';
						if bit_cnt = 0 then
							if in_cmd = '1' then
								-- command and address are out, data follows
								in_cmd <= '0';
								bit_cnt <= 7;
								state <= bit_low;
							else
								data_rom <= rx_sr;
								state <= write_byte;
							end if;
						else
							bit_cnt <= bit_cnt - 1;
							state <= bit_low;
						end if;
					else
						div <= div + 1;
					end if;

				-- address and data are stable here, one clock of wr_rom like SD_Card.
				-- The SPI clock just pauses meanwhile.
				when write_byte =>
					wr_rom <= '1';
					if data_rom /= x"FF" then
						not_empty <= '1';
					end if;
					state <= inc_addr;

				when inc_addr =>
					wr_rom <= '0';
					if unsigned(address_rom) = to_unsigned(Read_Bytes - 1, address_rom'length) then
						cs_n <= '1';
						state <= check_empty;
					else
						address_rom <= std_logic_vector(unsigned(address_rom) + 1);
						bit_cnt <= 7;
						state <= bit_low;
					end if;

				when check_empty =>
					counter <= 0;
					if not_empty = '1' then
						state <= all_done;
					else
						-- empty slot: running FF would be worse than showing the error
						state <= error;
					end if;

				when all_done =>
					-- wait a bit, then start cpu - same 500 ms as SD_Card
					Flash_error <= '1';
					if ( counter < 25000000 ) then
						counter <= counter + 1;
					else
						cpu_reset_l <= '1';
					end if;

				when error =>
					-- blink, 250 ms on / 250 ms off (LED active low: '0' = on)
					if counter < 12500000 then
						counter <= counter + 1;
					else
						counter <= 0;
						blink <= not blink;
					end if;
					Flash_error <= blink;

				end case;
			end if; --rst
		end if; --rising edge
		end process;

    end Behavioral;
