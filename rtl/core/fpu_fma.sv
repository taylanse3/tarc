import tarc_pkg::*;

module fpu_fma (
    input fp_unpacked_t a,
    input fp_unpacked_t b,
    input fp_unpacked_t c,
    input logic neg_p,
    input logic neg_c,
    input logic [2:0] rm,
    output fp_pre_t pre
);

    logic sp, sc;
    assign sp = a.sign ^ b.sign ^ neg_p;
    assign sc = c.sign ^ neg_c;

    logic any_nan, any_snan, prod_inv, prod_inf, prod_zero;
    assign any_nan = a.nan || b.nan || c.nan;
    assign any_snan = a.snan || b.snan || c.snan;
    assign prod_inv = (a.inf && b.zero) || (a.zero && b.inf);
    assign prod_inf = a.inf || b.inf;
    assign prod_zero = a.zero || b.zero;

    logic [105:0] prod;
    assign prod = a.mant * b.mant;

    logic prod_top;
    assign prod_top = prod[105];

    logic [105:0] prod_n;
    assign prod_n = prod_top ? prod : {prod[104:0], 1'b0};

    logic signed [15:0] a_exp, b_exp, c_exp;
    assign a_exp = a.exp;
    assign b_exp = b.exp;
    assign c_exp = c.exp;

    logic signed [15:0] exp_p, exp_pe, exp_ce;
    assign exp_p = a_exp + b_exp + (prod_top ? 16'sd1 : 16'sd0);
    assign exp_pe = prod_zero ? -16'sd10000 : exp_p;
    assign exp_ce = c.zero ? -16'sd10000 : c_exp;

    logic prod_large;
    assign prod_large = (exp_pe >= exp_ce);

    logic signed [15:0] exp_l, diff;
    assign exp_l = prod_large ? exp_pe : exp_ce;
    assign diff = prod_large ? (exp_pe - exp_ce) : (exp_ce - exp_pe);

    logic [7:0] dsh;
    assign dsh = (diff > 16'sd160) ? 8'd160 : diff[7:0];

    logic [127:0] frame_p, frame_c, frame_l, frame_s;
    assign frame_p = {1'b0, prod_n, 21'b0};
    assign frame_c = {1'b0, c.mant, 74'b0};
    assign frame_l = prod_large ? frame_p : frame_c;
    assign frame_s = prod_large ? frame_c : frame_p;

    logic [255:0] small_wide;
    assign small_wide = {frame_s, 128'b0} >> dsh;

    logic [128:0] ext_l, ext_s;
    assign ext_l = {frame_l, 1'b0};
    assign ext_s = {small_wide[255:128], |small_wide[127:0]};

    logic eff_sub, sign_l;
    assign eff_sub = (sp != sc);
    assign sign_l = prod_large ? sp : sc;

    logic [129:0] sum_raw;
    assign sum_raw = eff_sub ? ({1'b0, ext_l} - {1'b0, ext_s}) : ({1'b0, ext_l} + {1'b0, ext_s});

    logic neg;
    assign neg = eff_sub && sum_raw[129];

    logic [128:0] sum_abs;
    assign sum_abs = neg ? (~sum_raw[128:0] + 129'd1) : sum_raw[128:0];

    logic [7:0] lead;
    always_comb begin
        lead = '0;
        for (int i = 0; i < 129; i++) begin
            if (sum_abs[i]) begin
                lead = 8'(i);
            end
        end
    end

    logic [128:0] nrm;
    assign nrm = sum_abs << (8'd128 - lead);

    always_comb begin
        pre = '0;
        pre.kind = FPK_FINITE;
        if (any_nan || prod_inv) begin
            pre.kind = FPK_NAN;
            pre.nv = any_snan || prod_inv;
        end else if (prod_inf) begin
            if (c.inf && (sp != sc)) begin
                pre.kind = FPK_NAN;
                pre.nv = 1'b1;
            end else begin
                pre.kind = FPK_INF;
                pre.sign = sp;
            end
        end else if (c.inf) begin
            pre.kind = FPK_INF;
            pre.sign = sc;
        end else if (sum_abs == '0) begin
            pre.kind = FPK_ZERO;
            pre.sign = (sp == sc) ? sp : (rm == FRM_RDN);
        end else begin
            pre.sign = neg ? !sign_l : sign_l;
            pre.exp = exp_l + $signed({8'b0, lead}) - 16'sd127;
            pre.sig = nrm[128:1];
            pre.stk = nrm[0];
        end
    end

endmodule : fpu_fma
