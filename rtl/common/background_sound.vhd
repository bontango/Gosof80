--
-- background sound with MP3 Miniplayer
-- via 'Game Over' signal
--
-- commands
-- 7E FF 06 0F 00 01 02 EF Specify track "002" in the folder “01”
-- 7E FF 06 17 00 00 02 EF Specify repeat playback of the folder “02”
-- 7E FF 06 0E 00 00 00 EF Pause
-- 7E FF 06 0D 00 00 00 EF Play
--
-- bontango 03.2023
-- Version 0.1


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

	entity background_sound is
		port(
            clk        : in std_logic; -- CPU clock
				game_over  : in std_logic; 				
				folder  : in std_logic_vector(7 downto 0);
            DFcmd_cmd  : out std_logic_vector(7 downto 0);
				DFcmd_par1  : out std_logic_vector(7 downto 0);
				DFcmd_par2  : out std_logic_vector(7 downto 0);
				send_flag  : out std_logic; 				
				rst 		: in  STD_LOGIC --reset_l
            );
    end background_sound;
	 
   architecture Behavioral of background_sound is
	  type STATE_T is ( Idle, Start, Stop, Running); 
		signal state : STATE_T;        --State	   

    begin	 
		background_sound: process (clk, rst, game_over, folder)
			variable counter : integer range 0 to 16000000 := 0;
		begin
			if rst = '0' then --Reset condidition (reset_l)
				 send_flag <= '0';
				 state <= Idle;    
			elsif rising_edge(clk)then
				case state is
					when Idle =>
						if game_over = '1' then 
							 DFcmd_cmd <= X"17"; -- cmd for repeat folder to playback
							 DFcmd_par1 <= x"00"; -- fix
							 DFcmd_par2 <= folder; -- playback folder
							 send_flag <= '1'; -- start Background sound
							 state <= Start;
						end if;
					when Start => 
						send_flag <= '0';					
						state <= Running;						
					when Running => -- game over mode, check game over to stop
						if game_over = '0' then 
							 DFcmd_cmd <= X"0E"; -- cmd for pause
							 DFcmd_par1 <= x"00"; -- fix
							 DFcmd_par2 <= x"00"; -- fix
							 send_flag <= '1'; -- pause Background sound
							 state <= Stop;
						end if;
					when Stop => 
						send_flag <= '0';					
						state <= Idle;						
				end case;
			end if;
		end process;
    end Behavioral;				
