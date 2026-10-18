# pins.tcl - pin locations of hw5x_cyclone_IV (GOSOF 5.00 with EP4CE6E22C8N core board).
# From Target\GOSOF\v5.x\pins_Gosof_v5.xlsx and GOSOF_5_00.NET (header pin -> FPGA pin).
# DIP blocks: S2 (6 pole) = game_sel, S3 (4 pole) = option, S1 (8 pole) = SB_Opt, as on HW 4.x.
# Merged into GOSOF80.qsf by scripts\gen_qsf.ps1. Hand maintained.
set_location_assignment PIN_24 -to clk_50
set_location_assignment PIN_88 -to reset_sw
# PIN_88 is the dedicated clock input CLK7: no weak pull-up possible there (Error 169057).
# The reset button of the core board has its own pull-up. Switches off the one from
# scripts\common_header.tcl, which comes earlier in the generated .qsf.
set_instance_assignment -name WEAK_PULL_UP_RESISTOR OFF -to reset_sw
set_location_assignment PIN_144 -to DFP_rx
set_location_assignment PIN_143 -to DFP_tx
set_location_assignment PIN_70 -to Sound[0]
set_location_assignment PIN_68 -to Sound[1]
set_location_assignment PIN_66 -to Sound[2]
set_location_assignment PIN_64 -to Sound[3]
set_location_assignment PIN_72 -to Sound[4]
set_location_assignment PIN_111 -to Audio_O
set_location_assignment PIN_129 -to SB_Opt[1]
set_location_assignment PIN_127 -to SB_Opt[2]
set_location_assignment PIN_125 -to SB_Opt[3]
set_location_assignment PIN_121 -to SB_Opt[4]
set_location_assignment PIN_119 -to SB_Opt[5]
set_location_assignment PIN_112 -to SB_Opt[6]
set_location_assignment PIN_113 -to SB_Opt[7]
set_location_assignment PIN_110 -to SB_Opt[8]
set_location_assignment PIN_115 -to game_sel[0]
set_location_assignment PIN_120 -to game_sel[1]
set_location_assignment PIN_124 -to game_sel[2]
set_location_assignment PIN_126 -to game_sel[3]
set_location_assignment PIN_128 -to game_sel[4]
set_location_assignment PIN_132 -to game_sel[5]
set_location_assignment PIN_142 -to option[0]
set_location_assignment PIN_138 -to option[1]
set_location_assignment PIN_136 -to option[2]
set_location_assignment PIN_133 -to option[3]
set_location_assignment PIN_59 -to Gottlieb_Test
set_location_assignment PIN_55 -to Gosof_Test
set_location_assignment PIN_135 -to LED_trigger
set_location_assignment PIN_137 -to LED_sound
set_location_assignment PIN_1 -to LED_Flash_Error
# Configuration flash EPCS4: the dedicated configuration pins of the E22 package
# (DCLK 12, DATA0 13, nCSO 8, ASDO 6), released as regular I/O in device.tcl.
set_location_assignment PIN_12 -to FLASH_DCLK
set_location_assignment PIN_8 -to FLASH_NCS
set_location_assignment PIN_6 -to FLASH_ASDO
set_location_assignment PIN_13 -to FLASH_DATA0