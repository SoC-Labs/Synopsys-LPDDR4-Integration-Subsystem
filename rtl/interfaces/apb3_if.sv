interface apb3;
    wire [31:0] paddr;
    wire [31:0] pwdata;
    wire [31:0] prdata;
    wire        penable;
    wire        pwrite;
    wire        psel;
    wire        pready;
    wire        pslverr;

    modport subordinate (
        input paddr, pwdata, penable, pwrite, psel,
        output prdata, pready, pslverr
    );
    modport master (
        input prdata, pready, pslverr,
        output paddr, pwdata, penable, pwrite, psel
    );

endinterface
