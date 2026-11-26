// -----------------------------------------------------------------------------
// tb_lab02_top.v - Self-checking testbench for lab02_top (Lab 02)
// Language : Verilog-2001 (iverilog -g2001, Vivado xsim)
//
// DUT contract (see ../docs/spec.md, sections 3-6):
//   module lab02_top #(parameter STEP_CYCLES = 196000,
//                      parameter POR_CYCLES  = 16) (
//       input  wire clk_50m,
//       output wire led_g_n,    // active-low green LED
//       output wire led_r_n     // active-low red LED
//   );
//   - por_gen: reset high from configuration until POR_CYCLES rising edges
//     have passed (same timing as Lab 01).
//   - breath_ctrl (W = 8) gives d; pwm_core u_g gets d, u_r gets 255 - d.
//   - led_g_n = ~pwm_g, led_r_n = ~pwm_r.
//
// Checks (T5 of the verification plan, plus power-on behavior):
//   T5a Both outputs match a cycle-accurate model of the whole design, every cycle
//   T5b In every PWM period after the first: green high + red high = 255 cycles
//       (complementary duty), checked on the LED pins
//   T5c LEDs are off (led_*_n = 1) during the power-on reset
//
// Run (from labs/lab02_pwm_breathing):
//   xvlog tb\tb_lab02_top.v rtl\lab02_top.v rtl\por_gen.v rtl\breath_ctrl.v rtl\pwm_core.v
//   xelab tb_lab02_top -s tb_top
//   xsim tb_top -R
//   or: iverilog -g2001 -Wall -o build/sim_top tb/tb_lab02_top.v rtl/lab02_top.v rtl/por_gen.v rtl/breath_ctrl.v rtl/pwm_core.v && vvp build/sim_top
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module tb_lab02_top;

    // ---------------- Parameters ----------------
    parameter STEP_CYCLES = 100;      // small for simulation; several duty steps per PWM period
    parameter POR_CYCLES  = 16;
    parameter CLK_PERIOD  = 20;
    parameter MAX_ERRORS  = 10;

    localparam W      = 8;
    localparam MAX    = 255;
    localparam PERIOD = 256;
    localparam BREATH = 2 * MAX * STEP_CYCLES;

    // ---------------- DUT ----------------
    reg  clk_50m;
    wire led_g_n;
    wire led_r_n;

    lab02_top #(
        .STEP_CYCLES (STEP_CYCLES),
        .POR_CYCLES  (POR_CYCLES)
    ) dut (
        .clk_50m (clk_50m),
        .led_g_n (led_g_n),
        .led_r_n (led_r_n)
    );

    initial clk_50m = 1'b0;
    always #(CLK_PERIOD / 2) clk_50m = ~clk_50m;

    // ---------------- Golden model of the whole design ----------------
    integer edges;                      // rising edges since time 0
    reg     m_rst;
    integer b_tick, b_duty;             // breath_ctrl
    reg     b_up;
    integer p_cnt;                      // shared by both PWMs (same reset, same clock)
    integer g_sh, r_sh;
    reg     m_pwm_g, m_pwm_r;

    initial begin
        edges = 0;
        b_tick = 0; b_duty = 0; b_up = 1'b1;
        p_cnt = 0; g_sh = 0; r_sh = 0;
        m_pwm_g = 1'b0; m_pwm_r = 1'b0;
    end

    always @(posedge clk_50m) begin
        m_rst = (edges < POR_CYCLES);
        if (m_rst) begin
            b_tick <= 0; b_duty <= 0; b_up <= 1'b1;
            p_cnt <= 0; g_sh <= 0; r_sh <= 0;
            m_pwm_g <= 1'b0; m_pwm_r <= 1'b0;
        end else begin
            // pwm_core x2
            m_pwm_g <= (p_cnt < g_sh);
            m_pwm_r <= (p_cnt < r_sh);
            if (p_cnt == MAX) begin
                g_sh <= b_duty;
                r_sh <= MAX - b_duty;
            end
            p_cnt <= (p_cnt == MAX) ? 0 : p_cnt + 1;
            // breath_ctrl
            if (b_tick == STEP_CYCLES - 1) begin
                b_tick <= 0;
                if (b_up) begin
                    if (b_duty == MAX) begin b_up <= 1'b0; b_duty <= b_duty - 1; end
                    else                     b_duty <= b_duty + 1;
                end else begin
                    if (b_duty == 0)   begin b_up <= 1'b1; b_duty <= b_duty + 1; end
                    else                     b_duty <= b_duty - 1;
                end
            end else begin
                b_tick <= b_tick + 1;
            end
        end
        edges = edges + 1;
    end

    // ---------------- Checkers ----------------
    integer errors, checks, por_checks, periods;
    integer pos, hi_g, hi_r;
    integer min_g, max_g;

    initial begin
        errors = 0; checks = 0; por_checks = 0; periods = 0;
        pos = -1; hi_g = 0; hi_r = 0; min_g = MAX; max_g = 0;
    end

    always @(negedge clk_50m) begin
        #(CLK_PERIOD / 2 - 1);
        if (edges >= 1) begin
            // T5a / T5c: pin values every cycle
            checks = checks + 1;
            if (edges <= POR_CYCLES) por_checks = por_checks + 1;
            if (led_g_n !== ~m_pwm_g || led_r_n !== ~m_pwm_r) begin
                errors = errors + 1;
                if (errors <= MAX_ERRORS) begin
                    $display("[%0d ns] ERROR after edge %0d: led_g_n=%b led_r_n=%b, expected %b %b (d=%0d)",
                             $time, edges, led_g_n, led_r_n, ~m_pwm_g, ~m_pwm_r, b_duty);
                    if (edges <= POR_CYCLES) $display("    (power-on reset phase: both LEDs must be off)");
                end
            end

            // T5b: per-period sum on the pins, from the second period on
            if (edges > POR_CYCLES + PERIOD && p_cnt == 1) begin
                pos = 0; hi_g = 0; hi_r = 0;
            end
            if (pos >= 0) begin
                if (led_g_n === 1'b0) hi_g = hi_g + 1;
                if (led_r_n === 1'b0) hi_r = hi_r + 1;
                pos = pos + 1;
                if (pos == PERIOD) begin
                    periods = periods + 1;
                    if (hi_g < min_g) min_g = hi_g;
                    if (hi_g > max_g) max_g = hi_g;
                    if (hi_g + hi_r != MAX) begin
                        errors = errors + 1;
                        if (errors <= MAX_ERRORS)
                            $display("[%0d ns] ERROR: period %0d green %0d + red %0d = %0d high cycles, expected %0d",
                                     $time, periods, hi_g, hi_r, hi_g + hi_r, MAX);
                    end
                    pos = -1;
                end
            end
        end
    end

    // ---------------- Sequence ----------------
    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_lab02_top.vcd");
            $dumpvars(0, tb_lab02_top);
        end
        $display("=== tb_lab02_top: STEP_CYCLES = %0d, POR_CYCLES = %0d (one breath = %0d cycles) ===",
                 STEP_CYCLES, POR_CYCLES, BREATH);
        repeat (POR_CYCLES + 2 * BREATH + PERIOD) @(posedge clk_50m);
        @(negedge clk_50m);
        #(CLK_PERIOD / 2);
        // d moves at most PERIOD/STEP_CYCLES + 1 steps between two samples, so both ends
        // of the ramp must be seen within that distance
        if (min_g > PERIOD / STEP_CYCLES + 1 || max_g < MAX - PERIOD / STEP_CYCLES - 1) begin
            errors = errors + 1;
            $display("ERROR: green duty range seen %0d..%0d, the ramp does not reach both ends", min_g, max_g);
        end
        $display("checks = %0d (power-on reset phase: %0d), periods = %0d, green duty range = %0d..%0d, errors = %0d",
                 checks, por_checks, periods, min_g, max_g, errors);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED");
        $finish;
    end

endmodule
