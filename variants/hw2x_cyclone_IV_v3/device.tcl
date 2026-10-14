# device.tcl - what is specific to THIS board (hw2x_cyclone_IV_v3), apart from the pin locations.
# Merged into GOSOF80.qsf by scripts\gen_qsf.ps1. Hand maintained.
set_global_assignment -name FAMILY "Cyclone IV E"
set_global_assignment -name DEVICE EP4CE6F17C8
set_global_assignment -name LAST_QUARTUS_VERSION "22.1std.2 Lite Edition"
set_global_assignment -name EDA_SIMULATION_TOOL "Questa Intel FPGA (VHDL)"
set_global_assignment -name EDA_OUTPUT_DATA_FORMAT VHDL -section_id eda_simulation
