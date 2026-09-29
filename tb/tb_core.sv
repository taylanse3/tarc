import tarc_pkg::*;

module tb_core;

    logic clk = 0;
    logic rst_n = 0;

    always #5 clk = ~clk;

    logic imem_req;
    xlen_t imem_addr;
    instr_t imem_rdata;
    logic imem_ready;

    logic dmem_req, dmem_we;
    xlen_t dmem_addr, dmem_wdata, dmem_rdata;
    logic [1:0] dmem_size;
    logic dmem_ready;

    logic [2:0] irq_set = 3'b000;
    logic [2:0] irq_level = 3'b000;
    logic [2:0] irq_clear;
    logic slow_mem = 1'b0;
    logic dmem_wait_q = 1'b0;

    localparam logic [63:0] RESET_PC = 64'h0000_0000_0000_0000;
    localparam logic [63:0] ACK_ADDR = 64'h0000_0000_1000_0000;
    localparam logic [63:0] IRQ_BIT = 64'h8000_0000_0000_0000;
    localparam logic [63:0] EPC_DEFAULT = 64'hFFFF_FFFF_FFFF_FFFF;
    localparam logic [63:0] TS_U = 64'h0;
    localparam logic [63:0] TS_S = 64'h4;
    localparam logic [63:0] TS_S_IE = 64'h6;

    core #(
        .RESET_VECTOR(RESET_PC),
        .HARTID(3)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .imem_req(imem_req),
        .imem_addr(imem_addr),
        .imem_rdata(imem_rdata),
        .imem_ready(imem_ready),
        .dmem_req(dmem_req),
        .dmem_we(dmem_we),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_size(dmem_size),
        .dmem_rdata(dmem_rdata),
        .dmem_ready(dmem_ready),
        .irq_software(irq_level[0]),
        .irq_timer(irq_level[1]),
        .irq_external(irq_level[2])
    );

    instr_t imem [0:1023];
    xlen_t dmem [0:1023];

    assign imem_rdata = imem[imem_addr[11:2]];
    assign imem_ready = 1'b1;
    assign dmem_rdata = dmem[dmem_addr[12:3]];

    always_ff @(posedge clk) begin
        dmem_wait_q <= slow_mem && dmem_req && !dmem_we && !dmem_wait_q;
    end

    assign dmem_ready = !(slow_mem && dmem_req && !dmem_we) || dmem_wait_q;

    assign irq_clear = (dmem_req && dmem_we && dmem_addr == ACK_ADDR) ? dmem_wdata[2:0] : 3'b000;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            irq_level <= 3'b000;
        end else begin
            irq_level <= (irq_level | irq_set) & ~irq_clear;
        end
    end

    always_ff @(posedge clk) begin
        if (dmem_req && dmem_we && dmem_addr != ACK_ADDR) begin
            dmem[dmem_addr[12:3]] <= dmem_wdata;
        end
    end

    function automatic instr_t r_type(
        logic [5:0] opc,
        logic [4:0] rd,
        logic [2:0] f3,
        logic [4:0] rs1,
        logic [4:0] rs2,
        logic [7:0] rem
    );
        return {rem, rs2, rs1, f3, rd, opc};
    endfunction

    function automatic instr_t i_type(
        logic [5:0] opc,
        logic [4:0] rd,
        logic [2:0] f3,
        logic [4:0] rs1,
        logic [12:0] imm
    );
        return {imm, rs1, f3, rd, opc};
    endfunction

    function automatic instr_t s_type(
        logic [5:0] opc,
        logic [2:0] f3,
        logic [4:0] rs1,
        logic [4:0] rs2,
        logic [12:0] imm
    );
        return {imm[12:5], rs2, rs1, f3, imm[4:0], opc};
    endfunction

    function automatic instr_t b_type(
        logic [5:0] opc,
        logic [2:0] f3,
        logic [4:0] rs1,
        logic [4:0] rs2,
        logic [12:0] imm_scaled
    );
        return {imm_scaled[12:5], rs2, rs1, f3, imm_scaled[4:0], opc};
    endfunction

    function automatic instr_t u_type(
        logic [5:0] opc,
        logic [4:0] rd,
        logic [20:0] imm
    );
        return {imm, rd, opc};
    endfunction

    localparam logic [4:0] ZERO = 5'd0;
    localparam logic [4:0] A0 = 5'd6;
    localparam logic [4:0] A1 = 5'd7;
    localparam logic [4:0] A2 = 5'd8;
    localparam logic [4:0] A3 = 5'd9;
    localparam logic [4:0] A4 = 5'd10;
    localparam logic [4:0] A5 = 5'd11;
    localparam logic [4:0] A6 = 5'd12;
    localparam logic [4:0] A7 = 5'd13;
    localparam logic [4:0] T0 = 5'd14;
    localparam logic [4:0] T1 = 5'd15;
    localparam logic [4:0] T2 = 5'd16;
    localparam logic [4:0] T3 = 5'd17;
    localparam logic [4:0] T4 = 5'd18;
    localparam logic [4:0] T5 = 5'd19;
    localparam logic [4:0] T6 = 5'd20;
    localparam logic [4:0] T7 = 5'd21;
    localparam logic [4:0] S1 = 5'd22;
    localparam logic [4:0] S2 = 5'd23;
    localparam logic [4:0] S3 = 5'd24;
    localparam logic [4:0] S4 = 5'd25;
    localparam logic [4:0] S5 = 5'd26;
    localparam logic [4:0] S6 = 5'd27;
    localparam logic [4:0] S7 = 5'd28;
    localparam logic [4:0] S8 = 5'd29;
    localparam logic [4:0] S9 = 5'd30;
    localparam logic [4:0] S10 = 5'd31;

    function automatic instr_t addi(logic [4:0] rd, logic [4:0] rs1, logic [12:0] imm);
        return i_type(OPC_OP_IMM, rd, 3'b000, rs1, imm);
    endfunction

    function automatic instr_t nop();
        return addi(ZERO, ZERO, 13'd0);
    endfunction

    function automatic instr_t sll(logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
        return r_type(OPC_OP, rd, 3'b001, rs1, rs2, 8'h00);
    endfunction

    function automatic instr_t slli(logic [4:0] rd, logic [4:0] rs1, logic [5:0] shamt);
        return i_type(OPC_OP_IMM, rd, 3'b001, rs1, 13'(shamt));
    endfunction

    function automatic instr_t muldiv_op(logic [2:0] f3, logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
        return r_type(OPC_OP_M, rd, f3, rs1, rs2, 8'h00);
    endfunction

    function automatic instr_t mul(logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
        return muldiv_op(F3_MUL, rd, rs1, rs2);
    endfunction

    function automatic instr_t mulh(logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
        return muldiv_op(F3_MULH, rd, rs1, rs2);
    endfunction

    function automatic instr_t mulhsu(logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
        return muldiv_op(F3_MULHSU, rd, rs1, rs2);
    endfunction

    function automatic instr_t mulhu(logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
        return muldiv_op(F3_MULHU, rd, rs1, rs2);
    endfunction

    function automatic instr_t div(logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
        return muldiv_op(F3_DIV, rd, rs1, rs2);
    endfunction

    function automatic instr_t divu(logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
        return muldiv_op(F3_DIVU, rd, rs1, rs2);
    endfunction

    function automatic instr_t rem_(logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
        return muldiv_op(F3_REM, rd, rs1, rs2);
    endfunction

    function automatic instr_t remu(logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
        return muldiv_op(F3_REMU, rd, rs1, rs2);
    endfunction

    function automatic instr_t lui(logic [4:0] rd, logic [20:0] imm);
        return u_type(OPC_LUI, rd, imm);
    endfunction

    function automatic instr_t ld(logic [4:0] rd, logic [4:0] rs1, logic [12:0] imm);
        return i_type(OPC_LOAD, rd, 3'b011, rs1, imm);
    endfunction

    function automatic instr_t lw(logic [4:0] rd, logic [4:0] rs1, logic [12:0] imm);
        return i_type(OPC_LOAD, rd, 3'b010, rs1, imm);
    endfunction

    function automatic instr_t lh(logic [4:0] rd, logic [4:0] rs1, logic [12:0] imm);
        return i_type(OPC_LOAD, rd, 3'b001, rs1, imm);
    endfunction

    function automatic instr_t sd(logic [4:0] rs1, logic [4:0] rs2, logic [12:0] imm);
        return s_type(OPC_STORE, 3'b011, rs1, rs2, imm);
    endfunction

    function automatic instr_t sw(logic [4:0] rs1, logic [4:0] rs2, logic [12:0] imm);
        return s_type(OPC_STORE, 3'b010, rs1, rs2, imm);
    endfunction

    function automatic instr_t sh(logic [4:0] rs1, logic [4:0] rs2, logic [12:0] imm);
        return s_type(OPC_STORE, 3'b001, rs1, rs2, imm);
    endfunction

    function automatic instr_t jal(logic [4:0] rd, int offset);
        return u_type(OPC_JAL, rd, 21'(offset / 4));
    endfunction

    function automatic instr_t jalr(logic [4:0] rd, logic [4:0] rs1, logic [12:0] imm);
        return i_type(OPC_JALR, rd, 3'b000, rs1, imm);
    endfunction

    function automatic instr_t beq(logic [4:0] rs1, logic [4:0] rs2, int offset);
        return b_type(OPC_BRANCH, 3'b000, rs1, rs2, 13'(offset / 4));
    endfunction

    function automatic instr_t csr_op(
        logic [2:0] f3,
        logic [4:0] rd,
        logic [11:0] csr,
        logic [4:0] rs1
    );
        return i_type(OPC_CSR, rd, f3, rs1, {1'b0, csr});
    endfunction

    function automatic instr_t csrrw(logic [4:0] rd, logic [11:0] csr, logic [4:0] rs1);
        return csr_op(F3_CSRRW, rd, csr, rs1);
    endfunction

    function automatic instr_t csrrs(logic [4:0] rd, logic [11:0] csr, logic [4:0] rs1);
        return csr_op(F3_CSRRS, rd, csr, rs1);
    endfunction

    function automatic instr_t csrrwi(logic [4:0] rd, logic [11:0] csr, logic [4:0] uimm);
        return csr_op(F3_CSRRWI, rd, csr, uimm);
    endfunction

    function automatic instr_t csrrsi(logic [4:0] rd, logic [11:0] csr, logic [4:0] uimm);
        return csr_op(F3_CSRRSI, rd, csr, uimm);
    endfunction

    function automatic instr_t csrrci(logic [4:0] rd, logic [11:0] csr, logic [4:0] uimm);
        return csr_op(F3_CSRRCI, rd, csr, uimm);
    endfunction

    function automatic instr_t ecall();
        return i_type(OPC_SYSTEM, ZERO, F3_ECALL, ZERO, 13'd0);
    endfunction

    function automatic instr_t ebreak();
        return i_type(OPC_SYSTEM, ZERO, F3_EBREAK, ZERO, 13'd0);
    endfunction

    function automatic instr_t sret();
        return i_type(OPC_SYSTEM, ZERO, F3_SRET, ZERO, 13'd0);
    endfunction

    function automatic instr_t wfi();
        return i_type(OPC_SYSTEM, ZERO, F3_WFI, ZERO, 13'd0);
    endfunction

    int errors = 0;

    task automatic check(
        string name,
        xlen_t got,
        xlen_t expected
    );
        if (got !== expected) begin
            $display(
                "  [FAIL] %-34s got=%0d (0x%h) expected=%0d (0x%h)",
                name, $signed(got), got, $signed(expected), expected
            );
            errors++;
        end else begin
            $display("  [ OK ] %-34s = %0d", name, $signed(got));
        end
    endtask

    function automatic xlen_t gpr(int idx);
        return (idx == 0) ? 64'd0 : dut.u_regfile.regs[idx];
    endfunction

    int wp;
    int n_exp;
    xlen_t exp_cause [0:31];
    xlen_t exp_epc [0:31];
    xlen_t exp_tval [0:31];
    xlen_t exp_tstatus [0:31];

    task automatic emit(instr_t w);
        imem[wp] = w;
        wp++;
    endtask

    task automatic org(int byte_addr);
        wp = byte_addr / 4;
    endtask

    task automatic expect_trap(xlen_t cause, xlen_t epc, xlen_t tval, xlen_t tstatus);
        exp_cause[n_exp] = cause;
        exp_epc[n_exp] = epc;
        exp_tval[n_exp] = tval;
        exp_tstatus[n_exp] = tstatus;
        n_exp++;
    endtask

    task automatic emit_fault_full(
        instr_t w,
        xlen_t cause,
        xlen_t epc,
        xlen_t tval,
        xlen_t tstatus
    );
        emit(addi(S8, ZERO, 13'((wp + 2) * 4)));
        expect_trap(cause, (epc == EPC_DEFAULT) ? xlen_t'(wp * 4) : epc, tval, tstatus);
        emit(w);
    endtask

    task automatic emit_fault(instr_t w, xlen_t cause, xlen_t tstatus);
        emit_fault_full(w, cause, EPC_DEFAULT, 64'd0, tstatus);
    endtask

    task automatic emit_halt();
        emit(jal(ZERO, 0));
    endtask

    task automatic emit_init(bit with_ack);
        emit(addi(T0, ZERO, 13'h400));
        emit(csrrw(ZERO, CSR_TVEC, T0));
        emit(addi(S9, ZERO, 13'h200));
        if (with_ack) begin
            emit(lui(S8, 21'd32768));
        end
    endtask

    task automatic emit_log_record();
        emit(csrrs(T0, CSR_TCAUSE, ZERO));
        emit(sd(S9, T0, 13'd0));
        emit(csrrs(T0, CSR_TEPC, ZERO));
        emit(sd(S9, T0, 13'd8));
        emit(csrrs(T0, CSR_TVAL, ZERO));
        emit(sd(S9, T0, 13'd16));
        emit(csrrs(T0, CSR_TSTATUS, ZERO));
        emit(sd(S9, T0, 13'd24));
        emit(addi(S9, S9, 13'd32));
    endtask

    task automatic load_exc_handler();
        org(16'h400);
        emit_log_record();
        emit(csrrw(ZERO, CSR_TEPC, S8));
        emit(sret());
    endtask

    task automatic load_irq_handler();
        org(16'h400);
        emit(sd(S9, S1, 13'h400));
        emit_log_record();
        emit(csrrs(T0, CSR_TCAUSE, ZERO));
        emit(addi(T1, ZERO, 13'd1));
        emit(sll(T1, T1, T0));
        emit(sd(S8, T1, 13'd0));
        emit(sret());
    endtask

    task automatic begin_test();
        @(negedge clk);
        rst_n = 0;
        repeat (2) @(negedge clk);
        for (int i = 0; i < 1024; i++) begin
            imem[i] = nop();
            dmem[i] = '0;
        end
        wp = 0;
        n_exp = 0;
        slow_mem = 1'b0;
    endtask

    task automatic release_reset();
        @(negedge clk);
        rst_n = 1;
    endtask

    task automatic run(int cycles);
        release_reset();
        repeat (cycles) @(posedge clk);
    endtask

    task automatic raise_irq(logic [2:0] mask);
        @(negedge clk);
        irq_set = mask;
        @(negedge clk);
        irq_set = 3'b000;
    endtask

    task automatic check_trap_log();
        check("trap count (log pointer)", gpr(S9), 64'd512 + 64'd32 * n_exp);
        for (int i = 0; i < n_exp; i++) begin
            check($sformatf("trap[%0d].cause", i), dmem[64 + 4 * i], exp_cause[i]);
            check($sformatf("trap[%0d].epc", i), dmem[64 + 4 * i + 1], exp_epc[i]);
            check($sformatf("trap[%0d].tval", i), dmem[64 + 4 * i + 2], exp_tval[i]);
            check($sformatf("trap[%0d].tstatus", i), dmem[64 + 4 * i + 3], exp_tstatus[i]);
        end
    endtask

    task automatic test_csr_access();
        $display("Test 8 -- CSR access, WARL fields, CSR-result forwarding:");
        begin_test();
        emit(addi(T0, ZERO, 13'h123));
        emit(csrrw(A0, CSR_TSCRATCH, T0));
        emit(csrrs(A1, CSR_TSCRATCH, ZERO));
        emit(addi(A2, A1, 13'd1));
        emit(csrrsi(A3, CSR_TSCRATCH, 5'd28));
        emit(csrrci(A4, CSR_TSCRATCH, 5'd15));
        emit(csrrs(A5, CSR_TSCRATCH, ZERO));
        emit(csrrwi(A6, CSR_TSCRATCH, 5'd21));
        emit(csrrs(A7, CSR_TSCRATCH, ZERO));
        emit(csrrs(S1, CSR_HARTID, ZERO));
        emit(csrrs(S2, CSR_VLENB, ZERO));
        emit(addi(T1, ZERO, 13'h403));
        emit(csrrw(ZERO, CSR_TVEC, T1));
        emit(csrrs(S3, CSR_TVEC, ZERO));
        emit(csrrwi(ZERO, CSR_TIE, 5'd5));
        emit(csrrs(S4, CSR_TIE, ZERO));
        emit(csrrsi(ZERO, CSR_TSTATUS, 5'd1));
        emit(csrrs(S5, CSR_TSTATUS, ZERO));
        emit(csrrsi(ZERO, CSR_TSTATUS, 5'd8));
        emit(csrrs(S6, CSR_TSTATUS, ZERO));
        emit(csrrsi(ZERO, CSR_TSTATUS, 5'd24));
        emit(csrrs(S7, CSR_TSTATUS, ZERO));
        emit(csrrwi(ZERO, CSR_FCSR, 5'd29));
        emit(csrrs(S8, CSR_FCSR, ZERO));
        emit(csrrwi(ZERO, CSR_FCSR, 5'd10));
        emit(csrrs(S9, CSR_FCSR, ZERO));
        emit(addi(T2, ZERO, 13'd1));
        emit(csrrw(ZERO, CSR_SATP, T2));
        emit(csrrs(S10, CSR_SATP, ZERO));
        emit(addi(T3, ZERO, 13'd2));
        emit(csrrw(ZERO, CSR_SATP, T3));
        emit(csrrs(T4, CSR_SATP, ZERO));
        emit(csrrs(T5, CSR_VTYPE, ZERO));
        emit(csrrs(T6, CSR_VL, ZERO));
        emit(csrrs(T7, CSR_TCAUSE, ZERO));
        run(400);
        check("csrrw old value = 0", gpr(6), 64'h0);
        check("csrrs read-only = 0x123", gpr(7), 64'h123);
        check("consumer of CSR read = 0x124", gpr(8), 64'h124);
        check("csrrsi old = 0x123", gpr(9), 64'h123);
        check("csrrci old = 0x13F", gpr(10), 64'h13F);
        check("after csrrci = 0x130", gpr(11), 64'h130);
        check("csrrwi old = 0x130", gpr(12), 64'h130);
        check("after csrrwi = 21", gpr(13), 64'd21);
        check("hartid = 3", gpr(22), 64'd3);
        check("vlenb = 16", gpr(23), 64'd16);
        check("tvec low bits forced to zero", gpr(24), 64'h400);
        check("tie = 5", gpr(25), 64'd5);
        check("tstatus.IE set", gpr(26), 64'h1);
        check("tstatus.FS = Clean", gpr(27), 64'h9);
        check("tstatus.FS = 11 write ignored", gpr(28), 64'h9);
        check("fcsr: invalid rm ignored, flags kept", gpr(29), 64'h18);
        check("fcsr: valid rm and flags", gpr(30), 64'h0A);
        check("satp mode 1 accepted", gpr(31), 64'd1);
        check("satp mode 2 write ignored", gpr(18), 64'd1);
        check("vtype reads 0", gpr(19), 64'd0);
        check("vl reads 0", gpr(20), 64'd0);
        check("tcause reads 0 at reset", gpr(21), 64'd0);
    endtask

    task automatic test_illegal_and_system();
        $display("Test 9 -- illegal instructions, RO CSRs, ECALL/EBREAK in S-mode:");
        begin_test();
        emit_init(0);
        emit_fault(csrrw(ZERO, CSR_HARTID, ZERO), CAUSE_ILLEGAL_INSTR, TS_S);
        emit(csrrs(S2, CSR_HARTID, ZERO));
        emit_fault(csrrw(ZERO, 12'h00F, ZERO), CAUSE_ILLEGAL_INSTR, TS_S);
        emit_fault(csrrs(ZERO, 12'h123, ZERO), CAUSE_ILLEGAL_INSTR, TS_S);
        emit(csrrs(ZERO, CSR_VLENB, ZERO));
        emit_fault(csrrsi(ZERO, CSR_VLENB, 5'd1), CAUSE_ILLEGAL_INSTR, TS_S);
        emit_fault(s_type(OPC_STORE, 3'b100, ZERO, ZERO, 13'd0), CAUSE_ILLEGAL_INSTR, TS_S);
        emit_fault(b_type(OPC_BRANCH, 3'b010, ZERO, ZERO, 13'd2), CAUSE_ILLEGAL_INSTR, TS_S);
        emit_fault(i_type(OPC_LOAD, T0, 3'b111, ZERO, 13'd0), CAUSE_ILLEGAL_INSTR, TS_S);
        emit_fault(i_type(OPC_JALR, ZERO, 3'b001, ZERO, 13'd0), CAUSE_ILLEGAL_INSTR, TS_S);
        emit_fault(instr_t'(32'h0000003F), CAUSE_ILLEGAL_INSTR, TS_S);
        emit_fault(i_type(OPC_OP_IMM, T0, 3'b001, ZERO, 13'h0801), CAUSE_ILLEGAL_INSTR, TS_S);
        emit_fault(i_type(OPC_OP_IMM, T0, 3'b101, ZERO, 13'h1001), CAUSE_ILLEGAL_INSTR, TS_S);
        emit_fault(i_type(OPC_SYSTEM, ZERO, 3'b100, ZERO, 13'd0), CAUSE_ILLEGAL_INSTR, TS_S);
        emit_fault(i_type(OPC_SYSTEM, 5'd1, 3'b000, ZERO, 13'd0), CAUSE_ILLEGAL_INSTR, TS_S);
        emit_fault(i_type(OPC_CSR, T0, 3'b000, ZERO, 13'h004), CAUSE_ILLEGAL_INSTR, TS_S);
        emit_fault(i_type(OPC_CSR, T0, 3'b010, ZERO, 13'h1004), CAUSE_ILLEGAL_INSTR, TS_S);
        emit_fault(i_type(OPC_FENCE, ZERO, 3'b001, ZERO, 13'd0), CAUSE_ILLEGAL_INSTR, TS_S);
        emit_fault(i_type(OPC_FENCE, ZERO, 3'b000, ZERO, 13'h0100), CAUSE_ILLEGAL_INSTR, TS_S);
        emit_fault(ecall(), CAUSE_ECALL_S, TS_S);
        emit_fault(ebreak(), CAUSE_BREAKPOINT, TS_S);
        emit(addi(S5, S5, 13'd1));
        emit(addi(S5, S5, 13'd1));
        emit(i_type(OPC_FENCE, ZERO, 3'b000, ZERO, 13'h0FF));
        emit(addi(S4, ZERO, 13'h55));
        emit_halt();
        load_exc_handler();
        run(2500);
        check("legal RO read executed (hartid)", gpr(23), 64'd3);
        check("end marker reached", gpr(25), 64'h55);
        check("younger instrs squashed exactly once (s5 = 2)", gpr(26), 64'd2);
        check_trap_log();
    endtask

    task automatic test_user_mode();
        $display("Test 10 -- User mode: privilege checks, SRET/ECALL/EBREAK:");
        begin_test();
        emit_init(0);
        emit(addi(T0, ZERO, 13'h100));
        emit(csrrw(ZERO, CSR_TEPC, T0));
        emit(sret());
        org(16'h100);
        emit(addi(S1, ZERO, 13'd7));
        emit_fault(csrrs(A0, CSR_TSCRATCH, ZERO), CAUSE_ILLEGAL_INSTR, TS_U);
        emit(csrrs(A1, CSR_FCSR, ZERO));
        emit(csrrs(A2, CSR_VLENB, ZERO));
        emit(csrrwi(ZERO, CSR_FCSR, 5'd10));
        emit(csrrs(A3, CSR_FCSR, ZERO));
        emit_fault(ecall(), CAUSE_ECALL_U, TS_U);
        emit_fault(ebreak(), CAUSE_BREAKPOINT, TS_U);
        emit_fault(sret(), CAUSE_ILLEGAL_INSTR, TS_U);
        emit(addi(S2, ZERO, 13'd9));
        emit_halt();
        load_exc_handler();
        run(1200);
        check("user code started (s1 = 7)", gpr(22), 64'd7);
        check("S-only CSR read trapped (a0 = 0)", gpr(6), 64'd0);
        check("fcsr readable from U (a1)", gpr(7), 64'd0);
        check("vlenb readable from U (a2)", gpr(8), 64'd16);
        check("fcsr writable from U (a3)", gpr(9), 64'h0A);
        check("user code completed (s2 = 9)", gpr(23), 64'd9);
        check_trap_log();
    endtask

    task automatic test_misaligned();
        $display("Test 11 -- misaligned loads/stores/fetch:");
        begin_test();
        emit_init(0);
        emit(addi(A4, ZERO, 13'h77));
        emit_fault_full(ld(A0, ZERO, 13'd4), CAUSE_LOAD_MISALIGNED, EPC_DEFAULT, 64'd4, TS_S);
        emit_fault_full(sd(ZERO, A4, 13'd12), CAUSE_STORE_MISALIGNED, EPC_DEFAULT, 64'd12, TS_S);
        emit_fault_full(lw(A1, ZERO, 13'd2), CAUSE_LOAD_MISALIGNED, EPC_DEFAULT, 64'd2, TS_S);
        emit_fault_full(lh(A2, ZERO, 13'd1), CAUSE_LOAD_MISALIGNED, EPC_DEFAULT, 64'd1, TS_S);
        emit_fault_full(sw(ZERO, A4, 13'd6), CAUSE_STORE_MISALIGNED, EPC_DEFAULT, 64'd6, TS_S);
        emit_fault_full(sh(ZERO, A4, 13'd3), CAUSE_STORE_MISALIGNED, EPC_DEFAULT, 64'd3, TS_S);
        emit(sd(ZERO, A4, 13'd16));
        emit(ld(A3, ZERO, 13'd16));
        emit(addi(T1, ZERO, 13'h102));
        emit_fault_full(jalr(ZERO, T1, 13'd0), CAUSE_INSTR_MISALIGNED, 64'h102, 64'h102, TS_S);
        emit(addi(S4, ZERO, 13'h55));
        emit_halt();
        load_exc_handler();
        run(1200);
        check("faulting loads wrote nothing (a0)", gpr(6), 64'd0);
        check("faulting loads wrote nothing (a1)", gpr(7), 64'd0);
        check("faulting loads wrote nothing (a2)", gpr(8), 64'd0);
        check("misaligned stores did not write dmem[0]", dmem[0], 64'd0);
        check("misaligned stores did not write dmem[1]", dmem[1], 64'd0);
        check("aligned store still works", dmem[2], 64'h77);
        check("aligned load still works", gpr(9), 64'h77);
        check("end marker reached", gpr(25), 64'h55);
        check_trap_log();
    endtask

    task automatic test_fp_vec_disabled();
        $display("Test 12 -- FP/vector disabled exceptions:");
        begin_test();
        emit_init(0);
        emit_fault(r_type(OPC_FOP, ZERO, 3'b000, ZERO, ZERO, 8'h01), CAUSE_FP_DISABLED, TS_S);
        emit_fault(i_type(OPC_FLOAD, ZERO, 3'b001, ZERO, 13'd0), CAUSE_FP_DISABLED, TS_S);
        emit_fault(r_type(OPC_VIOP, 5'd1, 3'b000, 5'd2, 5'd3, 8'h01), CAUSE_VEC_DISABLED, TS_S);
        emit_fault(i_type(OPC_VCFG, A0, 3'b000, A1, 13'd0), CAUSE_VEC_DISABLED, TS_S);
        emit(csrrsi(ZERO, CSR_TSTATUS, 5'd8));
        emit(r_type(OPC_FOP, ZERO, 3'b000, ZERO, ZERO, 8'h01));
        emit(addi(T0, ZERO, 13'd32));
        emit(csrrs(ZERO, CSR_TSTATUS, T0));
        emit(r_type(OPC_VIOP, 5'd1, 3'b000, 5'd2, 5'd3, 8'h01));
        emit(csrrs(S3, CSR_TSTATUS, ZERO));
        emit(addi(S4, ZERO, 13'h55));
        emit_halt();
        load_exc_handler();
        run(1000);
        check("FS=Clean, VS=Clean, PP=S", gpr(24), 64'h2C);
        check("no trap once enabled (marker)", gpr(25), 64'h55);
        check_trap_log();
    endtask

    task automatic test_irq_masked_then_enabled();
        int s1_a;
        $display("Test 13 -- interrupt masked by IE, then taken:");
        begin_test();
        emit_init(1);
        emit(csrrwi(ZERO, CSR_TIE, 5'd2));
        emit(ld(T0, ZERO, 13'h80));
        emit(beq(T0, ZERO, -4));
        emit(csrrsi(ZERO, CSR_TSTATUS, 5'd1));
        expect_trap(IRQ_BIT | 64'd1, xlen_t'((wp + 1) * 4), 64'd0, TS_S_IE);
        emit(addi(S1, S1, 13'd1));
        emit(jal(ZERO, -4));
        load_irq_handler();
        release_reset();
        repeat (80) @(posedge clk);
        raise_irq(3'b010);
        repeat (80) @(posedge clk);
        check("no trap while IE = 0", gpr(S9), 64'd512);
        check("still polling (s1 = 0)", gpr(S1), 64'd0);
        dmem[16] = 64'd1;
        repeat (150) @(posedge clk);
        s1_a = int'(gpr(S1));
        repeat (60) @(posedge clk);
        check("program resumed after SRET", (gpr(S1) > xlen_t'(s1_a)) ? 64'd1 : 64'd0, 64'd1);
        check("irq source acknowledged", xlen_t'(irq_level), 64'd0);
        check_trap_log();
    endtask

    task automatic test_irq_priority();
        int loop_addr;
        $display("Test 14 -- interrupt priority (external > software > timer):");
        begin_test();
        emit_init(1);
        emit(csrrwi(ZERO, CSR_TIE, 5'd7));
        emit(csrrsi(ZERO, CSR_TSTATUS, 5'd1));
        loop_addr = wp * 4;
        emit(addi(S1, S1, 13'd1));
        emit(jal(ZERO, -4));
        expect_trap(IRQ_BIT | 64'd2, xlen_t'(loop_addr + 4), 64'd0, TS_S_IE);
        expect_trap(IRQ_BIT | 64'd0, xlen_t'(loop_addr), 64'd0, TS_S_IE);
        expect_trap(IRQ_BIT | 64'd1, xlen_t'(loop_addr + 4), 64'd0, TS_S_IE);
        load_irq_handler();
        release_reset();
        repeat (2) @(posedge clk);
        raise_irq(3'b111);
        repeat (500) @(posedge clk);
        check("all sources acknowledged", xlen_t'(irq_level), 64'd0);
        check("interrupted addi completed (s1 at trap 0)", dmem[192], 64'd1);
        check("interrupted jal, s1 unchanged (trap 1)", dmem[196], 64'd1);
        check("interrupted addi completed (s1 at trap 2)", dmem[200], 64'd2);
        check_trap_log();
    endtask

    task automatic test_irq_not_on_ie_write();
        $display("Test 18 -- interrupt never commits on the instruction that clears IE:");
        begin_test();
        emit_init(1);
        emit(csrrwi(ZERO, CSR_TIE, 5'd2));
        emit(csrrsi(ZERO, CSR_TSTATUS, 5'd1));
        emit(csrrci(ZERO, CSR_TSTATUS, 5'd1));
        emit(addi(S1, S1, 13'd1));
        emit(jal(ZERO, -12));
        load_irq_handler();
        release_reset();
        repeat (2) @(posedge clk);
        raise_irq(3'b010);
        repeat (400) @(posedge clk);
        check("no trap taken", gpr(S9), 64'd512);
        check("loop kept running (s1 > 0)", (gpr(S1) > 64'd0) ? 64'd1 : 64'd0, 64'd1);
        check("timer still pending", xlen_t'(irq_level), 64'd2);
    endtask

    task automatic test_wfi();
        $display("Test 15 -- WFI idles fetch, wakes on pending (not enabled) interrupt:");
        begin_test();
        emit_init(0);
        emit(wfi());
        emit(nop());
        emit(nop());
        emit(nop());
        emit(nop());
        emit(addi(S2, ZERO, 13'd5));
        emit(wfi());
        emit(addi(S3, ZERO, 13'd7));
        release_reset();
        repeat (100) @(posedge clk);
        check("fetch halted (s2 = 0)", gpr(S2), 64'd0);
        check("fetch halted (s3 = 0)", gpr(S3), 64'd0);
        raise_irq(3'b010);
        repeat (100) @(posedge clk);
        check("resumed after wake (s2 = 5)", gpr(S2), 64'd5);
        check("WFI with pending irq is a no-op (s3 = 7)", gpr(S3), 64'd7);
        check("no trap taken (masked)", gpr(S9), 64'd512);
    endtask

    task automatic test_wfi_fault();
        $display("Test 16 -- synchronous trap in the shadow of WFI still runs:");
        begin_test();
        emit_init(0);
        emit(wfi());
        emit_fault(instr_t'(32'h0000003F), CAUSE_ILLEGAL_INSTR, TS_S);
        emit(addi(S4, ZERO, 13'h55));
        emit_halt();
        load_exc_handler();
        run(300);
        check("marker after resume", gpr(25), 64'h55);
        check_trap_log();
    endtask

    task automatic test_slow_memory();
        $display("Test 17 -- memory stalls do not drop or reorder instructions:");
        begin_test();
        emit(addi(A0, ZERO, 13'd1));
        emit(ld(A1, ZERO, 13'd64));
        emit(addi(A2, ZERO, 13'd5));
        emit(addi(A3, A1, 13'd1));
        emit(addi(A4, ZERO, 13'd7));
        emit(sd(ZERO, A2, 13'd72));
        emit(ld(A5, ZERO, 13'd72));
        emit(ld(T0, ZERO, 13'd64));
        emit(beq(ZERO, ZERO, 8));
        emit(addi(S1, ZERO, 13'd99));
        emit(addi(S2, ZERO, 13'd3));
        dmem[8] = 64'd77;
        slow_mem = 1'b1;
        run(300);
        slow_mem = 1'b0;
        check("a0 = 1", gpr(6), 64'd1);
        check("load under stall (a1 = 77)", gpr(7), 64'd77);
        check("instr in EX during stall (a2 = 5)", gpr(8), 64'd5);
        check("load-use under stall (a3 = 78)", gpr(9), 64'd78);
        check("a4 = 7", gpr(10), 64'd7);
        check("store then load under stall (a5 = 5)", gpr(11), 64'd5);
        check("branch in EX during stall skipped (s1)", gpr(22), 64'd0);
        check("branch target executed (s2)", gpr(23), 64'd3);
    endtask

    task automatic test_muldiv_basic();
        $display("Test 19 -- multiply/divide correctness:");
        begin_test();
        emit(addi(T0, ZERO, 13'd6));
        emit(addi(T1, ZERO, 13'd7));
        emit(addi(T2, ZERO, -3));
        emit(addi(T3, ZERO, 13'd5));
        emit(addi(T4, ZERO, 13'd1));
        emit(slli(T4, T4, 6'd40));
        emit(addi(T5, ZERO, 13'd1));
        emit(slli(T5, T5, 6'd63));
        emit(addi(T6, ZERO, -1));
        emit(mul(A0, T0, T1));
        emit(mul(A1, T2, T3));
        emit(mulh(A2, T4, T4));
        emit(mulhu(A3, T4, T4));
        emit(mulhsu(A4, T5, T1));
        emit(div(A5, T0, T1));
        emit(divu(A6, T0, T1));
        emit(rem_(A7, T0, T1));
        emit(remu(S1, T0, T1));
        emit(div(S2, T0, ZERO));
        emit(divu(S3, T0, ZERO));
        emit(rem_(S4, T0, ZERO));
        emit(remu(S5, T0, ZERO));
        emit(div(S6, T5, T6));
        emit(rem_(S7, T5, T6));
        emit_halt();
        run(300);
        check("mul 6*7=42", gpr(6), 64'd42);
        check("mul (-3)*5=-15", gpr(7), -64'd15);
        check("mulh (1<<40)*(1<<40) high", gpr(8), 64'h10000);
        check("mulhu (1<<40)*(1<<40) high", gpr(9), 64'h10000);
        check("mulhsu MOST_NEG*7 high", gpr(10), -64'd4);
        check("div 6/7=0", gpr(11), 64'd0);
        check("divu 6/7=0", gpr(12), 64'd0);
        check("rem 6%7=6", gpr(13), 64'd6);
        check("remu 6%7=6", gpr(22), 64'd6);
        check("div by zero = -1", gpr(23), -64'd1);
        check("divu by zero = all-ones", gpr(24), 64'hFFFF_FFFF_FFFF_FFFF);
        check("rem by zero = dividend", gpr(25), 64'd6);
        check("remu by zero = dividend", gpr(26), 64'd6);
        check("div overflow MOST_NEG/-1 = MOST_NEG", gpr(27), 64'h8000_0000_0000_0000);
        check("rem overflow MOST_NEG%-1 = 0", gpr(28), 64'd0);
    endtask

    task automatic test_muldiv_scoreboard();
        $display("Test 20 -- scoreboard stall on a pending muldiv result:");
        begin_test();
        emit(addi(T0, ZERO, 13'd6));
        emit(addi(T1, ZERO, 13'd7));
        emit(mul(A0, T0, T1));
        emit(addi(A1, A0, 13'd1));
        emit_halt();
        run(100);
        check("mul result ready", gpr(6), 64'd42);
        check("dependent addi used forwarded mul result", gpr(7), 64'd43);
    endtask

    task automatic test_muldiv_structural();
        $display("Test 21 -- back-to-back independent multiplies (structural hazard):");
        begin_test();
        emit(addi(T0, ZERO, 13'd3));
        emit(addi(T1, ZERO, 13'd4));
        emit(addi(T2, ZERO, 13'd5));
        emit(mul(A0, T0, T1));
        emit(mul(A1, T1, T2));
        emit(mul(A2, T2, T0));
        emit_halt();
        run(150);
        check("first back-to-back mul 3*4=12", gpr(6), 64'd12);
        check("second back-to-back mul 4*5=20", gpr(7), 64'd20);
        check("third back-to-back mul 5*3=15", gpr(8), 64'd15);
    endtask

    task automatic test_muldiv_overlap();
        $display("Test 22 -- independent scalar ops overlap a long divide:");
        begin_test();
        emit(addi(T0, ZERO, 13'd20));
        emit(addi(T1, ZERO, 13'd3));
        emit(div(A0, T0, T1));
        emit(addi(A1, ZERO, 13'd1));
        emit(addi(A2, ZERO, 13'd2));
        emit(addi(A3, ZERO, 13'd3));
        emit(addi(A4, ZERO, 13'd4));
        emit_halt();
        run(15);
        check("independent addi 1 retired early", gpr(7), 64'd1);
        check("independent addi 2 retired early", gpr(8), 64'd2);
        check("independent addi 3 retired early", gpr(9), 64'd3);
        check("independent addi 4 retired early", gpr(10), 64'd4);
        check("divide not yet complete", gpr(6), 64'd0);
        repeat (15) @(posedge clk);
        check("divide eventually completes (20/3=6)", gpr(6), 64'd6);
    endtask

    task automatic test_muldiv_arbitration();
        $display("Test 23 -- writeback arbitration between main pipeline and muldiv:");
        begin_test();
        emit(addi(T0, ZERO, 13'd6));
        emit(addi(T1, ZERO, 13'd7));
        emit(mul(A0, T0, T1));
        emit(addi(A1, ZERO, 13'd99));
        emit_halt();
        run(60);
        check("muldiv result survives arbitration", gpr(6), 64'd42);
        check("colliding main-pipeline write survives arbitration", gpr(7), 64'd99);
    endtask

    initial begin
        for (int i = 0; i < 1024; i++) begin
            imem[i] = i_type(OPC_OP_IMM, 5'd0, 3'b000, 5'd0, 13'd0);
            dmem[i] = '0;
        end

        imem[0] = i_type(OPC_OP_IMM, 5'd6, 3'b000, 5'd0, 13'd10);
        imem[1] = i_type(OPC_OP_IMM, 5'd7, 3'b000, 5'd0, 13'd32);
        imem[2] = r_type(OPC_OP, 5'd8, 3'b000, 5'd6, 5'd7, 8'h00);

        imem[3] = i_type(OPC_OP_IMM, 5'd14, 3'b000, 5'd0, 13'd7);
        imem[4] = i_type(OPC_OP_IMM, 5'd15, 3'b000, 5'd14, 13'd1);
        imem[5] = i_type(OPC_OP_IMM, 5'd16, 3'b000, 5'd15, 13'd1);

        imem[6] = i_type(OPC_OP_IMM, 5'd17, 3'b000, 5'd0, 13'd100);
        imem[7] = i_type(OPC_OP_IMM, 5'd18, 3'b000, 5'd0, 13'd40);
        imem[8] = r_type(OPC_OP, 5'd19, 3'b000, 5'd17, 5'd18, 8'h80);
        imem[9] = r_type(OPC_OP, 5'd20, 3'b010, 5'd18, 5'd17, 8'h00);
        imem[10] = i_type(OPC_OP_IMM, 5'd21, 3'b100, 5'd18, 13'd15);

        imem[11] = i_type(OPC_OP_IMM, 5'd22, 3'b000, 5'd0, 13'h2A0);
        imem[12] = s_type(OPC_STORE, 3'b011, 5'd0, 5'd22, 13'd64);
        imem[13] = i_type(OPC_LOAD, 5'd23, 3'b011, 5'd0, 13'd64);
        imem[14] = i_type(OPC_OP_IMM, 5'd24, 3'b000, 5'd23, 13'd1);

        imem[15] = i_type(OPC_OP_IMM, 5'd25, 3'b000, 5'd0, 13'd1);
        imem[16] = b_type(OPC_BRANCH, 3'b000, 5'd0, 5'd0, 13'd2);
        imem[17] = i_type(OPC_OP_IMM, 5'd25, 3'b000, 5'd0, 13'd99);
        imem[18] = i_type(OPC_OP_IMM, 5'd26, 3'b000, 5'd0, 13'd5);

        imem[19] = i_type(OPC_OP_IMM, 5'd27, 3'b000, 5'd0, 13'd3);
        imem[20] = b_type(OPC_BRANCH, 3'b001, 5'd0, 5'd0, 13'd2);
        imem[21] = i_type(OPC_OP_IMM, 5'd28, 3'b000, 5'd0, 13'd77);

        imem[22] = u_type(OPC_LUI, 5'd29, 21'd3);
        imem[23] = i_type(OPC_OP_IMM, 5'd0, 3'b000, 5'd0, 13'd123);

        rst_n = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;

        repeat (60) @(posedge clk);

        $display("\n==================== RESULTS ====================");
        $display("Test 1 -- basic ALU:");
        check("a0 = 10", gpr(6), 64'd10);
        check("a1 = 32", gpr(7), 64'd32);
        check("a2 = a0+a1 = 42", gpr(8), 64'd42);

        $display("Test 2 -- back-to-back forwarding:");
        check("t0 = 7", gpr(14), 64'd7);
        check("t1 = t0+1 = 8", gpr(15), 64'd8);
        check("t2 = t1+1 = 9", gpr(16), 64'd9);

        $display("Test 3 -- SUB / SLT / XORI:");
        check("t3 = 100", gpr(17), 64'd100);
        check("t4 = 40", gpr(18), 64'd40);
        check("t5 = t3-t4 = 60", gpr(19), 64'd60);
        check("t6 = (t4<t3) = 1", gpr(20), 64'd1);
        check("t7 = t4^15 = 39", gpr(21), 64'd39);

        $display("Test 4 -- store/load + load-use interlock:");
        check("s1 = 0x2A0", gpr(22), 64'h2A0);
        check("s2 = loaded 0x2A0", gpr(23), 64'h2A0);
        check("s3 = s2+1 = 0x2A1", gpr(24), 64'h2A1);

        $display("Test 5 -- mispredicted taken branch:");
        check("s4 = 1 (not clobbered)", gpr(25), 64'd1);
        check("s5 = 5 (branch target)", gpr(26), 64'd5);

        $display("Test 6 -- correctly predicted not-taken branch:");
        check("s6 = 3", gpr(27), 64'd3);
        check("s7 = 77 (fell through)", gpr(28), 64'd77);

        $display("Test 7 -- LUI and r0 hardwiring:");
        check("s8 = 3<<13 = 24576", gpr(29), 64'd24576);
        check("r0 still zero", gpr(0), 64'd0);

        test_csr_access();
        test_illegal_and_system();
        test_user_mode();
        test_misaligned();
        test_fp_vec_disabled();
        test_irq_masked_then_enabled();
        test_irq_priority();
        test_irq_not_on_ie_write();
        test_wfi();
        test_wfi_fault();
        test_slow_memory();
        test_muldiv_basic();
        test_muldiv_scoreboard();
        test_muldiv_structural();
        test_muldiv_overlap();
        test_muldiv_arbitration();

        $display("================================================");
        if (errors == 0) begin
            $display("ALL TESTS PASSED");
        end else begin
            $display("%0d FAILURE(S)", errors);
        end
        $display("================================================\n");

        $finish;
    end

    initial begin
        #10000000;
        $display("TIMEOUT");
        $finish;
    end

endmodule : tb_core
