`timescale 1ns / 1ps
module por_gen#(
    parameter POR_CYCLES = 16
)(
    input wire clk,
    output reg rst = 1'b1
);
reg [7:0] por_cnt = 0;
always @(posedge clk) begin 
    if (por_cnt == POR_CYCLES - 1) begin
        rst <= 1'b0;
    end
    else begin
        rst <= 1'b1;
        por_cnt <= por_cnt + 1;
    end
end
endmodule
