import tarc_pkg::*;

module fpu_misc (
    input fpu_op_e op,
    input logic dbl,
    input xlen_t a_bits,
    input xlen_t b_bits,
    input xlen_t x,
    input fp_unpacked_t ua,
    input fp_unpacked_t ub,
    output xlen_t result,
    output logic [4:0] flags
);

    xlen_t a_eff, b_eff;
    assign a_eff = dbl ? a_bits
        : ((a_bits[63:32] == 32'hFFFF_FFFF) ? a_bits : 64'hFFFF_FFFF_7FC0_0000);
    assign b_eff = dbl ? b_bits
        : ((b_bits[63:32] == 32'hFFFF_FFFF) ? b_bits : 64'hFFFF_FFFF_7FC0_0000);

    logic sa, sb;
    logic [62:0] ma, mb;
    assign sa = dbl ? a_eff[63] : a_eff[31];
    assign sb = dbl ? b_eff[63] : b_eff[31];
    assign ma = dbl ? a_eff[62:0] : {32'b0, a_eff[30:0]};
    assign mb = dbl ? b_eff[62:0] : {32'b0, b_eff[30:0]};

    logic any_nan, any_snan;
    assign any_nan = ua.nan || ub.nan;
    assign any_snan = ua.snan || ub.snan;

    logic lt_ord, eq_val, lt_val;
    always_comb begin
        if (sa != sb) begin
            lt_ord = sa;
        end else if (!sa) begin
            lt_ord = (ma < mb);
        end else begin
            lt_ord = (ma > mb);
        end
        eq_val = (ua.zero && ub.zero) || ((sa == sb) && (ma == mb));
        lt_val = !(ua.zero && ub.zero) && lt_ord;
    end

    xlen_t canon_nan;
    assign canon_nan = dbl ? 64'h7FF8_0000_0000_0000 : 64'hFFFF_FFFF_7FC0_0000;

    logic sgn_inj;
    always_comb begin
        unique case (op)
            FPU_SGNJN: sgn_inj = !sb;
            FPU_SGNJX: sgn_inj = sa ^ sb;
            default: sgn_inj = sb;
        endcase
    end

    logic [9:0] class_bits;
    always_comb begin
        class_bits = '0;
        if (ua.nan) begin
            class_bits[ua.snan ? 8 : 9] = 1'b1;
        end else if (ua.inf) begin
            class_bits[ua.sign ? 0 : 7] = 1'b1;
        end else if (ua.zero) begin
            class_bits[ua.sign ? 3 : 4] = 1'b1;
        end else if (ua.sub) begin
            class_bits[ua.sign ? 2 : 5] = 1'b1;
        end else begin
            class_bits[ua.sign ? 1 : 6] = 1'b1;
        end
    end

    always_comb begin
        result = '0;
        flags = '0;
        unique case (op)
            FPU_EQ: begin
                result = {63'b0, !any_nan && eq_val};
                flags = {any_snan, 4'b0000};
            end
            FPU_LT: begin
                result = {63'b0, !any_nan && lt_val};
                flags = {any_nan, 4'b0000};
            end
            FPU_LE: begin
                result = {63'b0, !any_nan && (lt_val || eq_val)};
                flags = {any_nan, 4'b0000};
            end
            FPU_MIN, FPU_MAX: begin
                if (any_snan || (ua.nan && ub.nan)) begin
                    result = canon_nan;
                    flags = {any_snan, 4'b0000};
                end else if (ua.nan) begin
                    result = b_eff;
                end else if (ub.nan) begin
                    result = a_eff;
                end else if (op == FPU_MIN) begin
                    result = lt_ord ? a_eff : b_eff;
                end else begin
                    result = lt_ord ? b_eff : a_eff;
                end
            end
            FPU_SGNJ, FPU_SGNJN, FPU_SGNJX: begin
                result = dbl ? {sgn_inj, a_eff[62:0]} : {32'hFFFF_FFFF, sgn_inj, a_eff[30:0]};
            end
            FPU_CLASS: result = {54'b0, class_bits};
            FPU_MV_X_W: result = {{32{a_bits[31]}}, a_bits[31:0]};
            FPU_MV_W_X: result = {32'hFFFF_FFFF, x[31:0]};
            FPU_MV_X_D: result = a_bits;
            FPU_MV_D_X: result = x;
            default: begin
            end
        endcase
    end

endmodule : fpu_misc
