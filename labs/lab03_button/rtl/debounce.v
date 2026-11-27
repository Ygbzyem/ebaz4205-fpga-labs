`timescale 1ns / 1ps
module debounce#(
    parameter STABLE_CYCLES = 1000000,
    parameter RST_VAL = 1'b0
)(
    input wire clk,
    input wire rst,
    input wire din,
    output reg dout
);

function integer clog2;
    input integer value;
    begin
        value = value - 1;
        for (clog2 = 0; value > 0; clog2 = clog2 + 1)
            value = value >> 1;
    end
endfunction

localparam STABLE_WIDTH = clog2(STABLE_CYCLES);
reg [STABLE_WIDTH-1:0] stable_cnt;

always @(posedge clk) begin
    if (rst) begin
        stable_cnt <= 0;
        dout <= RST_VAL;
    end
    else if (din != dout) begin
        stable_cnt <= stable_cnt + 1;
        if (stable_cnt == STABLE_CYCLES - 1) begin
            dout <= din;
            stable_cnt <= 0;
        end
    end
    else begin
        stable_cnt <= 0;
    end
end
endmodule

