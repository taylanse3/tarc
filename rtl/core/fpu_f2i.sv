import tarc_pkg::*;

module fpu_f2i (
    input fp_unpacked_t a,
    input logic [2:0] rm,
    input logic int64,
    input logic uns,
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

    logic signed [15:0] e;
    assign e = a.exp;

    logic big;
    assign big = (e > 16'sd63);

    logic [127:0] shifted;
    logic [63:0] int_part;
    logic g, s;

    always_comb begin
        shifted = '0;
        int_part = '0;
        g = 1'b0;
        s = 1'b0;
        if (big) begin
        end else if (e >= 16'sd52) begin
            int_part = 64'({11'b0, a.mant} << (e[5:0] - 6'd52));
        end else if (e < -16'sd12) begin
            s = 1'b1;
        end else begin
            shifted = {11'b0, a.mant, 64'b0} >> 7'(16'sd52 - e);
            int_part = shifted[127:64];
            g = shifted[63];
            s = |shifted[62:0];
        end
    end

    logic inc;
    assign inc = round_inc(rm, a.sign, int_part[0], g, s);

    logic [64:0] rounded;
    assign rounded = {1'b0, int_part} + 65'(inc);

    logic [64:0] lim_pos, lim_neg;
    always_comb begin
        if (uns) begin
            lim_pos = int64 ? {1'b0, {64{1'b1}}} : 65'h0_0000_0000_FFFF_FFFF;
            lim_neg = 65'd0;
        end else begin
            lim_pos = int64 ? 65'h0_7FFF_FFFF_FFFF_FFFF : 65'h0_0000_0000_7FFF_FFFF;
            lim_neg = int64 ? 65'h0_8000_0000_0000_0000 : 65'h0_0000_0000_8000_0000;
        end
    end

    logic in_range;
    assign in_range = !big && (a.sign ? (rounded <= lim_neg) : (rounded <= lim_pos));

    xlen_t max_val, min_val;
    always_comb begin
        if (uns) begin
            max_val = int64 ? {64{1'b1}} : 64'h0000_0000_FFFF_FFFF;
            min_val = '0;
        end else begin
            max_val = int64 ? 64'h7FFF_FFFF_FFFF_FFFF : 64'h0000_0000_7FFF_FFFF;
            min_val = int64 ? 64'h8000_0000_0000_0000 : 64'hFFFF_FFFF_8000_0000;
        end
    end

    always_comb begin
        result = '0;
        flags = '0;
        if (a.nan) begin
            result = max_val;
            flags = 5'b10000;
        end else if (a.inf) begin
            result = a.sign ? min_val : max_val;
            flags = 5'b10000;
        end else if (a.zero) begin
            result = '0;
        end else if (in_range) begin
            result = a.sign ? (~rounded[63:0] + 64'd1) : rounded[63:0];
            flags = {4'b0000, g || s};
        end else begin
            result = a.sign ? min_val : max_val;
            flags = 5'b10000;
        end
    end

endmodule : fpu_f2i
