-- tb_gosof80b.vhd - runs one game (slot.bin) on top\GOSOF80B.vhd and reports what the CPUs do.
-- Sequence: wait for the start, sound commands 1..31 as the MPU sends them (lines active for
-- 2 ms, then Gap_ms pause), then the test switch of the original board.
-- Checks: both CPUs read the latch for every command, S16 alone (16) does not trigger. Reports frames and level of the SP0250 and the NMI
-- period against (256 - rate) * 1024 us. Audio goes to audio.raw (16 bit, 50 MHz / 1134).
-- Started by sim\gosof80b\run_sim.ps1.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_gosof80b is
	generic(
		Boot_ms : natural := 300;
		Gap_ms  : natural := 40
	);
end tb_gosof80b;

architecture sim of tb_gosof80b is
	signal clk      : std_logic := '0';
	signal test_sw  : std_logic := '1';
	signal sound    : std_logic_vector(4 downto 0) := (others => '0');
	signal audio    : std_logic;
	signal trigger  : std_logic;
	signal led      : std_logic;
	signal cs, mosi, sck, err : std_logic;
	signal done     : boolean := false;
begin
	clk <= not clk after 10 ns when not done;

	dut: entity work.gosof80b_core
	port map(
		clk_50 => clk, reset_sw => '1', test_sw => test_sw, gosof_test => '1',
		Audio_O => audio, Sound => sound, SB_Opt => "111", game_sel => "111111",
		trigger_o => trigger, diag_led_o => led, flash_error_o => err,
		FLASH_CS => cs, FLASH_MISO => '0', FLASH_MOSI => mosi, FLASH_CLK => sck
	);

	MAIN: process
		alias cpu_clk  is <<signal .tb_gosof80b.dut.cpu_clk  : std_logic>>;
		alias reset_l  is <<signal .tb_gosof80b.dut.reset_l  : std_logic>>;
		alias y_addr   is <<signal .tb_gosof80b.dut.y_addr   : std_logic_vector(15 downto 0)>>;
		alias y_dout   is <<signal .tb_gosof80b.dut.y_dout   : std_logic_vector(7 downto 0)>>;
		alias y_rw_n   is <<signal .tb_gosof80b.dut.y_rw_n   : std_logic>>;
		alias y_irq_n  is <<signal .tb_gosof80b.dut.y_irq_n  : std_logic>>;
		alias y_nmi_n  is <<signal .tb_gosof80b.dut.y_nmi_n  : std_logic>>;
		alias d_addr   is <<signal .tb_gosof80b.dut.d_addr   : std_logic_vector(15 downto 0)>>;
		alias d_rw_n   is <<signal .tb_gosof80b.dut.d_rw_n   : std_logic>>;
		alias d_irq_n  is <<signal .tb_gosof80b.dut.d_irq_n  : std_logic>>;
		alias d_nmi_n  is <<signal .tb_gosof80b.dut.d_nmi_n  : std_logic>>;
		alias ctrl     is <<signal .tb_gosof80b.dut.ctrl     : std_logic_vector(7 downto 0)>>;
		alias rate     is <<signal .tb_gosof80b.dut.nmi_rate : unsigned(7 downto 0)>>;
		alias mix      is <<signal .tb_gosof80b.dut.audio_mix : unsigned(16 downto 0)>>;
		alias sp_audio is <<signal .tb_gosof80b.dut.sp_audio : signed(15 downto 0)>>;
		alias sp_drq   is <<signal .tb_gosof80b.dut.sp_drq   : std_logic>>;

		type byte_file is file of character;
		file raw : byte_file;

		function hex(v : std_logic_vector) return string is
		begin
			return to_hstring(v);
		end function;
		variable cycles       : natural := 0;
		variable last_cpu     : std_logic := '0';
		variable sample_cnt   : natural := 0;
		variable s16          : natural;
		variable mix_min      : natural := 65535;
		variable mix_max      : natural := 0;
		variable sp_writes    : natural := 0;
		variable ay_bdir      : natural := 0;
		variable last_bdir    : std_logic := '0';
		variable dac_writes   : natural := 0;
		variable y_nmi_seen   : natural := 0;
		variable d_nmi_seen   : natural := 0;
		variable last_y_nmi   : std_logic := '1';
		variable last_d_nmi   : std_logic := '1';
		variable last_nmi_at  : natural := 0;
		variable nmi_rate_at  : unsigned(7 downto 0) := x"00";
		variable nmi_bad      : natural := 0;
		variable y_acks       : natural := 0;
		variable d_acks       : natural := 0;
		variable last_y_irq   : std_logic := '1';
		variable last_d_irq   : std_logic := '1';
		variable y_unmapped   : natural := 0;
		variable d_unmapped   : natural := 0;
		variable led_edges    : natural := 0;
		variable last_led     : std_logic := '0';
		variable rate_changes : natural := 0;
		variable last_rate    : unsigned(7 downto 0) := x"00";
		variable first_cycle  : natural := 0;
		variable cmd          : natural := 0;
		variable y_cmd_acks   : natural := 0;
		variable d_cmd_acks   : natural := 0;
		variable bad_cmds     : natural := 0;
		variable phase_end    : natural;
		variable phase        : natural := 0;
		variable reported_sp  : natural := 0;
		variable mix_i        : natural;
		variable sp_min       : integer := 0;
		variable sp_max       : integer := 0;
		variable sp_frames    : natural := 0;
		variable last_drq     : std_logic := '1';
		variable period       : natural;
	begin
		file_open(raw, "audio.raw", write_mode);
		wait until reset_l = '1';
		first_cycle := cycles;
		phase_end := Boot_ms * 1000;
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
				if to_integer(sp_audio) < sp_min then sp_min := to_integer(sp_audio); end if;
				if to_integer(sp_audio) > sp_max then sp_max := to_integer(sp_audio); end if;
			end if;
			-- the rest once per CPU cycle
			next when cpu_clk = last_cpu;
			last_cpu := cpu_clk;
			next when cpu_clk = '0';
			cycles := cycles + 1;

			-- Y bus
			case y_addr(15 downto 13) is
				when "001" =>
					if y_rw_n = '0' then
						sp_writes := sp_writes + 1;
						if reported_sp < 24 then
							reported_sp := reported_sp + 1;
							report "SP0250 write " & hex(y_dout) & " at cycle " & integer'image(cycles) & " cmd " & integer'image(cmd);
						end if;
					end if;
				when "101" =>
					null;
				when others => null;
			end case;
			if y_addr(15 downto 13) = "101" and y_addr(12 downto 11) = "11" then y_unmapped := y_unmapped + 1; end if;
			if d_addr(15 downto 14) = "11" and d_addr(13) = '0' then d_unmapped := d_unmapped + 1; end if;
			if d_addr(15 downto 14) = "01" and d_rw_n = '0' then dac_writes := dac_writes + 1; end if;

			-- a frame is complete when DRQ falls
			if sp_drq = '0' and last_drq = '1' then sp_frames := sp_frames + 1; end if;
			last_drq := sp_drq;

			if ctrl(2) /= last_bdir then
				if ctrl(2) = '1' then ay_bdir := ay_bdir + 1; end if;
				last_bdir := ctrl(2);
			end if;
			if led /= last_led then
				led_edges := led_edges + 1;
				last_led := led;
			end if;
			if rate /= last_rate then
				rate_changes := rate_changes + 1;
				report "NMI rate " & integer'image(to_integer(rate)) & " at cycle " & integer'image(cycles);
				last_rate := rate;
				last_nmi_at := 0;  -- the period after a change is not comparable
			end if;

			-- NMI period, in CPU cycles = us
			if y_nmi_n = '0' and last_y_nmi = '1' then
				y_nmi_seen := y_nmi_seen + 1;
				-- the NMI is gated: while the game has it disabled ticks are not seen, so a whole
				-- multiple of the period is fine
				period := (256 - to_integer(rate)) * 1024;
				if last_nmi_at /= 0 and (cycles - last_nmi_at) mod period /= 0 then
					nmi_bad := nmi_bad + 1;
					if nmi_bad < 5 then
						report "NMI period " & integer'image(cycles - last_nmi_at) & " us at rate " & integer'image(to_integer(rate));
					end if;
				end if;
				last_nmi_at := cycles;
				nmi_rate_at := rate;
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
						report "Boot done: Y IRQ/NMI/AY " & integer'image(y_acks) & "/" & integer'image(y_nmi_seen) & "/" & integer'image(ay_bdir) &
						       " DAC " & integer'image(dac_writes) & " LED edges " & integer'image(led_edges);
						phase := 1;
						cmd := 1;
						sound <= std_logic_vector(to_unsigned(cmd, 5));
						y_cmd_acks := 0; d_cmd_acks := 0;
						phase_end := phase_end + 2000;
					when 1 =>
						sound <= (others => '0');
						phase := 2;
						phase_end := phase_end + Gap_ms * 1000 - 2000;
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
							phase := 3;
							test_sw <= '0';
							report "test switch pressed at cycle " & integer'image(cycles);
							phase_end := phase_end + 200000;
						else
							cmd := cmd + 1;
							sound <= std_logic_vector(to_unsigned(cmd, 5));
							y_cmd_acks := 0; d_cmd_acks := 0;
							phase := 1;
							phase_end := phase_end + 2000;
						end if;
					when 3 =>
						test_sw <= '1';
						phase := 4;
						phase_end := phase_end + 100000;
					when others =>
						exit;
				end case;
			end if;
		end loop;
		file_close(raw);

		report "RESULT sim_ms=" & integer'image((cycles - first_cycle) / 1000) &
		       " bad_cmds=" & integer'image(bad_cmds) &
		       " y_irq=" & integer'image(y_acks) & " d_irq=" & integer'image(d_acks) &
		       " y_nmi=" & integer'image(y_nmi_seen) & " nmi_bad=" & integer'image(nmi_bad) &
		       " d_nmi=" & integer'image(d_nmi_seen) &
		       " ay_writes=" & integer'image(ay_bdir) & " dac_writes=" & integer'image(dac_writes) &
		       " sp_writes=" & integer'image(sp_writes) & " sp_frames=" & integer'image(sp_frames) &
		       " sp_audio=" & integer'image(sp_min) & ".." & integer'image(sp_max) &
		       " rates=" & integer'image(rate_changes) & " rate=" & integer'image(to_integer(rate)) &
		       " led_edges=" & integer'image(led_edges) &
		       " y_unmapped=" & integer'image(y_unmapped) & " d_mirror=" & integer'image(d_unmapped) &
		       " mix=" & integer'image(mix_min) & ".." & integer'image(mix_max);
		done <= true;
		wait;
	end process;
end sim;
