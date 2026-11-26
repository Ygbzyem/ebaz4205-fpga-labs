`timescale 1ns / 1ps
module lab02_top#(
    parameter W = 8,
    parameter STEP_CYCLES = 196000,
    parameter POR_CYCLES = 16
)(
    input wire clk_50m,
    output wire led_r_n,
    output wire led_g_n
);

wire rst;
wire [W-1:0] duty_g;
wire [W-1:0] duty_r;
wire pwm_out_r;
wire pwm_out_g;

por_gen#( 
    .POR_CYCLES(POR_CYCLES) 
)por_gen_inst(
    .clk(clk_50m),
    .rst(rst)
);
breath_ctrl#(
    .W(W),
    .STEP_CYCLES(STEP_CYCLES)
) breath_crtl_inst(
    .clk(clk_50m),
    .rst(rst),
    .duty(duty_g)
);

assign duty_r = {W{1'b1}} - duty_g;

pwm_core#(
    .W(W)
) pwm_core_inst_r(
    .clk(clk_50m),
    .rst(rst),
    .duty(duty_r),
    .pwm(pwm_out_r)
);

pwm_core#(
    .W(W)
) pwm_core_inst_g(
    .clk(clk_50m),
    .rst(rst),
    .duty(duty_g),
    .pwm(pwm_out_g)
);

assign led_r_n = ~pwm_out_r;
assign led_g_n = ~pwm_out_g;
endmodule