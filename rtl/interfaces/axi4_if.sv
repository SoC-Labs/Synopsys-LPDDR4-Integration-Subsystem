interface axi4 #(
    parameter DATA_W=32,
    parameter ID_W=6,
    parameter ADDR_W=32
);
    wire [ID_W-1:0]         AWID;
    wire [ADDR_W-1:0]       AWADDR;
    wire [7:0]              AWLEN;
    wire [2:0]              AWSIZE;
    wire [1:0]              AWBURST;
    wire                    AWLOCK;
    wire [3:0]              AWCACHE;
    wire [2:0]              AWPROT;
    wire                    AWVALID;
    wire                    AWREADY;

    wire [DATA_W-1:0]       WDATA;
    wire [(DATA_W/8)-1:0]   WSTRB;
    wire                    WLAST;
    wire                    WVALID;
    wire                    WREADY;

    wire [ID_W-1:0]         BID;
    wire [1:0]              BRESP;
    wire                    BVALID;
    wire                    BREADY;

    wire [ID_W-1:0]         ARID;
    wire [ADDR_W-1:0]       ARADDR;
    wire [7:0]              ARLEN;
    wire [2:0]              ARSIZE;
    wire [1:0]              ARBURST;
    wire                    ARLOCK;
    wire [3:0]              ARCACHE;
    wire [2:0]              ARPROT;
    wire                    ARVALID;
    wire                    ARREADY;
    wire [ID_W-1:0]         RID;
    wire [DATA_W-1:0]       RDATA;
    wire [1:0]              RRESP;
    wire                    RLAST;
    wire                    RVALID;
    wire                    RREADY;

    modport subordinate (
        input AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWLOCK, AWCACHE, AWPROT, AWVALID,
        WDATA, WSTRB, WLAST, WVALID, BREADY,
        ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARLOCK, ARCACHE, ARPROT, ARVALID, RREADY,
        output AWREADY, WREADY, BID, BRESP, BVALID, ARREADY,
        RID, RDATA, RRESP, RLAST, RVALID
    );
    modport master (
        input AWREADY, WREADY, BID, BRESP, BVALID, ARREADY,
        RID, RDATA, RRESP, RLAST, RVALID,
        output AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWLOCK, AWCACHE, AWPROT, AWVALID,
        WDATA, WSTRB, WLAST, WVALID, BREADY,
        ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARLOCK, ARCACHE, ARPROT, ARVALID, RREADY

    );

endinterface
