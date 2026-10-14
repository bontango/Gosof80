# Shared source files - part of every GOSOF80 variant.
# Paths are relative to the Quartus project directory, which is variants\<name>\.
# Order taken over from the old GOSOF80_HW2x_Cyclone10\GOSOF80.qsf; the megafunctions
# (SB_ROM, RAM) moved into files_<family>.tcl.
#
# GOSOF80.sdc is shared: it only names clk_50 and the hierarchy paths
# cpu_clk_gen:clock_gen|cpu_clk_out and uart_clk_gen:uart_gen|uart_clk_out, which are the
# same on every board. In the old tree only GOSOF80_HW2x_CycloneII had the file - the other
# three listed it but it was missing (Critical Warning 332012, built unconstrained).
set_global_assignment -name VHDL_FILE ../../rtl/common/attract.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/Votrax-SC01.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/uart_clk_gen.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/SPI_Master.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/slow_to_fast_clock_bus.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/SD_Card.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/DFPlayer_Mini_CMD.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/dac.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/cpu_clk_gen.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/background_sound.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/T65/T65_Pack.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/T65/T65_MCode.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/T65/T65_ALU.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/T65/T65.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/RIOT/R6532.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/RIOT/R6530.vhd
set_global_assignment -name SDC_FILE ../../rtl/common/GOSOF80.sdc
set_global_assignment -name VHDL_FILE ../../top/GOSOF80.vhd
