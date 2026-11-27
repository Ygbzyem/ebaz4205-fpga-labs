// -----------------------------------------------------------------------------
// tb_lab03_top.v - Self-checking testbench for lab03_top (Lab 03)
// Language : Verilog-2001 (iverilog -g2001, Vivado xsim)
//
// DUT contract (see ../docs/spec.md, section 7):
//   module lab03_top #(parameter STABLE_CYCLES = 1000000,
//                      parameter POR_CYCLES    = 16) (
//       input  wire clk_50m,
//       input  wire btn_n,      // active-low button, internal pull-up
//       output wire led_g_n,    // toggles on every press
//       output wire led_r_n     // on while the button is held (debounced)
//   );
//   Data path: btn_n -> sync_2ff (RST_VAL = 1) -> invert -> debounce
//   (RST_VAL = 0) = pressed -> edge_detect.rise -> toggle register.
//   pressed drives the red LED; the toggle register drives the green LED.
//   All registers use the power-on reset of por_gen (same timing as Lab 02).
//
// Checks (T5 of the verification plan):
//   T5a both LED pins match a cycle-accurate model of the whole chain, every cycle
//   T5b five presses, each with contact bounce at press and at release:
//       green toggles exactly 5 times, red is on for exactly 5 hold periods
//   T5c LEDs off during and right after the power-on reset
//
// Run (from labs/lab03_button):
//   xvlog tb\tb_lab03_top.v rtl\lab03_top.v rtl\por_gen.v rtl\sync_2ff.v rtl\debounce.v rtl\edge_detect.v
//   xelab tb_lab03_top -s tb_lab03
//   xsim tb_lab03 -R
//   or: iverilog -g2001 -Wall -o build/sim_top tb/tb_lab03_top.v rtl/lab03_top.v rtl/por_gen.v rtl/sync_2ff.v rtl/debounce.v rtl/edge_detect.v
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module tb_lab03_top;

    parameter STABLE_CYCLES = 20;       // small for simulation; board uses 1_000_000
    parameter POR_CYCLES    = 16;
    parameter PRESSES       = 5;
    parameter CLK_PERIOD    = 20;
    parameter MAX_ERRORS    = 10;
    localparam S = STABLE_CYCLES;

    reg  clk_50m;
    reg  btn_n;
    wire led_g_n;
    wire led_r_n;

    lab03_top #(
        .STABLE_CYCLES (STABLE_CYCLES),
        .POR_CYCLES    (POR_CYCLES)
    ) dut (
        .clk_50m (clk_50m),
        .btn_n   (btn_n),
        .led_g_n (led_g_n),
        .led_r_n (led_r_n)
    );

    initial clk_50m = 1'b0;
    always #(CLK_PERIOD / 2) clk_50m = ~clk_50m;

    // ---------------- Golden model of the whole chain ----------------
    integer edges;
    reg     m_rst;
    reg     s1, s2;                 // sync_2ff, RST_VAL = 1
    reg     db;  integer db_cnt;    // debounce, RST_VAL = 0, input = ~s2
    reg     e_d, e_rise;            // edge_detect
    reg     tog;                    // toggle register (green)
    initial begin edges = 0; end

    always @(posedge clk_50m) begin
        m_rst = (edges < POR_CYCLES);
        e_d <= db;
        if (m_rst) begin
            s1 <= 1'b1; s2 <= 1'b1;
            db <= 1'b0; db_cnt <= 0;
            e_rise <= 1'b0;
            tog <= 1'b0;
        end else begin
            s1 <= btn_n; s2 <= s1;
            if (~s2 == db)             db_cnt <= 0;
            else if (db_cnt == S - 1)  begin db <= ~s2; db_cnt <= 0; end
            else                       db_cnt <= db_cnt + 1;
            e_rise <= db & ~e_d;
            if (e_rise) tog <= ~tog;
        end
        edges = edges + 1;
    end

    // ---------------- Checker ----------------
    integer errors, checks, por_checks, g_toggles, r_on;
    reg     g_prev, r_prev;
    initial begin errors = 0; checks = 0; por_checks = 0; g_toggles = 0; r_on = 0; g_prev = 1'bx; r_prev = 1'bx; end

    always @(negedge clk_50m) begin
        #(CLK_PERIOD / 2 - 1);
        if (edges >= 1) begin
            checks = checks + 1;
            if (edges <= POR_CYCLES) por_checks = por_checks + 1;
            if (led_g_n !== ~tog || led_r_n !== ~db) begin
                errors = errors + 1;
                if (errors <= MAX_ERRORS) begin
                    $display("[%0d ns] ERROR after edge %0d: led_g_n=%b led_r_n=%b, expected %b %b (btn_n=%b)",
                             $time, edges, led_g_n, led_r_n, ~tog, ~db, btn_n);
                    if (edges <= POR_CYCLES) $display("    (power-on reset phase: both LEDs must be off)");
                end
            end
            if (g_prev !== 1'bx && led_g_n !== g_prev) g_toggles = g_toggles + 1;
            if (r_prev === 1'b1 && led_r_n === 1'b0) r_on = r_on + 1;
            g_prev = led_g_n;
            r_prev = led_r_n;
        end
    end

    // ---------------- Button model ----------------
    integer seed;
    task hold_btn;                  // keep btn_n for n clock periods, change between edges
        input       val;
        input integer n;
        integer ofs;
        begin
            // 2..18 ns after the falling edge, never on a rising edge (10 ns): asynchronous
            ofs = 2 + 2 * ({$random(seed)} % 8);
            if (ofs == 10) ofs = 18;
            #(ofs);
            btn_n = val;
            repeat (n) @(negedge clk_50m);
        end
    endtask

    task bounce_to;                 // contact bounce, then settle at val
        input val;
        integer i, n;
        begin
            n = 3 + {$random(seed)} % 6;
            for (i = 0; i < n; i = i + 1)
                hold_btn(i[0] ? val : ~val, 1 + {$random(seed)} % (S - 2));
            hold_btn(val, 1);
        end
    endtask

    integer p;
    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_lab03_top.vcd");
            $dumpvars(0, tb_lab03_top);
        end
        seed = 2026;
        btn_n = 1'b1;                          // released (pull-up)
        $display("=== tb_lab03_top: STABLE_CYCLES = %0d, POR_CYCLES = %0d, %0d presses ===", S, POR_CYCLES, PRESSES);
        repeat (POR_CYCLES + 3 * S) @(negedge clk_50m);
        for (p = 0; p < PRESSES; p = p + 1) begin
            bounce_to(1'b0);                   // press
            hold_btn(1'b0, 4 * S);
            bounce_to(1'b1);                   // release
            hold_btn(1'b1, 3 * S);
        end
        repeat (2 * S) @(negedge clk_50m);
        if (g_toggles != PRESSES || r_on != PRESSES) begin
            errors = errors + 1;
            $display("ERROR: green toggled %0d times and red turned on %0d times, expected %0d each",
                     g_toggles, r_on, PRESSES);
        end
        $display("checks = %0d (power-on reset phase: %0d), green toggles = %0d, red presses = %0d, errors = %0d",
                 checks, por_checks, g_toggles, r_on, errors);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED");
        $finish;
    end

    initial begin
        #(CLK_PERIOD * (POR_CYCLES + PRESSES * 20 * S + 2000));
        $display("TEST FAILED: timeout");
        $finish;
    end

endmodule
