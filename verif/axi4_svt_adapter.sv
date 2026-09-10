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
module axi4_svt_adapter #(
    parameter bit CONNECT_SLAVE = 1'b1
)(
    svt_axi_if axi_if,
    axi4       DRAM_AXI
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

    // ---------------- slave VIP connections (CONNECT_SLAVE=0: dram_wrapper
    // is the subordinate and drives these signals itself) ----------------
    generate
        if (CONNECT_SLAVE) begin : slave_connect
            assign axi_if.slave_if[0].awid      = DRAM_AXI.AWID;
            assign axi_if.slave_if[0].awaddr    = DRAM_AXI.AWADDR;
            assign axi_if.slave_if[0].awlen     = DRAM_AXI.AWLEN;
            assign axi_if.slave_if[0].awsize    = DRAM_AXI.AWSIZE;
            assign axi_if.slave_if[0].awburst   = DRAM_AXI.AWBURST;
            assign axi_if.slave_if[0].awlock    = DRAM_AXI.AWLOCK;
            assign axi_if.slave_if[0].awcache   = DRAM_AXI.AWCACHE;
            assign axi_if.slave_if[0].awprot    = DRAM_AXI.AWPROT;
            assign axi_if.slave_if[0].awvalid   = DRAM_AXI.AWVALID;
            assign DRAM_AXI.AWREADY = axi_if.slave_if[0].awready;

            assign axi_if.slave_if[0].wdata     = DRAM_AXI.WDATA;
            assign axi_if.slave_if[0].wstrb     = DRAM_AXI.WSTRB;
            assign axi_if.slave_if[0].wlast     = DRAM_AXI.WLAST;
            assign axi_if.slave_if[0].wvalid    = DRAM_AXI.WVALID;
            assign axi_if.slave_if[0].wid       = '0;
            assign DRAM_AXI.WREADY  = axi_if.slave_if[0].wready;

            assign axi_if.slave_if[0].bready    = DRAM_AXI.BREADY;
            assign DRAM_AXI.BID      = axi_if.slave_if[0].bid;
            assign DRAM_AXI.BRESP    = axi_if.slave_if[0].bresp;
            assign DRAM_AXI.BVALID   = axi_if.slave_if[0].bvalid;

            assign axi_if.slave_if[0].arid      = DRAM_AXI.ARID;
            assign axi_if.slave_if[0].araddr    = DRAM_AXI.ARADDR;
            assign axi_if.slave_if[0].arlen     = DRAM_AXI.ARLEN;
            assign axi_if.slave_if[0].arsize    = DRAM_AXI.ARSIZE;
            assign axi_if.slave_if[0].arburst   = DRAM_AXI.ARBURST;
            assign axi_if.slave_if[0].arlock    = DRAM_AXI.ARLOCK;
            assign axi_if.slave_if[0].arcache   = DRAM_AXI.ARCACHE;
            assign axi_if.slave_if[0].arprot    = DRAM_AXI.ARPROT;
            assign axi_if.slave_if[0].arvalid   = DRAM_AXI.ARVALID;
            assign DRAM_AXI.ARREADY = axi_if.slave_if[0].arready;

            assign axi_if.slave_if[0].rid       = DRAM_AXI.RID;
            assign axi_if.slave_if[0].rdata     = DRAM_AXI.RDATA;
            assign axi_if.slave_if[0].rresp     = DRAM_AXI.RRESP;
            assign axi_if.slave_if[0].rlast     = DRAM_AXI.RLAST;
            assign axi_if.slave_if[0].rvalid    = DRAM_AXI.RVALID;
            assign DRAM_AXI.RID      = axi_if.slave_if[0].rid;
            assign DRAM_AXI.RDATA    = axi_if.slave_if[0].rdata;
            assign DRAM_AXI.RRESP    = axi_if.slave_if[0].rresp;
            assign DRAM_AXI.RLAST    = axi_if.slave_if[0].rlast;
            assign DRAM_AXI.RVALID   = axi_if.slave_if[0].rvalid;
            assign axi_if.slave_if[0].rready    = DRAM_AXI.RREADY;
        end
    endgenerate

endmodule

`endif // GUARD_AXI4_SVT_ADAPTER_SV