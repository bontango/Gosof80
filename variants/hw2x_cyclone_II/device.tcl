# device.tcl - what is specific to THIS board (hw2x_cyclone_II), apart from the pin locations.
# Merged into GOSOF80.qsf by scripts\gen_qsf.ps1. Hand maintained.
set_global_assignment -name FAMILY "Cyclone II"
set_global_assignment -name DEVICE EP2C5T144C8
set_global_assignment -name LAST_QUARTUS_VERSION "13.0 SP1"
set_global_assignment -name EDA_SIMULATION_TOOL "ModelSim-Altera (VHDL)"
set_global_assignment -name EDA_OUTPUT_DATA_FORMAT VHDL -section_id eda_simulation
# Test 14.10.2026: hold violations on the divided clocks (cpu_clk_out, uart_clk_out),
# see VARIANTEN.md. Lets the fitter add delay on all paths, not just I/O.
set_global_assignment -name OPTIMIZE_HOLD_TIMING "ALL PATHS"
