# pins.tcl - pin locations of 80B_ma886_gen3 (Gosof80B PCB with the 'dev_open' board DEV190806036).
# From Gosof80B\target\pins_Gosof80B.xlsx and Gosof80B_01.NET (DEV1 pad -> FPGA pin), checked against
# the schematic of the board (N:\Projekte\FPGA\DEV190806036 Open\01_SCH).
# DIP blocks as printed on the PCB: S1 "game select", S2 "options" (the other way round than GOSOF 5.00).
# Merged into GOSOF80.qsf by scripts\gen_qsf.ps1. Hand maintained.
#
# Not used by the MA-886 core, inputs with weak pull-up (RESERVE_ALL_UNUSED_PINS):
#   S32 = 74, S64 = 80, S128 = 84, S2_DIP4..6 = 65, 67, 69, SW2 = 89 (no switch read on these boards)
set_location_assignment PIN_91 -to clk_50
# SW1: button to +3.3V with 1k to GND, so ACTIVE HIGH. top\board_886_dev_open.vhd inverts it.
set_location_assignment PIN_88 -to reset_sw
# PIN_88..90 are the dedicated clock inputs CLK7, 6, 5: no weak pull-up possible there (Error 169057).
# SW2 and SW3 have 1k to +3.3V on the board. Switches off the one from
# scripts\common_header.tcl, which comes earlier in the generated .qsf.
set_instance_assignment -name WEAK_PULL_UP_RESISTOR OFF -to reset_sw
set_location_assignment PIN_90 -to Gosof_Test
# Sound lines behind the ULN2803, weak pull-up from scripts\common_header.tcl
set_location_assignment PIN_76 -to Sound[0]
set_location_assignment PIN_72 -to Sound[1]
set_location_assignment PIN_70 -to Sound[2]
set_location_assignment PIN_68 -to Sound[3]
set_location_assignment PIN_86 -to Sound[4]
set_location_assignment PIN_87 -to Audio_O
# S2 "options"
set_location_assignment PIN_54 -to SB_Opt[1]
set_location_assignment PIN_58 -to SB_Opt[2]
set_location_assignment PIN_60 -to SB_Opt[3]
# S1 "game select"
set_location_assignment PIN_30 -to game_sel[0]
set_location_assignment PIN_32 -to game_sel[1]
set_location_assignment PIN_34 -to game_sel[2]
set_location_assignment PIN_39 -to game_sel[3]
set_location_assignment PIN_43 -to game_sel[4]
set_location_assignment PIN_46 -to game_sel[5]
# LED1..LED3 of the board, between +3.3V (1k) and the pin: ACTIVE LOW
set_location_assignment PIN_101 -to LED_trigger
set_location_assignment PIN_100 -to LED_sound
set_location_assignment PIN_99 -to LED_Flash_Error
# Configuration flash EPCS16: the dedicated configuration pins of the E22 package
# (DCLK 12, DATA0 13, nCSO 8, ASDO 6), released as regular I/O in device.tcl.
set_location_assignment PIN_12 -to FLASH_DCLK
set_location_assignment PIN_8 -to FLASH_NCS
set_location_assignment PIN_6 -to FLASH_ASDO
set_location_assignment PIN_13 -to FLASH_DATA0

# SRAM U1 AS6C1008-55 (3.3 V, E2 tied high on the PCB). Used here, unlike in 80B_ma766.
set_location_assignment PIN_121 -to SRAM_A[0]
set_location_assignment PIN_125 -to SRAM_A[1]
set_location_assignment PIN_127 -to SRAM_A[2]
set_location_assignment PIN_129 -to SRAM_A[3]
set_location_assignment PIN_133 -to SRAM_A[4]
set_location_assignment PIN_136 -to SRAM_A[5]
set_location_assignment PIN_138 -to SRAM_A[6]
set_location_assignment PIN_142 -to SRAM_A[7]
set_location_assignment PIN_141 -to SRAM_A[8]
set_location_assignment PIN_137 -to SRAM_A[9]
set_location_assignment PIN_128 -to SRAM_A[10]
set_location_assignment PIN_135 -to SRAM_A[11]
set_location_assignment PIN_144 -to SRAM_A[12]
set_location_assignment PIN_143 -to SRAM_A[13]
set_location_assignment PIN_2 -to SRAM_A[14]
set_location_assignment PIN_3 -to SRAM_A[15]
set_location_assignment PIN_7 -to SRAM_A[16]
set_location_assignment PIN_119 -to SRAM_DQ[0]
set_location_assignment PIN_114 -to SRAM_DQ[1]
set_location_assignment PIN_112 -to SRAM_DQ[2]
set_location_assignment PIN_111 -to SRAM_DQ[3]
set_location_assignment PIN_113 -to SRAM_DQ[4]
set_location_assignment PIN_115 -to SRAM_DQ[5]
set_location_assignment PIN_120 -to SRAM_DQ[6]
set_location_assignment PIN_124 -to SRAM_DQ[7]
set_location_assignment PIN_1 -to SRAM_WE_n
set_location_assignment PIN_132 -to SRAM_OE_n
set_location_assignment PIN_126 -to SRAM_CE_n
