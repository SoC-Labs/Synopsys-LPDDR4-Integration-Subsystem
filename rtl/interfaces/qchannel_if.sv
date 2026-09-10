interface qchannel;
    wire        qreqn;
    wire        qacceptn;
    wire        qdeny;
    wire        qactive;

    modport subordinate (
        input qreqn,
        output qacceptn, qdeny, qactive
    );
    modport master (
        input qacceptn, qdeny, qactive,
        output qreqn
    );

endinterface