--
-- generate (default) 893KHz clock for Gottlieb Soundboard from 50Mhz system clock
-- original SB runs at appr. 800KHz, surprisingly emulation Frequenz need
-- to be higher to have same 'feeling'
-- clock can be adjusted in ranges via variable
--

LIBRARY ieee;
USE ieee.std_logic_1164.all;

	entity cpu_clk_gen is
		port(
                clk_in  : in std_logic;                
                cpu_clk_out : out std_logic;
					 clk_adj : in 	std_logic_vector(0 to 2)
            );
    end cpu_clk_gen;
	 
   architecture Behavioral of cpu_clk_gen is
	   signal q_cpuClkCount : integer range 0 to 100;
    begin
		cpu_clk_gen: process (clk_in, clk_adj)
			variable counter1 : integer range 0 to 100;
			variable counter2 : integer range 0 to 100;
			begin		
				case (clk_adj) is
					when "000" => counter1 := 48; -- 1042KHz
					when "010" => counter1 := 50; -- 1000KHz
					when "100" => counter1 := 52; -- 962KHz
					when "110" => counter1 := 54; -- 925KHz
					when "101" => counter1 := 58; -- 862KHz
					when "011" => counter1 := 60; -- 833KHz
					when "001" => counter1 := 62; -- 806KHz
					when others => counter1 := 56; --default 895KHz "111" all OFF
				end case;
				case (clk_adj) is
					when "000" => counter2 := 24; -- 1042KHz
					when "010" => counter2 := 25; -- 1000KHz
					when "100" => counter2 := 26; -- 962KHz
					when "110" => counter2 := 27; -- 925KHz
					when "101" => counter2 := 29; -- 862KHz
					when "011" => counter2 := 30; -- 833KHz
					when "001" => counter2 := 31; -- 806KHz
					when others => counter2 := 28; --default 895KHz "111" all OFF
				end case;				
				if rising_edge(clk_in) then
					if q_cpuClkCount < counter1 then		
						q_cpuClkCount <= q_cpuClkCount + 1;
					else
						q_cpuClkCount <= 0;
					end if;
					if q_cpuClkCount < counter2 then	
						cpu_clk_out <= '0';
					else
						cpu_clk_out <= '1';
					end if;
				end if;
			end process;
    end Behavioral;				

-- CPU Clock

-- CPU frequency 	Counter top 	Counter half-way
-- 532Khz if cpuClkCount < 93 then 	if cpuClkCount < 47 then
-- 806Khz if cpuClkCount < 62 then 	if cpuClkCount < 31 then
--1MHz 	if cpuClkCount < 49 then 	if cpuClkCount < 25 then
--2MHz 	if cpuClkCount < 24 then 	if cpuClkCount < 12 then
--5MHz 	if cpuClkCount < 9 then 	if cpuClkCount < 4 then
--10MHz 	if cpuClkCount < 4 then 	if cpuClkCount < 2 then
--12.5MHz 	if cpuClkCount < 3 then 	if cpuClkCount < 2 then
--16.6MHz 	if cpuClkCount < 2 then 	if cpuClkCount < 2 then
--25MHz 	if cpuClkCount < 1 then 	if cpuClkCount < 1 then	

    