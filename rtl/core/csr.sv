import tarc_pkg::*;

module csr #(
    parameter int HARTID = 0
) (
    input logic clk,
    input logic rst_n,

    input logic access_en,
    input csr_funct3_e access_op,
    input logic [11:0] access_addr,
    input xlen_t access_wdata,
    input logic access_do_write,
    output xlen_t access_rdata,
    output logic access_illegal,

    input logic trap_enter,
    input xlen_t trap_epc,
    input xlen_t trap_cause,
    input xlen_t trap_tval,
    input logic sret_commit,

    input logic fflags_en,
    input logic [4:0] fflags_set,
    input logic fs_dirty,

    input logic irq_software,
    input logic irq_timer,
    input logic irq_external,

    output logic priv_s,
    output xlen_t tvec,
    output xlen_t tepc,
    output logic [2:0] frm,
    output logic fs_off,
    output logic vs_off,
    output logic irq_any_pending,
    output logic irq_pending,
    output logic irq_enabled,
    output irq_cause_e irq_cause
);

    logic priv_s_q;
    logic ie_q, pie_q, pp_q;
    logic [1:0] fs_q, vs_q;
    logic [2:0] tie_q;
    logic [2:0] tip_sw_q;
    xlen_t tvec_q, tscratch_q, tepc_q, tcause_q, tval_q, satp_q;
    logic [2:0] frm_q;
    logic [4:0] fflags_q;
    logic [$clog2(VLEN)-1:0] vstart_q;

    logic [2:0] tip_hw_bits;
    logic [2:0] tip_bits;
    assign tip_hw_bits = {irq_external, irq_timer, irq_software};
    assign tip_bits = tip_hw_bits | tip_sw_q;

    xlen_t tstatus_val;
    assign tstatus_val = {57'b0, vs_q, fs_q, pp_q, pie_q, ie_q};

    xlen_t read_val;
    logic csr_defined, csr_user_ok, csr_read_only;

    always_comb begin
        read_val = '0;
        csr_defined = 1'b1;
        csr_user_ok = 1'b0;
        csr_read_only = 1'b0;
        unique case (access_addr)
            CSR_TSTATUS: read_val = tstatus_val;
            CSR_TIE: read_val = {61'b0, tie_q};
            CSR_TIP: read_val = {61'b0, tip_bits};
            CSR_TVEC: read_val = tvec_q;
            CSR_TSCRATCH: read_val = tscratch_q;
            CSR_TEPC: read_val = tepc_q;
            CSR_TCAUSE: begin
                read_val = tcause_q;
                csr_read_only = 1'b1;
            end
            CSR_TVAL: begin
                read_val = tval_q;
                csr_read_only = 1'b1;
            end
            CSR_SATP: read_val = satp_q;
            CSR_HARTID: begin
                read_val = xlen_t'(HARTID);
                csr_read_only = 1'b1;
            end
            CSR_FCSR: begin
                read_val = {56'b0, fflags_q, frm_q};
                csr_user_ok = 1'b1;
            end
            CSR_VSTART: begin
                read_val = xlen_t'(vstart_q);
                csr_user_ok = 1'b1;
            end
            CSR_VTYPE: begin
                read_val = '0;
                csr_user_ok = 1'b1;
                csr_read_only = 1'b1;
            end
            CSR_VL: begin
                read_val = '0;
                csr_user_ok = 1'b1;
                csr_read_only = 1'b1;
            end
            CSR_VLENB: begin
                read_val = xlen_t'(VLEN) >> 3;
                csr_user_ok = 1'b1;
                csr_read_only = 1'b1;
            end
            default: csr_defined = 1'b0;
        endcase
    end

    xlen_t new_val;
    always_comb begin
        unique case (access_op)
            F3_CSRRW, F3_CSRRWI: new_val = access_wdata;
            F3_CSRRS, F3_CSRRSI: new_val = read_val | access_wdata;
            F3_CSRRC, F3_CSRRCI: new_val = read_val & ~access_wdata;
            default: new_val = read_val;
        endcase
    end

    xlen_t tip_new_val;
    always_comb begin
        unique case (access_op)
            F3_CSRRW, F3_CSRRWI: tip_new_val = access_wdata;
            F3_CSRRS, F3_CSRRSI: tip_new_val = {61'b0, tip_sw_q} | access_wdata;
            F3_CSRRC, F3_CSRRCI: tip_new_val = {61'b0, tip_sw_q} & ~access_wdata;
            default: tip_new_val = {61'b0, tip_sw_q};
        endcase
    end

    logic priv_violation;
    assign priv_violation = !priv_s_q && !csr_user_ok;

    assign access_rdata = read_val;
    assign access_illegal = access_en
        && (!csr_defined || priv_violation || (access_do_write && csr_read_only));

    logic write_en;
    assign write_en = access_en && access_do_write && !access_illegal;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            priv_s_q <= 1'b1;
            ie_q <= 1'b0;
            pie_q <= 1'b0;
            pp_q <= 1'b0;
            fs_q <= 2'b00;
            vs_q <= 2'b00;
            tie_q <= 3'b000;
            tip_sw_q <= 3'b000;
            tvec_q <= '0;
            tscratch_q <= '0;
            tepc_q <= '0;
            tcause_q <= '0;
            tval_q <= '0;
            satp_q <= '0;
            frm_q <= 3'b000;
            fflags_q <= 5'b00000;
            vstart_q <= '0;
        end else begin
            if (trap_enter) begin
                tepc_q <= trap_epc;
                tcause_q <= trap_cause;
                tval_q <= trap_tval;
                pp_q <= priv_s_q;
                priv_s_q <= 1'b1;
                pie_q <= ie_q;
                ie_q <= 1'b0;
            end else if (sret_commit) begin
                priv_s_q <= pp_q;
                ie_q <= pie_q;
            end else if (write_en) begin
                unique case (access_addr)
                    CSR_TSTATUS: begin
                        ie_q <= new_val[0];
                        pie_q <= new_val[1];
                        pp_q <= new_val[2];
                        if (new_val[4:3] != 2'b11) begin
                            fs_q <= new_val[4:3];
                        end
                        if (new_val[6:5] != 2'b11) begin
                            vs_q <= new_val[6:5];
                        end
                    end
                    CSR_TIE: tie_q <= new_val[2:0];
                    CSR_TIP: tip_sw_q <= tip_new_val[2:0];
                    CSR_TVEC: tvec_q <= {new_val[63:2], 2'b00};
                    CSR_TSCRATCH: tscratch_q <= new_val;
                    CSR_TEPC: tepc_q <= new_val;
                    CSR_SATP: begin
                        if (new_val[3:0] <= 4'd1) begin
                            satp_q <= {8'b0, new_val[55:0]};
                        end
                    end
                    CSR_FCSR: begin
                        fflags_q <= new_val[7:3];
                        if (new_val[2:0] <= 3'b100) begin
                            frm_q <= new_val[2:0];
                        end
                    end
                    CSR_VSTART: vstart_q <= new_val[$clog2(VLEN)-1:0];
                    default: begin
                    end
                endcase
            end

            if (fflags_en) begin
                fflags_q <= fflags_q | fflags_set;
            end

            if (fs_dirty && fs_q == FPVEC_CLEAN) begin
                fs_q <= FPVEC_DIRTY;
            end
        end
    end

    logic [2:0] pend_enabled;
    assign pend_enabled = tip_bits & tie_q;

    assign priv_s = priv_s_q;
    assign tvec = tvec_q;
    assign tepc = tepc_q;
    assign frm = frm_q;
    assign fs_off = (fs_q == 2'b00);
    assign vs_off = (vs_q == 2'b00);
    assign irq_any_pending = |tip_bits;
    assign irq_pending = |pend_enabled;
    assign irq_enabled = ie_q;

    always_comb begin
        if (pend_enabled[2]) begin
            irq_cause = IRQ_EXTERNAL;
        end else if (pend_enabled[0]) begin
            irq_cause = IRQ_SOFTWARE;
        end else begin
            irq_cause = IRQ_TIMER;
        end
    end

endmodule : csr
