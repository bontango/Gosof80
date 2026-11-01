# GOSOF80B timing constraints (80B_dev_open, scripts\files_80b_common.tcl).
# The board shell top\board_80b_dev_open.vhd puts the core in instance "core".
set_time_format -unit ns -decimal_places 3

create_clock -name {clk_50} -period 20.000 -waveform { 0.000 10.000 } [get_ports {clk_50}]
derive_clock_uncertainty

# CPU clock 1 MHz: a register of the core, clk_50 / 50
create_generated_clock -name cpu_clk_1m -divide_by 50 -source [get_ports {clk_50}] [get_registers {*core|cpu_clk}]

# 9600 baud clock, here the time base of the sound test: a divider register as well
create_generated_clock -name uart_clk_out -divide_by 5208 -source [get_ports {clk_50}] [get_registers {*uart_gen|uart_clk_out}]
