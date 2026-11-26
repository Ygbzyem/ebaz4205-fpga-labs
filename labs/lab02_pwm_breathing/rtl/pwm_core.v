`timescale 1ns / 1ps
module pwm_core#(
    parameter W = 8
)(
    input wire clk,
    input wire rst,
    input wire [W-1:0] duty,
    output reg pwm
);
reg [W-1:0] cnt;
reg [W-1:0] duty_shadow;
always @(posedge clk) begin
    if (rst) begin
        cnt <= 0;
        duty_shadow <= 0;
        pwm <= 1'b0;
    end
    else begin  
        if (cnt == 2**W - 1) begin
            cnt <= 0;
            duty_shadow <= duty;
        end
        else begin
            cnt <= cnt + 1;
        end

        if (cnt < duty_shadow) begin
            pwm <= 1'b1;
        end
        else begin
            pwm <= 1'b0;
        end
    end
end
endmodule