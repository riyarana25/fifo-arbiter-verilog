// Self-checking test bench for sync_fifo.
// A simple reference model (a circular array) runs beside the design.
// On every clock edge the test bench compares full, empty, count, rd_data,
// overflow and underflow against the model.
`timescale 1ns/1ps
module tb_sync_fifo;
    localparam WIDTH = 8;
    localparam DEPTH = 16;

    reg              clk = 0, rst_n = 0;
    reg              wr_en = 0, rd_en = 0;
    reg  [WIDTH-1:0] wr_data = 0;
    wire [WIDTH-1:0] rd_data;
    wire             full, empty, overflow, underflow;
    wire [$clog2(DEPTH):0] count;

    sync_fifo #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dut (
        .clk(clk), .rst_n(rst_n), .wr_en(wr_en), .wr_data(wr_data),
        .rd_en(rd_en), .rd_data(rd_data), .full(full), .empty(empty),
        .count(count), .overflow(overflow), .underflow(underflow));

    initial begin $dumpfile("build/fifo.vcd"); $dumpvars(0, tb_sync_fifo); end
    always #5 clk = ~clk;

    // ---------------- reference model ----------------
    reg [WIDTH-1:0] m_mem [0:DEPTH-1];
    integer m_head = 0, m_tail = 0, m_cnt = 0;
    reg     exp_ovf = 0, exp_unf = 0;
    integer errors = 0;
    integer cycles = 0;
    reg     aw, ar;

    // coverage-style tallies: each scenario must happen at least once
    integer cov_full = 0, cov_empty = 0, cov_ovf = 0, cov_unf = 0;
    integer cov_simul = 0, cov_simul_full = 0, cov_simul_empty = 0, cov_wrap = 0;

    task fail(input [255:0] msg);
        begin
            errors = errors + 1;
            if (errors <= 10)
                $display("ERROR t=%0t: %0s  (cnt model=%0d dut=%0d, rd_data=%h)",
                         $time, msg, m_cnt, count, rd_data);
        end
    endtask

    always @(posedge clk) begin
        cycles = cycles + 1;
        if (!rst_n) begin
            m_head = 0; m_tail = 0; m_cnt = 0; exp_ovf = 0; exp_unf = 0;
        end else begin
            // 1. compare design outputs with the model state BEFORE this edge
            if (full  !== (m_cnt == DEPTH)) fail("full flag wrong");
            if (empty !== (m_cnt == 0))     fail("empty flag wrong");
            if (count !== m_cnt)            fail("count wrong");
            if (m_cnt > 0 && rd_data !== m_mem[m_head]) fail("read data wrong");
            if (overflow  !== exp_ovf)      fail("overflow flag wrong");
            if (underflow !== exp_unf)      fail("underflow flag wrong");

            // 2. apply this edge's operation to the model
            exp_ovf = wr_en && (m_cnt == DEPTH);
            exp_unf = rd_en && (m_cnt == 0);
            aw = wr_en && (m_cnt <  DEPTH);
            ar = rd_en && (m_cnt >  0);

            if (m_cnt == DEPTH) cov_full  = cov_full + 1;
            if (m_cnt == 0)     cov_empty = cov_empty + 1;
            if (exp_ovf)        cov_ovf   = cov_ovf + 1;
            if (exp_unf)        cov_unf   = cov_unf + 1;
            if (aw && ar)       cov_simul = cov_simul + 1;
            if (wr_en && rd_en && m_cnt == DEPTH) cov_simul_full  = cov_simul_full + 1;
            if (wr_en && rd_en && m_cnt == 0)     cov_simul_empty = cov_simul_empty + 1;

            if (aw) begin
                m_mem[m_tail] = wr_data;
                m_tail = (m_tail + 1) % DEPTH;
                if (m_tail == 0) cov_wrap = cov_wrap + 1;
            end
            if (ar) m_head = (m_head + 1) % DEPTH;
            m_cnt = m_cnt + (aw ? 1 : 0) - (ar ? 1 : 0);
        end
    end

    // ---------------- stimulus helpers ----------------
    reg [WIDTH-1:0] next_data = 8'h01;

    // Drive inputs just after the falling edge so they are stable at the rising edge.
    task step(input w, input r);
        begin
            @(negedge clk);
            wr_en = w; rd_en = r; wr_data = next_data;
            if (w) next_data = next_data * 8'd5 + 8'd3;    // easy-to-check pseudo data
        end
    endtask
    task idle(input integer n);
        integer k;
        begin for (k = 0; k < n; k = k + 1) step(0, 0); end
    endtask

    integer i, seed, pw, pr;
    initial begin
        // reset
        repeat (3) @(negedge clk);
        rst_n = 1;

        // Test 1: fill exactly to full, then try 3 extra writes (overflow)
        for (i = 0; i < DEPTH; i = i + 1) step(1, 0);
        for (i = 0; i < 3;     i = i + 1) step(1, 0);
        idle(2);
        // Test 2: drain everything in order (data integrity), then 3 extra reads (underflow)
        for (i = 0; i < DEPTH; i = i + 1) step(0, 1);
        for (i = 0; i < 3;     i = i + 1) step(0, 1);
        idle(2);
        // Test 3: simultaneous read and write at mid occupancy
        for (i = 0; i < 5;  i = i + 1) step(1, 0);
        for (i = 0; i < 40; i = i + 1) step(1, 1);
        // Test 4: simultaneous read and write while FULL (read accepted, write rejected)
        for (i = 0; i < DEPTH + 2; i = i + 1) step(1, 0);
        for (i = 0; i < 4;         i = i + 1) step(1, 1);
        // Test 5: simultaneous read and write while EMPTY (write accepted, read rejected)
        for (i = 0; i < DEPTH + 2; i = i + 1) step(0, 1);
        step(1, 1); step(1, 1);
        idle(2);
        // Test 6: pointer wrap-around (several times around the array)
        for (i = 0; i < 6 * DEPTH; i = i + 1) step(1, 1);
        // Test 7: reset in the middle of operation, then check it is empty
        for (i = 0; i < 6; i = i + 1) step(1, 0);
        @(negedge clk); rst_n = 0; wr_en = 0; rd_en = 0;
        @(negedge clk); rst_n = 1;
        idle(2);
        // Test 8: constrained-random phases (write-heavy, read-heavy, balanced)
        seed = 32'h1234;
        repeat (3) begin
            for (pw = 90; pw >= 10; pw = pw - 40) begin
                pr = 100 - pw;
                for (i = 0; i < 3000; i = i + 1)
                    step(($random(seed) & 32'h7fffffff) % 100 < pw,
                         ($random(seed) & 32'h7fffffff) % 100 < pr);
            end
        end
        idle(3);

        // ---------------- verdict ----------------
        $display("---- scenario tallies ----");
        $display("cycles at full=%0d  at empty=%0d  overflow attempts=%0d  underflow attempts=%0d",
                 cov_full, cov_empty, cov_ovf, cov_unf);
        $display("simultaneous r/w accepted=%0d  at full=%0d  at empty=%0d  pointer wraps=%0d",
                 cov_simul, cov_simul_full, cov_simul_empty, cov_wrap);
        if (cov_full == 0 || cov_empty == 0 || cov_ovf == 0 || cov_unf == 0 ||
            cov_simul == 0 || cov_simul_full == 0 || cov_simul_empty == 0 || cov_wrap == 0) begin
            $display("a scenario never happened, so the test is incomplete");
            errors = errors + 1;
        end
        if (errors == 0) $display("TEST PASSED (sync_fifo, %0d cycles)", cycles);
        else             $display("TEST FAILED (sync_fifo): %0d errors", errors);
        $finish;
    end

    initial begin #20000000; $display("TEST FAILED (timeout)"); $finish; end
endmodule
