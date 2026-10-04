import tarc_pkg::*;

module fpu_sqrt (
    input fp_unpacked_t a,
    output fp_pre_t pre
);

    logic [111:0] radicand;
    assign radicand = a.exp[0] ? {a.mant, 59'b0} : {1'b0, a.mant, 58'b0};

    logic [111:0] op_r, res_r, one_r;

    always_comb begin
        op_r = radicand;
        res_r = '0;
        one_r = 112'd1 << 110;
        for (int i = 0; i < 56; i++) begin
            if (op_r >= (res_r + one_r)) begin
                op_r = op_r - (res_r + one_r);
                res_r = (res_r >> 1) + one_r;
            end else begin
                res_r = res_r >> 1;
            end
            one_r = one_r >> 2;
        end
    end

    logic signed [15:0] a_exp;
    assign a_exp = a.exp;

    always_comb begin
        pre = '0;
        pre.kind = FPK_FINITE;
        if (a.nan) begin
            pre.kind = FPK_NAN;
            pre.nv = a.snan;
        end else if (a.zero) begin
            pre.kind = FPK_ZERO;
            pre.sign = a.sign;
        end else if (a.sign) begin
            pre.kind = FPK_NAN;
            pre.nv = 1'b1;
        end else if (a.inf) begin
            pre.kind = FPK_INF;
        end else begin
            pre.exp = a_exp >>> 1;
            pre.sig = {res_r[55:0], 72'b0};
            pre.stk = (op_r != '0);
        end
    end

endmodule : fpu_sqrt
