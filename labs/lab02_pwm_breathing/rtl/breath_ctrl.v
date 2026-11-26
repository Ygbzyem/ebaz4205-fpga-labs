`timescale 1ns / 1ps
module breath_ctrl#(
    parameter W = 8,
    parameter STEP_CYCLES = 196000
)(
    input wire clk,
    input wire rst,
    output reg [W-1:0] duty
);

function integer clog2;
    input integer value;
    begin
        value = value - 1;
        for (clog2 = 0; value > 0; clog2 = clog2 + 1)
            value = value >> 1;
    end
endfunction

localparam CNT_WIDTH = clog2(STEP_CYCLES);
reg [CNT_WIDTH-1:0] cnt;
reg direction; // 1: increasing, 0: decreasing

always @(posedge clk) begin
    if (rst) begin
        duty <= 0;
        cnt <= 0;
        direction <= 1; // Start by increasing
    end
    else if (cnt == STEP_CYCLES - 1) begin
        cnt <= 0;
        if (direction) begin
            if (duty < 2**W - 1) begin
                duty <= duty + 1;
            end 
            else begin
                direction <= 0; // Change direction to decreasing
                duty <= duty - 1; // Start decreasing
            end
        end else begin
            if (duty > 0) begin
                duty <= duty - 1;
            end else begin
                direction <= 1; // Change direction to increasing
                duty <= duty + 1; // Start increasing
            end
        end
    end
    else begin
        cnt <= cnt + 1;
    end
end
endmodule

