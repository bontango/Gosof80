# GOSOF80 timing constraints - shared by every variant (scripts\files_common.tcl).
# Names only clk_50 and hierarchy paths behind wildcards, which are the same on every
# board (the board shell top\board_*.vhd puts the core in instance "core").
set_time_format -unit ns -decimal_places 3

create_clock -name {clk_50} -period 20.000 -waveform { 0.000 10.000 } [get_ports {clk_50}]

# CPU clock 892 / 1020 kHz: on Cyclone IV/10 the outputs of the ALTPLL Gosof_PLL
derive_pll_clocks -create_base_clocks
derive_clock_uncertainty

# ... on Cyclone II Gosof_PLL is a divider (rtl\cyclone_II\Gosof_PLL.vhd), its two
# outputs are registers. Only there do these registers exist.
set gosof_div0 [get_registers -nowarn {*PLL|c0_r}]
if {[get_collection_size $gosof_div0] > 0} {
	create_generated_clock -name cpu_clk_892 -divide_by 56 -source [get_ports {clk_50}] $gosof_div0
}
set gosof_div1 [get_registers -nowarn {*PLL|c1_r}]
if {[get_collection_size $gosof_div1] > 0} {
	create_generated_clock -name cpu_clk_1020 -divide_by 49 -source [get_ports {clk_50}] $gosof_div1
}

# The CPU runs on ONE of the two clocks (cpu_clk <= clk_1042 when DIP1 ON else clk_892, a
# clock mux in the core). Paths launched by one and latched by the other do not exist -
# without this TimeQuest reports them (hold -0.009 ns fast model, 15.10.2026).
set_clock_groups -logically_exclusive \
	-group [get_clocks -nowarn {*pll1|clk\[0\] cpu_clk_892}] \
	-group [get_clocks -nowarn {*pll1|clk\[1\] cpu_clk_1020}]

# 9600 baud clock of the DFPlayer UART, a divider register as well
create_generated_clock -name uart_clk_out -divide_by 5208 -source [get_ports {clk_50}] [get_registers {*uart_gen|uart_clk_out}]