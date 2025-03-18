# XDC constraints for the ALINX AX7203
# part: xc7a200tfbg484-2
# General configuration

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true [current_design]

# differential clock
set_property -dict {PACKAGE_PIN R4 IOSTANDARD DIFF_SSTL15} [get_ports clk_p]
set_property -dict {PACKAGE_PIN T4 IOSTANDARD DIFF_SSTL15} [get_ports clk_n]
create_clock -period 5.000 -name clk [get_ports clk_p]

# Reset button
set_property -dict {PACKAGE_PIN T6 IOSTANDARD LVCMOS15} [get_ports reset_n]
set_false_path -from [get_ports reset_n]
set_input_delay 0.000 [get_ports reset_n]