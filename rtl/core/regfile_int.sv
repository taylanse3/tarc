import tarc_pkg::*;

module regfile_int (
    input logic clk,
    input logic rst_n,

    input greg_t rs1_addr,
    output xlen_t rs1_data,
    input greg_t rs2_addr,
    output xlen_t rs2_data,

    input logic we,
    input greg_t rd_addr,
    input xlen_t rd_data
);

    xlen_t regs [1:NUM_GPR-1];

    logic rs1_wr_collision, rs2_wr_collision;
    assign rs1_wr_collision = we && (rd_addr != '0) && (rd_addr == rs1_addr);
    assign rs2_wr_collision = we && (rd_addr != '0) && (rd_addr == rs2_addr);

    assign rs1_data =
        (rs1_addr == '0) ? '0 :
        rs1_wr_collision ? rd_data :
        regs[rs1_addr];

    assign rs2_data =
        (rs2_addr == '0) ? '0 :
        rs2_wr_collision ? rd_data :
        regs[rs2_addr];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 1; i < NUM_GPR; i++) begin
                regs[i] <= '0;
            end
        end else if (we && rd_addr != '0) begin
            regs[rd_addr] <= rd_data;
        end
    end

endmodule : regfile_int
