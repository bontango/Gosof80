# HW 5.x board (hw5x_cyclone_IV, Options = @('hw5x')): no SD card, the game ROMs come
# from the configuration flash EPCS4 (Flash_ROM, taken over from WillFA7), wrapped as
# entity sd_reader; board shell with the HW 5.x pin names.
set_global_assignment -name VHDL_FILE ../../rtl/hw5x/Flash_ROM.vhd
set_global_assignment -name VHDL_FILE ../../rtl/hw5x/sd_reader_hw5x.vhd
set_global_assignment -name VHDL_FILE ../../top/board_hw5x.vhd