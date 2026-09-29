import tarc_pkg::*;

module writeback (
    input mem_wb_t mem_wb,

    input logic muldiv_valid,
    input greg_t muldiv_rd,
    input xlen_t muldiv_result,
    output logic muldiv_grant,

    input logic fpu_valid,
    input regfile_e fpu_rd_rf,
    input logic [4:0] fpu_rd,
    input xlen_t fpu_result,
    output logic fpu_grant,

    input logic vec_valid,
    input regfile_e vec_rd_rf,
    input logic [4:0] vec_rd,
    input xlen_t vec_result,
    output logic vec_grant,

    output logic int_we,
    output greg_t int_waddr,
    output xlen_t int_wdata,

    output logic fp_we,
    output logic [4:0] fp_waddr,
    output xlen_t fp_wdata,

    output logic vecrf_we,
    output logic [4:0] vecrf_waddr,
    output xlen_t vecrf_wdata
);

    always_comb begin
        int_we = 1'b0;
        int_waddr = '0;
        int_wdata = '0;
        fp_we = 1'b0;
        fp_waddr = '0;
        fp_wdata = '0;
        vecrf_we = 1'b0;
        vecrf_waddr = '0;
        vecrf_wdata = '0;
        muldiv_grant = 1'b0;
        fpu_grant = 1'b0;
        vec_grant = 1'b0;

        if (mem_wb.valid && mem_wb.reg_write && mem_wb.rd_rf == RF_INT) begin
            int_we = 1'b1;
            int_waddr = mem_wb.rd;
            int_wdata = mem_wb.result;
        end else if (muldiv_valid) begin
            int_we = 1'b1;
            int_waddr = muldiv_rd;
            int_wdata = muldiv_result;
            muldiv_grant = 1'b1;
        end else if (fpu_valid && fpu_rd_rf == RF_INT) begin
            int_we = 1'b1;
            int_waddr = fpu_rd;
            int_wdata = fpu_result;
            fpu_grant = 1'b1;
        end else if (vec_valid && vec_rd_rf == RF_INT) begin
            int_we = 1'b1;
            int_waddr = vec_rd;
            int_wdata = vec_result;
            vec_grant = 1'b1;
        end

        if (mem_wb.valid && mem_wb.reg_write && mem_wb.rd_rf == RF_FP) begin
            fp_we = 1'b1;
            fp_waddr = mem_wb.rd[4:0];
            fp_wdata = mem_wb.result;
        end else if (fpu_valid && fpu_rd_rf == RF_FP && !fpu_grant) begin
            fp_we = 1'b1;
            fp_waddr = fpu_rd;
            fp_wdata = fpu_result;
            fpu_grant = 1'b1;
        end else if (vec_valid && vec_rd_rf == RF_FP && !vec_grant) begin
            fp_we = 1'b1;
            fp_waddr = vec_rd;
            fp_wdata = vec_result;
            vec_grant = 1'b1;
        end

        if (mem_wb.valid && mem_wb.reg_write && mem_wb.rd_rf == RF_VEC) begin
            vecrf_we = 1'b1;
            vecrf_waddr = mem_wb.rd[4:0];
            vecrf_wdata = mem_wb.result;
        end else if (vec_valid && vec_rd_rf == RF_VEC && !vec_grant) begin
            vecrf_we = 1'b1;
            vecrf_waddr = vec_rd;
            vecrf_wdata = vec_result;
            vec_grant = 1'b1;
        end
    end

endmodule : writeback
