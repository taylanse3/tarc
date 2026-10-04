import tarc_pkg::*;

module fpu_unpack (
    input xlen_t bits,
    input logic dbl,
    output fp_unpacked_t un
);

    logic boxed;
    assign boxed = (bits[63:32] == 32'hFFFF_FFFF);

    logic [31:0] s_bits;
    assign s_bits = boxed ? bits[31:0] : 32'h7FC0_0000;

    logic [7:0] s_exp;
    logic [22:0] s_frac;
    logic [10:0] d_exp;
    logic [51:0] d_frac;

    assign s_exp = s_bits[30:23];
    assign s_frac = s_bits[22:0];
    assign d_exp = bits[62:52];
    assign d_frac = bits[51:0];

    logic [4:0] s_pos;
    logic [5:0] d_pos;

    always_comb begin
        s_pos = '0;
        for (int i = 0; i < 23; i++) begin
            if (s_frac[i]) begin
                s_pos = 5'(i);
            end
        end
        d_pos = '0;
        for (int i = 0; i < 52; i++) begin
            if (d_frac[i]) begin
                d_pos = 6'(i);
            end
        end
    end

    always_comb begin
        un = '0;
        if (dbl) begin
            un.sign = bits[63];
            if (d_exp == 11'h7FF) begin
                un.inf = (d_frac == '0);
                un.nan = (d_frac != '0);
                un.snan = (d_frac != '0) && !d_frac[51];
            end else if (d_exp == 11'h000) begin
                if (d_frac == '0) begin
                    un.zero = 1'b1;
                end else begin
                    un.sub = 1'b1;
                    un.mant = {1'b0, d_frac} << (6'd52 - d_pos);
                    un.exp = $signed({10'b0, d_pos}) - 16'sd1074;
                end
            end else begin
                un.mant = {1'b1, d_frac};
                un.exp = $signed({5'b0, d_exp}) - 16'sd1023;
            end
        end else begin
            un.sign = s_bits[31];
            if (s_exp == 8'hFF) begin
                un.inf = (s_frac == '0);
                un.nan = (s_frac != '0);
                un.snan = (s_frac != '0) && !s_frac[22];
            end else if (s_exp == 8'h00) begin
                if (s_frac == '0) begin
                    un.zero = 1'b1;
                end else begin
                    un.sub = 1'b1;
                    un.mant = {s_frac, 30'b0} << (5'd22 - s_pos);
                    un.exp = $signed({11'b0, s_pos}) - 16'sd149;
                end
            end else begin
                un.mant = {1'b1, s_frac, 29'b0};
                un.exp = $signed({8'b0, s_exp}) - 16'sd127;
            end
        end
    end

endmodule : fpu_unpack
