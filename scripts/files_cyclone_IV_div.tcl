# Cyclone IV E without PLL: the megafunctions of rtl\cyclone_IV\, but Gosof_PLL is the plain
# divider of rtl\cyclone_II\ (same entity and ports, c0 = 50 MHz / 56, c1 = 50 MHz / 49 - the
# same frequencies as the ALTPLL). Selected through RtlFamily = 'cyclone_IV_div' in
# variants\<name>\variant.psd1. Used by hw5x_cyclone_IV since 28.10.2026: the PLL of one
# EP4CE6 core board was dead (standalone test, supplies ok), the divider runs on every board.
# GOSOF80.sdc finds the divider registers on its own; hold needs OPTIMIZE_HOLD_TIMING "ALL PATHS".
set_global_assignment -name QIP_FILE ../../rtl/cyclone_IV/SB_ROM.qip
set_global_assignment -name QIP_FILE ../../rtl/cyclone_IV/RAM.qip
set_global_assignment -name QIP_FILE ../../rtl/cyclone_II/Gosof_PLL.qip
