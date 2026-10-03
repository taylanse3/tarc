import tarc_pkg::*;

module core #(
    parameter logic [63:0] RESET_VECTOR = 64'h0000_0000_0000_1000,
    parameter int HARTID = 0,
    parameter logic [63:0] UNCACHED_BASE = 64'h0000_0000_1000_0000
) (
    input logic clk,
    input logic rst_n,

    output logic imem_req,
    output xlen_t imem_addr,
    input xlen_t imem_rdata,
    input logic imem_ready,

    output logic dmem_req,
    output logic dmem_we,
    output xlen_t dmem_addr,
    output xlen_t dmem_wdata,
    output logic [7:0] dmem_wstrb,
    input xlen_t dmem_rdata,
    input logic dmem_ready,

    input logic irq_software,
    input logic irq_timer,
    input logic irq_external
);

    if_id_t if_id;
    id_ex_t id_ex_d, id_ex_q, id_ex_hold;
    ex_mem_t ex_mem_d, ex_mem_q;
    mem_wb_t mem_wb_d, mem_wb_q;

    logic stall_f_hz, stall_d_hz, flush_d;
    logic stall_f;
    logic branch_mispredict;
    xlen_t branch_target;
    logic mem_stall;

    logic ic_req;
    xlen_t ic_addr;
    instr_t ic_rdata;
    logic ic_ready;

    logic dc_req, dc_we;
    xlen_t dc_addr, dc_wdata, dc_rdata;
    logic [1:0] dc_size;
    logic dc_ready;

    logic trap_valid, sret_valid, wfi_valid;
    xlen_t trap_epc, trap_cause, trap_tval;
    logic trap_flush;

    assign stall_f = stall_f_hz || mem_stall;
    assign trap_flush = trap_valid || sret_valid;

    logic csr_access, csr_illegal, priv_s;
    xlen_t csr_rdata, tvec, tepc;
    logic fs_off, vs_off;
    logic irq_any_pending, irq_pending, irq_enabled;
    irq_cause_e irq_cause;

    fetch #(
        .RESET_VECTOR(RESET_VECTOR)
    ) u_fetch (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall_f),
        .flush(flush_d),
        .hart_wake(1'b0),
        .hart_wake_pc('0),
        .trap_redirect(trap_valid),
        .trap_vector(tvec),
        .sret_redirect(sret_valid),
        .sret_pc(tepc),
        .branch_redirect(branch_mispredict),
        .branch_pc(branch_target),
        .wfi_halt(wfi_valid),
        .irq_any_pending(irq_any_pending),
        .imem_req(ic_req),
        .imem_addr(ic_addr),
        .imem_rdata(ic_rdata),
        .imem_ready(ic_ready),
        .imem_fault(1'b0),
        .imem_fault_cause(CAUSE_INSTR_FAULT),
        .if_id(if_id)
    );

    icache u_icache (
        .clk(clk),
        .rst_n(rst_n),
        .req(ic_req),
        .addr(ic_addr),
        .rdata(ic_rdata),
        .ready(ic_ready),
        .mem_req(imem_req),
        .mem_addr(imem_addr),
        .mem_rdata(imem_rdata),
        .mem_ready(imem_ready)
    );

    greg_t rs1_addr, rs2_addr;
    xlen_t rs1_data_raw, rs2_data_raw;
    logic d_reads_rs1, d_reads_rs2, d_is_csr_write;
    fu_tag_e d_fu;

    logic int_we;
    greg_t int_waddr;
    xlen_t int_wdata;

    regfile_int u_regfile (
        .clk(clk),
        .rst_n(rst_n),
        .rs1_addr(rs1_addr),
        .rs1_data(rs1_data_raw),
        .rs2_addr(rs2_addr),
        .rs2_data(rs2_data_raw),
        .we(int_we),
        .rd_addr(int_waddr),
        .rd_data(int_wdata)
    );

    decode u_decode (
        .if_id(if_id),
        .fs_off(fs_off),
        .vs_off(vs_off),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rs1_data_raw(rs1_data_raw),
        .rs2_data_raw(rs2_data_raw),
        .id_ex(id_ex_d),
        .hz_reads_rs1(d_reads_rs1),
        .hz_reads_rs2(d_reads_rs2),
        .hz_fu(d_fu),
        .hz_is_csr_write(d_is_csr_write)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_ex_q <= '0;
        end else if (trap_flush) begin
            id_ex_q <= '0;
        end else if (mem_stall) begin
            id_ex_q <= id_ex_hold;
        end else if (branch_mispredict) begin
            id_ex_q <= '0;
        end else if (stall_d_hz) begin
            id_ex_q <= '0;
        end else begin
            id_ex_q <= id_ex_d;
        end
    end

    xlen_t ex_rs1_fwd, ex_rs2_fwd;
    logic ex_rs1_use_fwd, ex_rs2_use_fwd;

    always_comb begin
        id_ex_hold = id_ex_q;
        if (ex_rs1_use_fwd && id_ex_q.reads_rs1) begin
            id_ex_hold.rs1_data = ex_rs1_fwd;
        end
        if (ex_rs2_use_fwd && id_ex_q.reads_rs2) begin
            id_ex_hold.rs2_data = ex_rs2_fwd;
        end
    end

    execute u_execute (
        .id_ex(id_ex_q),
        .rs1_fwd_data(ex_rs1_fwd),
        .rs2_fwd_data(ex_rs2_fwd),
        .rs1_use_fwd(ex_rs1_use_fwd),
        .rs2_use_fwd(ex_rs2_use_fwd),
        .ex_mem(ex_mem_d),
        .branch_mispredict(branch_mispredict),
        .branch_target(branch_target)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem_q <= '0;
        end else if (trap_flush) begin
            ex_mem_q <= '0;
        end else if (mem_stall) begin
            ex_mem_q <= ex_mem_q;
        end else begin
            ex_mem_q <= ex_mem_d;
        end
    end

    memory u_memory (
        .ex_mem(ex_mem_q),
        .dmem_req(dc_req),
        .dmem_we(dc_we),
        .dmem_addr(dc_addr),
        .dmem_wdata(dc_wdata),
        .dmem_size(dc_size),
        .dmem_rdata(dc_rdata),
        .dmem_ready(dc_ready),
        .dmem_fault(1'b0),
        .dmem_fault_cause(CAUSE_LOAD_FAULT),
        .dmem_fault_tval('0),
        .csr_access(csr_access),
        .csr_illegal(csr_illegal),
        .csr_rdata(csr_rdata),
        .priv_s(priv_s),
        .irq_pending(irq_pending),
        .irq_enabled(irq_enabled),
        .irq_cause_in(irq_cause),
        .mem_wb(mem_wb_d),
        .mem_stall(mem_stall),
        .trap_valid(trap_valid),
        .trap_epc(trap_epc),
        .trap_cause(trap_cause),
        .trap_tval(trap_tval),
        .sret_valid(sret_valid),
        .wfi_valid(wfi_valid)
    );

    dcache #(
        .UNCACHED_BASE(UNCACHED_BASE)
    ) u_dcache (
        .clk(clk),
        .rst_n(rst_n),
        .req(dc_req),
        .we(dc_we),
        .addr(dc_addr),
        .wdata(dc_wdata),
        .size(dc_size),
        .rdata(dc_rdata),
        .ready(dc_ready),
        .mem_req(dmem_req),
        .mem_we(dmem_we),
        .mem_addr(dmem_addr),
        .mem_wdata(dmem_wdata),
        .mem_wstrb(dmem_wstrb),
        .mem_rdata(dmem_rdata),
        .mem_ready(dmem_ready)
    );

    csr #(
        .HARTID(HARTID)
    ) u_csr (
        .clk(clk),
        .rst_n(rst_n),
        .access_en(csr_access),
        .access_op(ex_mem_q.csr_kind),
        .access_addr(ex_mem_q.csr_addr),
        .access_wdata(ex_mem_q.csr_wdata),
        .access_do_write(ex_mem_q.is_csr_write),
        .access_rdata(csr_rdata),
        .access_illegal(csr_illegal),
        .trap_enter(trap_valid),
        .trap_epc(trap_epc),
        .trap_cause(trap_cause),
        .trap_tval(trap_tval),
        .sret_commit(sret_valid),
        .irq_software(irq_software),
        .irq_timer(irq_timer),
        .irq_external(irq_external),
        .priv_s(priv_s),
        .tvec(tvec),
        .tepc(tepc),
        .fs_off(fs_off),
        .vs_off(vs_off),
        .irq_any_pending(irq_any_pending),
        .irq_pending(irq_pending),
        .irq_enabled(irq_enabled),
        .irq_cause(irq_cause)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb_q <= '0;
        end else if (mem_stall) begin
            mem_wb_q <= '0;
        end else begin
            mem_wb_q <= mem_wb_d;
        end
    end

    logic muldiv_valid, muldiv_busy;
    greg_t muldiv_rd, muldiv_pending_rd;
    xlen_t muldiv_result;
    logic fp_we, vecrf_we;
    logic [4:0] fp_waddr, vecrf_waddr;
    xlen_t fp_wdata, vecrf_wdata;
    logic muldiv_grant, fpu_grant, vec_grant;

    muldiv u_muldiv (
        .clk(clk),
        .rst_n(rst_n),
        .id_ex(id_ex_q),
        .rs1_fwd_data(ex_rs1_fwd),
        .rs2_fwd_data(ex_rs2_fwd),
        .rs1_use_fwd(ex_rs1_use_fwd),
        .rs2_use_fwd(ex_rs2_use_fwd),
        .trap_flush(trap_flush),
        .mem_stall(mem_stall),
        .muldiv_grant(muldiv_grant),
        .muldiv_valid(muldiv_valid),
        .muldiv_rd(muldiv_rd),
        .muldiv_result(muldiv_result),
        .muldiv_busy(muldiv_busy),
        .muldiv_pending_rd(muldiv_pending_rd)
    );

    writeback u_writeback (
        .mem_wb(mem_wb_q),
        .muldiv_valid(muldiv_valid),
        .muldiv_rd(muldiv_rd),
        .muldiv_result(muldiv_result),
        .muldiv_grant(muldiv_grant),
        .fpu_valid(1'b0),
        .fpu_rd_rf(RF_NONE),
        .fpu_rd('0),
        .fpu_result('0),
        .fpu_grant(fpu_grant),
        .vec_valid(1'b0),
        .vec_rd_rf(RF_NONE),
        .vec_rd('0),
        .vec_result('0),
        .vec_grant(vec_grant),
        .int_we(int_we),
        .int_waddr(int_waddr),
        .int_wdata(int_wdata),
        .fp_we(fp_we),
        .fp_waddr(fp_waddr),
        .fp_wdata(fp_wdata),
        .vecrf_we(vecrf_we),
        .vecrf_waddr(vecrf_waddr),
        .vecrf_wdata(vecrf_wdata)
    );

    hazard_unit u_hazard (
        .ex_valid(id_ex_q.valid),
        .ex_rs1(id_ex_q.rs1),
        .ex_rs2(id_ex_q.rs2),
        .ex_reads_rs1(id_ex_q.valid && id_ex_q.reads_rs1),
        .ex_reads_rs2(id_ex_q.valid && id_ex_q.reads_rs2),
        .ex_rd(id_ex_q.rd),
        .ex_result_late(id_ex_q.is_load || id_ex_q.is_csr),
        .mem_valid(ex_mem_q.valid),
        .mem_reg_write(ex_mem_q.reg_write),
        .mem_rd_rf(ex_mem_q.rd_rf),
        .mem_rd(ex_mem_q.rd),
        .mem_alu_result(ex_mem_q.alu_result),
        .mem_result_late(ex_mem_q.is_load || ex_mem_q.is_csr),
        .wb_valid(mem_wb_q.valid),
        .wb_reg_write(mem_wb_q.reg_write),
        .wb_rd_rf(mem_wb_q.rd_rf),
        .wb_rd(mem_wb_q.rd),
        .wb_result(mem_wb_q.result),
        .muldiv_valid(muldiv_valid),
        .muldiv_rd(muldiv_rd),
        .muldiv_result(muldiv_result),
        .d_valid(if_id.valid),
        .d_rs1(rs1_addr),
        .d_rs2(rs2_addr),
        .d_reads_rs1(d_reads_rs1),
        .d_reads_rs2(d_reads_rs2),
        .d_fu(d_fu),
        .d_is_csr_write(d_is_csr_write),
        .muldiv_busy(muldiv_busy),
        .muldiv_pending_rd(muldiv_pending_rd),
        .fpu_busy(1'b0),
        .vec_busy(1'b0),
        .csr_drain_active(
            (id_ex_q.valid && id_ex_q.is_csr_write) || (ex_mem_q.valid && ex_mem_q.is_csr_write)
        ),
        .ex_branch_mispredict(branch_mispredict),
        .ex_rs1_fwd_data(ex_rs1_fwd),
        .ex_rs2_fwd_data(ex_rs2_fwd),
        .ex_rs1_use_fwd(ex_rs1_use_fwd),
        .ex_rs2_use_fwd(ex_rs2_use_fwd),
        .stall_f(stall_f_hz),
        .stall_d(stall_d_hz),
        .flush_d(flush_d)
    );

endmodule : core
