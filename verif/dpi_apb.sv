`include "uvm_pkg.sv"
`include "svt_apb.uvm.pkg"
`include "svt_apb_if.svi"

// =============================================================================
// DPI-C bridge: drives the two APB VIPs from C firmware.
// This module is a pure DPI-C bridge — it does not start a UVM test.
// The UVM environment is created by combined_test in lpddr4_tb.sv.
// =============================================================================
module dpi_apb #(
    parameter int APB_TIMEOUT_CYCLES = 100000
)(
    input  wire        PCLK,
    input  wire        PRESETn,
    apb3.master       DRAM_CFG_APB_master,
    apb4.master       DRAM_PHY_CFG_APB_master
);

    svt_apb_if apb3_if ();
    svt_apb_if apb4_if ();

    assign apb3_if.pclk    = PCLK;
    assign apb3_if.presetn = PRESETn;

    assign DRAM_CFG_APB_master.paddr   = apb3_if.paddr;
    assign DRAM_CFG_APB_master.pwdata  = apb3_if.pwdata;
    assign DRAM_CFG_APB_master.penable = apb3_if.penable;
    assign DRAM_CFG_APB_master.pwrite  = apb3_if.pwrite;
    assign DRAM_CFG_APB_master.psel    = apb3_if.psel[0];
    always @(*) assign apb3_if.slave_if[0].prdata  = DRAM_CFG_APB_master.prdata;
    always @(*) assign apb3_if.slave_if[0].pready  = DRAM_CFG_APB_master.pready;
    always @(*) assign apb3_if.slave_if[0].pslverr = DRAM_CFG_APB_master.pslverr;

    assign apb4_if.pclk    = PCLK;
    assign apb4_if.presetn = PRESETn;

    assign DRAM_PHY_CFG_APB_master.paddr   = apb4_if.paddr;
    assign DRAM_PHY_CFG_APB_master.pwdata  = apb4_if.pwdata;
    assign DRAM_PHY_CFG_APB_master.penable = apb4_if.penable;
    assign DRAM_PHY_CFG_APB_master.pwrite  = apb4_if.pwrite;
    assign DRAM_PHY_CFG_APB_master.psel    = apb4_if.psel[0];
    assign DRAM_PHY_CFG_APB_master.pprot   = 3'b001;
    assign DRAM_PHY_CFG_APB_master.pstrb   = apb4_if.pstrb;
    always @(*) assign apb4_if.slave_if[0].prdata  = DRAM_PHY_CFG_APB_master.prdata;
    always @(*) assign apb4_if.slave_if[0].pready  = DRAM_PHY_CFG_APB_master.pready;
    always @(*) assign apb4_if.slave_if[0].pslverr = DRAM_PHY_CFG_APB_master.pslverr;

    export "DPI-C" task sv_apb3_write;
    export "DPI-C" task sv_apb3_read;
    export "DPI-C" task sv_apb4_write;
    export "DPI-C" task sv_apb4_read;

    task automatic apb3_master_tx(
        input  bit          is_write,
        input  bit [31:0]   addr,
        input  bit [31:0]   wdata,
        output logic [31:0] rdata
    );
        dpi_apb_seq seq;
        int timeout_cnt;

        while (!dpi_apb_test::r3) @(posedge PCLK);
        if (dpi_apb_test::s3 == null) begin
            $display("%0t [DPI_APB] APB3 sequencer unavailable", $time);
            rdata = 32'hDEADBEEF;
            return;
        end

        seq = new("apb3_tx");
        seq.is_write = is_write;
        seq.addr     = addr;
        seq.wdata    = wdata;

        fork : apb3_xact_fork
            seq.start(dpi_apb_test::s3);
        join_none

        timeout_cnt = 0;
        while (!seq.done && timeout_cnt < APB_TIMEOUT_CYCLES) begin
            @(posedge PCLK);
            timeout_cnt++;
        end
        if (!seq.done) begin
            $display("%0t [DPI_APB] APB3 %s timeout addr=0x%08x", $time,
                     is_write ? "WRITE" : "READ", addr);
            disable apb3_xact_fork;
        end
        rdata = seq.result;
    endtask

    task automatic apb4_master_tx(
        input  bit          is_write,
        input  bit [31:0]   addr,
        input  bit [31:0]   wdata,
        output logic [31:0] rdata
    );
        dpi_apb_seq seq;
        int timeout_cnt;

        while (!dpi_apb_test::r4) @(posedge PCLK);
        if (dpi_apb_test::s4 == null) begin
            $display("%0t [DPI_APB] APB4 sequencer unavailable", $time);
            rdata = 32'hDEADBEEF;
            return;
        end

        seq = new("apb4_tx");
        seq.is_write = is_write;
        seq.addr     = addr;
        seq.wdata    = wdata;

        fork : apb4_xact_fork
            seq.start(dpi_apb_test::s4);
        join_none

        timeout_cnt = 0;
        while (!seq.done && timeout_cnt < APB_TIMEOUT_CYCLES) begin
            @(posedge PCLK);
            timeout_cnt++;
        end
        if (!seq.done) begin
            $display("%0t [DPI_APB] APB4 %s timeout addr=0x%08x", $time,
                     is_write ? "WRITE" : "READ", addr);
            disable apb4_xact_fork;
        end
        rdata = seq.result;
    endtask

    task automatic sv_apb3_write(input int unsigned addr, input int unsigned data);
        logic [31:0] rdata;
        apb3_master_tx(1'b1, addr, data, rdata);
    endtask

    task automatic sv_apb3_read(input int unsigned addr, output int unsigned data);
        logic [31:0] rdata;
        apb3_master_tx(1'b0, addr, 32'h0, rdata);
        data = rdata;
    endtask

    task automatic sv_apb4_write(input int unsigned addr, input int unsigned data);
        logic [31:0] rdata;
        apb4_master_tx(1'b1, addr, data, rdata);
    endtask

    task automatic sv_apb4_read(input int unsigned addr, output int unsigned data);
        logic [31:0] rdata;
        apb4_master_tx(1'b0, addr, 32'h0, rdata);
        data = rdata;
    endtask

    initial begin
        uvm_config_db#(svt_apb_vif)::set(uvm_root::get(), "uvm_test_top.dpi_apb_test.apb3_env", "vif", apb3_if);
        uvm_config_db#(svt_apb_vif)::set(uvm_root::get(), "uvm_test_top.combined_test.dpi_apb_test.apb3_env", "vif", apb3_if);
        uvm_config_db#(svt_apb_vif)::set(uvm_root::get(), "uvm_test_top.dpi_apb_test.apb4_env", "vif", apb4_if);
        uvm_config_db#(svt_apb_vif)::set(uvm_root::get(), "uvm_test_top.combined_test.dpi_apb_test.apb4_env", "vif", apb4_if);
    end

endmodule
