// -----------------------------------------------------------------------------
// tb_edge_detect.v - Self-checking testbench for edge_detect (Lab 03)
// Language : Verilog-2001 (iverilog -g2001, Vivado xsim)
//
// DUT contract (see ../docs/spec.md, section 6):
//   module edge_detect (
//       input  wire clk,
//       input  wire rst,    // synchronous, active high
//       input  wire din,    // clean level
//       output reg  rise,   // registered
//       output reg  fall    // registered
//   );
//   Cycle model, every rising edge:
//       din_d <= din                              (also while rst = 1)
//       rst = 1 : rise <= 0;                fall <= 0
//       rst = 0 : rise <= din & ~din_d;     fall <= ~din & din_d
//   rise is 1 for exactly one cycle, in the cycle after the first cycle in
//   which din is 1. Because din_d follows din during reset, releasing reset
//   never produces a pulse, whatever the level of din.
//
// Checks (T4 of the verification plan):
//   T4a rise/fall compared with the model 1 ns before every rising edge
//   T4b number of rise pulses = number of 0->1 changes of din (same for fall),
//       every pulse exactly one cycle wide
//   T4c no pulse when reset is released with din = 1 or din = 0
//
// Run (from labs/lab03_button):
//   xvlog tb\tb_edge_detect.v rtl\edge_detect.v
//   xelab tb_edge_detect -s tb_edge
//   xsim tb_edge -R
//   or: iverilog -g2001 -Wall -o build/sim_edge tb/tb_edge_detect.v rtl/edge_detect.v
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module tb_edge_detect;

    parameter CLK_PERIOD = 20;
    parameter MAX_ERRORS = 10;

    reg  clk;
    reg  rst;
    reg  din;
    wire rise;
    wire fall;

    edge_detect dut (.clk(clk), .rst(rst), .din(din), .rise(rise), .fall(fall));

    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // ---------------- Golden model ----------------
    reg m_d, m_rise, m_fall;
    always @(posedge clk) begin
        m_d <= din;
        if (rst) begin
            m_rise <= 1'b0;
            m_fall <= 1'b0;
        end else begin
            m_rise <= din & ~m_d;
            m_fall <= ~din & m_d;
        end
    end

    // ---------------- Checkers ----------------
    integer errors, checks;
    integer n_up, n_down, n_rise, n_fall;   // input edges and output pulses (outside reset)
    reg     check_en, din_prev, rise_prev, fall_prev;
    initial begin
        errors = 0; checks = 0; check_en = 1'b0;
        n_up = 0; n_down = 0; n_rise = 0; n_fall = 0;
    end

    always @(negedge clk) begin
        #(CLK_PERIOD / 2 - 1);
        if (check_en) begin
            checks = checks + 1;
            if (rise !== m_rise || fall !== m_fall) begin
                errors = errors + 1;
                if (errors <= MAX_ERRORS)
                    $display("[%0d ns] ERROR: rise=%b fall=%b expected %b %b (rst=%b din=%b)",
                             $time, rise, fall, m_rise, m_fall, rst, din);
            end
            if (rise === 1'b1 && rise_prev === 1'b1) begin
                errors = errors + 1;
                $display("[%0d ns] ERROR: rise high for more than one cycle", $time);
            end
            if (fall === 1'b1 && fall_prev === 1'b1) begin
                errors = errors + 1;
                $display("[%0d ns] ERROR: fall high for more than one cycle", $time);
            end
            if (rise === 1'b1 && rise_prev !== 1'b1) n_rise = n_rise + 1;
            if (fall === 1'b1 && fall_prev !== 1'b1) n_fall = n_fall + 1;
            rise_prev = rise;
            fall_prev = fall;
        end
    end

    // input edges, counted only while out of reset (sampled on the rising edge)
    always @(posedge clk) begin
        if (check_en && !rst) begin
            if (din === 1'b1 && din_prev === 1'b0) n_up   = n_up + 1;
            if (din === 1'b0 && din_prev === 1'b1) n_down = n_down + 1;
        end
        din_prev = din;
    end

    task hold;
        input       val;
        input integer n;
        integer i;
        begin
            din = val;
            for (i = 0; i < n; i = i + 1) @(negedge clk);
        end
    endtask

    integer i, pulses_at_release;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_edge_detect.vcd");
            $dumpvars(0, tb_edge_detect);
        end
        $display("=== tb_edge_detect ===");
        rst = 1'b1; din = 1'b1; din_prev = 1'b1; rise_prev = 1'b0; fall_prev = 1'b0;
        @(posedge clk);
        check_en = 1'b1;
        @(negedge clk);
        // T4c: release reset with din = 1 -> no pulse
        hold(1'b1, 3);
        rst = 1'b0;
        pulses_at_release = n_rise + n_fall;
        hold(1'b1, 4);
        if (n_rise + n_fall != pulses_at_release) begin
            errors = errors + 1;
            $display("ERROR: pulse after reset release with din = 1");
        end
        // T4a/b: long levels, single-cycle levels, alternating every cycle
        hold(1'b0, 5);
        hold(1'b1, 6);
        hold(1'b0, 1);
        hold(1'b1, 1);
        hold(1'b0, 3);
        for (i = 0; i < 8; i = i + 1) hold(i[0], 1);
        hold(1'b1, 2);
        hold(1'b0, 4);
        $display("T4a/b pulse width and count : checked (rise %0d / %0d, fall %0d / %0d)", n_rise, n_up, n_fall, n_down);
        // T4c: reset while din toggles, release with din = 0 -> no pulse
        rst = 1'b1;
        hold(1'b1, 1);
        hold(1'b0, 2);
        rst = 1'b0;
        pulses_at_release = n_rise + n_fall;
        hold(1'b0, 4);
        if (n_rise + n_fall != pulses_at_release) begin
            errors = errors + 1;
            $display("ERROR: pulse after reset release with din = 0");
        end
        hold(1'b1, 3);
        hold(1'b0, 3);
        $display("T4c no pulse at reset release: checked");
        if (n_rise != n_up || n_fall != n_down) begin
            errors = errors + 1;
            $display("ERROR: %0d rise pulses for %0d rising inputs, %0d fall pulses for %0d falling inputs",
                     n_rise, n_up, n_fall, n_down);
        end
        $display("checks = %0d, rise = %0d, fall = %0d, errors = %0d", checks, n_rise, n_fall, errors);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED");
        $finish;
    end

    initial begin
        #(CLK_PERIOD * 300);
        $display("TEST FAILED: timeout");
        $finish;
    end

endmodule
