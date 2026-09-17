`ifndef GUARD_AXI4_SVT_ADAPTER_SV
`define GUARD_AXI4_SVT_ADAPTER_SV

`include "svt_axi_if.svi"

// =============================================================================
// Adapter that bridges the SVT AXI VIP interface to the repo 'axi4' interface.
// The 'axi4' instance (DRAM_AXI) is the exact pin-level bus that will later be
// consumed by dram_wrapper through the 'subordinate' modport.
//
// Two connection modes:
//   - CONNECT_SLAVE=1 (standalone axi_tb): DRAM_AXI acts as the interconnect
//     between the SVT master VIP (axi_if.master_if[0]) and the SVT slave VIP
//     (axi_if.slave_if[0], internal memory).
//   - CONNECT_SLAVE=0 (lpddr4_tb): only the SVT master VIP is attached to
//     DRAM_AXI, which is driven as a subordinate by dram_wrapper.  The slave
//     VIP connections are left out so they never fight the wrapper's drivers.
// =============================================================================
module axi4_svt_adapter (
    svt_axi_if axi_if,
    axi4.master       DRAM_AXI
);

    // ---------------- write address channel ----------------
    assign DRAM_AXI.AWID     = axi_if.master_if[0].awid;
    assign DRAM_AXI.AWADDR   = axi_if.master_if[0].awaddr;
    assign DRAM_AXI.AWLEN    = axi_if.master_if[0].awlen;
    assign DRAM_AXI.AWSIZE   = axi_if.master_if[0].awsize;
    assign DRAM_AXI.AWBURST  = axi_if.master_if[0].awburst;
    assign DRAM_AXI.AWLOCK   = axi_if.master_if[0].awlock;
    assign DRAM_AXI.AWCACHE  = axi_if.master_if[0].awcache;
    assign DRAM_AXI.AWPROT   = axi_if.master_if[0].awprot;
    assign DRAM_AXI.AWVALID  = axi_if.master_if[0].awvalid;
    assign axi_if.master_if[0].awready  = DRAM_AXI.AWREADY;

    // ---------------- write data channel ----------------
    assign DRAM_AXI.WDATA    = axi_if.master_if[0].wdata;
    assign DRAM_AXI.WSTRB    = axi_if.master_if[0].wstrb;
    assign DRAM_AXI.WLAST    = axi_if.master_if[0].wlast;
    assign DRAM_AXI.WVALID   = axi_if.master_if[0].wvalid;
    assign axi_if.master_if[0].wready   = DRAM_AXI.WREADY;

    // ---------------- write response channel ----------------
    assign axi_if.master_if[0].bid      = DRAM_AXI.BID;
    assign axi_if.master_if[0].bresp    = DRAM_AXI.BRESP;
    assign axi_if.master_if[0].bvalid   = DRAM_AXI.BVALID;
    assign DRAM_AXI.BREADY   = axi_if.master_if[0].bready;

    // ---------------- read address channel ----------------
    assign DRAM_AXI.ARID     = axi_if.master_if[0].arid;
    assign DRAM_AXI.ARADDR   = axi_if.master_if[0].araddr;
    assign DRAM_AXI.ARLEN    = axi_if.master_if[0].arlen;
    assign DRAM_AXI.ARSIZE   = axi_if.master_if[0].arsize;
    assign DRAM_AXI.ARBURST  = axi_if.master_if[0].arburst;
    assign DRAM_AXI.ARLOCK   = axi_if.master_if[0].arlock;
    assign DRAM_AXI.ARCACHE  = axi_if.master_if[0].arcache;
    assign DRAM_AXI.ARPROT   = axi_if.master_if[0].arprot;
    assign DRAM_AXI.ARVALID  = axi_if.master_if[0].arvalid;
    assign axi_if.master_if[0].arready  = DRAM_AXI.ARREADY;

    // ---------------- read data channel ----------------
    assign axi_if.master_if[0].rid      = DRAM_AXI.RID;
    assign axi_if.master_if[0].rdata    = DRAM_AXI.RDATA;
    assign axi_if.master_if[0].rresp    = DRAM_AXI.RRESP;
    assign axi_if.master_if[0].rlast    = DRAM_AXI.RLAST;
    assign axi_if.master_if[0].rvalid   = DRAM_AXI.RVALID;
    assign DRAM_AXI.RREADY   = axi_if.master_if[0].rready;


endmodule

`endif // GUARD_AXI4_SVT_ADAPTER_SV