import tarc_pkg::*;

module fpu_round (
    input fp_pre_t pre,
    input logic dbl,
    input logic [2:0] rm,
    output xlen_t result,
    output logic [4:0] flags
);

    function automatic logic round_inc(
        input logic [2:0] mode,
        input logic sgn,
        input logic lsb,
        input logic rnd_b,
        input logic stk_b
    );
        unique case (mode)
            FRM_RNE: round_inc = rnd_b && (stk_b || lsb);
            FRM_RTZ: round_inc = 1'b0;
            FRM_RDN: round_inc = sgn && (rnd_b || stk_b);
            FRM_RUP: round_inc = !sgn && (rnd_b || stk_b);
            FRM_RMM: round_inc = rnd_b;
            default: round_inc = 1'b0;
        endcase
    endfunction

    logic signed [15:0] emin, emax, bias;
    assign emin = dbl ? -16'sd1022 : -16'sd126;
    assign emax = dbl ? 16'sd1023 : 16'sd127;
    assign bias = dbl ? 16'sd1023 : 16'sd127;

    logic signed [15:0] exp_in;
    assign exp_in = pre.exp;

    logic is_sub;
    assign is_sub = (exp_in < emin);

    logic signed [15:0] sh_full;
    assign sh_full = emin - exp_in;

    logic [7:0] shc;
    assign shc = !is_sub ? 8'd0 : (sh_full > 16'sd130) ? 8'd130 : sh_full[7:0];

    logic [255:0] wide;
    assign wide = {pre.sig, 128'b0} >> shc;

    logic [127:0] sig_sh;
    logic lost;
    assign sig_sh = wide[255:128];
    assign lost = |wide[127:0];

    logic [52:0] mant_p;
    logic rnd, stk_all;

    always_comb begin
        if (dbl) begin
            mant_p = sig_sh[127:75];
            rnd = sig_sh[74];
            stk_all = (|sig_sh[73:0]) || lost || pre.stk;
        end else begin
            mant_p = {29'b0, sig_sh[127:104]};
            rnd = sig_sh[103];
            stk_all = (|sig_sh[102:0]) || lost || pre.stk;
        end
    end

    logic inexact, inc;
    assign inexact = rnd || stk_all;
    assign inc = round_inc(rm, pre.sign, mant_p[0], rnd, stk_all);

    logic [53:0] mant_r;
    assign mant_r = {1'b0, mant_p} + 54'(inc);

    logic carry, hidden_r;
    assign carry = dbl ? mant_r[53] : mant_r[24];
    assign hidden_r = dbl ? mant_r[52] : mant_r[23];

    logic signed [15:0] exp_r;
    assign exp_r = exp_in + (carry ? 16'sd1 : 16'sd0);

    logic overflow;
    assign overflow = !is_sub && (exp_r > emax);

    logic [10:0] exp_field;
    always_comb begin
        if (is_sub) begin
            exp_field = hidden_r ? 11'd1 : 11'd0;
        end else begin
            exp_field = 11'(exp_r + bias);
        end
    end

    logic to_inf;
    assign to_inf = (rm == FRM_RNE) || (rm == FRM_RMM)
        || (rm == FRM_RUP && !pre.sign) || (rm == FRM_RDN && pre.sign);

    logic [52:0] mant_u;
    logic rnd_u, stk_u;

    always_comb begin
        if (dbl) begin
            mant_u = pre.sig[127:75];
            rnd_u = pre.sig[74];
            stk_u = (|pre.sig[73:0]) || pre.stk;
        end else begin
            mant_u = {29'b0, pre.sig[127:104]};
            rnd_u = pre.sig[103];
            stk_u = (|pre.sig[102:0]) || pre.stk;
        end
    end

    logic inc_u, carry_u, tiny;
    assign inc_u = round_inc(rm, pre.sign, mant_u[0], rnd_u, stk_u);
    assign carry_u = inc_u && (dbl ? (&mant_u[52:0]) : (&mant_u[23:0]));
    assign tiny = is_sub && !((exp_in == emin - 16'sd1) && carry_u);

    xlen_t zero_bits, inf_bits, nan_bits, max_bits, fin_bits;

    always_comb begin
        if (dbl) begin
            zero_bits = {pre.sign, 63'b0};
            inf_bits = {pre.sign, 11'h7FF, 52'b0};
            nan_bits = {1'b0, 11'h7FF, 1'b1, 51'b0};
            max_bits = {pre.sign, 11'h7FE, {52{1'b1}}};
            fin_bits = {pre.sign, exp_field, mant_r[51:0]};
        end else begin
            zero_bits = {32'hFFFF_FFFF, pre.sign, 31'b0};
            inf_bits = {32'hFFFF_FFFF, pre.sign, 8'hFF, 23'b0};
            nan_bits = {32'hFFFF_FFFF, 1'b0, 8'hFF, 1'b1, 22'b0};
            max_bits = {32'hFFFF_FFFF, pre.sign, 8'hFE, {23{1'b1}}};
            fin_bits = {32'hFFFF_FFFF, pre.sign, exp_field[7:0], mant_r[22:0]};
        end
    end

    always_comb begin
        result = fin_bits;
        flags = '0;
        unique case (pre.kind)
            FPK_FINITE: begin
                if (overflow) begin
                    result = to_inf ? inf_bits : max_bits;
                    flags = 5'b00101;
                end else begin
                    flags = {2'b00, 1'b0, tiny && inexact, inexact};
                end
            end
            FPK_ZERO: begin
                result = zero_bits;
                flags = {pre.nv, pre.dz, 3'b000};
            end
            FPK_INF: begin
                result = inf_bits;
                flags = {pre.nv, pre.dz, 3'b000};
            end
            FPK_NAN: begin
                result = nan_bits;
                flags = {pre.nv, pre.dz, 3'b000};
            end
            default: begin
            end
        endcase
    end

endmodule : fpu_round
