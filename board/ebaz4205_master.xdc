## =============================================================================
## ebaz4205_master.xdc - Master pin constraints for the EBAZ4205 (XC7Z010CLG400-1)
##
## Usage: copy the lines you need into a lab XDC, uncomment them and rename the
## port in get_ports to match your top-level signal name.
##
## Derived from Development/EBAZ4205.xdc in https://github.com/xjtuecho/EBAZ4205
## Copyright (c) 2020 xjtuecho - MIT License. Changes in this file:
##   - clock period set to 20.000 ns (X5 on this board is 50 MHz, the original
##     file uses 10 ns)
##   - LED polarity (active-low) and header power pins documented
##   - Ethernet pins removed (not used by these labs)
## See board/README.md for the schematic evidence.
## =============================================================================

## ---------------------------------------------------------------------------
## PL clock - X5 oscillator, 50 MHz (fitted by the seller; marked NC in the
## vendor schematic)
## ---------------------------------------------------------------------------
#set_property -dict { PACKAGE_PIN N18 IOSTANDARD LVCMOS33 } [get_ports { clk_50m }];
#create_clock -name clk_50m -period 20.000 -waveform {0.000 10.000} [get_ports { clk_50m }];

## ---------------------------------------------------------------------------
## On-board dual LED (LED6, R+G). Anodes to VCC through 150 ohm,
## cathodes to the FPGA pins -> ACTIVE-LOW: drive 0 to light the LED.
## ---------------------------------------------------------------------------
#set_property -dict { PACKAGE_PIN W13 IOSTANDARD LVCMOS33 } [get_ports { led_g_n }];
#set_property -dict { PACKAGE_PIN W14 IOSTANDARD LVCMOS33 } [get_ports { led_r_n }];

## ---------------------------------------------------------------------------
## DATA1 / DATA2 / DATA3 headers (2x10, 2.0 mm pitch), 22 ohm series resistors
##   pin 1, 2 : VCC-DATAx = board supply input  -> NEVER connect logic here
##   pin 4, 12: GND
##   pin 10   : NC
##   pin 3    : not mapped to an FPGA pin in this file - do not use
## I/O standard LVCMOS33 (3.3 V). Do not apply 5 V.
## ---------------------------------------------------------------------------

## DATA1
#set_property -dict { PACKAGE_PIN A20 IOSTANDARD LVCMOS33 } [get_ports { DATA1_5 }];
#set_property -dict { PACKAGE_PIN H16 IOSTANDARD LVCMOS33 } [get_ports { DATA1_6 }];
#set_property -dict { PACKAGE_PIN B19 IOSTANDARD LVCMOS33 } [get_ports { DATA1_7 }];
#set_property -dict { PACKAGE_PIN B20 IOSTANDARD LVCMOS33 } [get_ports { DATA1_8 }];
#set_property -dict { PACKAGE_PIN C20 IOSTANDARD LVCMOS33 } [get_ports { DATA1_9 }];
#set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports { DATA1_11 }];
#set_property -dict { PACKAGE_PIN D20 IOSTANDARD LVCMOS33 } [get_ports { DATA1_13 }];
#set_property -dict { PACKAGE_PIN D18 IOSTANDARD LVCMOS33 } [get_ports { DATA1_14 }];
#set_property -dict { PACKAGE_PIN H18 IOSTANDARD LVCMOS33 } [get_ports { DATA1_15 }];
#set_property -dict { PACKAGE_PIN D19 IOSTANDARD LVCMOS33 } [get_ports { DATA1_16 }];
#set_property -dict { PACKAGE_PIN F20 IOSTANDARD LVCMOS33 } [get_ports { DATA1_17 }];
#set_property -dict { PACKAGE_PIN E19 IOSTANDARD LVCMOS33 } [get_ports { DATA1_18 }];
#set_property -dict { PACKAGE_PIN F19 IOSTANDARD LVCMOS33 } [get_ports { DATA1_19 }];
#set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS33 } [get_ports { DATA1_20 }];

## DATA2
#set_property -dict { PACKAGE_PIN G20 IOSTANDARD LVCMOS33 } [get_ports { DATA2_5 }];
#set_property -dict { PACKAGE_PIN J18 IOSTANDARD LVCMOS33 } [get_ports { DATA2_6 }];
#set_property -dict { PACKAGE_PIN G19 IOSTANDARD LVCMOS33 } [get_ports { DATA2_7 }];
#set_property -dict { PACKAGE_PIN H20 IOSTANDARD LVCMOS33 } [get_ports { DATA2_8 }];
#set_property -dict { PACKAGE_PIN J19 IOSTANDARD LVCMOS33 } [get_ports { DATA2_9 }];
#set_property -dict { PACKAGE_PIN K18 IOSTANDARD LVCMOS33 } [get_ports { DATA2_11 }];
#set_property -dict { PACKAGE_PIN K19 IOSTANDARD LVCMOS33 } [get_ports { DATA2_13 }];
#set_property -dict { PACKAGE_PIN J20 IOSTANDARD LVCMOS33 } [get_ports { DATA2_14 }];
#set_property -dict { PACKAGE_PIN L16 IOSTANDARD LVCMOS33 } [get_ports { DATA2_15 }];
#set_property -dict { PACKAGE_PIN L19 IOSTANDARD LVCMOS33 } [get_ports { DATA2_16 }];
#set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS33 } [get_ports { DATA2_17 }];
#set_property -dict { PACKAGE_PIN L20 IOSTANDARD LVCMOS33 } [get_ports { DATA2_18 }];
#set_property -dict { PACKAGE_PIN M20 IOSTANDARD LVCMOS33 } [get_ports { DATA2_19 }];
#set_property -dict { PACKAGE_PIN L17 IOSTANDARD LVCMOS33 } [get_ports { DATA2_20 }];

## DATA3
#set_property -dict { PACKAGE_PIN M19 IOSTANDARD LVCMOS33 } [get_ports { DATA3_5 }];
#set_property -dict { PACKAGE_PIN N20 IOSTANDARD LVCMOS33 } [get_ports { DATA3_6 }];
#set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } [get_ports { DATA3_7 }];
#set_property -dict { PACKAGE_PIN M17 IOSTANDARD LVCMOS33 } [get_ports { DATA3_8 }];
#set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports { DATA3_9 }];
#set_property -dict { PACKAGE_PIN P20 IOSTANDARD LVCMOS33 } [get_ports { DATA3_11 }];
#set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports { DATA3_13 }];
#set_property -dict { PACKAGE_PIN R19 IOSTANDARD LVCMOS33 } [get_ports { DATA3_14 }];
#set_property -dict { PACKAGE_PIN P19 IOSTANDARD LVCMOS33 } [get_ports { DATA3_15 }];
#set_property -dict { PACKAGE_PIN T20 IOSTANDARD LVCMOS33 } [get_ports { DATA3_16 }];
#set_property -dict { PACKAGE_PIN U20 IOSTANDARD LVCMOS33 } [get_ports { DATA3_17 }];
#set_property -dict { PACKAGE_PIN T19 IOSTANDARD LVCMOS33 } [get_ports { DATA3_18 }];
#set_property -dict { PACKAGE_PIN V20 IOSTANDARD LVCMOS33 } [get_ports { DATA3_19 }];
#set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports { DATA3_20 }];

## ---------------------------------------------------------------------------
## Fan connectors J3 / J5 (speed sense and PWM)
## ---------------------------------------------------------------------------
#set_property -dict { PACKAGE_PIN V13 IOSTANDARD LVCMOS33 } [get_ports { J3_SPEED }];
#set_property -dict { PACKAGE_PIN U12 IOSTANDARD LVCMOS33 } [get_ports { J3_PWM }];
#set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } [get_ports { J5_SPEED }];
#set_property -dict { PACKAGE_PIN V12 IOSTANDARD LVCMOS33 } [get_ports { J5_PWM }];

## ---------------------------------------------------------------------------
## Pin assignments used by these labs (for reference)
##   clk_50m      N18          all labs
##   led_g_n      W13          all labs
##   led_r_n      W14          all labs
##   btn_n        A20 DATA1-5  lab03+ (push button to GND on DATA1-4, PULLUP)
##   uart_txd     H16 DATA1-6  lab05+ (to USB-UART RXD)
##   uart_rxd     B20 DATA1-8  lab06+ (from USB-UART TXD)
## ---------------------------------------------------------------------------
