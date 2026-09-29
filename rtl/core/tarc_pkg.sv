package tarc_pkg;

    parameter int XLEN = 64;
    parameter int ILEN = 32;
    parameter int VLEN = 128;
    parameter int NUM_GPR = 32;
    parameter int NUM_FPR = 32;
    parameter int NUM_VR = 32;

    typedef logic [XLEN-1:0] xlen_t;
    typedef logic [ILEN-1:0] instr_t;
    typedef logic [$clog2(NUM_GPR)-1:0] greg_t;
    typedef logic [VLEN-1:0] vreg_t;

    typedef enum logic [5:0] {
        OPC_OP = 6'h00,
        OPC_OP_M = 6'h01,
        OPC_AMO = 6'h02,
        OPC_OP_IMM = 6'h03,
        OPC_LOAD = 6'h04,
        OPC_JALR = 6'h05,
        OPC_CSR = 6'h06,
        OPC_FENCE = 6'h07,
        OPC_STORE = 6'h08,
        OPC_BRANCH = 6'h09,
        OPC_LUI = 6'h0A,
        OPC_AUIPC = 6'h0B,
        OPC_JAL = 6'h0C,
        OPC_SYSTEM = 6'h0D,
        OPC_TLBINV = 6'h0E,

        OPC_FMADD = 6'h20,
        OPC_FOP = 6'h21,
        OPC_FCMP = 6'h22,
        OPC_FCVT = 6'h23,
        OPC_FLOAD = 6'h24,
        OPC_FSTORE = 6'h25,
        OPC_FSGNJ = 6'h26,
        OPC_FMV = 6'h27,

        OPC_VCFG = 6'h30,
        OPC_VIOP = 6'h31,
        OPC_VMUL = 6'h32,
        OPC_VFOP = 6'h33,
        OPC_VFMACC = 6'h34,
        OPC_VCMP = 6'h35,
        OPC_VFCMP = 6'h36,
        OPC_VLOAD = 6'h37,
        OPC_VSTORE = 6'h38,
        OPC_VRED = 6'h39,
        OPC_VFRED = 6'h3A,
        OPC_VPERM = 6'h3B,
        OPC_VMASK = 6'h3C,
        OPC_VFSGNJ = 6'h3D
    } opcode_e;

    typedef enum logic [2:0] {
        F3_ADDSUB = 3'b000,
        F3_SLL = 3'b001,
        F3_SLT = 3'b010,
        F3_SLTU = 3'b011,
        F3_XOR = 3'b100,
        F3_SRLSRA = 3'b101,
        F3_OR = 3'b110,
        F3_AND = 3'b111
    } alu_funct3_e;

    typedef enum logic [3:0] {
        ALU_ADD,
        ALU_SUB,
        ALU_SLL,
        ALU_SLT,
        ALU_SLTU,
        ALU_XOR,
        ALU_SRL,
        ALU_SRA,
        ALU_OR,
        ALU_AND,
        ALU_PASS_B
    } alu_op_e;

    typedef enum logic [2:0] {
        F3_MUL = 3'b000,
        F3_MULH = 3'b001,
        F3_MULHSU = 3'b010,
        F3_MULHU = 3'b011,
        F3_DIV = 3'b100,
        F3_DIVU = 3'b101,
        F3_REM = 3'b110,
        F3_REMU = 3'b111
    } muldiv_funct3_e;

    typedef enum logic [2:0] {
        F3_BEQ = 3'b000,
        F3_BNE = 3'b001,
        F3_BLT = 3'b100,
        F3_BGE = 3'b101,
        F3_BLTU = 3'b110,
        F3_BGEU = 3'b111
    } branch_funct3_e;

    typedef enum logic [2:0] {
        F3_LB = 3'b000,
        F3_LH = 3'b001,
        F3_LW = 3'b010,
        F3_LD = 3'b011,
        F3_LBU = 3'b100,
        F3_LHU = 3'b101,
        F3_LWU = 3'b110
    } load_funct3_e;

    typedef enum logic [2:0] {
        F3_SB = 3'b000,
        F3_SH = 3'b001,
        F3_SW = 3'b010,
        F3_SD = 3'b011
    } store_funct3_e;

    typedef enum logic [2:0] {
        F3_ECALL = 3'b000,
        F3_EBREAK = 3'b001,
        F3_SRET = 3'b010,
        F3_WFI = 3'b011
    } system_funct3_e;

    typedef enum logic [2:0] {
        F3_CSRRW = 3'b001,
        F3_CSRRS = 3'b010,
        F3_CSRRC = 3'b011,
        F3_CSRRWI = 3'b101,
        F3_CSRRSI = 3'b110,
        F3_CSRRCI = 3'b111
    } csr_funct3_e;

    parameter logic [11:0] CSR_TSTATUS = 12'h000;
    parameter logic [11:0] CSR_TIE = 12'h001;
    parameter logic [11:0] CSR_TIP = 12'h002;
    parameter logic [11:0] CSR_TVEC = 12'h003;
    parameter logic [11:0] CSR_TSCRATCH = 12'h004;
    parameter logic [11:0] CSR_TEPC = 12'h005;
    parameter logic [11:0] CSR_TCAUSE = 12'h006;
    parameter logic [11:0] CSR_TVAL = 12'h007;
    parameter logic [11:0] CSR_SATP = 12'h008;
    parameter logic [11:0] CSR_HARTID = 12'h009;
    parameter logic [11:0] CSR_FCSR = 12'h00A;
    parameter logic [11:0] CSR_VSTART = 12'h00B;
    parameter logic [11:0] CSR_VTYPE = 12'h00C;
    parameter logic [11:0] CSR_VL = 12'h00D;
    parameter logic [11:0] CSR_VLENB = 12'h00E;

    parameter int TSTATUS_IE_BIT = 0;
    parameter int TSTATUS_PIE_BIT = 1;
    parameter int TSTATUS_PP_BIT = 2;
    parameter int TSTATUS_FS_LO = 3;
    parameter int TSTATUS_FS_HI = 4;
    parameter int TSTATUS_VS_LO = 5;
    parameter int TSTATUS_VS_HI = 6;

    typedef enum logic [1:0] {
        FPVEC_OFF = 2'b00,
        FPVEC_CLEAN = 2'b01,
        FPVEC_DIRTY = 2'b10
    } fpvec_state_e;

    typedef enum logic [5:0] {
        CAUSE_INSTR_MISALIGNED = 6'd0,
        CAUSE_INSTR_FAULT = 6'd1,
        CAUSE_ILLEGAL_INSTR = 6'd2,
        CAUSE_BREAKPOINT = 6'd3,
        CAUSE_LOAD_MISALIGNED = 6'd4,
        CAUSE_LOAD_FAULT = 6'd5,
        CAUSE_STORE_MISALIGNED = 6'd6,
        CAUSE_STORE_FAULT = 6'd7,
        CAUSE_ECALL_U = 6'd8,
        CAUSE_ECALL_S = 6'd9,
        CAUSE_INSTR_PAGEFAULT = 6'd10,
        CAUSE_LOAD_PAGEFAULT = 6'd11,
        CAUSE_STORE_PAGEFAULT = 6'd12,
        CAUSE_FP_DISABLED = 6'd13,
        CAUSE_VEC_DISABLED = 6'd14
    } exc_cause_e;

    typedef enum logic [1:0] {
        IRQ_SOFTWARE = 2'd0,
        IRQ_TIMER = 2'd1,
        IRQ_EXTERNAL = 2'd2
    } irq_cause_e;

    typedef enum logic [2:0] {
        FU_MAIN = 3'd0,
        FU_MULDIV = 3'd1,
        FU_FPU = 3'd2,
        FU_VEC = 3'd3,
        FU_NONE = 3'd7
    } fu_tag_e;

    typedef enum logic [1:0] {
        RF_INT = 2'd0,
        RF_FP = 2'd1,
        RF_VEC = 2'd2,
        RF_NONE = 2'd3
    } regfile_e;

    typedef enum logic [2:0] {
        IMM_I,
        IMM_S,
        IMM_B,
        IMM_U,
        IMM_J,
        IMM_NONE
    } imm_sel_e;

    typedef struct packed {
        xlen_t pc;
        instr_t instr;
        logic valid;
        logic pred_taken;
        xlen_t pred_target;
        logic fault_valid;
        exc_cause_e fault_cause;
        xlen_t fault_tval;
    } if_id_t;

    typedef struct packed {
        xlen_t pc;
        logic valid;
        opcode_e opcode;
        greg_t rd, rs1, rs2;
        xlen_t rs1_data, rs2_data;
        logic reads_rs1, reads_rs2;
        xlen_t imm;
        alu_op_e alu_op;
        logic is_branch;
        branch_funct3_e branch_kind;
        logic pred_taken;
        xlen_t pred_target;
        logic is_jump;
        logic is_load, is_store;
        logic mem_unsigned;
        logic [1:0] mem_size;
        fu_tag_e fu;
        regfile_e rd_rf;
        logic fault_valid;
        exc_cause_e fault_cause;
        xlen_t fault_tval;
        logic is_csr;
        logic is_csr_write;
        logic [11:0] csr_addr;
        csr_funct3_e csr_kind;
        logic is_system;
        system_funct3_e system_kind;
    } id_ex_t;

    typedef struct packed {
        xlen_t pc;
        logic valid;
        xlen_t alu_result;
        xlen_t rs2_data;
        greg_t rd;
        logic reg_write;
        regfile_e rd_rf;
        logic is_load, is_store;
        logic mem_unsigned;
        logic [1:0] mem_size;
        fu_tag_e fu;
        logic fault_valid;
        exc_cause_e fault_cause;
        xlen_t fault_tval;
        logic is_csr;
        logic is_csr_write;
        logic [11:0] csr_addr;
        csr_funct3_e csr_kind;
        xlen_t csr_wdata;
        xlen_t next_pc;
        logic is_system;
        system_funct3_e system_kind;
    } ex_mem_t;

    typedef struct packed {
        xlen_t pc;
        logic valid;
        xlen_t result;
        greg_t rd;
        logic reg_write;
        regfile_e rd_rf;
        fu_tag_e fu;
        logic commit_fault;
        exc_cause_e fault_cause;
        xlen_t fault_tval;
        logic commit_irq;
        irq_cause_e irq_cause;
    } mem_wb_t;

endpackage : tarc_pkg
