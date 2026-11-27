// -----------------------------------------------------------------------------
// tb_sync_2ff.v - Self-checking testbench for sync_2ff (Lab 03)
// Language : Verilog-2001 (iverilog -g2001, Vivado xsim)
//
// DUT contract (see ../docs/spec.md, section 4):
//   module sync_2ff #(parameter RST_VAL = 1'b0) (
//       input  wire clk,
//       input  wire rst,    // synchronous, active high
//       input  wire d,      // asynchronous input
//       output wire q       // or output reg
//   );
//   Cycle model, every rising edge:
//       rst = 1 : ff1 <= RST_VAL; q <= RST_VAL
//       rst = 0 : ff1 <= d;       q <= ff1
//   A change of d between two edges appears on q after exactly 2 rising edges.
//
// Checks (T1 of the verification plan):
//   T1a q compared with the model 1 ns before every rising edge
//   T1b latency measured for every change of d: exactly 2 edges
//   T1c reset value RST_VAL, reset asserted while d differs from RST_VAL
//   d changes at several offsets inside the clock period (never on the edge),
//   as an asynchronous button would.
//
// Run (from labs/lab03_button):
//   xvlog tb\tb_sync_2ff.v rtl\sync_2ff.v
//   xelab tb_sync_2ff -s tb_sync
//   xsim tb_sync -R
//   other reset value: xelab tb_sync_2ff -generic_top "RST_VAL=1" -s tb_sync1
//   or: iverilog -g2001 -Wall -Ptb_sync_2ff.RST_VAL=1 -o build/sim_sync tb/tb_sync_2ff.v rtl/sync_2ff.v
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module tb_sync_2ff;

    parameter RST_VAL    = 1'b0;
    parameter CLK_PERIOD = 20;
    parameter MAX_ERRORS = 10;

    reg  clk;
    reg  rst;
    reg  d;
    wire q;

    sync_2ff #(.RST_VAL(RST_VAL)) dut (.clk(clk), .rst(rst), .d(d), .q(q));

    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // ---------------- Golden model ----------------
    reg m_ff1, m_q;
    always @(posedge clk) begin
        if (rst) begin
            m_ff1 <= RST_VAL;
            m_q   <= RST_VAL;
        end else begin
            m_ff1 <= d;
            m_q   <= m_ff1;
        end
    end

    // ---------------- Checker: every cycle ----------------
    integer errors, checks;
    reg     check_en;
    initial begin errors = 0; checks = 0; check_en = 1'b0; end

    always @(negedge clk) begin
        #(CLK_PERIOD / 2 - 1);
        if (check_en) begin
            checks = checks + 1;
            if (q !== m_q) begin
                errors = errors + 1;
                if (errors <= MAX_ERRORS)
                    $display("[%0d ns] ERROR: q=%b expected %b (rst=%b d=%b)", $time, q, m_q, rst, d);
            end
        end
    end

    // ---------------- Latency measurement ----------------
    integer edges;            // rising edges since time 0
    integer change_edge;      // value of 'edges' when d last changed (-1 = none pending)
    integer latencies, bad_lat;
    initial begin edges = 0; change_edge = -1; latencies = 0; bad_lat = 0; end
    always @(posedge clk) edges = edges + 1;

    // Toggle d at an offset (ns) after the next rising edge, then measure.
    task change_d;
        input integer offset;
        integer start, k;
        reg     val;
        begin
            @(posedge clk);
            #(offset);
            val = ~d;
            d   = val;
            start = edges;
            // wait for q to take the new value, at most 5 edges
            k = 0;
            while (q !== val && k < 5) begin
                @(posedge clk); #1; k = k + 1;
            end
            latencies = latencies + 1;
            if (edges - start != 2) begin
                bad_lat = bad_lat + 1;
                errors  = errors + 1;
                if (errors <= MAX_ERRORS)
                    $display("[%0d ns] ERROR: latency %0d edges after d -> %b, expected 2", $time, edges - start, val);
            end
            repeat (2) @(posedge clk);
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_sync_2ff.vcd");
            $dumpvars(0, tb_sync_2ff);
        end
        $display("=== tb_sync_2ff: RST_VAL = %b ===", RST_VAL);
        rst = 1'b1;
        d   = ~RST_VAL;          // input differs from the reset value during reset
        @(posedge clk);
        check_en = 1'b1;
        repeat (3) @(posedge clk);
        #3 rst = 1'b0;           // released between edges
        // T1b: changes at different offsets inside the 20 ns period
        repeat (4) @(posedge clk);
        change_d(1);
        change_d(7);
        change_d(13);
        change_d(18);
        change_d(4);
        change_d(11);
        $display("T1a/T1b latency            : checked (%0d changes measured)", latencies);
        // T1c: reset in the middle of operation, d opposite to RST_VAL
        @(negedge clk) d = ~RST_VAL;
        repeat (3) @(posedge clk);
        #5 rst = 1'b1;
        repeat (2) @(posedge clk);
        #5 rst = 1'b0;
        repeat (4) @(posedge clk);
        // a pulse on d shorter than one clock period, between two edges
        @(posedge clk); #4 d = RST_VAL; #8 d = ~RST_VAL;
        repeat (4) @(posedge clk);
        $display("T1c reset and short pulse   : checked");
        $display("checks = %0d, errors = %0d", checks, errors);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED");
        $finish;
    end

    initial begin
        #(CLK_PERIOD * 400);
        $display("TEST FAILED: timeout");
        $finish;
    end

endmodule
