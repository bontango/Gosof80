# Source files of GOSOF80B for the MA-886, one list per generation through CommonFiles in variant.psd1.
# Shared with the MA-766: T65, dac, soundtest, Flash_ROM, RAM megafunction, AY-3-8913.
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
set_global_assignment -name VHDL_FILE ../../rtl/hw5x_80b/mf4_table_pkg.vhd
set_global_assignment -name VHDL_FILE ../../rtl/hw5x_80b/mf4_filter.vhd
set_global_assignment -name VHDL_FILE ../../rtl/hw5x_80b/sram_arbiter.vhd
set_global_assignment -name QIP_FILE ../../rtl/hw5x_80b/ram.qip
set_global_assignment -name VHDL_FILE ../../rtl/hw5x/Flash_ROM.vhd
set_global_assignment -name VHDL_FILE ../../rtl/hw5x/sd_reader_hw5x.vhd
set_global_assignment -name SDC_FILE ../../rtl/hw5x_80b/GOSOF80B_886.sdc
set_global_assignment -name VHDL_FILE ../../top/GOSOF80B_886.vhd
set_global_assignment -name VHDL_FILE ../../top/board_886_dev_open.vhd
set_global_assignment -name QIP_FILE ../../rtl/hw5x_80b/jt51/jt51.qip
