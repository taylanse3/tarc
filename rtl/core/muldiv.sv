import tarc_pkg::*;

module muldiv #(
    parameter int MUL_LATENCY = 3,
    parameter int DIV_LATENCY = 16
) (
    input logic clk,
    input logic rst_n,

    input id_ex_t id_ex,

    input xlen_t rs1_fwd_data,
    input xlen_t rs2_fwd_data,
    input logic rs1_use_fwd,
    input logic rs2_use_fwd,

    input logic trap_flush,
    input logic muldiv_grant,

    output logic muldiv_valid,
    output greg_t muldiv_rd,
    output xlen_t muldiv_result,
    output logic muldiv_busy,
    output greg_t muldiv_pending_rd
);

    xlen_t op_a, op_b;
    assign op_a = (rs1_use_fwd && id_ex.reads_rs1) ? rs1_fwd_data : id_ex.rs1_data;
    assign op_b = (rs2_use_fwd && id_ex.reads_rs2) ? rs2_fwd_data : id_ex.rs2_data;

    logic dispatch_is_div;
    assign dispatch_is_div = (id_ex.muldiv_kind == F3_DIV) || (id_ex.muldiv_kind == F3_DIVU)
        || (id_ex.muldiv_kind == F3_REM) || (id_ex.muldiv_kind == F3_REMU);

    logic busy_q;
    logic dispatch;
    assign dispatch = id_ex.valid && (id_ex.fu == FU_MULDIV) && !busy_q && !trap_flush;

    greg_t rd_q;
    muldiv_funct3_e kind_q;
    xlen_t a_q, b_q;
    logic [7:0] countdown_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy_q <= 1'b0;
            rd_q <= '0;
            kind_q <= muldiv_funct3_e'('0);
            a_q <= '0;
            b_q <= '0;
            countdown_q <= '0;
        end else if (dispatch) begin
            busy_q <= 1'b1;
            rd_q <= id_ex.rd;
            kind_q <= id_ex.muldiv_kind;
            a_q <= op_a;
            b_q <= op_b;
            countdown_q <= dispatch_is_div ? 8'(DIV_LATENCY - 1) : 8'(MUL_LATENCY - 1);
        end else if (busy_q && (countdown_q != 8'd0)) begin
            countdown_q <= countdown_q - 8'd1;
        end else if (busy_q && muldiv_grant) begin
            busy_q <= 1'b0;
        end
    end

    assign muldiv_busy = busy_q || dispatch;
    assign muldiv_pending_rd = dispatch ? id_ex.rd : rd_q;
    assign muldiv_valid = busy_q && (countdown_q == 8'd0);
    assign muldiv_rd = rd_q;

    logic [XLEN:0] mulh_a, mulh_b_signed, mulh_b_unsigned;
    assign mulh_a = {a_q[XLEN-1], a_q};
    assign mulh_b_signed = {b_q[XLEN-1], b_q};
    assign mulh_b_unsigned = {1'b0, b_q};

    logic signed [2*XLEN+1:0] mul_ss, mul_su;
    logic [2*XLEN-1:0] mul_uu;
    assign mul_ss = $signed(mulh_a) * $signed(mulh_b_signed);
    assign mul_su = $signed(mulh_a) * $signed(mulh_b_unsigned);
    assign mul_uu = a_q * b_q;

    logic div_by_zero, div_overflow;
    assign div_by_zero = (b_q == '0);
    assign div_overflow = (a_q == {1'b1, {(XLEN - 1){1'b0}}}) && (b_q == {XLEN{1'b1}});

    xlen_t div_result, divu_result, rem_result, remu_result;
    assign div_result = div_by_zero ? {XLEN{1'b1}} :
        div_overflow ? a_q : xlen_t'($signed(a_q) / $signed(b_q));
    assign divu_result = div_by_zero ? {XLEN{1'b1}} : (a_q / b_q);
    assign rem_result = div_by_zero ? a_q :
        div_overflow ? '0 : xlen_t'($signed(a_q) % $signed(b_q));
    assign remu_result = div_by_zero ? a_q : (a_q % b_q);

    always_comb begin
        unique case (kind_q)
            F3_MUL: muldiv_result = mul_uu[XLEN-1:0];
            F3_MULH: muldiv_result = xlen_t'(mul_ss[2*XLEN-1:XLEN]);
            F3_MULHSU: muldiv_result = xlen_t'(mul_su[2*XLEN-1:XLEN]);
            F3_MULHU: muldiv_result = mul_uu[2*XLEN-1:XLEN];
            F3_DIV: muldiv_result = div_result;
            F3_DIVU: muldiv_result = divu_result;
            F3_REM: muldiv_result = rem_result;
            F3_REMU: muldiv_result = remu_result;
            default: muldiv_result = '0;
        endcase
    end

endmodule : muldiv
