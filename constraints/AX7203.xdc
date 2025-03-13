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

# Gigabit Ethernet RGMII PHY 1
set_property -dict {PACKAGE_PIN B17 IOSTANDARD LVCMOS33} [get_ports phy_rx_clk_0]
set_property -dict {PACKAGE_PIN A16 IOSTANDARD LVCMOS33} [get_ports {phy_rxd_0[0]}]
set_property -dict {PACKAGE_PIN B18 IOSTANDARD LVCMOS33} [get_ports {phy_rxd_0[1]}]
set_property -dict {PACKAGE_PIN C18 IOSTANDARD LVCMOS33} [get_ports {phy_rxd_0[2]}]
set_property -dict {PACKAGE_PIN C19 IOSTANDARD LVCMOS33} [get_ports {phy_rxd_0[3]}]
set_property -dict {PACKAGE_PIN A15 IOSTANDARD LVCMOS33} [get_ports phy_rx_ctl_0]

set_property -dict {PACKAGE_PIN E18 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 16} [get_ports phy_tx_clk_0]
set_property -dict {PACKAGE_PIN C20 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 16} [get_ports {phy_txd_0[0]}]
set_property -dict {PACKAGE_PIN D20 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 16} [get_ports {phy_txd_0[1]}]
set_property -dict {PACKAGE_PIN A19 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 16} [get_ports {phy_txd_0[2]}]
set_property -dict {PACKAGE_PIN A18 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 16} [get_ports {phy_txd_0[3]}]
set_property -dict {PACKAGE_PIN F18 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 16} [get_ports phy_tx_ctl_0]
set_property -dict {PACKAGE_PIN D16 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports phy_reset_n_0]
create_clock -period 8.000 -name phy_rx_clk_0 [get_ports phy_rx_clk_0]
set_false_path -to [get_ports phy_reset_n_0]
set_output_delay 0.000 [get_ports phy_reset_n_0]

#Gigabit Ethernet RGMII PHY 2
set_property -dict {PACKAGE_PIN E19 IOSTANDARD LVCMOS33} [get_ports phy_rx_clk_1]
set_property -dict {PACKAGE_PIN A20 IOSTANDARD LVCMOS33} [get_ports {phy_rxd_1[0]}]
set_property -dict {PACKAGE_PIN B20 IOSTANDARD LVCMOS33} [get_ports {phy_rxd_1[1]}]
set_property -dict {PACKAGE_PIN D19 IOSTANDARD LVCMOS33} [get_ports {phy_rxd_1[2]}]
set_property -dict {PACKAGE_PIN C17 IOSTANDARD LVCMOS33} [get_ports {phy_rxd_1[3]}]
set_property -dict {PACKAGE_PIN F19 IOSTANDARD LVCMOS33} [get_ports phy_rx_ctl_1]

set_property -dict {PACKAGE_PIN A14 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 16} [get_ports phy_tx_clk_1]
set_property -dict {PACKAGE_PIN E17 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 16} [get_ports {phy_txd_1[0]}]
set_property -dict {PACKAGE_PIN C14 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 16} [get_ports {phy_txd_1[1]}]
set_property -dict {PACKAGE_PIN C15 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 16} [get_ports {phy_txd_1[2]}]
set_property -dict {PACKAGE_PIN A13 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 16} [get_ports {phy_txd_1[3]}]
set_property -dict {PACKAGE_PIN D17 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 16} [get_ports phy_tx_ctl_1]
set_property -dict {PACKAGE_PIN B22 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports phy_reset_n_1]
create_clock -period 8.000 -name phy_rx_clk_1 [get_ports phy_rx_clk_1]
set_false_path -to [get_ports phy_reset_n_1]
set_output_delay 0.000 [get_ports phy_reset_n_1]




