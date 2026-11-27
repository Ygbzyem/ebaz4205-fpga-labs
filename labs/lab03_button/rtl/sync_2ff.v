`timescale 1ns / 1ps
module sync_2ff#(
    parameter RST_VAL = 1'b0
)
(
    input wire clk,
    input wire rst,
    input wire d,
    output wire q
);

(* ASYNC_REG = "TRUE" *) reg sync_ff1;
(* ASYNC_REG = "TRUE" *) reg sync_ff2;

always @(posedge clk) begin
    if (rst) begin
        sync_ff1 <= RST_VAL;
        sync_ff2 <= RST_VAL;
    end
    else begin
        sync_ff1 <= d;
        sync_ff2 <= sync_ff1;
    end
end
    assign q = sync_ff2;
endmodule