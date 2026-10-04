import tarc_pkg::*;

module fpu_i2f (
    input xlen_t x,
    input logic int64,
    input logic uns,
    output fp_pre_t pre
);

    logic neg;
    xlen_t val, mag;

    always_comb begin
        if (int64) begin
            neg = !uns && x[63];
            val = x;
        end else begin
            neg = !uns && x[31];
            val = uns ? {32'b0, x[31:0]} : {{32{x[31]}}, x[31:0]};
        end
        mag = neg ? (~val + 64'd1) : val;
    end

    logic [5:0] lead;

    always_comb begin
        lead = '0;
        for (int i = 0; i < 64; i++) begin
            if (mag[i]) begin
                lead = 6'(i);
            end
        end
    end

    always_comb begin
        pre = '0;
        if (mag == '0) begin
            pre.kind = FPK_ZERO;
        end else begin
            pre.kind = FPK_FINITE;
            pre.sign = neg;
            pre.exp = $signed({10'b0, lead});
            pre.sig = {(mag << (6'd63 - lead)), 64'b0};
        end
    end

endmodule : fpu_i2f
