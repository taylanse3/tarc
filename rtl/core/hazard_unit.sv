import tarc_pkg::*;

module hazard_unit (
    input logic ex_valid,
    input greg_t ex_rs1,
    input greg_t ex_rs2,
    input logic ex_reads_rs1,
    input logic ex_reads_rs2,
    input greg_t ex_rd,
    input regfile_e ex_rd_rf,
    input greg_t ex_rs3,
    input logic ex_reads_fp1,
    input logic ex_reads_fp2,
    input logic ex_reads_fp3,
    input logic ex_result_late,

    input logic mem_valid,
    input logic mem_reg_write,
    input regfile_e mem_rd_rf,
    input greg_t mem_rd,
    input xlen_t mem_alu_result,
    input logic mem_result_late,

    input logic wb_valid,
    input logic wb_reg_write,
    input regfile_e wb_rd_rf,
    input greg_t wb_rd,
    input xlen_t wb_result,

    input logic muldiv_valid,
    input greg_t muldiv_rd,
    input xlen_t muldiv_result,

    input logic d_valid,
    input greg_t d_rs1,
    input greg_t d_rs2,
    input greg_t d_rs3,
    input greg_t d_rd,
    input regfile_e d_rd_rf,
    input regfile_e d_fu_rd_rf,
    input logic d_reads_rs1,
    input logic d_reads_rs2,
    input logic d_reads_fp1,
    input logic d_reads_fp2,
    input logic d_reads_fp3,
    input fu_tag_e d_fu,
    input logic d_is_csr_write,
    input logic d_is_fcsr_access,

    input logic muldiv_busy,
    input greg_t muldiv_pending_rd,
    input logic fpu_busy,
    input regfile_e fpu_pending_rf,
    input greg_t fpu_pending_rd,
    input logic vec_busy,

    input logic csr_drain_active,

    input logic ex_branch_mispredict,

    output xlen_t ex_rs1_fwd_data,
    output xlen_t ex_rs2_fwd_data,
    output logic ex_rs1_use_fwd,
    output logic ex_rs2_use_fwd,
    output xlen_t ex_fp1_fwd_data,
    output xlen_t ex_fp2_fwd_data,
    output xlen_t ex_fp3_fwd_data,
    output logic ex_fp1_use_fwd,
    output logic ex_fp2_use_fwd,
    output logic ex_fp3_use_fwd,

    output logic stall_f,
    output logic stall_d,
    output logic flush_d
);

    logic mem_fwd_rs1, mem_fwd_rs2;
    logic wb_fwd_rs1, wb_fwd_rs2;
    logic mul_fwd_rs1, mul_fwd_rs2;

    assign mem_fwd_rs1 = mem_valid && mem_reg_write && (mem_rd_rf == RF_INT)
        && (mem_rd != '0) && (mem_rd == ex_rs1) && ex_reads_rs1;
    assign mem_fwd_rs2 = mem_valid && mem_reg_write && (mem_rd_rf == RF_INT)
        && (mem_rd != '0) && (mem_rd == ex_rs2) && ex_reads_rs2;

    assign mul_fwd_rs1 = muldiv_valid && (muldiv_rd != '0)
        && (muldiv_rd == ex_rs1) && ex_reads_rs1;
    assign mul_fwd_rs2 = muldiv_valid && (muldiv_rd != '0)
        && (muldiv_rd == ex_rs2) && ex_reads_rs2;

    assign wb_fwd_rs1 = wb_valid && wb_reg_write && (wb_rd_rf == RF_INT)
        && (wb_rd != '0) && (wb_rd == ex_rs1) && ex_reads_rs1;
    assign wb_fwd_rs2 = wb_valid && wb_reg_write && (wb_rd_rf == RF_INT)
        && (wb_rd != '0) && (wb_rd == ex_rs2) && ex_reads_rs2;

    always_comb begin
        if (mem_fwd_rs1 && !mem_result_late) begin
            ex_rs1_use_fwd = 1'b1;
            ex_rs1_fwd_data = mem_alu_result;
        end else if (mul_fwd_rs1) begin
            ex_rs1_use_fwd = 1'b1;
            ex_rs1_fwd_data = muldiv_result;
        end else if (wb_fwd_rs1) begin
            ex_rs1_use_fwd = 1'b1;
            ex_rs1_fwd_data = wb_result;
        end else begin
            ex_rs1_use_fwd = 1'b0;
            ex_rs1_fwd_data = '0;
        end

        if (mem_fwd_rs2 && !mem_result_late) begin
            ex_rs2_use_fwd = 1'b1;
            ex_rs2_fwd_data = mem_alu_result;
        end else if (mul_fwd_rs2) begin
            ex_rs2_use_fwd = 1'b1;
            ex_rs2_fwd_data = muldiv_result;
        end else if (wb_fwd_rs2) begin
            ex_rs2_use_fwd = 1'b1;
            ex_rs2_fwd_data = wb_result;
        end else begin
            ex_rs2_use_fwd = 1'b0;
            ex_rs2_fwd_data = '0;
        end
    end

    logic wb_fwd_fp1, wb_fwd_fp2, wb_fwd_fp3;

    assign wb_fwd_fp1 = wb_valid && wb_reg_write && (wb_rd_rf == RF_FP)
        && (wb_rd == ex_rs1) && ex_reads_fp1;
    assign wb_fwd_fp2 = wb_valid && wb_reg_write && (wb_rd_rf == RF_FP)
        && (wb_rd == ex_rs2) && ex_reads_fp2;
    assign wb_fwd_fp3 = wb_valid && wb_reg_write && (wb_rd_rf == RF_FP)
        && (wb_rd == ex_rs3) && ex_reads_fp3;

    assign ex_fp1_use_fwd = wb_fwd_fp1;
    assign ex_fp2_use_fwd = wb_fwd_fp2;
    assign ex_fp3_use_fwd = wb_fwd_fp3;
    assign ex_fp1_fwd_data = wb_fwd_fp1 ? wb_result : '0;
    assign ex_fp2_fwd_data = wb_fwd_fp2 ? wb_result : '0;
    assign ex_fp3_fwd_data = wb_fwd_fp3 ? wb_result : '0;

    logic load_use_int, load_use_fp, load_use_stall;
    assign load_use_int = ex_result_late && ex_valid && (ex_rd_rf == RF_INT) && (ex_rd != '0)
        && d_valid
        && ((d_reads_rs1 && (d_rs1 == ex_rd)) || (d_reads_rs2 && (d_rs2 == ex_rd)));
    assign load_use_fp = ex_result_late && ex_valid && (ex_rd_rf == RF_FP) && d_valid
        && ((d_reads_fp1 && (d_rs1 == ex_rd)) || (d_reads_fp2 && (d_rs2 == ex_rd))
        || (d_reads_fp3 && (d_rs3 == ex_rd)));
    assign load_use_stall = load_use_int || load_use_fp;

    logic fu_busy_stall;
    always_comb begin
        unique case (d_fu)
            FU_MULDIV: fu_busy_stall = d_valid && muldiv_busy;
            FU_FPU: fu_busy_stall = d_valid && fpu_busy;
            FU_VEC: fu_busy_stall = d_valid && vec_busy;
            default: fu_busy_stall = 1'b0;
        endcase
    end

    logic scoreboard_stall;
    assign scoreboard_stall = d_valid && muldiv_busy && (muldiv_pending_rd != '0)
        && ((d_reads_rs1 && (d_rs1 == muldiv_pending_rd))
        || (d_reads_rs2 && (d_rs2 == muldiv_pending_rd)));

    regfile_e d_dest_rf;
    assign d_dest_rf = (d_rd_rf != RF_NONE) ? d_rd_rf : d_fu_rd_rf;

    logic waw_stall;
    assign waw_stall = d_valid && muldiv_busy && (muldiv_pending_rd != '0)
        && (d_dest_rf == RF_INT) && (d_rd == muldiv_pending_rd);

    logic fpu_pend_int, fpu_pend_fp;
    assign fpu_pend_int = fpu_busy && (fpu_pending_rf == RF_INT) && (fpu_pending_rd != '0);
    assign fpu_pend_fp = fpu_busy && (fpu_pending_rf == RF_FP);

    logic fpu_scoreboard_stall;
    assign fpu_scoreboard_stall = d_valid && (
        (fpu_pend_int && ((d_reads_rs1 && (d_rs1 == fpu_pending_rd))
        || (d_reads_rs2 && (d_rs2 == fpu_pending_rd))))
        || (fpu_pend_fp && ((d_reads_fp1 && (d_rs1 == fpu_pending_rd))
        || (d_reads_fp2 && (d_rs2 == fpu_pending_rd))
        || (d_reads_fp3 && (d_rs3 == fpu_pending_rd)))));

    logic fpu_waw_stall;
    assign fpu_waw_stall = d_valid && (
        (fpu_pend_int && (d_dest_rf == RF_INT) && (d_rd == fpu_pending_rd))
        || (fpu_pend_fp && (d_dest_rf == RF_FP) && (d_rd == fpu_pending_rd)));

    logic csr_unit_stall;
    assign csr_unit_stall = d_valid && (
        (d_is_csr_write && (muldiv_busy || fpu_busy || vec_busy))
        || (d_is_fcsr_access && fpu_busy));

    logic stall_any;
    assign stall_any = load_use_stall || fu_busy_stall || scoreboard_stall || waw_stall
        || fpu_scoreboard_stall || fpu_waw_stall || csr_drain_active || csr_unit_stall;

    assign flush_d = ex_branch_mispredict;
    assign stall_f = stall_any && !ex_branch_mispredict;
    assign stall_d = stall_any && !ex_branch_mispredict;

endmodule : hazard_unit
