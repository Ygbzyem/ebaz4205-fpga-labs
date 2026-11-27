// -----------------------------------------------------------------------------
// tb_debounce.v - Self-checking testbench for debounce (Lab 03)
// Language : Verilog-2001 (iverilog -g2001, Vivado xsim)
//
// DUT contract (see ../docs/spec.md, section 5):
//   module debounce #(parameter STABLE_CYCLES = 1000000,
//                     parameter RST_VAL       = 1'b0) (
//       input  wire clk,
//       input  wire rst,    // synchronous, active high
//       input  wire din,    // already synchronized, still bouncing
//       output reg  dout    // or output wire
//   );
//   Cycle model, every rising edge (cnt counts consecutive samples din != dout):
//       rst = 1                      : dout <= RST_VAL; cnt <= 0
//       din == dout                  : cnt <= 0
//       din != dout, cnt < S-1       : cnt <= cnt + 1
//       din != dout, cnt == S-1      : dout <= din; cnt <= 0
//   (S = STABLE_CYCLES.) dout changes on the edge where din has been sampled
//   different from dout on S consecutive edges, that edge included. A pulse
//   of S-1 samples never passes; a pulse of S samples does.
//
// Checks (T2, T3 of the verification plan):
//   T2  bursts of pseudo-random pulses, all shorter than S: dout unchanged
//   T3  stable change: dout changes exactly S edges after the last din edge
//   T3b pulses of exactly S-1 (blocked) and exactly S (passed) samples
//   T3c reset in the middle of a count
//   dout compared with the model 1 ns before every rising edge.
//
// Run (from labs/lab03_button):
//   xvlog tb\tb_debounce.v rtl\debounce.v
//   xelab tb_debounce -s tb_deb
//   xsim tb_deb -R
//   or: iverilog -g2001 -Wall -o build/sim_deb tb/tb_debounce.v rtl/debounce.v
//   other values: -generic_top "STABLE_CYCLES=5" -generic_top "RST_VAL=1"
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module tb_debounce;

    parameter STABLE_CYCLES = 8;       // small for simulation; board uses 1_000_000
    parameter RST_VAL       = 1'b0;
    parameter CLK_PERIOD    = 20;
    parameter MAX_ERRORS    = 10;
    localparam S = STABLE_CYCLES;

    reg  clk;
    reg  rst;
    reg  din;
    wire dout;

    debounce #(.STABLE_CYCLES(STABLE_CYCLES), .RST_VAL(RST_VAL)) dut (
        .clk(clk), .rst(rst), .din(din), .dout(dout));

    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // ---------------- Golden model ----------------
    reg     m_dout;
    integer m_cnt;
    always @(posedge clk) begin
        if (rst) begin
            m_dout <= RST_VAL;
            m_cnt  <= 0;
        end else if (din == m_dout) begin
            m_cnt  <= 0;
        end else if (m_cnt == S - 1) begin
            m_dout <= din;
            m_cnt  <= 0;
        end else begin
            m_cnt  <= m_cnt + 1;
        end
    end

    // ---------------- Checker ----------------
    integer errors, checks, changes;
    reg     check_en, prev;
    initial begin errors = 0; checks = 0; changes = 0; check_en = 1'b0; prev = 1'bx; end

    always @(negedge clk) begin
        #(CLK_PERIOD / 2 - 1);
        if (check_en) begin
            checks = checks + 1;
            if (dout !== m_dout) begin
                errors = errors + 1;
                if (errors <= MAX_ERRORS)
                    $display("[%0d ns] ERROR: dout=%b expected %b (rst=%b din=%b, model cnt=%0d)",
                             $time, dout, m_dout, rst, din, m_cnt);
            end
            if (prev !== 1'bx && dout !== prev) changes = changes + 1;
            prev = dout;
        end
    end

    // ---------------- Stimulus helpers (din changes on the falling edge) ----------------
    task hold;                         // keep din for n samples
        input       val;
        input integer n;
        integer i;
        begin
            din = val;
            for (i = 0; i < n; i = i + 1) @(negedge clk);
        end
    endtask

    integer seed;
    task bounce;                       // pseudo-random pulses, each 1..S-1 samples
        input integer pulses;
        integer i;
        begin
            for (i = 0; i < pulses; i = i + 1)
                hold(~din, 1 + ({$random(seed)} % (S - 1)));
        end
    endtask

    // Measure: after the last din edge, count edges until dout follows.
    task stable_change;
        input val;
        integer k;
        reg     before;
        begin
            before = dout;
            din = val;
            k = 0;
            while (dout === before && k < S + 5) begin
                @(posedge clk); #1; k = k + 1;
            end
            if (k != S) begin
                errors = errors + 1;
                $display("[%0d ns] ERROR: dout followed din after %0d edges, expected %0d", $time, k, S);
            end
            @(negedge clk);
        end
    endtask

    integer changes_before;

    initial begin
        if (S < 3) begin
            $display("TB CONFIG ERROR: STABLE_CYCLES must be >= 3 (got %0d)", S);
            $finish;
        end
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_debounce.vcd");
            $dumpvars(0, tb_debounce);
        end
        seed = 12345;
        $display("=== tb_debounce: STABLE_CYCLES = %0d, RST_VAL = %b ===", S, RST_VAL);
        rst = 1'b1;
        din = ~RST_VAL;
        @(posedge clk);
        check_en = 1'b1;
        @(negedge clk);
        hold(~RST_VAL, 3);            // input differs during reset: dout must stay RST_VAL
        rst = 1'b0;
        hold(RST_VAL, 2 * S);

        // T2: bursts shorter than S around the idle level
        changes_before = changes;
        din = RST_VAL;
        bounce(30);
        hold(RST_VAL, 2 * S);
        if (changes != changes_before) begin
            errors = errors + 1;
            $display("ERROR: dout changed during a burst of short pulses");
        end
        $display("T2  bounce burst                : checked");

        // T3: press with bounce, then stable; release with bounce, then stable
        bounce(16);   // even count: din ends at the dout level, so the next edge is the last one
        stable_change(~RST_VAL);
        hold(~RST_VAL, 3 * S);
        bounce(16);   // even count: din ends at the dout level, so the next edge is the last one
        stable_change(RST_VAL);
        hold(RST_VAL, 2 * S);
        $display("T3  stable change after S edges : checked");

        // T3b: exactly S-1 samples (blocked), exactly S samples (passed)
        changes_before = changes;
        hold(~RST_VAL, S - 1);
        hold(RST_VAL, 2 * S);
        if (changes != changes_before) begin
            errors = errors + 1;
            $display("ERROR: a pulse of S-1 samples reached dout");
        end
        hold(~RST_VAL, S);
        hold(RST_VAL, 2 * S + 2);
        if (changes != changes_before + 2) begin
            errors = errors + 1;
            $display("ERROR: a pulse of S samples did not reach dout (changes %0d)", changes - changes_before);
        end
        $display("T3b S-1 blocked, S passed       : checked");

        // T3c: reset in the middle of a count
        hold(~RST_VAL, S / 2);
        rst = 1'b1;
        hold(~RST_VAL, 2);
        rst = 1'b0;
        hold(~RST_VAL, S + 3);
        hold(RST_VAL, S + 3);
        $display("T3c reset mid-count             : checked");

        $display("checks = %0d, dout changes = %0d, errors = %0d", checks, changes, errors);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED");
        $finish;
    end

    initial begin
        #(CLK_PERIOD * (60 * S + 2000));
        $display("TEST FAILED: timeout");
        $finish;
    end

endmodule
