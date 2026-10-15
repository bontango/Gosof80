# Megafunctions generated for Cyclone II, generated with Quartus 13.0sp1. Selected through the RtlFamily key
# in variants\<name>\variant.psd1. Same entity names (SB_ROM, RAM, Gosof_PLL) and port lists in
# every rtl\cyclone_*\ folder - the top level does not know its family, the .qsf decides.
# rtl\cyclone_10\ and rtl\cyclone_IV\ differ in nothing but intended_device_family.
# Gosof_PLL is a plain clock divider here (the PLL cannot make 892 kHz), see its header.
# The .qip reference their files via $::quartus(qip_path) and are location independent.
set_global_assignment -name QIP_FILE ../../rtl/cyclone_II/SB_ROM.qip
set_global_assignment -name QIP_FILE ../../rtl/cyclone_II/RAM.qip
set_global_assignment -name QIP_FILE ../../rtl/cyclone_II/Gosof_PLL.qip
