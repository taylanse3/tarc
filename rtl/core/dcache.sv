import tarc_pkg::*;

module dcache #(
    parameter logic [63:0] UNCACHED_BASE = 64'h0000_0000_1000_0000
) (
    input logic clk,
    input logic rst_n,

    input logic req,
    input logic we,
    input xlen_t addr,
    input xlen_t wdata,
    input logic [1:0] size,
    output xlen_t rdata,
    output logic ready,

    output logic mem_req,
    output logic mem_we,
    output xlen_t mem_addr,
    output xlen_t mem_wdata,
    output logic [7:0] mem_wstrb,
    input xlen_t mem_rdata,
    input logic mem_ready
);

    cache_index_t index;
    cache_tag_t tag;
    cache_beat_t beat;
    logic [2:0] lane;

    assign index = addr[CACHE_OFFSET_BITS+CACHE_INDEX_BITS-1:CACHE_OFFSET_BITS];
    assign tag = addr[XLEN-1:CACHE_OFFSET_BITS+CACHE_INDEX_BITS];
    assign beat = addr[CACHE_OFFSET_BITS-1:3];
    assign lane = addr[2:0];

    cache_tag_t tag_array [0:CACHE_LINES-1];
    xlen_t data_array [0:CACHE_LINES*CACHE_BEATS-1];
    logic [CACHE_LINES-1:0] valid_q;

    cache_state_e state_q;
    cache_index_t refill_index_q;
    cache_tag_t refill_tag_q;
    cache_beat_t refill_beat_q;

    logic idle;
    assign idle = (state_q == CACHE_IDLE);

    logic cacheable;
    assign cacheable = (addr < UNCACHED_BASE);

    logic hit;
    assign hit = valid_q[index] && (tag_array[index] == tag);

    logic passthrough;
    assign passthrough = idle && req && (we || !cacheable);

    logic miss;
    assign miss = idle && req && !we && cacheable && !hit;

    logic [7:0] size_mask;
    always_comb begin
        unique case (size)
            2'b00: size_mask = 8'h01;
            2'b01: size_mask = 8'h03;
            2'b10: size_mask = 8'h0F;
            2'b11: size_mask = 8'hFF;
            default: size_mask = 8'h00;
        endcase
    end

    logic [7:0] wstrb;
    xlen_t wdata_lane;
    assign wstrb = size_mask << lane;
    assign wdata_lane = wdata << {lane, 3'b000};

    xlen_t line_beat;
    assign line_beat = data_array[{index, beat}];

    xlen_t load_beat;
    assign load_beat = cacheable ? line_beat : mem_rdata;

    assign rdata = load_beat >> {lane, 3'b000};
    assign ready = idle && (passthrough ? mem_ready : hit);

    assign mem_req = passthrough || !idle;
    assign mem_we = passthrough && we;
    assign mem_addr = idle
        ? {addr[XLEN-1:3], 3'b000}
        : {refill_tag_q, refill_index_q, refill_beat_q, 3'b000};
    assign mem_wdata = wdata_lane;
    assign mem_wstrb = (passthrough && we) ? wstrb : 8'h00;

    logic refill_last;
    assign refill_last = &refill_beat_q;

    logic store_hit;
    assign store_hit = passthrough && we && mem_ready && cacheable && hit;

    xlen_t store_beat;
    always_comb begin
        store_beat = line_beat;
        for (int i = 0; i < 8; i++) begin
            if (wstrb[i]) begin
                store_beat[8*i +: 8] = wdata_lane[8*i +: 8];
            end
        end
    end

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
        if (store_hit) begin
            data_array[{index, beat}] <= store_beat;
        end else if (!idle && mem_ready) begin
            data_array[{refill_index_q, refill_beat_q}] <= mem_rdata;
        end
    end

endmodule : dcache
