import tarc_pkg::*;

module decode (
    input if_id_t if_id,

    input logic fs_off,
    input logic vs_off,

    output greg_t rs1_addr,
    output greg_t rs2_addr,
    input xlen_t rs1_data_raw,
    input xlen_t rs2_data_raw,

    output id_ex_t id_ex,

    output logic hz_reads_rs1,
    output logic hz_reads_rs2,
    output fu_tag_e hz_fu,
    output logic hz_is_csr_write
);

    opcode_e op;
    logic [2:0] funct3;
    logic [7:0] rem;

    assign op = opcode_e'(if_id.instr[5:0]);
    assign funct3 = if_id.instr[13:11];
    assign rem = if_id.instr[31:24];
    assign rs1_addr = if_id.instr[18:14];
    assign rs2_addr = if_id.instr[23:19];

    greg_t rd_field;
    assign rd_field = if_id.instr[10:6];

    xlen_t rs1_data, rs2_data;
    assign rs1_data = rs1_data_raw;
    assign rs2_data = rs2_data_raw;

    xlen_t imm_i, imm_s, imm_b, imm_u, imm_j;

    assign imm_i = {{51{if_id.instr[31]}}, if_id.instr[31:19]};

    logic [12:0] imm_sb_bits;
    assign imm_sb_bits = {if_id.instr[31:24], if_id.instr[10:6]};
    assign imm_s = {{51{imm_sb_bits[12]}}, imm_sb_bits};
    assign imm_b = {{49{imm_sb_bits[12]}}, imm_sb_bits, 2'b00};

    assign imm_u = {{43{if_id.instr[31]}}, if_id.instr[31:11]};
    assign imm_j = {{41{if_id.instr[31]}}, if_id.instr[31:11], 2'b00};

    logic illegal_opcode;
    always_comb begin
        unique case (op)
            OPC_OP, OPC_OP_M, OPC_AMO, OPC_OP_IMM, OPC_LOAD, OPC_JALR,
            OPC_CSR, OPC_FENCE, OPC_STORE, OPC_BRANCH, OPC_LUI, OPC_AUIPC,
            OPC_JAL, OPC_SYSTEM, OPC_TLBINV,
            OPC_FMADD, OPC_FOP, OPC_FCMP, OPC_FCVT, OPC_FLOAD, OPC_FSTORE,
            OPC_FSGNJ, OPC_FMV,
            OPC_VCFG, OPC_VIOP, OPC_VMUL, OPC_VFOP, OPC_VFMACC, OPC_VCMP,
            OPC_VFCMP, OPC_VLOAD, OPC_VSTORE, OPC_VRED, OPC_VFRED, OPC_VPERM,
            OPC_VMASK, OPC_VFSGNJ: begin
                illegal_opcode = 1'b0;
            end

            default: begin
                illegal_opcode = 1'b1;
            end
        endcase
    end

    logic csr_imm_form;
    assign csr_imm_form = (funct3 == F3_CSRRWI) || (funct3 == F3_CSRRSI) || (funct3 == F3_CSRRCI);

    logic csr_writes;
    assign csr_writes = (funct3 == F3_CSRRW) || (funct3 == F3_CSRRWI) || (rs1_addr != '0);

    logic illegal;
    exc_cause_e illegal_cause;

    always_comb begin
        id_ex = '0;
        id_ex.pc = if_id.pc;
        id_ex.valid = if_id.valid && !if_id.fault_valid;
        id_ex.opcode = op;
        id_ex.rd = rd_field;
        id_ex.rs1 = rs1_addr;
        id_ex.rs2 = rs2_addr;
        id_ex.rs1_data = rs1_data;
        id_ex.rs2_data = rs2_data;
        id_ex.fu = FU_NONE;
        id_ex.rd_rf = RF_NONE;
        id_ex.pred_taken = if_id.pred_taken;
        id_ex.pred_target = if_id.pred_target;

        id_ex.fault_valid = if_id.fault_valid;
        id_ex.fault_cause = if_id.fault_cause;
        id_ex.fault_tval = if_id.fault_tval;

        hz_reads_rs1 = 1'b0;
        hz_reads_rs2 = 1'b0;
        hz_is_csr_write = 1'b0;

        illegal = 1'b0;
        illegal_cause = CAUSE_ILLEGAL_INSTR;

        if (!if_id.fault_valid) begin
            if (illegal_opcode) begin
                illegal = 1'b1;
            end else begin
                unique case (op)

                    OPC_OP: begin
                        hz_reads_rs1 = 1'b1;
                        hz_reads_rs2 = 1'b1;
                        id_ex.fu = FU_MAIN;
                        id_ex.rd_rf = RF_INT;
                        unique case (funct3)
                            F3_ADDSUB: id_ex.alu_op = rem[7] ? ALU_SUB : ALU_ADD;
                            F3_SLL: id_ex.alu_op = ALU_SLL;
                            F3_SLT: id_ex.alu_op = ALU_SLT;
                            F3_SLTU: id_ex.alu_op = ALU_SLTU;
                            F3_XOR: id_ex.alu_op = ALU_XOR;
                            F3_SRLSRA: id_ex.alu_op = rem[7] ? ALU_SRA : ALU_SRL;
                            F3_OR: id_ex.alu_op = ALU_OR;
                            F3_AND: id_ex.alu_op = ALU_AND;
                        endcase
                        if (rem != 8'b0 && funct3 != F3_ADDSUB && funct3 != F3_SRLSRA) begin
                            illegal = 1'b1;
                        end
                    end

                    OPC_OP_IMM: begin
                        hz_reads_rs1 = 1'b1;
                        id_ex.fu = FU_MAIN;
                        id_ex.rd_rf = RF_INT;
                        if (funct3 == F3_SLL || funct3 == F3_SRLSRA) begin
                            id_ex.rs2_data = {58'b0, imm_i[5:0]};
                            id_ex.alu_op = (funct3 == F3_SLL) ? ALU_SLL : (imm_i[11] ? ALU_SRA : ALU_SRL);
                            if (imm_i[12] || (imm_i[10:6] != 5'b0) || (funct3 == F3_SLL && imm_i[11])) begin
                                illegal = 1'b1;
                            end
                        end else begin
                            id_ex.rs2_data = imm_i;
                            unique case (funct3)
                                F3_ADDSUB: id_ex.alu_op = ALU_ADD;
                                F3_SLT: id_ex.alu_op = ALU_SLT;
                                F3_SLTU: id_ex.alu_op = ALU_SLTU;
                                F3_XOR: id_ex.alu_op = ALU_XOR;
                                F3_OR: id_ex.alu_op = ALU_OR;
                                F3_AND: id_ex.alu_op = ALU_AND;
                                default: id_ex.alu_op = ALU_ADD;
                            endcase
                        end
                    end

                    OPC_LOAD: begin
                        hz_reads_rs1 = 1'b1;
                        id_ex.fu = FU_MAIN;
                        id_ex.rd_rf = RF_INT;
                        id_ex.alu_op = ALU_ADD;
                        id_ex.rs2_data = imm_i;
                        id_ex.is_load = 1'b1;
                        id_ex.mem_unsigned = (funct3 == F3_LBU || funct3 == F3_LHU || funct3 == F3_LWU);
                        unique case (funct3)
                            F3_LB, F3_LBU: id_ex.mem_size = 2'b00;
                            F3_LH, F3_LHU: id_ex.mem_size = 2'b01;
                            F3_LW, F3_LWU: id_ex.mem_size = 2'b10;
                            F3_LD: id_ex.mem_size = 2'b11;
                            default: illegal = 1'b1;
                        endcase
                    end

                    OPC_STORE: begin
                        hz_reads_rs1 = 1'b1;
                        hz_reads_rs2 = 1'b1;
                        id_ex.fu = FU_MAIN;
                        id_ex.rd_rf = RF_NONE;
                        id_ex.alu_op = ALU_ADD;
                        id_ex.imm = imm_s;
                        id_ex.is_store = 1'b1;
                        unique case (funct3)
                            F3_SB: id_ex.mem_size = 2'b00;
                            F3_SH: id_ex.mem_size = 2'b01;
                            F3_SW: id_ex.mem_size = 2'b10;
                            F3_SD: id_ex.mem_size = 2'b11;
                            default: illegal = 1'b1;
                        endcase
                    end

                    OPC_BRANCH: begin
                        hz_reads_rs1 = 1'b1;
                        hz_reads_rs2 = 1'b1;
                        id_ex.fu = FU_MAIN;
                        id_ex.rd_rf = RF_NONE;
                        id_ex.is_branch = 1'b1;
                        id_ex.branch_kind = branch_funct3_e'(funct3);
                        id_ex.imm = imm_b;
                        if (funct3 == 3'b010 || funct3 == 3'b011) begin
                            illegal = 1'b1;
                        end
                    end

                    OPC_JAL: begin
                        id_ex.fu = FU_MAIN;
                        id_ex.rd_rf = RF_INT;
                        id_ex.is_jump = 1'b1;
                        id_ex.imm = imm_j;
                        id_ex.alu_op = ALU_ADD;
                    end

                    OPC_JALR: begin
                        hz_reads_rs1 = 1'b1;
                        id_ex.fu = FU_MAIN;
                        id_ex.rd_rf = RF_INT;
                        id_ex.is_jump = 1'b1;
                        id_ex.imm = imm_i;
                        id_ex.alu_op = ALU_ADD;
                        if (funct3 != 3'b000) begin
                            illegal = 1'b1;
                        end
                    end

                    OPC_LUI, OPC_AUIPC: begin
                        id_ex.fu = FU_MAIN;
                        id_ex.rd_rf = RF_INT;
                        id_ex.alu_op = ALU_ADD;
                        id_ex.rs1_data = (op == OPC_AUIPC) ? if_id.pc : '0;
                        id_ex.rs2_data = xlen_t'($signed(imm_u) <<< 13);
                    end

                    OPC_SYSTEM: begin
                        id_ex.fu = FU_MAIN;
                        id_ex.rd_rf = RF_NONE;
                        id_ex.is_system = 1'b1;
                        id_ex.system_kind = system_funct3_e'(funct3);
                        if (funct3[2] || rd_field != '0 || rs1_addr != '0) begin
                            illegal = 1'b1;
                        end
                    end

                    OPC_CSR: begin
                        hz_reads_rs1 = !csr_imm_form;
                        id_ex.fu = FU_MAIN;
                        id_ex.rd_rf = RF_INT;
                        id_ex.is_csr = 1'b1;
                        id_ex.is_csr_write = csr_writes;
                        id_ex.csr_addr = if_id.instr[30:19];
                        id_ex.csr_kind = csr_funct3_e'(funct3);
                        if (csr_imm_form) begin
                            id_ex.rs1_data = {59'b0, rs1_addr};
                        end
                        hz_is_csr_write = csr_writes;
                        if (funct3 == 3'b000 || funct3 == 3'b100 || if_id.instr[31]) begin
                            illegal = 1'b1;
                        end
                    end

                    OPC_OP_M: begin
                        hz_reads_rs1 = 1'b1;
                        hz_reads_rs2 = 1'b1;
                        id_ex.fu = FU_MULDIV;
                        id_ex.rd_rf = RF_NONE;
                        id_ex.muldiv_kind = muldiv_funct3_e'(funct3);
                    end

                    OPC_FMADD, OPC_FOP, OPC_FCMP, OPC_FCVT, OPC_FLOAD, OPC_FSTORE,
                    OPC_FSGNJ, OPC_FMV: begin
                        hz_reads_rs1 = 1'b1;
                        hz_reads_rs2 = 1'b1;
                        id_ex.fu = FU_FPU;
                        id_ex.rd_rf = RF_FP;
                        illegal = 1'b1;
                        illegal_cause = fs_off ? CAUSE_FP_DISABLED : CAUSE_ILLEGAL_INSTR;
                    end

                    OPC_VCFG, OPC_VIOP, OPC_VMUL, OPC_VFOP, OPC_VFMACC, OPC_VCMP,
                    OPC_VFCMP, OPC_VLOAD, OPC_VSTORE, OPC_VRED, OPC_VFRED, OPC_VPERM,
                    OPC_VMASK, OPC_VFSGNJ: begin
                        hz_reads_rs1 = 1'b1;
                        hz_reads_rs2 = 1'b1;
                        id_ex.fu = FU_VEC;
                        id_ex.rd_rf = RF_VEC;
                        illegal = 1'b1;
                        illegal_cause = vs_off ? CAUSE_VEC_DISABLED : CAUSE_ILLEGAL_INSTR;
                    end

                    OPC_FENCE: begin
                        id_ex.fu = FU_NONE;
                        id_ex.rd_rf = RF_NONE;
                        if (funct3 != 3'b000 || rd_field != '0 || rs1_addr != '0 || if_id.instr[31:27] != 5'b0) begin
                            illegal = 1'b1;
                        end
                    end

                    OPC_AMO: begin
                        illegal = 1'b1;
                    end

                    OPC_TLBINV: begin
                        id_ex.fu = FU_NONE;
                        id_ex.rd_rf = RF_NONE;
                    end

                    default: begin
                    end
                endcase
            end

            if (illegal) begin
                id_ex = '0;
                id_ex.pc = if_id.pc;
                id_ex.valid = if_id.valid;
                id_ex.opcode = op;
                id_ex.fu = FU_NONE;
                id_ex.rd_rf = RF_NONE;
                id_ex.fault_valid = 1'b1;
                id_ex.fault_cause = illegal_cause;
                id_ex.fault_tval = '0;
                hz_reads_rs1 = 1'b0;
                hz_reads_rs2 = 1'b0;
                hz_is_csr_write = 1'b0;
            end
        end

        id_ex.reads_rs1 = hz_reads_rs1;
        id_ex.reads_rs2 = hz_reads_rs2;
        hz_fu = id_ex.fu;
    end

endmodule : decode
