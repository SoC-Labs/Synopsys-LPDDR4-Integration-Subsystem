`include "uvm_pkg.sv"
`include "svt_axi.uvm.pkg"
`include "svt_axi_if.svi"

// =============================================================================
// DPI-C bridge: drives the AXI VIP master from C firmware.
// This module is a pure DPI-C bridge — it does not start a UVM test.
// The UVM environment is created by combined_test in lpddr4_tb.sv.
// =============================================================================
module dpi_axi #(
    parameter int  AXI_TIMEOUT_CYCLES = 1000000
)(
    input wire ACLK,
    input wire ARESETn,
    axi4.master   DRAM_AXI
);

    svt_axi_if axi_if ();
    axi4_svt_adapter u_axi4_adapter(axi_if, DRAM_AXI);

    assign axi_if.common_aclk          = ACLK;
    assign axi_if.master_if[0].aclk    = ACLK;
    assign axi_if.master_if[0].aresetn = ARESETn;
    assign axi_if.slave_if[0].aresetn  = ARESETn;

    export "DPI-C" task sv_axi_write;
    export "DPI-C" task sv_axi_read;

    task automatic axi_master_tx(
        input  bit          is_write,
        input  bit [63:0]   addr,
        input  bit [63:0]   wdata,
        input  int unsigned burst_length,
        output logic [63:0] rdata
    );
        dpi_axi_seq seq;
        int timeout_cnt;

        while (!dpi_axi_test::rx_ready) @(posedge ACLK);
        if (dpi_axi_test::sm == null) begin
            $display("%0t [DPI_AXI] AXI master sequencer unavailable", $time);
            rdata = 64'hDEAD_BEEF_DEAD_BEEF;
            return;
        end

        seq = new("axi_tx");
        seq.is_write      = is_write;
        seq.addr          = addr;
        seq.wdata         = wdata;
        seq.burst_length  = burst_length;

        fork : axi_xact_fork
            seq.start(dpi_axi_test::sm);
        join_none

        timeout_cnt = 0;
        while (!seq.done && timeout_cnt < AXI_TIMEOUT_CYCLES) begin
            @(posedge ACLK);
            timeout_cnt++;
        end
        if (!seq.done) begin
            $display("%0t [DPI_AXI] AXI %s timeout addr=0x%08x", $time,
                     is_write ? "WRITE" : "READ", addr[31:0]);
            disable axi_xact_fork;
        end
        rdata = seq.result;
    endtask

    task automatic sv_axi_write(input longint unsigned addr, input longint unsigned data, input int unsigned burst_length);
        logic [63:0] rdata;
        axi_master_tx(1'b1, addr[63:0], data[63:0], burst_length, rdata);
    endtask

    task automatic sv_axi_read(input longint unsigned addr, output longint unsigned data, input int unsigned burst_length);
        logic [63:0] rdata;
        axi_master_tx(1'b0, addr[63:0], 64'h0, burst_length, rdata);
        data = rdata;
    endtask

    initial begin
        uvm_config_db#(svt_axi_vif)::set(uvm_root::get(), "uvm_test_top.dpi_axi_test.axi_system_env", "vif", axi_if);
        uvm_config_db#(svt_axi_vif)::set(uvm_root::get(), "uvm_test_top.combined_test.dpi_axi_test.axi_system_env", "vif", axi_if);
    end

endmodule
