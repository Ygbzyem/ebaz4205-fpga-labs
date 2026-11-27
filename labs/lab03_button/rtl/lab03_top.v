`timescale 1ns / 1ps
module lab03_top#(
    parameter STABLE_CYCLES = 1000000,
    parameter POR_CYCLES = 16
)(
    input wire clk_50m, 
    input wire btn_n,
    output wire led_g_n,
    output wire led_r_n
);

wire rst;
wire pressed;
wire rise;
wire btn_sync;
reg led_g;

always @(posedge clk_50m) begin
    if (rst) begin
        led_g <= 1'b0;
    end
    else if(rise) begin
        led_g <= ~led_g;
    end
end

por_gen#(
    .POR_CYCLES(POR_CYCLES)
) por_gen_inst(
    .clk(clk_50m),
    .rst(rst)
);

sync_2ff#(
    .RST_VAL(1'b1)
) sync_2ff_inst(
    .clk(clk_50m),
    .rst(rst),
    .d(btn_n),
    .q(btn_sync)
);

debounce#(
    .STABLE_CYCLES(STABLE_CYCLES)
) debounce_inst(
    .clk(clk_50m),
    .rst(rst),
    .din(~btn_sync),
    .dout(pressed)
);

edge_detect edge_detect_inst_rise(
    .clk(clk_50m),
    .rst(rst),
    .din(pressed),
    .rise(rise)
);

assign led_r_n = ~pressed;
assign led_g_n = ~led_g;

endmodule