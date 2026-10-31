# Source files of GOSOF80B (MA-766), takes the place of files_common.tcl through
# CommonFiles = 'files_80b_common' in variant.psd1: other core, no RIOT, no Votrax, no DFPlayer.
# Shared with GOSOF80: T65, dac, soundtest, Flash_ROM. Megafunctions (8 KB ROM, 2 KB RAM),
# AY-3-8913 and SP0250 in rtl\hw5x_80b\.
set_global_assignment -name VHDL_FILE variant_pkg.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/uart_clk_gen.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/slow_to_fast_clock_bus.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/dac.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/soundtest.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/T65/T65_Pack.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/T65/T65_MCode.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/T65/T65_ALU.vhd
set_global_assignment -name VHDL_FILE ../../rtl/common/T65/T65.vhd
set_global_assignment -name VHDL_FILE ../../rtl/hw5x_80b/ym2149_audio.vhd
set_global_assignment -name VHDL_FILE ../../rtl/hw5x_80b/sp0250.vhd
set_global_assignment -name QIP_FILE ../../rtl/hw5x_80b/rom.qip
set_global_assignment -name QIP_FILE ../../rtl/hw5x_80b/ram.qip
set_global_assignment -name VHDL_FILE ../../rtl/hw5x/Flash_ROM.vhd
set_global_assignment -name VHDL_FILE ../../rtl/hw5x/sd_reader_hw5x.vhd
set_global_assignment -name SDC_FILE ../../rtl/hw5x_80b/GOSOF80B.sdc
set_global_assignment -name VHDL_FILE ../../top/GOSOF80B.vhd
set_global_assignment -name VHDL_FILE ../../top/board_hw5x_80b.vhd
