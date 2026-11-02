-- tb_gosof886.vhd - runs one game (slot.bin) on top\GOSOF80B_886.vhd with the SRAM model and reports
-- what the CPUs do. Sequence: wait for the start, sound commands 1..31 as the MPU sends them (lines
-- active for 2 ms, then Gap_ms pause).
-- Checks: both CPUs read the latch for every command, S16 alone (16) does not trigger, the NMI
-- period is (256 - rate) * 1024 us, the bytes of the SRAM read by the CPU are never 'X' (55 ns met).
-- Audio goes to audio.raw (16 bit, 50 MHz / 1134). Started by sim\gosof886\run_sim.ps1.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_gosof886 is
	generic(
		GEN     : natural := 2;
		Boot_ms : natural := 300;
		Gap_ms  : natural := 40
	);
end tb_gosof886;

architecture sim of tb_gosof886 is
	signal clk      : std_logic := '0';
	signal sound    : std_logic_vector(4 downto 0) := (others => '0');
	signal audio    : std_logic;
	signal trigger, led, err : std_logic;
	signal cs, mosi, sck : std_logic;
	signal sram_a   : std_logic_vector(16 downto 0);
	signal sram_dq  : std_logic_vector(7 downto 0);
	signal sram_do  : std_logic_vector(7 downto 0);
	signal sram_oe_d, sram_we_n, sram_oe_n : std_logic;
	signal done     : boolean := false;
begin
	clk <= not clk after 10 ns when not done;

	SRAM: entity work.sram_model
	port map(a => sram_a, dq => sram_dq, ce_n => '0', oe_n => sram_oe_n, we_n => sram_we_n);
	sram_dq <= sram_do when sram_oe_d = '1' else (others => 'Z');

	dut: entity work.gosof80b_886_core
	generic map(GEN => GEN)
	port map(
		clk_50 => clk, reset_sw => '1', gosof_test => '1',
		Audio_O => audio, Sound => sound, SB_Opt => "111", game_sel => "111111",
		trigger_o => trigger, diag_led_o => led, flash_error_o => err,
		FLASH_CS => cs, FLASH_MISO => '0', FLASH_MOSI => mosi, FLASH_CLK => sck,
		sram_a => sram_a, sram_di => sram_dq, sram_do => sram_do, sram_oe_d => sram_oe_d,
		sram_we_n => sram_we_n, sram_oe_n => sram_oe_n
	);

	MAIN: process
		alias cpu_clk  is <<signal .tb_gosof886.dut.cpu_clk  : std_logic>>;
		alias reset_l  is <<signal .tb_gosof886.dut.reset_l  : std_logic>>;
		alias y_addr   is <<signal .tb_gosof886.dut.y_addr   : std_logic_vector(15 downto 0)>>;
		alias y_rw_n   is <<signal .tb_gosof886.dut.y_rw_n   : std_logic>>;
		alias y_irq_n  is <<signal .tb_gosof886.dut.y_irq_n  : std_logic>>;
		alias y_nmi_n  is <<signal .tb_gosof886.dut.y_nmi_n  : std_logic>>;
		alias yrom_q   is <<signal .tb_gosof886.dut.yrom_dout : std_logic_vector(7 downto 0)>>;
		alias d_addr   is <<signal .tb_gosof886.dut.d_addr   : std_logic_vector(15 downto 0)>>;
		alias d_rw_n   is <<signal .tb_gosof886.dut.d_rw_n   : std_logic>>;
		alias d_irq_n  is <<signal .tb_gosof886.dut.d_irq_n  : std_logic>>;
		alias d_nmi_n  is <<signal .tb_gosof886.dut.d_nmi_n  : std_logic>>;
		alias drom_q   is <<signal .tb_gosof886.dut.drom_dout : std_logic_vector(7 downto 0)>>;
		alias ctrl     is <<signal .tb_gosof886.dut.ctrl     : std_logic_vector(7 downto 0)>>;
		alias rate     is <<signal .tb_gosof886.dut.nmi_rate : unsigned(7 downto 0)>>;
		alias mix      is <<signal .tb_gosof886.dut.audio_mix : unsigned(16 downto 0)>>;
		alias mf4_n    is <<signal .tb_gosof886.dut.mf4_n    : std_logic_vector(7 downto 0)>>;
		alias ym_wr_n  is <<signal .tb_gosof886.dut.ym_wr_n  : std_logic>>;

		type byte_file is file of character;
		file raw : byte_file;

		variable cycles       : natural := 0;
		variable last_cpu     : std_logic := '0';
		variable sample_cnt   : natural := 0;
		variable mix_min      : natural := 65535;
		variable mix_max      : natural := 0;
		variable ay_bdir      : natural := 0;
		variable last_bdir    : std_logic := '0';
		variable dac_writes   : natural := 0;
		variable mf4_writes   : natural := 0;
		variable mf4_min      : natural := 255;
		variable mf4_max      : natural := 0;
		variable last_mf4     : std_logic_vector(7 downto 0) := x"00";
		variable ym_writes    : natural := 0;
		variable last_ym      : std_logic := '1';
		variable y_nmi_seen   : natural := 0;
		variable d_nmi_seen   : natural := 0;
		variable last_y_nmi   : std_logic := '1';
		variable last_d_nmi   : std_logic := '1';
		variable last_nmi_at  : natural := 0;
		variable nmi_bad      : natural := 0;
		variable y_acks       : natural := 0;
		variable d_acks       : natural := 0;
		variable last_y_irq   : std_logic := '1';
		variable last_d_irq   : std_logic := '1';
		variable led_edges    : natural := 0;
		variable last_led     : std_logic := '0';
		variable last_rate    : unsigned(7 downto 0) := x"00";
		variable first_cycle  : natural := 0;
		variable cmd          : natural := 0;
		variable y_cmd_acks   : natural := 0;
		variable d_cmd_acks   : natural := 0;
		variable bad_cmds     : natural := 0;
		variable bad_rom      : natural := 0;
		variable phase_end    : natural;
		variable phase        : natural := 0;
		variable mix_i        : natural;
		variable period       : natural;
	begin
		file_open(raw, "audio.raw", write_mode);
		wait until reset_l = '1';
		first_cycle := cycles;
		phase_end := Boot_ms * 2000;
		loop
			wait until rising_edge(clk);
			-- audio sample every 1134 clk_50 = 44.09 kHz
			sample_cnt := sample_cnt + 1;
			if sample_cnt = 1134 then
				sample_cnt := 0;
				mix_i := to_integer(mix) / 2;
				write(raw, character'val(mix_i mod 256));
				write(raw, character'val(mix_i / 256));
				if mix_i < mix_min then mix_min := mix_i; end if;
				if mix_i > mix_max then mix_max := mix_i; end if;
			end if;
			-- the rest once per CPU cycle
			next when cpu_clk = last_cpu;
			last_cpu := cpu_clk;
			next when cpu_clk = '0';
			cycles := cycles + 1;

			-- a read of the ROM has to see valid data
			if y_addr(15) = '1' and y_rw_n = '1' and is_x(yrom_q) then bad_rom := bad_rom + 1; end if;
			if d_addr(15) = '1' and d_rw_n = '1' and is_x(drom_q) then bad_rom := bad_rom + 1; end if;

			if d_addr(15 downto 14) = "10" and d_rw_n = '0' then dac_writes := dac_writes + 1; end if;
			if y_addr(15 downto 13) = "001" and y_rw_n = '0' then mf4_writes := mf4_writes + 1; end if;
			if mf4_n /= last_mf4 then
				last_mf4 := mf4_n;
				if to_integer(unsigned(mf4_n)) < mf4_min then mf4_min := to_integer(unsigned(mf4_n)); end if;
				if to_integer(unsigned(mf4_n)) > mf4_max then mf4_max := to_integer(unsigned(mf4_n)); end if;
			end if;
			if ym_wr_n = '0' and last_ym = '1' then ym_writes := ym_writes + 1; end if;
			last_ym := ym_wr_n;

			if ctrl(2) /= last_bdir then
				if ctrl(2) = '1' then ay_bdir := ay_bdir + 1; end if;
				last_bdir := ctrl(2);
			end if;
			if led /= last_led then
				led_edges := led_edges + 1;
				last_led := led;
			end if;
			if rate /= last_rate then
				report "NMI rate " & integer'image(to_integer(rate)) & " at cycle " & integer'image(cycles);
				last_rate := rate;
				last_nmi_at := 0;  -- the period after a change is not comparable
			end if;

			-- NMI period, in CPU cycles = 0.5 us. Gated by ctrl(0): a whole multiple is fine.
			if y_nmi_n = '0' and last_y_nmi = '1' then
				y_nmi_seen := y_nmi_seen + 1;
				period := (256 - to_integer(rate)) * 2048;
				if last_nmi_at /= 0 and (cycles - last_nmi_at) mod period /= 0 then
					nmi_bad := nmi_bad + 1;
					if nmi_bad < 5 then
						report "NMI period " & integer'image(cycles - last_nmi_at) & " cycles at rate " & integer'image(to_integer(rate));
					end if;
				end if;
				last_nmi_at := cycles;
			end if;
			last_y_nmi := y_nmi_n;
			if d_nmi_n = '0' and last_d_nmi = '1' then d_nmi_seen := d_nmi_seen + 1; end if;
			last_d_nmi := d_nmi_n;

			-- IRQ: set by the command, cleared by the CPU reading the latch
			if y_irq_n = '1' and last_y_irq = '0' then y_acks := y_acks + 1; y_cmd_acks := y_cmd_acks + 1; end if;
			last_y_irq := y_irq_n;
			if d_irq_n = '1' and last_d_irq = '0' then d_acks := d_acks + 1; d_cmd_acks := d_cmd_acks + 1; end if;
			last_d_irq := d_irq_n;

			-- sequence
			if cycles - first_cycle = phase_end then
				case phase is
					when 0 =>
						report "Boot done: Y IRQ/NMI " & integer'image(y_acks) & "/" & integer'image(y_nmi_seen) &
						       " AY " & integer'image(ay_bdir) & " YM " & integer'image(ym_writes) &
						       " DAC " & integer'image(dac_writes) & " LED edges " & integer'image(led_edges);
						phase := 1;
						cmd := 1;
						sound <= std_logic_vector(to_unsigned(cmd, 5));
						y_cmd_acks := 0; d_cmd_acks := 0;
						phase_end := phase_end + 4000;
					when 1 =>
						sound <= (others => '0');
						phase := 2;
						phase_end := phase_end + Gap_ms * 2000 - 4000;
					when 2 =>
						if cmd = 16 then
							if y_cmd_acks /= 0 or d_cmd_acks /= 0 then
								report "cmd 16 (S16 alone) must not trigger: acks " & integer'image(y_cmd_acks) & " " & integer'image(d_cmd_acks) severity error;
								bad_cmds := bad_cmds + 1;
							end if;
						elsif y_cmd_acks /= 1 or d_cmd_acks /= 1 then
							report "cmd " & integer'image(cmd) & ": acks Y " & integer'image(y_cmd_acks) & " D " & integer'image(d_cmd_acks) severity warning;
							bad_cmds := bad_cmds + 1;
						end if;
						if cmd = 31 then
							exit;
						else
							cmd := cmd + 1;
							sound <= std_logic_vector(to_unsigned(cmd, 5));
							y_cmd_acks := 0; d_cmd_acks := 0;
							phase := 1;
							phase_end := phase_end + 4000;
						end if;
					when others =>
						exit;
				end case;
			end if;
		end loop;
		file_close(raw);

		report "RESULT sim_ms=" & integer'image((cycles - first_cycle) / 2000) &
		       " bad_cmds=" & integer'image(bad_cmds) & " bad_rom=" & integer'image(bad_rom) &
		       " y_irq=" & integer'image(y_acks) & " d_irq=" & integer'image(d_acks) &
		       " y_nmi=" & integer'image(y_nmi_seen) & " nmi_bad=" & integer'image(nmi_bad) &
		       " d_nmi=" & integer'image(d_nmi_seen) &
		       " ay_writes=" & integer'image(ay_bdir) & " ym_writes=" & integer'image(ym_writes) &
		       " dac_writes=" & integer'image(dac_writes) &
		       " mf4_writes=" & integer'image(mf4_writes) & " mf4_n=" & integer'image(mf4_min) & ".." & integer'image(mf4_max) &
		       " rate=" & integer'image(to_integer(rate)) & " led_edges=" & integer'image(led_edges) &
		       " mix=" & integer'image(mix_min) & ".." & integer'image(mix_max);
		done <= true;
		wait;
	end process;
end sim;
