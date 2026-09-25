// Self-checking test bench for rr_arbiter (N = 4).
// It checks four properties on every cycle:
//   P1 safety          : at most one grant, and only to a requester
//   P2 work-conserving : if anyone requests, someone is granted (and none if nobody requests)
//   P3 fairness        : a requester that keeps requesting waits at most N-1 cycles
//   P4 exact order     : grant equals an independent reference model of round-robin
`timescale 1ns/1ps
module tb_rr_arbiter;
    localparam N = 4;

    reg          clk = 0, rst_n = 0;
    reg  [N-1:0] req = 0;
    wire [N-1:0] grant;

    rr_arbiter #(.N(N)) dut (.clk(clk), .rst_n(rst_n), .req(req), .grant(grant));
    initial begin $dumpfile("build/arbiter.vcd"); $dumpvars(0, tb_rr_arbiter); end
    always #5 clk = ~clk;

    integer errors = 0, cycles = 0;
    integer wait_cnt [0:N-1];
    integer grants   [0:N-1];
    integer ref_last = N-1;
    integer k, ones, e_idx;
    reg [N-1:0]   e_grant;
    reg [2*N-1:0] dbl;
    reg [N-1:0]   rot;
    reg           got;

    task fail(input [255:0] msg);
        begin
            errors = errors + 1;
            if (errors <= 10) $display("ERROR t=%0t: %0s (req=%b grant=%b)", $time, msg, req, grant);
        end
    endtask

    initial for (k = 0; k < N; k = k + 1) begin wait_cnt[k] = 0; grants[k] = 0; end

    always @(posedge clk) begin
        cycles = cycles + 1;
        if (!rst_n) begin
            ref_last = N-1;
            for (k = 0; k < N; k = k + 1) wait_cnt[k] = 0;
        end else begin
            // P1 safety
            ones = 0;
            for (k = 0; k < N; k = k + 1) ones = ones + grant[k];
            if (ones > 1)            fail("P1: more than one grant");
            if ((grant & ~req) != 0) fail("P1: grant to a non-requester");
            // P2 work conservation
            if ((req != 0) && (grant == 0)) fail("P2: request ignored");
            if ((req == 0) && (grant != 0)) fail("P2: grant with no request");
            // P3 fairness
            for (k = 0; k < N; k = k + 1) begin
                if (req[k] && !grant[k]) wait_cnt[k] = wait_cnt[k] + 1;
                else                     wait_cnt[k] = 0;
                if (wait_cnt[k] > N-1)   fail("P3: requester starved");
                if (grant[k])            grants[k] = grants[k] + 1;
            end
            // P4 independent reference model: rotate req so the requester after
            // ref_last is bit 0, find the lowest set bit, rotate the index back.
            dbl = {req, req};
            rot = dbl >> ((ref_last + 1) % N);
            e_grant = 0; got = 0; e_idx = 0;
            for (k = 0; k < N; k = k + 1)
                if (!got && rot[k]) begin got = 1; e_idx = (ref_last + 1 + k) % N; end
            if (got) e_grant[e_idx] = 1'b1;
            if (grant !== e_grant) fail("P4: differs from reference model");
            if (got) ref_last = e_idx;
        end
    end

    task drive(input [N-1:0] r);
        begin @(negedge clk); req = r; end
    endtask

    integer i, seed, d;
    initial begin
        repeat (3) @(negedge clk);
        rst_n = 1;
        // single requesters
        for (i = 0; i < N; i = i + 1) begin drive(1 << i); drive(1 << i); end
        drive(0); drive(0);
        // everybody requests for 40 cycles: each requester should get exactly 10 grants
        for (k = 0; k < N; k = k + 1) grants[k] = 0;
        for (i = 0; i < 40; i = i + 1) drive(4'b1111);
        drive(0);
        for (k = 0; k < N; k = k + 1)
            if (grants[k] < 9 || grants[k] > 11) fail("equal share not met in all-request phase");
        $display("grants per requester in the all-request phase: %0d %0d %0d %0d",
                 grants[0], grants[1], grants[2], grants[3]);
        // two requesters, and a sparse pattern
        for (i = 0; i < 20; i = i + 1) drive(4'b0101);
        for (i = 0; i < 20; i = i + 1) drive(4'b1010);
        for (i = 0; i < 20; i = i + 1) drive(4'b0111);
        // random requests at several densities
        seed = 32'h5eed;
        for (d = 20; d <= 90; d = d + 35)
            for (i = 0; i < 5000; i = i + 1)
                drive({(($random(seed) & 32'h7fffffff) % 100 < d),
                       (($random(seed) & 32'h7fffffff) % 100 < d),
                       (($random(seed) & 32'h7fffffff) % 100 < d),
                       (($random(seed) & 32'h7fffffff) % 100 < d)});
        drive(0); drive(0);
        if (errors == 0) $display("TEST PASSED (rr_arbiter, %0d cycles)", cycles);
        else             $display("TEST FAILED (rr_arbiter): %0d errors", errors);
        $finish;
    end
    initial begin #20000000; $display("TEST FAILED (timeout)"); $finish; end
endmodule
