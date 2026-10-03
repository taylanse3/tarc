import tarc_pkg::*;

module icache (
    input logic clk,
    input logic rst_n,

    input logic req,
    input xlen_t addr,
    output instr_t rdata,
    output logic ready,

    output logic mem_req,
    output xlen_t mem_addr,
    input xlen_t mem_rdata,
    input logic mem_ready
);

    cache_index_t index;
    cache_tag_t tag;
    cache_beat_t beat;

    assign index = addr[CACHE_OFFSET_BITS+CACHE_INDEX_BITS-1:CACHE_OFFSET_BITS];
    assign tag = addr[XLEN-1:CACHE_OFFSET_BITS+CACHE_INDEX_BITS];
    assign beat = addr[CACHE_OFFSET_BITS-1:3];

    cache_tag_t tag_array [0:CACHE_LINES-1];
    xlen_t data_array [0:CACHE_LINES*CACHE_BEATS-1];
    logic [CACHE_LINES-1:0] valid_q;

    cache_state_e state_q;
    cache_index_t refill_index_q;
    cache_tag_t refill_tag_q;
    cache_beat_t refill_beat_q;

    logic idle;
    assign idle = (state_q == CACHE_IDLE);

    logic hit;
    assign hit = valid_q[index] && (tag_array[index] == tag);

    logic miss;
    assign miss = idle && req && !hit;

    xlen_t line_beat;
    assign line_beat = data_array[{index, beat}];

    assign rdata = addr[2] ? line_beat[63:32] : line_beat[31:0];
    assign ready = idle && hit;

    assign mem_req = !idle;
    assign mem_addr = {refill_tag_q, refill_index_q, refill_beat_q, 3'b000};

    logic refill_last;
    assign refill_last = &refill_beat_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q <= CACHE_IDLE;
            valid_q <= '0;
            refill_index_q <= '0;
            refill_tag_q <= '0;
            refill_beat_q <= '0;
        end else begin
            unique case (state_q)
                CACHE_IDLE: begin
                    if (miss) begin
                        state_q <= CACHE_REFILL;
                        valid_q[index] <= 1'b0;
                        refill_index_q <= index;
                        refill_tag_q <= tag;
                        refill_beat_q <= '0;
                    end
                end
                CACHE_REFILL: begin
                    if (mem_ready) begin
                        refill_beat_q <= refill_beat_q + 1'b1;
                        if (refill_last) begin
                            state_q <= CACHE_IDLE;
                            valid_q[refill_index_q] <= 1'b1;
                        end
                    end
                end
                default: begin
                end
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (miss) begin
            tag_array[index] <= tag;
        end
        if (mem_req && mem_ready) begin
            data_array[{refill_index_q, refill_beat_q}] <= mem_rdata;
        end
    end

endmodule : icache
