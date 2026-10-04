import tarc_pkg::*;

module regfile_fp (
    input logic clk,
    input logic rst_n,

    input greg_t rs1_addr,
    output xlen_t rs1_data,
    input greg_t rs2_addr,
    output xlen_t rs2_data,
    input greg_t rs3_addr,
    output xlen_t rs3_data,

    input logic we,
    input greg_t rd_addr,
    input xlen_t rd_data
);

    xlen_t regs [0:NUM_FPR-1];

    logic rs1_wr_collision, rs2_wr_collision, rs3_wr_collision;
    assign rs1_wr_collision = we && (rd_addr == rs1_addr);
    assign rs2_wr_collision = we && (rd_addr == rs2_addr);
    assign rs3_wr_collision = we && (rd_addr == rs3_addr);

    assign rs1_data = rs1_wr_collision ? rd_data : regs[rs1_addr];
    assign rs2_data = rs2_wr_collision ? rd_data : regs[rs2_addr];
    assign rs3_data = rs3_wr_collision ? rd_data : regs[rs3_addr];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_FPR; i++) begin
                regs[i] <= '0;
            end
        end else if (we) begin
            regs[rd_addr] <= rd_data;
        end
    end

endmodule : regfile_fp
