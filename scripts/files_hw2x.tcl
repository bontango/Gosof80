# HW 2.x boards (all hw2x_* variants, Options = @('hw2x')): SD card reader with the
# 4 KB per game image format, board shell with the HW 2.x pin names.
set_global_assignment -name VHDL_FILE ../../rtl/common/SPI_Master.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/SD_Card.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/sd_reader_hw2x.vhd
set_global_assignment -name VHDL_FILE ../../top/board_hw2x.vhd