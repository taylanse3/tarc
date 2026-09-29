import tarc_pkg::*;

module alu (
    input alu_op_e op,
    input xlen_t a,
    input xlen_t b,
    output xlen_t result,
    output logic eq,
    output logic lt_signed,
    output logic lt_unsigned
);

    logic [5:0] shamt;
    assign shamt = b[5:0];

    assign eq = (a == b);
    assign lt_signed = ($signed(a) < $signed(b));
    assign lt_unsigned = (a < b);

    always_comb begin
        unique case (op)
            ALU_ADD: result = a + b;
            ALU_SUB: result = a - b;
            ALU_SLL: result = a << shamt;
            ALU_SLT: result = {63'b0, lt_signed};
            ALU_SLTU: result = {63'b0, lt_unsigned};
            ALU_XOR: result = a ^ b;
            ALU_SRL: result = a >> shamt;
            ALU_SRA: result = xlen_t'($signed(a) >>> shamt);
            ALU_OR: result = a | b;
            ALU_AND: result = a & b;
            ALU_PASS_B: result = b;
            default: result = '0;
        endcase
    end

endmodule : alu
