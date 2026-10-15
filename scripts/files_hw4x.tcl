# HW 4.x board (hw4x_cyclone_10, Options = @('hw4x')): SD card reader with the
# 64 KB per game image format and CRC check, its SPI master (do_not_enable_SS),
# the GOSOF sound test, the CPU clock from the PLL (Gosof_PLL in rtl\cyclone_10\).
# Taken over 1:1 from FPGA_source_alt\HW 4.x GOSOF80 - Multi SD (v4.01).
set_global_assignment -name VHDL_FILE ../../rtl/hw4x/soundtest.vhd
set_global_assignment -name VHDL_FILE ../../rtl/hw4x/crc16_ccitt.vhd
set_global_assignment -name VHDL_FILE ../../rtl/hw4x/SPI_Master.vhd
set_global_assignment -name VHDL_FILE ../../rtl/hw4x/SD_Card.vhd
set_global_assignment -name SDC_FILE ../../rtl/hw4x/GOSOF80.sdc
set_global_assignment -name VHDL_FILE ../../top/GOSOF80_hw4x.vhd
set_global_assignment -name QIP_FILE ../../rtl/cyclone_10/Gosof_PLL.qip