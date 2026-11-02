-- tb_mf4.vhd - checks rtl\hw5x_80b\mf4_filter.vhd against the response of a 4th order Butterworth
-- low pass: |H| = 1 / sqrt(1 + (f / fc)^8). A sine at 1/2, 1 and 2 times the corner for several values
-- of N, after the filter has settled the peak of the output is compared.
-- Started by sim\gosof886\run_mf4.ps1.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_mf4 is
end tb_mf4;

architecture sim of tb_mf4 is
	signal clk : std_logic := '0';
	signal n : std_logic_vector(7 downto 0) := x"00";
	signal din, dout : signed(15 downto 0) := (others => '0');
	signal done : boolean := false;
begin
	clk <= not clk after 10 ns when not done;

	DUT: entity work.mf4_filter
	port map(clk => clk, n => n, audio_in => din, audio_out => dout);

	process
		type int_array is array (natural range <>) of natural;
		constant NS : int_array := (216, 246, 252, 176);  -- 1 kHz, 4 kHz, 10 kHz, 500 Hz
		constant AMP : real := 6000.0;
		variable fc, f, t, want, got, db : real;
		variable peak : natural;
		variable errors : natural := 0;
		variable cycles : natural;
	begin
		for i in NS'range loop
			n <= std_logic_vector(to_unsigned(NS(i), 8));
			fc := 40000.0 / real(256 - NS(i));
			for k in 0 to 2 loop
				f := fc * (0.5 * 2.0 ** k);
				cycles := integer(20.0 / f * 50.0e6);
				peak := 0;
				for c in 0 to 2 * cycles loop
					wait until rising_edge(clk);
					-- one new sample every 128 clocks is all the filter looks at
					if c mod 64 = 0 then
						t := real(c) / 50.0e6;
						din <= to_signed(integer(AMP * sin(MATH_2_PI * f * t)), 16);
					end if;
					if c > cycles and abs(to_integer(dout)) > peak then
						peak := abs(to_integer(dout));
					end if;
				end loop;
				want := 1.0 / sqrt(1.0 + (f / fc) ** 8);
				got := real(peak) / AMP;
				db := 20.0 * log10(got / want);
				report "N=" & integer'image(NS(i)) & " f=" & integer'image(integer(f)) &
				       " Hz gain " & real'image(got) & " expected " & real'image(want) & " = " & real'image(db) & " dB";
				-- Above 15 kHz the state variable filter deviates by design (20 kHz at N = 252: +1.5 dB at
				-- -24 dB, f is 5 % of fs), so 2 dB there, 1 dB in the rest of the audio band.
				if (f <= 15000.0 and abs(db) > 1.0) or abs(db) > 2.0 then
					errors := errors + 1;
					report "too far off" severity error;
				end if;
			end loop;
		end loop;
		if errors = 0 then report "PASS"; else report "FAIL, " & integer'image(errors) & " errors" severity failure; end if;
		done <= true;
		wait;
	end process;
end sim;
