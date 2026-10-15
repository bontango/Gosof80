# HW 4.x board (hw4x_cyclone_10, Options = @('hw4x')): SD card reader with the
# 64 KB per game image format and CRC check, its SPI master (do_not_enable_SS),
# board shell with the HW 4.x pin names. SD_Card/SPI_Master/crc16 taken over 1:1
# from FPGA_source_alt\HW 4.x GOSOF80 - Multi SD (v4.01).
set_global_assignment -name VHDL_FILE ../../rtl/hw4x/crc16_ccitt.vhd
set_global_assignment -name VHDL_FILE ../../rtl/hw4x/SPI_Master.vhd
set_global_assignment -name VHDL_FILE ../../rtl/hw4x/SD_Card.vhd
set_global_assignment -name VHDL_FILE ../../rtl/hw4x/sd_reader_hw4x.vhd
set_global_assignment -name VHDL_FILE ../../top/board_hw4x.vhd