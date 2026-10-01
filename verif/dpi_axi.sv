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
    export "DPI-C" task sv_axi_write_strb;
    export "DPI-C" task sv_axi_narrow;
    export "DPI-C" function sv_axi_queue;
    export "DPI-C" task sv_axi_run_queue;
    export "DPI-C" function sv_axi_queue_beat;
    export "DPI-C" function sv_axi_last_read_len;
    export "DPI-C" function sv_axi_last_read_beat;

    // All beats of the most recent read burst, so C tests can check every beat
    logic [63:0] last_read_beats[];

    task automatic axi_master_tx(
        input  bit          is_write,
        input  bit [63:0]   addr,
        input  bit [63:0]   wdata,
        input  int unsigned burst_length,
        input  bit [7:0]    wstrb,
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
        seq.wstrb         = wstrb;

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
        if (!is_write) begin
            if (seq.done) last_read_beats = seq.rdata_beats;
            else          last_read_beats.delete();
        end
    endtask

    // ------------------------------------------------------------------
    // Queued transactions: C queues several reads/writes, then runs them
    // concurrently so the controller sees multiple outstanding requests
    // (back-to-back ACTs across banks, read/write turnarounds). Results of
    // queued reads stay available until the next sv_axi_run_queue().
    // ------------------------------------------------------------------
    dpi_axi_seq axi_queue[$];
    dpi_axi_seq queue_done[$];

    // automatic: module functions are static by default, and a static
    // initializer would create the sequence only once for every call
    function automatic void sv_axi_queue(input int is_write, input longint unsigned addr,
                                         input longint unsigned data, input int unsigned burst_length,
                                         input int unsigned id, input byte unsigned strb);
        dpi_axi_seq seq;
        seq = new($sformatf("axi_q%0d", axi_queue.size()));
        seq.is_write     = (is_write != 0);
        seq.addr         = addr;
        seq.wdata        = data;
        seq.burst_length = burst_length;
        seq.id           = id[8:0];
        seq.wstrb        = strb;
        axi_queue.push_back(seq);
    endfunction

    // Returns the number of transactions that did not complete (0 = all done)
    task automatic sv_axi_run_queue(output int unsigned not_done);
        int timeout_cnt = 0;
        bit all_done;
        while (!dpi_axi_test::rx_ready) @(posedge ACLK);
        // Copy the index inside the fork so each process gets its own sequence
        foreach (axi_queue[i]) begin
            fork
                automatic int k = i;
                axi_queue[k].start(dpi_axi_test::sm);
            join_none
        end
        do begin
            @(posedge ACLK);
            timeout_cnt++;
            all_done = 1;
            foreach (axi_queue[i]) if (!axi_queue[i].done) all_done = 0;
        end while (!all_done && timeout_cnt < AXI_TIMEOUT_CYCLES);
        not_done = 0;
        foreach (axi_queue[i]) if (!axi_queue[i].done) not_done++;
        if (not_done != 0)
            $display("%0t [DPI_AXI] queue timeout: %0d of %0d not done", $time, not_done, axi_queue.size());
        queue_done = axi_queue;
        axi_queue.delete();
    endtask

    function longint unsigned sv_axi_queue_beat(input int unsigned idx, input int unsigned beat);
        if (idx >= queue_done.size() || beat >= queue_done[idx].rdata_beats.size())
            return 64'hDEAD_BEEF_DEAD_BEEF;
        return queue_done[idx].rdata_beats[beat];
    endfunction

    function int unsigned sv_axi_last_read_len();
        return last_read_beats.size();
    endfunction

    function longint unsigned sv_axi_last_read_beat(input int unsigned idx);
        if (idx >= last_read_beats.size()) return 64'hDEAD_BEEF_DEAD_BEEF;
        return last_read_beats[idx];
    endfunction

    task automatic sv_axi_write(input longint unsigned addr, input longint unsigned data, input int unsigned burst_length);
        logic [63:0] rdata;
        axi_master_tx(1'b1, addr[63:0], data[63:0], burst_length, 8'hFF, rdata);
    endtask

    task automatic sv_axi_write_strb(input longint unsigned addr, input longint unsigned data,
                                     input int unsigned burst_length, input byte unsigned strb);
        logic [63:0] rdata;
        axi_master_tx(1'b1, addr[63:0], data[63:0], burst_length, strb, rdata);
    endtask

    // Single-beat narrow transfer (size_bytes = 1, 2 or 4). For writes the
    // caller supplies the byte strobe for the active lanes.
    task automatic sv_axi_narrow(input int is_write, input longint unsigned addr,
                                 input longint unsigned data, input int unsigned size_bytes,
                                 input byte unsigned strb, output longint unsigned rdata);
        dpi_axi_seq seq;
        int timeout_cnt = 0;
        while (!dpi_axi_test::rx_ready) @(posedge ACLK);
        seq = new("axi_narrow");
        seq.is_write     = (is_write != 0);
        seq.addr         = addr;
        seq.wdata        = data;
        seq.burst_length = 1;
        seq.wstrb        = strb;
        seq.size_bytes   = size_bytes;
        fork seq.start(dpi_axi_test::sm); join_none
        while (!seq.done && timeout_cnt < AXI_TIMEOUT_CYCLES) begin
            @(posedge ACLK);
            timeout_cnt++;
        end
        if (!seq.done) $display("%0t [DPI_AXI] narrow %s timeout addr=0x%08x", $time,
                                is_write ? "WRITE" : "READ", addr[31:0]);
        rdata = seq.done ? seq.result : 64'hDEAD_BEEF_DEAD_BEEF;
    endtask

    task automatic sv_axi_read(input longint unsigned addr, output longint unsigned data, input int unsigned burst_length);
        logic [63:0] rdata;
        axi_master_tx(1'b0, addr[63:0], 64'h0, burst_length, 8'hFF, rdata);
        data = rdata;
    endtask

    initial begin
        uvm_config_db#(svt_axi_vif)::set(uvm_root::get(), "uvm_test_top.dpi_axi_test.axi_system_env", "vif", axi_if);
        uvm_config_db#(svt_axi_vif)::set(uvm_root::get(), "uvm_test_top.combined_test.dpi_axi_test.axi_system_env", "vif", axi_if);
    end

endmodule
