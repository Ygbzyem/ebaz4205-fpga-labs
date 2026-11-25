// -----------------------------------------------------------------------------
// tb_lab01_top.v - Self-checking testbench for lab01_top (Lab 01)
// Language : Verilog-2001 (iverilog -g2001, Vivado xsim)
//
// DUT contract (see ../docs/spec.md, section 5):
//   module lab01_top #(parameter HALF_PERIOD = 25000000,
//                      parameter POR_CYCLES  = 16) (
//       input  wire clk_50m,
//       output wire led_g_n,     // active-low green LED
//       output wire led_r_n      // active-low red LED
//   );
//   - No reset port: an internal power-on reset is high from configuration
//     until POR_CYCLES rising edges of clk_50m have passed.
//   - led_g_n = ~led_g, led_r_n = ~led_r of blink_core.
//
// Checks (T6, T7 of the verification plan):
//   T6  During the first POR_CYCLES edges the LEDs show the reset state:
//       green off (led_g_n = 1), red on (led_r_n = 0).
//   T7  After the power-on reset, the outputs follow a cycle-accurate model of
//       blink_core, inverted; led_g_n and led_r_n are always complementary.
//
// Run (from labs/lab01_blink):
//   xvlog tb\tb_lab01_top.v rtl\lab01_top.v rtl\blink_core.v
//   xelab tb_lab01_top -s tb_top
//   xsim tb_top -R
//   or: iverilog -g2001 -Wall -o build/sim_top tb/tb_lab01_top.v rtl/lab01_top.v rtl/blink_core.v
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module tb_lab01_top;

    parameter HALF_PERIOD = 4;        // small value for simulation
    parameter POR_CYCLES  = 16;
    parameter CLK_PERIOD  = 20;       // 50 MHz
    parameter MAX_ERRORS  = 10;

    reg  clk_50m;
    wire led_g_n;
    wire led_r_n;

    lab01_top #(
        .HALF_PERIOD (HALF_PERIOD),
        .POR_CYCLES  (POR_CYCLES)
    ) dut (
        .clk_50m (clk_50m),
        .led_g_n (led_g_n),
        .led_r_n (led_r_n)
    );

    initial clk_50m = 1'b0;
    always #(CLK_PERIOD / 2) clk_50m = ~clk_50m;

    // ---------------- Reference model ----------------
    integer edges;        // rising edges since time 0
    integer m_cnt;
    reg     m_led;        // expected active-high green
    reg     m_rst;        // expected internal reset as sampled on this edge

    initial begin
        edges = 0;
        m_cnt = 0;
        m_led = 1'b0;
    end

    always @(posedge clk_50m) begin
        m_rst = (edges < POR_CYCLES);      // reset is high for the first POR_CYCLES edges
        if (m_rst) begin
            m_cnt <= 0;
            m_led <= 1'b0;
        end else if (m_cnt == HALF_PERIOD - 1) begin
            m_cnt <= 0;
            m_led <= ~m_led;
        end else begin
            m_cnt <= m_cnt + 1;
        end
        edges = edges + 1;
    end

    // ---------------- Checker: 1 ns before each rising edge ----------------
    integer errors, checks, por_checks, toggles;
    reg     prev_g;

    initial begin
        errors = 0; checks = 0; por_checks = 0; toggles = 0; prev_g = 1'bx;
    end

    always @(negedge clk_50m) begin
        #(CLK_PERIOD / 2 - 1);
        if (edges >= 1) begin
            checks = checks + 1;
            if (edges <= POR_CYCLES) por_checks = por_checks + 1;
            if (led_g_n !== ~m_led || led_r_n !== m_led) begin
                errors = errors + 1;
                if (errors <= MAX_ERRORS)
                    $display("[%0d ns] ERROR after edge %0d: led_g_n=%b led_r_n=%b, expected led_g_n=%b led_r_n=%b%s",
                             $time, edges, led_g_n, led_r_n, ~m_led, m_led,
                             (edges <= POR_CYCLES) ? " (power-on reset phase)" : "");
            end
            if (led_g_n !== prev_g && prev_g !== 1'bx) toggles = toggles + 1;
            prev_g = led_g_n;
        end
    end

    // ---------------- Sequence ----------------
    initial begin
        $display("=== tb_lab01_top: HALF_PERIOD = %0d, POR_CYCLES = %0d ===", HALF_PERIOD, POR_CYCLES);
        repeat (POR_CYCLES + 8 * HALF_PERIOD + 4) @(posedge clk_50m);
        @(negedge clk_50m);
        #(CLK_PERIOD / 2);
        if (toggles == 0) begin
            errors = errors + 1;
            $display("ERROR: LEDs never toggled");
        end
        $display("checks = %0d (power-on reset phase: %0d), toggles seen = %0d, errors = %0d",
                 checks, por_checks, toggles, errors);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED");
        $finish;
    end

endmodule
