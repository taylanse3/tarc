import tarc_pkg::*;

module fpu_div (
    input fp_unpacked_t a,
    input fp_unpacked_t b,
    output fp_pre_t pre
);

    logic [111:0] num, den, quo, rmd;
    assign num = {3'b0, a.mant, 56'b0};
    assign den = {59'b0, b.mant | 53'(b.zero)};
    assign quo = num / den;
    assign rmd = num % den;

    logic signed [15:0] a_exp, b_exp;
    assign a_exp = a.exp;
    assign b_exp = b.exp;

    logic sign_q;
    assign sign_q = a.sign ^ b.sign;

    always_comb begin
        pre = '0;
        pre.kind = FPK_FINITE;
        pre.sign = sign_q;
        if (a.nan || b.nan) begin
            pre.kind = FPK_NAN;
            pre.nv = a.snan || b.snan;
        end else if ((a.inf && b.inf) || (a.zero && b.zero)) begin
            pre.kind = FPK_NAN;
            pre.nv = 1'b1;
        end else if (a.inf) begin
            pre.kind = FPK_INF;
        end else if (b.inf) begin
            pre.kind = FPK_ZERO;
        end else if (b.zero) begin
            pre.kind = FPK_INF;
            pre.dz = 1'b1;
        end else if (a.zero) begin
            pre.kind = FPK_ZERO;
        end else begin
            pre.exp = a_exp - b_exp - (quo[56] ? 16'sd0 : 16'sd1);
            pre.sig = quo[56] ? {quo[56:0], 71'b0} : {quo[55:0], 72'b0};
            pre.stk = (rmd != '0);
        end
    end

endmodule : fpu_div
