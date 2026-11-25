`timescale 1ns / 1ps
module lab01_top#(
    parameter HALF_PERIOD = 25000000,
    parameter POR_CYCLES = 16
)(
    input wire clk_50m,
    output wire led_g_n,
    output wire led_r_n
);
wire led_g;
wire led_r;

reg [7:0] por_cnt = 0;
wire rst = (por_cnt < POR_CYCLES);

always @(posedge clk_50m) begin
    if (por_cnt < POR_CYCLES)
        por_cnt <= por_cnt + 1;
end

blink_core #(
    .HALF_PERIOD(HALF_PERIOD)
) u_blink_core (
    .clk(clk_50m),
    .rst(rst),
    .led_g(led_g),
    .led_r(led_r)
);

assign led_g_n = ~led_g;
assign led_r_n = ~led_r;

endmodule

