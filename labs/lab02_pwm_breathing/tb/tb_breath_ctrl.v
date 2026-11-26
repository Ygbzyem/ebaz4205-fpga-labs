// -----------------------------------------------------------------------------
// tb_breath_ctrl.v - Self-checking testbench for breath_ctrl (Lab 02)
// Language : Verilog-2001 (iverilog -g2001, Vivado xsim)
//
// DUT contract (see ../docs/spec.md, section 5):
//   module breath_ctrl #(parameter W = 8,
//                        parameter STEP_CYCLES = 196000) (
//       input  wire         clk,
//       input  wire         rst,    // synchronous, active high
//       output reg  [W-1:0] duty    // or output wire
//   );
//   - Reset: duty = 0, direction = up, step timer = 0.
//   - duty holds each value for exactly STEP_CYCLES cycles, then changes by 1
//     on the STEP_CYCLES-th rising edge after reset release (and every
//     STEP_CYCLES edges after that).
//   - Triangle without repeated end values: 0,1,...,MAX,MAX-1,...,1,0,1,...
//
// Checks (T4 of the verification plan):
//   T4a duty compared every cycle with a cycle-accurate golden model
//   T4b every value 0..MAX is reached, both ends turn around, at least 2 breaths
//   T4c reset in the middle of a falling ramp restarts from 0 going up
//
// Run (from labs/lab02_pwm_breathing):
//   xvlog tb\tb_breath_ctrl.v rtl\breath_ctrl.v
//   xelab tb_breath_ctrl -s tb_breath
//   xsim tb_breath -R
//   or: iverilog -g2001 -Wall -o build/sim_breath tb/tb_breath_ctrl.v rtl/breath_ctrl.v && vvp build/sim_breath
//   The spec case W = 3, STEP_CYCLES = 3 is the default. Other values:
//   xelab tb_breath_ctrl -generic_top "W=8" -generic_top "STEP_CYCLES=5" -s tb_breath8
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module tb_breath_ctrl;

    // ---------------- Parameters ----------------
    parameter W           = 3;
    parameter STEP_CYCLES = 3;
    parameter CLK_PERIOD  = 20;
    parameter MAX_ERRORS  = 10;

    localparam MAX    = (1 << W) - 1;
    localparam BREATH = 2 * MAX * STEP_CYCLES;   // cycles for one full breath

    // ---------------- DUT ----------------
    reg          clk;
    reg          rst;
    wire [W-1:0] duty;

    breath_ctrl #(
        .W           (W),
        .STEP_CYCLES (STEP_CYCLES)
    ) dut (
        .clk  (clk),
        .rst  (rst),
        .duty (duty)
    );

    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // ---------------- Golden model ----------------
    integer m_tick;       // 0 .. STEP_CYCLES-1
    integer m_duty;
    reg     m_up;

    always @(posedge clk) begin
        if (rst) begin
            m_tick <= 0;
            m_duty <= 0;
            m_up   <= 1'b1;
        end else if (m_tick == STEP_CYCLES - 1) begin
            m_tick <= 0;
            if (m_up) begin
                if (m_duty == MAX) begin m_up <= 1'b0; m_duty <= m_duty - 1; end
                else                     m_duty <= m_duty + 1;
            end else begin
                if (m_duty == 0)   begin m_up <= 1'b1; m_duty <= m_duty + 1; end
                else                     m_duty <= m_duty - 1;
            end
        end else begin
            m_tick <= m_tick + 1;
        end
    end

    // ---------------- Checker ----------------
    integer errors, checks, steps, top_turns, bottom_turns;
    reg     check_en;
    reg     seen [0:MAX];
    integer prev2, prev1;   // last two distinct duty values, for turn detection
    integer last;
    integer i;

    initial begin
        errors = 0; checks = 0; steps = 0; top_turns = 0; bottom_turns = 0;
        check_en = 1'b0; prev2 = -1; prev1 = -1; last = -1;
        for (i = 0; i <= MAX; i = i + 1) seen[i] = 1'b0;
    end

    always @(negedge clk) begin
        #(CLK_PERIOD / 2 - 1);
        if (check_en) begin
            checks = checks + 1;
            if (duty !== m_duty) begin
                errors = errors + 1;
                if (errors <= MAX_ERRORS)
                    $display("[%0d ns] ERROR: duty=%0d expected %0d (rst=%b, model tick=%0d, up=%b)",
                             $time, duty, m_duty, rst, m_tick, m_up);
            end
            if (!rst) begin
                seen[m_duty] = 1'b1;
                if (m_duty != last) begin
                    if (last >= 0) steps = steps + 1;
                    prev2 = prev1;
                    prev1 = last;
                    last  = m_duty;
                    if (prev1 == MAX && last == MAX - 1) top_turns    = top_turns + 1;
                    if (prev1 == 0   && last == 1 && prev2 == 1) bottom_turns = bottom_turns + 1;
                end
            end
        end
    end

    // ---------------- Helpers ----------------
    task wait_cycles;
        input integer n;
        integer k;
        begin
            for (k = 0; k < n; k = k + 1) @(negedge clk);
        end
    endtask

    // ---------------- Test sequence ----------------
    integer missing;

    initial begin
        if (W < 2 || STEP_CYCLES < 2) begin
            $display("TB CONFIG ERROR: need W >= 2 and STEP_CYCLES >= 2 (got %0d, %0d)", W, STEP_CYCLES);
            $finish;
        end
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_breath_ctrl.vcd");
            $dumpvars(0, tb_breath_ctrl);
        end

        $display("=== tb_breath_ctrl: W = %0d, STEP_CYCLES = %0d (one breath = %0d cycles) ===",
                 W, STEP_CYCLES, BREATH);
        rst = 1'b1;
        @(posedge clk);
        check_en = 1'b1;
        wait_cycles(3);
        @(negedge clk) rst = 1'b0;

        // T4a/T4b: two and a half breaths
        wait_cycles(2 * BREATH + BREATH / 2);
        missing = 0;
        for (i = 0; i <= MAX; i = i + 1) if (!seen[i]) missing = missing + 1;
        if (missing != 0 || top_turns < 2 || bottom_turns < 2) begin
            errors = errors + 1;
            $display("ERROR: coverage - values missing = %0d, top turns = %0d, bottom turns = %0d",
                     missing, top_turns, bottom_turns);
        end
        $display("T4a/b ramp, step timing, turns : checked (steps = %0d, top turns = %0d, bottom turns = %0d)",
                 steps, top_turns, bottom_turns);

        // T4c: reset while the ramp is going down, in the middle of a step
        while (!(m_up == 1'b0 && m_duty == MAX / 2 && m_tick == STEP_CYCLES / 2)) @(negedge clk);
        rst = 1'b1;
        wait_cycles(2);
        rst = 1'b0;
        wait_cycles(MAX * STEP_CYCLES + STEP_CYCLES);   // must climb again from 0
        $display("T4c reset on falling ramp      : checked");

        $display("checks = %0d, errors = %0d", checks, errors);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED");
        $finish;
    end

    // ---------------- Watchdog ----------------
    initial begin
        #(CLK_PERIOD * (5 * BREATH + 500));
        $display("TEST FAILED: timeout");
        $finish;
    end

endmodule
