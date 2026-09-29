import tarc_pkg::*;

module fetch #(
    parameter logic [63:0] RESET_VECTOR = 64'h0000_0000_0000_1000
) (
    input logic clk,
    input logic rst_n,

    input logic stall,
    input logic flush,

    input logic hart_wake,
    input xlen_t hart_wake_pc,
    input logic trap_redirect,
    input xlen_t trap_vector,
    input logic sret_redirect,
    input xlen_t sret_pc,
    input logic branch_redirect,
    input xlen_t branch_pc,

    input logic wfi_halt,
    input logic irq_any_pending,

    output logic imem_req,
    output xlen_t imem_addr,
    input instr_t imem_rdata,
    input logic imem_ready,
    input logic imem_fault,
    input exc_cause_e imem_fault_cause,

    output if_id_t if_id
);

    xlen_t pc_q;
    logic idle_q;

    logic pc_misaligned;
    assign pc_misaligned = (pc_q[1:0] != 2'b00);

    logic is_branch_insn;
    logic pred_taken;
    xlen_t pred_target;
    logic [12:0] b_imm_bits;

    assign is_branch_insn = (imem_rdata[5:0] == OPC_BRANCH);
    assign b_imm_bits = {imem_rdata[31:24], imem_rdata[10:6]};
    assign pred_target = pc_q + {{49{b_imm_bits[12]}}, b_imm_bits, 2'b00};
    assign pred_taken = is_branch_insn && b_imm_bits[12];

    xlen_t pc_next;
    always_comb begin
        if (hart_wake) begin
            pc_next = hart_wake_pc;
        end else if (trap_redirect) begin
            pc_next = trap_vector;
        end else if (sret_redirect) begin
            pc_next = sret_pc;
        end else if (branch_redirect) begin
            pc_next = branch_pc;
        end else if (pred_taken) begin
            pc_next = pred_target;
        end else begin
            pc_next = pc_q + 4;
        end
    end

    logic idle_next;
    always_comb begin
        if (hart_wake || trap_redirect || sret_redirect) begin
            idle_next = 1'b0;
        end else if (irq_any_pending) begin
            idle_next = 1'b0;
        end else if (wfi_halt) begin
            idle_next = 1'b1;
        end else begin
            idle_next = idle_q;
        end
    end

    assign imem_req = !idle_q && !stall;
    assign imem_addr = pc_q;

    logic fetch_valid;
    assign fetch_valid = imem_req && imem_ready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_q <= RESET_VECTOR;
            idle_q <= 1'b0;
        end else begin
            idle_q <= idle_next;
            if (hart_wake || trap_redirect || sret_redirect || branch_redirect) begin
                pc_q <= pc_next;
            end else if (!stall && !idle_q && imem_ready) begin
                pc_q <= pc_next;
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id <= '0;
        end else if (flush || hart_wake || trap_redirect || sret_redirect || branch_redirect) begin
            if_id <= '0;
        end else if (!stall) begin
            if_id.pc <= pc_q;
            if_id.instr <= imem_rdata;
            if_id.valid <= fetch_valid;
            if_id.pred_taken <= pred_taken;
            if_id.pred_target <= pred_target;
            if_id.fault_valid <= fetch_valid && (pc_misaligned || imem_fault);
            if_id.fault_cause <= pc_misaligned ? CAUSE_INSTR_MISALIGNED : imem_fault_cause;
            if_id.fault_tval <= pc_q;
        end
    end

endmodule : fetch
