-- soundtest on GOSOF
-- bontango 02.2026
--
-- v 1.0 

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

    entity soundtest is        
        port(
         clk_in  : in std_logic;   --uart clock 9,6KHz
			i_Rst_L	: in std_logic;    -- FPGA Reset					   
			start : in std_logic; 
			--output 
			test_activ		: out std_logic;        -- set to 1 when read finished
			sound	:	buffer std_logic_vector(4 downto 0)
			
            );
    end soundtest;
    ---------------------------------------------------
    architecture Behavioral of soundtest is
	 	type STATE_T is ( Idle, Play, Pause ); 
		signal state : STATE_T := Idle;     
		signal Count : integer range 0 to 50000; 
		signal sound_count : std_logic_vector(4 downto 0);
		
	begin		
	 soundtest: process (clk_in, start, i_Rst_L)
    begin
			if i_Rst_L = '0' then --Reset condidition (reset_l)    
			  state <= Idle;
			  sound <= "00000";
			  sound_count <= "00000";
			  test_activ <= '0';
			  Count <= 0;
			  state <= Idle;
			elsif rising_edge(clk_in) then			
				case state is
					when Idle =>
						test_activ <= '0';
						Sound <= "00000";
						sound_count <= "00001";
						if ( start = '0') then
							test_activ <= '1';
							Count <= 0;						
							state <= Play;
						end if;
					when Play =>
						-- next sound
						sound_count <= std_LOGIC_VECTOR(unsigned(sound_count) +1);
					   Sound <= sound_count;
						state <= Pause;	
					when Pause =>						
						Sound <= "00000";
						Count <= Count +1;
						if ( Count > 16000 ) then --5seconds per sound
							Count <= 0;
							if ( sound_count = "00000" ) then
								state <= Idle;
							else	
								state <= Play;
							end if;								
						end if;	
				end case;				
			end if; --rese / rising edge		
		end process;
    end Behavioral;