// Synchronous FIFO, first-word-fall-through read.
// rd_data always shows the oldest entry while empty is 0.
// A write is accepted only if the FIFO is not full.
// A read  is accepted only if the FIFO is not empty.
// The two decisions are independent, so at full a read and a write in the
// same cycle pops one entry and the write is rejected (overflow flag).
module sync_fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 16                 // must be a power of two
) (
    input  wire             clk,
    input  wire             rst_n,       // active-low synchronous reset
    input  wire             wr_en,
    input  wire [WIDTH-1:0] wr_data,
    input  wire             rd_en,
    output wire [WIDTH-1:0] rd_data,
    output wire             full,
    output wire             empty,
    output wire [$clog2(DEPTH):0] count,
    output reg              overflow,    // pulse: write attempted while full
    output reg              underflow    // pulse: read attempted while empty
);
    localparam AW = $clog2(DEPTH);

    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [AW:0]      wr_ptr, rd_ptr;      // one extra bit tells full from empty

    assign count   = wr_ptr - rd_ptr;
    assign empty   = (wr_ptr == rd_ptr);
`ifdef BUG_FULL_OFF_BY_ONE
    assign full    = (count == DEPTH-1); // BUG: full one entry too early
`else
    assign full    = (count == DEPTH);
`endif
    assign rd_data = mem[rd_ptr[AW-1:0]];

`ifdef BUG_NO_OVERFLOW_PROTECT
    wire do_write = wr_en;               // BUG: writes even when full
`else
    wire do_write = wr_en && !full;
`endif
`ifdef BUG_SIMUL_RW
    wire do_read  = rd_en && !empty && !wr_en;   // BUG: read ignored if write at same time
`else
    wire do_read  = rd_en && !empty;
`endif

    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr    <= 0;
            rd_ptr    <= 0;
            overflow  <= 1'b0;
            underflow <= 1'b0;
        end else begin
            overflow  <= wr_en && full;
            underflow <= rd_en && empty;
            if (do_write) begin
                mem[wr_ptr[AW-1:0]] <= wr_data;
                wr_ptr <= wr_ptr + 1'b1;
            end
            if (do_read)
                rd_ptr <= rd_ptr + 1'b1;
        end
    end
endmodule
