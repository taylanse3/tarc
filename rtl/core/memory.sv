import tarc_pkg::*;

module memory (
    input ex_mem_t ex_mem,

    output logic dmem_req,
    output logic dmem_we,
    output xlen_t dmem_addr,
    output xlen_t dmem_wdata,
    output logic [1:0] dmem_size,
    input xlen_t dmem_rdata,
    input logic dmem_ready,
    input logic dmem_fault,
    input exc_cause_e dmem_fault_cause,
    input xlen_t dmem_fault_tval,

    output logic csr_access,
    input logic csr_illegal,
    input xlen_t csr_rdata,
    input logic priv_s,

    input logic irq_pending,
    input logic irq_enabled,
    input irq_cause_e irq_cause_in,

    output mem_wb_t mem_wb,
    output logic mem_stall,

    output logic trap_valid,
    output xlen_t trap_epc,
    output xlen_t trap_cause,
    output xlen_t trap_tval,
    output logic sret_valid,
    output logic wfi_valid
);

    logic mem_op;
    assign mem_op = ex_mem.valid && (ex_mem.is_load || ex_mem.is_store);

    logic misaligned;
    always_comb begin
        unique case (ex_mem.mem_size)
            2'b00: misaligned = 1'b0;
            2'b01: misaligned = ex_mem.alu_result[0];
            2'b10: misaligned = |ex_mem.alu_result[1:0];
            2'b11: misaligned = |ex_mem.alu_result[2:0];
            default: misaligned = 1'b0;
        endcase
    end

    assign dmem_req = mem_op && !ex_mem.fault_valid && !misaligned;
    assign dmem_we = ex_mem.is_store;
    assign dmem_addr = ex_mem.alu_result;
    assign dmem_wdata = ex_mem.rs2_data;
    assign dmem_size = ex_mem.mem_size;

    assign mem_stall = dmem_req && !dmem_ready && !dmem_fault;

    logic sys_op;
    assign sys_op = ex_mem.valid && ex_mem.is_system && !ex_mem.fault_valid;

    logic is_ecall, is_ebreak, is_sret, is_wfi;
    assign is_ecall = sys_op && (ex_mem.system_kind == F3_ECALL);
    assign is_ebreak = sys_op && (ex_mem.system_kind == F3_EBREAK);
    assign is_sret = sys_op && (ex_mem.system_kind == F3_SRET);
    assign is_wfi = sys_op && (ex_mem.system_kind == F3_WFI);

    assign csr_access = ex_mem.valid && ex_mem.is_csr && !ex_mem.fault_valid;

    logic fault_commit;
    exc_cause_e fault_cause_commit;
    xlen_t fault_tval_commit;

    always_comb begin
        fault_commit = 1'b1;
        fault_cause_commit = exc_cause_e'('0);
        fault_tval_commit = '0;
        if (ex_mem.fault_valid) begin
            fault_cause_commit = ex_mem.fault_cause;
            fault_tval_commit = ex_mem.fault_tval;
        end else if (is_ebreak) begin
            fault_cause_commit = CAUSE_BREAKPOINT;
        end else if (is_ecall) begin
            fault_cause_commit = priv_s ? CAUSE_ECALL_S : CAUSE_ECALL_U;
        end else if ((is_sret && !priv_s) || csr_illegal) begin
            fault_cause_commit = CAUSE_ILLEGAL_INSTR;
        end else if (mem_op && misaligned) begin
            fault_cause_commit = ex_mem.is_store ? CAUSE_STORE_MISALIGNED : CAUSE_LOAD_MISALIGNED;
            fault_tval_commit = ex_mem.alu_result;
        end else if (dmem_req && dmem_fault) begin
            fault_cause_commit = dmem_fault_cause;
            fault_tval_commit = dmem_fault_tval;
        end else begin
            fault_commit = 1'b0;
        end
    end

    xlen_t load_result;
    always_comb begin
        unique case (ex_mem.mem_size)
            2'b00: load_result = ex_mem.mem_unsigned
                ? {56'b0, dmem_rdata[7:0]}
                : {{56{dmem_rdata[7]}}, dmem_rdata[7:0]};
            2'b01: load_result = ex_mem.mem_unsigned
                ? {48'b0, dmem_rdata[15:0]}
                : {{48{dmem_rdata[15]}}, dmem_rdata[15:0]};
            2'b10: load_result = ex_mem.mem_unsigned
                ? {32'b0, dmem_rdata[31:0]}
                : {{32{dmem_rdata[31]}}, dmem_rdata[31:0]};
            2'b11: load_result = dmem_rdata;
            default: load_result = dmem_rdata;
        endcase
    end

    logic csr_write_op;
    assign csr_write_op = csr_access && ex_mem.is_csr_write;

    logic irq_commit;
    assign irq_commit = ex_mem.valid && !fault_commit && !mem_stall
        && irq_pending && irq_enabled && !csr_write_op && !is_sret;

    assign trap_valid = fault_commit || irq_commit;
    assign trap_epc = irq_commit ? ex_mem.next_pc : ex_mem.pc;
    assign trap_cause = irq_commit ? {1'b1, 61'b0, irq_cause_in} : {58'b0, fault_cause_commit};
    assign trap_tval = irq_commit ? '0 : fault_tval_commit;
    assign sret_valid = is_sret && priv_s;
    assign wfi_valid = is_wfi;

    xlen_t mem_result;
    assign mem_result =
        ex_mem.is_load ? load_result :
        ex_mem.is_csr ? csr_rdata :
        ex_mem.alu_result;

    always_comb begin
        mem_wb = '0;
        mem_wb.pc = ex_mem.pc;
        mem_wb.valid = ex_mem.valid && !mem_stall;
        mem_wb.result = mem_result;
        mem_wb.rd = ex_mem.rd;
        mem_wb.rd_rf = ex_mem.rd_rf;
        mem_wb.reg_write = ex_mem.reg_write && !fault_commit;
        mem_wb.fu = ex_mem.fu;

        mem_wb.commit_fault = fault_commit;
        mem_wb.fault_cause = fault_cause_commit;
        mem_wb.fault_tval = fault_tval_commit;

        mem_wb.commit_irq = irq_commit;
        mem_wb.irq_cause = irq_cause_in;
    end

endmodule : memory
