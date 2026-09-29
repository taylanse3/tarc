import tarc_pkg::*;

module execute (
    input id_ex_t id_ex,

    input xlen_t rs1_fwd_data,
    input xlen_t rs2_fwd_data,
    input logic rs1_use_fwd,
    input logic rs2_use_fwd,

    output ex_mem_t ex_mem,

    output logic branch_mispredict,
    output xlen_t branch_target
);

    xlen_t op_a, op_b;
    assign op_a = (rs1_use_fwd && id_ex.reads_rs1) ? rs1_fwd_data : id_ex.rs1_data;
    assign op_b = (rs2_use_fwd && id_ex.reads_rs2) ? rs2_fwd_data : id_ex.rs2_data;

    xlen_t alu_result;
    logic eq, lt_signed, lt_unsigned;

    alu u_alu (
        .op(id_ex.alu_op),
        .a(op_a),
        .b(op_b),
        .result(alu_result),
        .eq(eq),
        .lt_signed(lt_signed),
        .lt_unsigned(lt_unsigned)
    );

    logic branch_taken;
    always_comb begin
        unique case (id_ex.branch_kind)
            F3_BEQ: branch_taken = eq;
            F3_BNE: branch_taken = !eq;
            F3_BLT: branch_taken = lt_signed;
            F3_BGE: branch_taken = !lt_signed;
            F3_BLTU: branch_taken = lt_unsigned;
            F3_BGEU: branch_taken = !lt_unsigned;
            default: branch_taken = 1'b0;
        endcase
    end

    xlen_t branch_taken_addr;
    assign branch_taken_addr = id_ex.pc + id_ex.imm;

    always_comb begin
        if (id_ex.is_jump) begin
            branch_mispredict = id_ex.valid;
            branch_target = (id_ex.opcode == OPC_JALR) ? (op_a + id_ex.imm) : (id_ex.pc + id_ex.imm);
        end else if (id_ex.is_branch) begin
            branch_mispredict = id_ex.valid && (
                (branch_taken != id_ex.pred_taken) ||
                (branch_taken && (branch_taken_addr != id_ex.pred_target))
            );
            branch_target = branch_taken ? branch_taken_addr : (id_ex.pc + 4);
        end else begin
            branch_mispredict = 1'b0;
            branch_target = '0;
        end
    end

    always_comb begin
        ex_mem = '0;
        ex_mem.pc = id_ex.pc;
        ex_mem.valid = id_ex.valid;
        ex_mem.rd = id_ex.rd;
        ex_mem.rd_rf = id_ex.rd_rf;
        ex_mem.reg_write = (id_ex.rd_rf != RF_NONE);
        ex_mem.is_load = id_ex.is_load;
        ex_mem.is_store = id_ex.is_store;
        ex_mem.mem_unsigned = id_ex.mem_unsigned;
        ex_mem.mem_size = id_ex.mem_size;
        ex_mem.fu = id_ex.fu;
        ex_mem.fault_valid = id_ex.fault_valid;
        ex_mem.fault_cause = id_ex.fault_cause;
        ex_mem.fault_tval = id_ex.fault_tval;
        ex_mem.is_csr = id_ex.is_csr;
        ex_mem.is_csr_write = id_ex.is_csr_write;
        ex_mem.csr_addr = id_ex.csr_addr;
        ex_mem.csr_kind = id_ex.csr_kind;
        ex_mem.csr_wdata = op_a;
        ex_mem.next_pc = (id_ex.is_jump || id_ex.is_branch) ? branch_target : (id_ex.pc + 4);
        ex_mem.is_system = id_ex.is_system;
        ex_mem.system_kind = id_ex.system_kind;

        if (id_ex.is_jump) begin
            ex_mem.alu_result = id_ex.pc + 4;
        end else if (id_ex.is_store) begin
            ex_mem.alu_result = op_a + id_ex.imm;
            ex_mem.rs2_data = op_b;
        end else begin
            ex_mem.alu_result = alu_result;
        end
    end

endmodule : execute
