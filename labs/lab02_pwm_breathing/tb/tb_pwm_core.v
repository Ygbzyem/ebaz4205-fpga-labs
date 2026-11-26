// -----------------------------------------------------------------------------
// tb_pwm_core.v - Self-checking testbench for pwm_core (Lab 02)
// Language : Verilog-2001 (iverilog -g2001, Vivado xsim)
//
// DUT contract (see ../docs/spec.md, section 4):
//   module pwm_core #(parameter W = 8) (
//       input  wire         clk,
//       input  wire         rst,    // synchronous, active high
//       input  wire [W-1:0] duty,
//       output reg          pwm     // registered
//   );
//   Cycle model (one line per rising edge, rst low):
//       pwm    <= (cnt < duty_sh);
//       duty_sh <= (cnt == 2^W-1) ? duty : duty_sh;
//       cnt    <= cnt + 1;                    // wraps 2^W-1 -> 0
//   Reset: cnt = 0, duty_sh = 0, pwm = 0.
//   So one PWM period = 2^W cycles, pwm is high for exactly duty_sh cycles,
//   one cycle after cnt = 0 (pwm is a register), and duty is captured only at
//   the wrap edge. The first period after reset is always low (duty_sh = 0).
//
// Checks (T1-T3 of the verification plan):
//   T1  duty = 0, 1, 2, MAX/2, MAX/2+1, MAX-1, MAX: high cycles per period = duty
//   T2  duty changed in the middle of a period: current period unchanged
//   T3  reset in the middle of a period, and a 1-cycle reset pulse
//   Every cycle the output is compared with a cycle-accurate golden model,
//   1 ns before the rising edge. In addition, the high cycles of every PWM
//   period are counted and compared with the duty captured for that period.
//
// Run (from labs/lab02_pwm_breathing):
//   xvlog tb\tb_pwm_core.v rtl\pwm_core.v
//   xelab tb_pwm_core -s tb_pwm
//   xsim tb_pwm -R
//   or: iverilog -g2001 -Wall -o build/sim_pwm tb/tb_pwm_core.v rtl/pwm_core.v && vvp build/sim_pwm
//   Other width: xelab tb_pwm_core -generic_top "W=4" -s tb_pwm4
//                iverilog ... -Ptb_pwm_core.W=4 ...
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module tb_pwm_core;

    // ---------------- Parameters ----------------
    parameter W          = 8;
    parameter CLK_PERIOD = 20;          // 50 MHz
    parameter MAX_ERRORS = 10;

    localparam MAX    = (1 << W) - 1;   // largest duty value
    localparam PERIOD = (1 << W);       // cycles per PWM period

    // ---------------- DUT ----------------
    reg          clk;
    reg          rst;
    reg  [W-1:0] duty;
    wire         pwm;

    pwm_core #(.W(W)) dut (
        .clk  (clk),
        .rst  (rst),
        .duty (duty),
        .pwm  (pwm)
    );

    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // ---------------- Golden model ----------------
    integer m_cnt;        // 0 .. MAX
    integer m_sh;         // duty used in the current period
    reg     m_pwm;
    integer m_sh_prev;    // duty of the period that is being output now

    always @(posedge clk) begin
        if (rst) begin
            m_pwm <= 1'b0;
            m_sh  <= 0;
            m_cnt <= 0;
        end else begin
            m_pwm <= (m_cnt < m_sh);
            if (m_cnt == MAX) m_sh <= duty;
            m_cnt <= (m_cnt == MAX) ? 0 : m_cnt + 1;
        end
    end

    // ---------------- Checker 1: every cycle ----------------
    integer errors, checks;
    reg     check_en;

    initial begin
        errors = 0; checks = 0; check_en = 1'b0;
    end

    always @(negedge clk) begin
        #(CLK_PERIOD / 2 - 1);
        if (check_en) begin
            checks = checks + 1;
            if (pwm !== m_pwm) begin
                errors = errors + 1;
                if (errors <= MAX_ERRORS)
                    $display("[%0d ns] ERROR: pwm=%b expected %b (rst=%b, model cnt=%0d, captured duty=%0d)",
                             $time, pwm, m_pwm, rst, m_cnt, m_sh);
            end
        end
    end

    // ---------------- Checker 2: high cycles per period ----------------
    // A PWM period is output during the PERIOD cycles that follow the edge where
    // the model counter goes from 0 to 1 (pwm is one cycle behind cnt).
    integer p_high;       // high cycles counted in the current output period
    integer p_pos;        // position inside the output period, -1 = not aligned
    integer p_duty;       // duty expected for the current output period
    integer periods;      // completed periods checked

    initial begin
        p_high = 0; p_pos = -1; p_duty = 0; periods = 0;
    end

    always @(negedge clk) begin
        #(CLK_PERIOD / 2 - 1);
        if (rst) begin
            p_pos = -1;
        end else if (check_en) begin
            if (m_cnt == 1) begin          // first cycle of an output period
                p_pos  = 0;
                p_high = 0;
                p_duty = m_sh;
            end
            if (p_pos >= 0) begin
                if (pwm === 1'b1) p_high = p_high + 1;
                p_pos = p_pos + 1;
                if (p_pos == PERIOD) begin
                    periods = periods + 1;
                    if (p_high != p_duty) begin
                        errors = errors + 1;
                        if (errors <= MAX_ERRORS)
                            $display("[%0d ns] ERROR: period %0d had %0d high cycles, expected %0d",
                                     $time, periods, p_high, p_duty);
                    end
                    p_pos = -1;
                end
            end
        end
    end

    // ---------------- Stimulus helpers ----------------
    task wait_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) @(negedge clk);
        end
    endtask

    // Wait until the model counter has value c mod PERIOD (sampled at the falling edge).
    task wait_cnt;
        input integer c;
        begin
            @(negedge clk);
            while (m_cnt != c % PERIOD) @(negedge clk);
        end
    endtask

    // Set a new duty at a given counter position and hold it for n full periods.
    task run_duty;
        input integer d;
        input integer at_cnt;
        input integer n;
        begin
            wait_cnt(at_cnt);
            duty = d;
            wait_cycles(n * PERIOD);
            $display("    duty = %0d held for %0d periods", d, n);
        end
    endtask

    // ---------------- Test sequence ----------------
    initial begin
        if (W < 2) begin
            $display("TB CONFIG ERROR: W must be >= 2 (got %0d)", W);
            $finish;
        end
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_pwm_core.vcd");
            $dumpvars(0, tb_pwm_core);
        end

        $display("=== tb_pwm_core: W = %0d (period %0d cycles, max duty %0d) ===", W, PERIOD, MAX);
        rst  = 1'b1;
        duty = 0;
        @(posedge clk);
        check_en = 1'b1;
        wait_cycles(3);
        @(negedge clk) rst = 1'b0;

        // T1: high cycles per period for the corner and middle duty values
        $display("T1 duty values:");
        run_duty(0,         5, 3);
        run_duty(1,         7, 3);
        run_duty(2,         3, 3);
        run_duty(MAX/2,     MAX, 3);   // set on the wrap edge position
        run_duty(MAX/2 + 1, 0, 3);
        run_duty(MAX - 1,   1, 3);
        run_duty(MAX,       2, 3);
        run_duty(0,         4, 3);     // back to 0: output must go fully low
        $display("T1 high cycles per period : checked");

        // T2: change duty in the middle of a period, twice in the same period
        wait_cnt(MAX/4);
        duty = 3;
        wait_cnt(MAX/2);
        duty = MAX - 2;                // last value before the wrap is the one captured
        wait_cnt(MAX - 1);
        wait_cycles(3 * PERIOD);
        $display("T2 mid-period change      : checked");

        // T3: reset in the middle of a period, then a 1-cycle reset pulse
        duty = MAX/2;
        wait_cnt(MAX/3);
        rst = 1'b1;
        wait_cycles(3);
        rst = 1'b0;
        wait_cycles(4 * PERIOD);
        wait_cnt(MAX/2);
        rst = 1'b1;
        wait_cycles(1);
        rst = 1'b0;
        wait_cycles(4 * PERIOD);
        $display("T3 reset mid-period       : checked");

        // ---------------- Summary ----------------
        if (periods < 20) begin
            errors = errors + 1;
            $display("ERROR: only %0d PWM periods were checked", periods);
        end
        $display("checks = %0d, periods checked = %0d, errors = %0d", checks, periods, errors);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED");
        $finish;
    end

    // ---------------- Watchdog ----------------
    initial begin
        #(CLK_PERIOD * (40 * PERIOD + 500));
        $display("TEST FAILED: timeout");
        $finish;
    end

endmodule
