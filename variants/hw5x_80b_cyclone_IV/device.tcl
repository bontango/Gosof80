# device.tcl - what is specific to THIS board (hw5x_80b_cyclone_IV), apart from the pin locations.
# Taken over from hw5x_cyclone_IV\device.tcl. Merged into GOSOF80.qsf by scripts\gen_qsf.ps1. Hand maintained.
set_global_assignment -name FAMILY "Cyclone IV E"
set_global_assignment -name DEVICE EP4CE6E22C8
set_global_assignment -name ORIGINAL_QUARTUS_VERSION "13.0 SP1"
set_global_assignment -name PROJECT_CREATION_TIME_DATE "10:36:54  MARCH 29, 2020"
set_global_assignment -name LAST_QUARTUS_VERSION "22.1std.2 Lite Edition"
set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files
set_global_assignment -name MIN_CORE_JUNCTION_TEMP 0
set_global_assignment -name MAX_CORE_JUNCTION_TEMP 85
set_global_assignment -name STRATIX_DEVICE_IO_STANDARD "3.3-V LVTTL"
set_global_assignment -name PARTITION_NETLIST_TYPE SOURCE -section_id Top
set_global_assignment -name PARTITION_FITTER_PRESERVATION_LEVEL PLACEMENT_AND_ROUTING -section_id Top
set_global_assignment -name PARTITION_COLOR 16764057 -section_id Top
set_global_assignment -name EDA_SIMULATION_TOOL "<None>"
set_global_assignment -name EDA_OUTPUT_DATA_FORMAT NONE -section_id eda_simulation
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to game_sel[2]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to game_sel[1]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to game_sel[0]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to Sound[4]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to Sound[3]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to Sound[2]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to Sound[1]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to Sound[0]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to SB_Opt[1]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to SB_Opt[2]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to SB_Opt[3]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to game_sel[3]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to game_sel[4]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to game_sel[5]
set_global_assignment -name CYCLONEII_RESERVE_NCEO_AFTER_CONFIGURATION "USE AS REGULAR IO"
set_global_assignment -name RESERVE_ALL_UNUSED_PINS "AS INPUT TRI-STATED WITH WEAK PULL-UP"
set_global_assignment -name POWER_PRESET_COOLING_SOLUTION "23 MM HEAT SINK WITH 200 LFPM AIRFLOW"
set_global_assignment -name POWER_BOARD_THERMAL_MODEL "NONE (CONSERVATIVE)"
set_global_assignment -name EDA_GENERATE_FUNCTIONAL_NETLIST OFF -section_id eda_board_design_timing
set_global_assignment -name EDA_GENERATE_FUNCTIONAL_NETLIST OFF -section_id eda_board_design_symbol
set_global_assignment -name EDA_GENERATE_FUNCTIONAL_NETLIST OFF -section_id eda_board_design_signal_integrity
set_global_assignment -name EDA_GENERATE_FUNCTIONAL_NETLIST OFF -section_id eda_board_design_boundary_scan
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to Gosof_Test
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to Gottlieb_Test
set_instance_assignment -name PARTITION_HIERARCHY root_partition -to | -section_id Top

# Compressed bitstream: uncompressed the EP4CE6 takes 368 KB of the 512 KB EPCS4, which
# leaves no room for the 24 KB game slots from FLASH_BASE (variant_pkg.vhd) on.
set_global_assignment -name ON_CHIP_BITSTREAM_DECOMPRESSION ON

# The configuration flash is the source of the game ROMs (rtl/hw5x/Flash_ROM.vhd), so its
# pins have to become ordinary I/O once the FPGA is configured. As in WillFA7 s_cyclone_iv_v4.
set_global_assignment -name RESERVE_DATA0_AFTER_CONFIGURATION "USE AS REGULAR IO"
set_global_assignment -name RESERVE_DATA1_AFTER_CONFIGURATION "USE AS REGULAR IO"
set_global_assignment -name RESERVE_FLASH_NCE_AFTER_CONFIGURATION "USE AS REGULAR IO"
set_global_assignment -name RESERVE_DCLK_AFTER_CONFIGURATION "USE AS REGULAR IO"

# CPU clock from a divider in the core, no PLL: a register output behind clk_50, hold needs the
# fitter on all paths (as on hw5x_cyclone_IV).
set_global_assignment -name OPTIMIZE_HOLD_TIMING "ALL PATHS"
