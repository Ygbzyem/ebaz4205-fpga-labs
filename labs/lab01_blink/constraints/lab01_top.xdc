set_property -dict { PACKAGE_PIN N18 IOSTANDARD LVCMOS33 } [get_ports { clk_50m }]
create_clock -name clk_50m -period 20.000 -waveform {0.000 10.000} [get_ports { clk_50m }]
set_property -dict { PACKAGE_PIN W13 IOSTANDARD LVCMOS33 } [get_ports { led_g_n }]
set_property -dict { PACKAGE_PIN W14 IOSTANDARD LVCMOS33 } [get_ports { led_r_n }]