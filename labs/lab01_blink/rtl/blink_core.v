`timescale 1ns / 1ps

module blink_core#(
    parameter HALF_PERIOD = 25000000
)(
    input wire clk,
    input wire rst,
    output reg led_g,
    output wire led_r
);
function integer clog2; //number of bits to hold 0 .. value-1
    input integer value;
    begin
        value = value - 1;
        for (clog2 = 0; value > 0; clog2 = clog2 + 1)
            value = value >> 1;
    end
endfunction

localparam CNT_WIDTH = clog2(HALF_PERIOD);
reg [CNT_WIDTH-1:0] cnt;

assign led_r = ~led_g;

always @(posedge clk) begin
    if (rst) begin
        led_g <= 1'b0;
        cnt <= 0;
    end
    else if (cnt == HALF_PERIOD - 1) begin
        led_g <= ~led_g;
        cnt <= 0;
    end
    else begin
        cnt <= cnt + 1;
    end
end
endmodule

