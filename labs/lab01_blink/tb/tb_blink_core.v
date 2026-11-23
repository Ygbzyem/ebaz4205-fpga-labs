// -----------------------------------------------------------------------------
// tb_blink_core.v - Self-checking testbench for blink_core (Lab 01)
// Language : Verilog-2001 (iverilog -g2001, Vivado xsim)
//
// DUT contract (see ../docs/spec.md):
//   module blink_core #(parameter HALF_PERIOD = 25000000) (
//       input  wire clk,    // rising-edge clock
//       input  wire rst,    // synchronous, active-high reset
//       output wire led_g,  // or output reg
//       output wire led_r
//   );
//   - While rst is sampled high on a rising edge: led_g = 0, led_r = 1.
//   - After reset release, led_g toggles on every HALF_PERIOD-th rising edge
//     (it stays 0 for exactly HALF_PERIOD cycles, then 1 for HALF_PERIOD, ...).
//   - led_r is always the complement of led_g.
//
// Checking method:
//   A cycle-accurate golden model runs in parallel with the DUT. Outputs are
//   compared 1 ns before every rising edge, so a reset that acts
//   asynchronously (not allowed by the spec) is also caught.
//
// Run (from labs/lab01_blink):
//   mkdir -p build
//   iverilog -g2001 -Wall -Ptb_blink_core.HALF_PERIOD=5 -o build/sim tb/tb_blink_core.v rtl/blink_core.v
//   vvp build/sim            (add +vcd to dump tb_blink_core.vcd)
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module tb_blink_core;

    // ---------------- Parameters ----------------
    parameter HALF_PERIOD = 5;       // small value for simulation; board uses 25_000_000
    parameter CLK_PERIOD  = 20;      // 50 MHz clock, in ns
    parameter MAX_ERRORS  = 10;      // stop printing after this many mismatches

    // ---------------- DUT signals ----------------
    reg  clk;
    reg  rst;
    wire led_g;
    wire led_r;

    blink_core #(
        .HALF_PERIOD (HALF_PERIOD)
    ) dut (
        .clk   (clk),
        .rst   (rst),
        .led_g (led_g),
        .led_r (led_r)
    );

    // ---------------- Clock ----------------
    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // ---------------- Golden model ----------------
    integer m_cnt;     // clock edges counted since last toggle / reset
    reg     m_led;     // expected led_g

    always @(posedge clk) begin
        if (rst) begin
            m_cnt <= 0;
            m_led <= 1'b0;
        end else if (m_cnt == HALF_PERIOD - 1) begin
            m_cnt <= 0;
            m_led <= ~m_led;
        end else begin
            m_cnt <= m_cnt + 1;
        end
    end

    // ---------------- Checker ----------------
    integer errors;
    integer checks;
    integer toggles;
    reg     check_en;
    reg     prev_led_g;

    initial begin
        errors   = 0;
        checks   = 0;
        toggles  = 0;
        check_en = 1'b0;
    end

    // Compare 1 ns before each rising edge (outputs must be stable by then).
    always @(negedge clk) begin
        #(CLK_PERIOD / 2 - 1);
        if (check_en) begin
            checks = checks + 1;
            if (led_g !== m_led || led_r !== ~m_led) begin
                errors = errors + 1;
                if (errors <= MAX_ERRORS)
                    $display("[%0t ns] ERROR: rst=%b led_g=%b led_r=%b, expected led_g=%b led_r=%b (model cnt=%0d)",
                             $time, rst, led_g, led_r, m_led, ~m_led, m_cnt);
            end
            if (led_g !== prev_led_g && prev_led_g !== 1'bx)
                toggles = toggles + 1;
            prev_led_g = led_g;
        end
    end

    // ---------------- Stimulus helpers ----------------
    task wait_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(negedge clk);
        end
    endtask

    // Reset is changed on the falling edge, away from the sampling edge.
    task apply_reset;
        input integer n;
        begin
            @(negedge clk) rst = 1'b1;
            wait_cycles(n);
            rst = 1'b0;
        end
    endtask

    // ---------------- Test sequence ----------------
    initial begin
        if (HALF_PERIOD < 2) begin
            $display("TB CONFIG ERROR: HALF_PERIOD must be >= 2 (got %0d)", HALF_PERIOD);
            $finish;
        end

        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_blink_core.vcd");
            $dumpvars(0, tb_blink_core);
        end

        $display("=== tb_blink_core: HALF_PERIOD = %0d ===", HALF_PERIOD);
        rst        = 1'b1;
        prev_led_g = 1'bx;

        // T1: outputs during reset (start checking after the first edge in reset)
        @(posedge clk);
        check_en = 1'b1;
        wait_cycles(4);
        $display("T1 reset values          : checked");

        // T2: free-running toggling, several full periods
        rst = 1'b0;
        wait_cycles(6 * HALF_PERIOD + 3);
        $display("T2 toggle period         : checked");

        // T3: reset in the middle of a count, then counting restarts from 0
        wait_cycles(HALF_PERIOD / 2);
        apply_reset(3);
        wait_cycles(4 * HALF_PERIOD);
        $display("T3 mid-count reset       : checked");

        // T4: reset on the same edge where a toggle would happen (reset wins)
        while (m_cnt != HALF_PERIOD - 1) @(negedge clk);
        rst = 1'b1;
        wait_cycles(2);
        rst = 1'b0;
        wait_cycles(3 * HALF_PERIOD);
        $display("T4 reset at toggle edge  : checked");

        // T5: one-cycle reset pulse
        apply_reset(1);
        wait_cycles(3 * HALF_PERIOD);
        $display("T5 1-cycle reset pulse   : checked");

        // ---------------- Summary ----------------
        if (toggles == 0) begin
            errors = errors + 1;
            $display("ERROR: led_g never toggled");
        end
        $display("checks = %0d, toggles seen = %0d, errors = %0d", checks, toggles, errors);
        if (errors == 0)
            $display("TEST PASSED");
        else
            $display("TEST FAILED");
        $finish;
    end

    // ---------------- Watchdog ----------------
    initial begin
        #(CLK_PERIOD * (40 * HALF_PERIOD + 200));
        $display("TEST FAILED: timeout");
        $finish;
    end

endmodule
