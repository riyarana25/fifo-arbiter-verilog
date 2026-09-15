// Round-robin arbiter, N requesters.
// grant is combinational: it picks the first requester AFTER the one that was
// granted last time, wrapping around. last_grant updates every time a grant is given.
module rr_arbiter #(
    parameter N = 4
) (
    input  wire         clk,
    input  wire         rst_n,
    input  wire [N-1:0] req,
    output reg  [N-1:0] grant
);
    localparam IW = $clog2(N);

    reg [IW-1:0] last;                   // index granted most recently
    reg [IW-1:0] idx;
    integer      i;
    reg          found;

    always @* begin
        grant = {N{1'b0}};
        found = 1'b0;
        idx   = {IW{1'b0}};
`ifdef BUG_FIXED_PRIORITY
        // BUG: always starts from requester 0, so low indices can starve the rest
        for (i = 0; i < N; i = i + 1) begin
            if (!found && req[i]) begin grant[i] = 1'b1; found = 1'b1; end
        end
`else
        for (i = 1; i <= N; i = i + 1) begin
            idx = (last + i) % N;
            if (!found && req[idx]) begin
                grant[idx] = 1'b1;
                found      = 1'b1;
            end
        end
`endif
`ifdef BUG_GRANT_IDLE
        // BUG: grants a requester even when nobody is requesting
        if (!found) grant[last] = 1'b1;
`endif
    end

    always @(posedge clk) begin
        if (!rst_n)
            last <= N-1;                 // so requester 0 has first priority after reset
        else begin
            for (i = 0; i < N; i = i + 1)
`ifdef BUG_NO_ROTATE
                ;                        // BUG: pointer never moves
`else
                if (grant[i]) last <= i;
`endif
        end
    end
endmodule
