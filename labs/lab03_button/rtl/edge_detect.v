`timescale 1ns / 1ps
module edge_detect(
    input wire clk,
    input wire rst,
    input wire  din,
    output reg  rise,
    output reg  fall
);

reg din_prev;

always @(posedge clk) begin
    if (rst) begin
        rise <= 1'b0;
        fall <= 1'b0;
        din_prev <= din;
    end
    else begin
        rise <= din & ~din_prev;
        fall <= ~din & din_prev;
        din_prev <= din;
    end
end
endmodule
//din_prev	din	    Ý nghĩa
//0	        0	    Không có cạnh
//0	        1	    Cạnh lên
//1	        0	    Cạnh xuống
//1	        1	    Không có cạnh