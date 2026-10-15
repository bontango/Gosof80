# HW 2.x boards (all hw2x_* variants, Options = @('hw2x')): SD card reader with the
# 4 KB per game image format, shared top level.
#
# GOSOF80.sdc only names clk_50 and the hierarchy paths cpu_clk_gen:clock_gen|cpu_clk_out
# and uart_clk_gen:uart_gen|uart_clk_out. In the old tree only GOSOF80_HW2x_CycloneII had
# the file - the other three listed it but it was missing (Critical Warning 332012).
set_global_assignment -name VHDL_FILE ../../rtl/common/SPI_Master.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/SD_Card.vhd
set_global_assignment -name SDC_FILE ../../rtl/common/GOSOF80.sdc
set_global_assignment -name VHDL_FILE ../../top/GOSOF80.vhd