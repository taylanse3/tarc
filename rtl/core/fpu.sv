import tarc_pkg::*;

module fpu #(
    parameter int SIMPLE_LATENCY = 1,
    parameter int ARITH_LATENCY = 4,
    parameter int DIV_LATENCY = 16,
    parameter int SQRT_LATENCY = 20
) (
    input logic clk,
    input logic rst_n,

    input id_ex_t id_ex,

    input xlen_t rs1_fwd_data,
    input logic rs1_use_fwd,
    input xlen_t fp1_fwd_data,
    input xlen_t fp2_fwd_data,
    input xlen_t fp3_fwd_data,
    input logic fp1_use_fwd,
    input logic fp2_use_fwd,
    input logic fp3_use_fwd,
    input logic [2:0] frm,

    input logic trap_flush,
    input logic mem_stall,
    input logic fpu_grant,

    output logic fpu_valid,
    output regfile_e fpu_rd_rf,
    output logic [4:0] fpu_rd,
    output xlen_t fpu_result,
    output logic [4:0] fpu_flags,
    output logic fpu_busy,
    output regfile_e fpu_pending_rf,
    output greg_t fpu_pending_rd,
    output logic fpu_dirty
);

    xlen_t op_x, op_a, op_b, op_c;
    assign op_x = (rs1_use_fwd && id_ex.reads_rs1) ? rs1_fwd_data : id_ex.rs1_data;
    assign op_a = (fp1_use_fwd && id_ex.reads_fp1) ? fp1_fwd_data : id_ex.fp1_data;
    assign op_b = (fp2_use_fwd && id_ex.reads_fp2) ? fp2_fwd_data : id_ex.fp2_data;
    assign op_c = (fp3_use_fwd && id_ex.reads_fp3) ? fp3_fwd_data : id_ex.fp3_data;

    logic [2:0] rm_resolved;
    assign rm_resolved = (id_ex.fp_rm == FRM_DYN) ? frm : id_ex.fp_rm;

    logic [7:0] dispatch_latency;
    always_comb begin
        unique case (id_ex.fpu_op)
            FPU_DIV: dispatch_latency = 8'(DIV_LATENCY);
            FPU_SQRT: dispatch_latency = 8'(SQRT_LATENCY);
            FPU_ADD, FPU_SUB, FPU_MUL, FPU_FMADD, FPU_FMSUB, FPU_FNMADD, FPU_FNMSUB,
            FPU_CVT_F2F, FPU_CVT_F2I, FPU_CVT_I2F: dispatch_latency = 8'(ARITH_LATENCY);
            default: dispatch_latency = 8'(SIMPLE_LATENCY);
        endcase
    end

    logic busy_q;
    logic dispatch;
    assign dispatch = id_ex.valid && (id_ex.fu == FU_FPU) && !busy_q
        && !trap_flush && !mem_stall;

    greg_t rd_q;
    regfile_e rf_q;
    fpu_op_e op_q;
    logic src_dbl_q, dst_dbl_q, int64_q, uns_q;
    logic [2:0] rm_q;
    xlen_t x_q, a_q, b_q, c_q;
    logic [7:0] countdown_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy_q <= 1'b0;
            rd_q <= '0;
            rf_q <= RF_NONE;
            op_q <= FPU_ADD;
            src_dbl_q <= 1'b0;
            dst_dbl_q <= 1'b0;
            int64_q <= 1'b0;
            uns_q <= 1'b0;
            rm_q <= '0;
            x_q <= '0;
            a_q <= '0;
            b_q <= '0;
            c_q <= '0;
            countdown_q <= '0;
        end else if (dispatch) begin
            busy_q <= 1'b1;
            rd_q <= id_ex.rd;
            rf_q <= id_ex.fu_rd_rf;
            op_q <= id_ex.fpu_op;
            src_dbl_q <= id_ex.fp_src_dbl;
            dst_dbl_q <= id_ex.fp_dst_dbl;
            int64_q <= id_ex.fp_int64;
            uns_q <= id_ex.fp_uns;
            rm_q <= rm_resolved;
            x_q <= op_x;
            a_q <= op_a;
            b_q <= op_b;
            c_q <= op_c;
            countdown_q <= dispatch_latency - 8'd1;
        end else if (busy_q && (countdown_q != 8'd0)) begin
            countdown_q <= countdown_q - 8'd1;
        end else if (busy_q && fpu_grant) begin
            busy_q <= 1'b0;
        end
    end

    assign fpu_busy = busy_q || dispatch;
    assign fpu_pending_rd = dispatch ? id_ex.rd : rd_q;
    assign fpu_pending_rf = dispatch ? id_ex.fu_rd_rf : rf_q;
    assign fpu_valid = busy_q && (countdown_q == 8'd0);
    assign fpu_rd_rf = rf_q;
    assign fpu_rd = rd_q;
    assign fpu_dirty = dispatch && (id_ex.fu_rd_rf == RF_FP);

    logic a_dbl;
    assign a_dbl = (op_q == FPU_CLASS) ? !(a_q[63:32] == 32'hFFFF_FFFF) : src_dbl_q;

    fp_unpacked_t ua, ub, uc;

    fpu_unpack u_unpack_a (
        .bits(a_q),
        .dbl(a_dbl),
        .un(ua)
    );

    fpu_unpack u_unpack_b (
        .bits(b_q),
        .dbl(src_dbl_q),
        .un(ub)
    );

    fpu_unpack u_unpack_c (
        .bits(c_q),
        .dbl(src_dbl_q),
        .un(uc)
    );

    fp_unpacked_t one_un, zero_un;

    always_comb begin
        one_un = '0;
        one_un.mant = 53'h10_0000_0000_0000;
        zero_un = '0;
        zero_un.zero = 1'b1;
        zero_un.sign = ua.sign ^ ub.sign;
    end

    fp_unpacked_t fma_a, fma_b, fma_c;
    logic fma_neg_p, fma_neg_c;

    always_comb begin
        fma_a = ua;
        fma_b = ub;
        fma_c = uc;
        fma_neg_p = 1'b0;
        fma_neg_c = 1'b0;
        unique case (op_q)
            FPU_ADD: begin
                fma_b = one_un;
                fma_c = ub;
            end
            FPU_SUB: begin
                fma_b = one_un;
                fma_c = ub;
                fma_neg_c = 1'b1;
            end
            FPU_MUL: begin
                fma_c = zero_un;
            end
            FPU_FMSUB: begin
                fma_neg_c = 1'b1;
            end
            FPU_FNMADD: begin
                fma_neg_p = 1'b1;
                fma_neg_c = 1'b1;
            end
            FPU_FNMSUB: begin
                fma_neg_p = 1'b1;
            end
            default: begin
            end
        endcase
    end

    fp_pre_t pre_fma, pre_div, pre_sqrt, pre_i2f, pre_f2f, pre_sel;

    fpu_fma u_fma (
        .a(fma_a),
        .b(fma_b),
        .c(fma_c),
        .neg_p(fma_neg_p),
        .neg_c(fma_neg_c),
        .rm(rm_q),
        .pre(pre_fma)
    );

    fpu_div u_div (
        .a(ua),
        .b(ub),
        .pre(pre_div)
    );

    fpu_sqrt u_sqrt (
        .a(ua),
        .pre(pre_sqrt)
    );

    fpu_i2f u_i2f (
        .x(x_q),
        .int64(int64_q),
        .uns(uns_q),
        .pre(pre_i2f)
    );

    always_comb begin
        pre_f2f = '0;
        pre_f2f.sign = ua.sign;
        if (ua.nan) begin
            pre_f2f.kind = FPK_NAN;
            pre_f2f.nv = ua.snan;
        end else if (ua.inf) begin
            pre_f2f.kind = FPK_INF;
        end else if (ua.zero) begin
            pre_f2f.kind = FPK_ZERO;
        end else begin
            pre_f2f.kind = FPK_FINITE;
            pre_f2f.exp = ua.exp;
            pre_f2f.sig = {ua.mant, 75'b0};
        end
    end

    always_comb begin
        unique case (op_q)
            FPU_DIV: pre_sel = pre_div;
            FPU_SQRT: pre_sel = pre_sqrt;
            FPU_CVT_I2F: pre_sel = pre_i2f;
            FPU_CVT_F2F: pre_sel = pre_f2f;
            default: pre_sel = pre_fma;
        endcase
    end

    xlen_t round_result;
    logic [4:0] round_flags;

    fpu_round u_round (
        .pre(pre_sel),
        .dbl(dst_dbl_q),
        .rm(rm_q),
        .result(round_result),
        .flags(round_flags)
    );

    xlen_t f2i_result;
    logic [4:0] f2i_flags;

    fpu_f2i u_f2i (
        .a(ua),
        .rm(rm_q),
        .int64(int64_q),
        .uns(uns_q),
        .result(f2i_result),
        .flags(f2i_flags)
    );

    xlen_t misc_result;
    logic [4:0] misc_flags;

    fpu_misc u_misc (
        .op(op_q),
        .dbl(src_dbl_q),
        .a_bits(a_q),
        .b_bits(b_q),
        .x(x_q),
        .ua(ua),
        .ub(ub),
        .result(misc_result),
        .flags(misc_flags)
    );

    always_comb begin
        unique case (op_q)
            FPU_CVT_F2I: begin
                fpu_result = f2i_result;
                fpu_flags = f2i_flags;
            end
            FPU_MIN, FPU_MAX, FPU_EQ, FPU_LT, FPU_LE, FPU_SGNJ, FPU_SGNJN, FPU_SGNJX,
            FPU_CLASS, FPU_MV_X_W, FPU_MV_W_X, FPU_MV_X_D, FPU_MV_D_X: begin
                fpu_result = misc_result;
                fpu_flags = misc_flags;
            end
            default: begin
                fpu_result = round_result;
                fpu_flags = round_flags;
            end
        endcase
    end

endmodule : fpu
