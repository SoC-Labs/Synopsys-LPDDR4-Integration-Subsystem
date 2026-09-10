interface apb4;
    wire [31:0] paddr;
    wire [31:0] pwdata;
    wire [31:0] prdata;
    wire        penable;
    wire        pwrite;
    wire        psel;
    wire        pready;
    wire        pslverr;
    wire [2:0]  pprot;
    wire [3:0]  pstrb;

    modport subordinate (
        input paddr, pwdata, penable, pwrite, psel, pprot, pstrb,
        output prdata, pready, pslverr
    );
    modport master (
        input prdata, pready, pslverr,
        output paddr, pwdata, penable, pwrite, psel, pprot, pstrb
    );

endinterface
