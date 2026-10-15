# device.tcl - what is specific to THIS board (hw3x_cyclone_IV), apart from the pin locations.
# Taken over from the old "HW 3.x GOSOF80 - Multi SD - CycloneIV_v6\GOSOF80.qsf". Merged into GOSOF80.qsf by scripts\gen_qsf.ps1. Hand maintained.
set_global_assignment -name FAMILY "Cyclone IV E"
set_global_assignment -name DEVICE EP4CE6F17C8
set_global_assignment -name ORIGINAL_QUARTUS_VERSION "13.0 SP1"
set_global_assignment -name PROJECT_CREATION_TIME_DATE "10:36:54  MARCH 29, 2020"
set_global_assignment -name LAST_QUARTUS_VERSION "22.1std.2 Lite Edition"
set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files
set_global_assignment -name MIN_CORE_JUNCTION_TEMP 0
set_global_assignment -name MAX_CORE_JUNCTION_TEMP 85
set_global_assignment -name USE_CONFIGURATION_DEVICE ON
set_global_assignment -name STRATIX_DEVICE_IO_STANDARD "3.3-V LVTTL"
set_global_assignment -name PARTITION_NETLIST_TYPE SOURCE -section_id Top
set_global_assignment -name PARTITION_FITTER_PRESERVATION_LEVEL PLACEMENT_AND_ROUTING -section_id Top
set_global_assignment -name PARTITION_COLOR 16764057 -section_id Top
set_global_assignment -name EDA_SIMULATION_TOOL "Questa Intel FPGA (VHDL)"
set_global_assignment -name EDA_OUTPUT_DATA_FORMAT VHDL -section_id eda_simulation
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to test
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
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to SB_Opt[4]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to SB_Opt[5]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to SB_Opt[6]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to game_sel[3]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to game_sel[4]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to game_sel[5]
set_global_assignment -name CYCLONEII_RESERVE_NCEO_AFTER_CONFIGURATION "USE AS REGULAR IO"
set_global_assignment -name RESERVE_ALL_UNUSED_PINS "AS INPUT TRI-STATED WITH WEAK PULL-UP"
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to option[3]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to option[2]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to option[1]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to option[0]
set_global_assignment -name POWER_PRESET_COOLING_SOLUTION "23 MM HEAT SINK WITH 200 LFPM AIRFLOW"
set_global_assignment -name POWER_BOARD_THERMAL_MODEL "NONE (CONSERVATIVE)"
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to reset_sw
set_instance_assignment -name PARTITION_HIERARCHY root_partition -to | -section_id Top