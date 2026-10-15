# HW 3.x board (hw3x_cyclone_IV, Options = @('hw3x')): the SD card reader of HW 2.x
# (4 KB per game image format), board shell with the HW 3.x pin names.
set_global_assignment -name VHDL_FILE ../../rtl/common/SPI_Master.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/SD_Card.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/sd_reader_hw2x.vhd
set_global_assignment -name VHDL_FILE ../../top/board_hw3x.vhd