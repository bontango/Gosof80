# common_header.tcl - global assignments that are identical in every GOSOF80
# variant. Merged into every generated GOSOF80.qsf by scripts\gen_qsf.ps1.
#
# NOT here: FAMILY / DEVICE / LAST_QUARTUS_VERSION and the EDA tool lines - those
# live in variants\<name>\device.tcl. TOP_LEVEL_ENTITY is written by gen_qsf.ps1.
# Taken over 1:1 from the four old GOSOF80_HW2x_* .qsf files (intersection).
set_global_assignment -name ORIGINAL_QUARTUS_VERSION "13.0 SP1"
set_global_assignment -name PROJECT_CREATION_TIME_DATE "10:36:54  MARCH 29, 2020"
set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files
set_global_assignment -name MIN_CORE_JUNCTION_TEMP 0
set_global_assignment -name MAX_CORE_JUNCTION_TEMP 85
set_global_assignment -name USE_CONFIGURATION_DEVICE ON
set_global_assignment -name STRATIX_DEVICE_IO_STANDARD "3.3-V LVTTL"
set_global_assignment -name PARTITION_NETLIST_TYPE SOURCE -section_id Top
set_global_assignment -name PARTITION_FITTER_PRESERVATION_LEVEL PLACEMENT_AND_ROUTING -section_id Top
set_global_assignment -name PARTITION_COLOR 16764057 -section_id Top
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
