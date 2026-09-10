`include "uvm_pkg.sv"
`include "svt_apb.uvm.pkg"
`include "svt_apb_if.svi"

import uvm_pkg::*;
import svt_uvm_pkg::*;
import svt_apb_uvm_pkg::*;

`include "apb_shared_cfg.sv"

// =============================================================================
// UVM test that builds two independent Synopsys APB system environments:
//   - apb3_env : APB3 master on DRAM_CFG_APB    (UMCTL2 configuration bus)
//   - apb4_env : APB4 master on DRAM_PHY_CFG_APB (multiPHY configuration bus)
// The master sequencers and readiness flags are exposed to the DPI-C bridge
// (module dpi_apb below) through static handles.
// =============================================================================
class dpi_apb_test extends uvm_test;

  `uvm_component_utils(dpi_apb_test)

  svt_apb_system_env apb3_env;
  svt_apb_system_env apb4_env;
  apb_shared_cfg cfg;

  static svt_apb_master_sequencer s3;
  static svt_apb_master_sequencer s4;
  static bit r3;
  static bit r4;

  function new(string name = "dpi_apb_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(apb_shared_cfg)::get(this, "", "cfg", cfg)) begin
      cfg = apb_shared_cfg::type_id::create("cfg", this);
    end

    cfg.force_x_on_pclk    = 0;
    cfg.force_x_on_presetn = 0;

    cfg.master_cfg.apb4_enable = 0;
    cfg.master_cfg.paddr_width = svt_apb_system_configuration::PADDR_WIDTH_32;
    cfg.master_cfg.pdata_width = svt_apb_system_configuration::PDATA_WIDTH_32;

    cfg.slave_cfg.apb4_enable  = 1;
    cfg.slave_cfg.paddr_width  = svt_apb_system_configuration::PADDR_WIDTH_32;
    cfg.slave_cfg.pdata_width  = svt_apb_system_configuration::PDATA_WIDTH_16;
    cfg.slave_cfg.is_active    = 1;
    cfg.slave_cfg.slave_cfg[0].is_active = 0;
    cfg.slave_cfg.slave_addr_allocation_enable = 0;
    cfg.slave_cfg.slave_addr_ranges = new[cfg.slave_cfg.num_slaves];
    foreach (cfg.slave_cfg.slave_addr_ranges[i]) begin
      cfg.slave_cfg.slave_addr_ranges[i] = new($sformatf("slave_addr_ranges['d%0d]", i));
      cfg.slave_cfg.slave_addr_ranges[i].start_addr = 32'h0000_0000;
      cfg.slave_cfg.slave_addr_ranges[i].end_addr   = 32'hFFFF_FFFF;
      cfg.slave_cfg.slave_addr_ranges[i].slave_id   = i;
    end
    $display("%0t [DPI_APB] slave_cfg ranges size=%0d, num_slaves=%0d", $time, cfg.slave_cfg.slave_addr_ranges.size(), cfg.slave_cfg.num_slaves);

    uvm_config_db#(svt_apb_system_configuration)::set(this, "apb3_env", "cfg", cfg.master_cfg);
    apb3_env = svt_apb_system_env::type_id::create("apb3_env", this);

    uvm_config_db#(svt_apb_system_configuration)::set(this, "apb4_env", "cfg", cfg.slave_cfg);
    apb4_env = svt_apb_system_env::type_id::create("apb4_env", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    s3 = apb3_env.master.sequencer;
    s4 = apb4_env.master.sequencer;
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "hold apb vip alive");
    r3 = 1;
    r4 = 1;
    forever begin
      #1;
    end
  endtask

endclass

// =============================================================================
// Single-transfer sequence usable on either master sequencer.  Used by the
// DPI-C bridge so completion and read data go through the standard VIP
// response mechanism (get_response), matching the SVT reference sequences.
// =============================================================================
class dpi_apb_seq extends svt_apb_master_base_sequence;

  `uvm_object_utils(dpi_apb_seq)

  bit          is_write;
  bit [31:0]   addr;
  bit [31:0]   wdata;
  bit [31:0]   result;
  bit          done;

  function new(string name = "dpi_apb_seq");
    super.new(name);
  endfunction

  virtual task pre_body();
  endtask

  virtual task post_body();
  endtask

  virtual task body();
    svt_apb_master_transaction txn;
    svt_apb_master_transaction rsp;

    super.body();
    if (!is_write && addr == 32'h0004_017c)
      $display("%0t [DPI_APB] seq cfg ranges size=%0d slave_id=%0d", $time,
               cfg.slave_addr_ranges.size(), cfg.get_slave_id(addr, 1));
    txn = svt_apb_master_transaction::type_id::create("txn");
    txn.cfg       = cfg;
    txn.xact_type = is_write ? svt_apb_transaction::WRITE : svt_apb_transaction::READ;
    txn.address   = addr;
    txn.data      = wdata;

    start_item(txn);
    finish_item(txn);
    get_response(rsp);

    result = (rsp != null) ? rsp.data[31:0] : txn.data[31:0];
    done   = 1;
  endtask

endclass

// =============================================================================
// DPI-C bridge: drives the two APB VIPs from C code.
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
        uvm_config_db#(svt_apb_vif)::set(uvm_root::get(), "uvm_test_top.apb3_env", "vif", apb3_if);
        uvm_config_db#(svt_apb_vif)::set(uvm_root::get(), "uvm_test_top.apb4_env", "vif", apb4_if);
        run_test("dpi_apb_test");
    end

endmodule