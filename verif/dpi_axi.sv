`include "uvm_pkg.sv"
`include "svt_axi.uvm.pkg"
`include "svt_axi_if.svi"

import uvm_pkg::*;
import svt_uvm_pkg::*;
import svt_axi_uvm_pkg::*;

`include "axi_slave_mem_response_sequence.sv"

// =============================================================================
// UVM test that builds a single Synopsys AXI system environment:
//   - axi_system_env : 1 active AXI master + 1 active AXI slave (with built-in
//     memory, driven by the axi_slave_mem_response_sequence default responder)
// The master sequencer and a readiness flag are exposed to the DPI-C bridge
// (module dpi_axi below) through static handles.
// =============================================================================
class dpi_axi_test extends uvm_test;

  `uvm_component_utils(dpi_axi_test)

  svt_axi_system_env        axi_system_env;
  svt_axi_system_configuration cfg;

  static svt_axi_master_sequencer sm;
  static bit rx_ready;

  function new(string name = "dpi_axi_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    cfg = svt_axi_system_configuration::type_id::create("cfg");
    cfg.num_masters          = 1;
    cfg.num_slaves           = 1;
    cfg.system_monitor_enable = 0;
    cfg.create_sub_cfgs(1, 1);

    cfg.master_cfg[0].data_width = 64;
    cfg.master_cfg[0].id_width   = 8;
    cfg.master_cfg[0].axi_interface_type = svt_axi_port_configuration::AXI4;
    cfg.slave_cfg[0].data_width  = 64;
    cfg.slave_cfg[0].id_width    = 8;
    cfg.slave_cfg[0].axi_interface_type  = svt_axi_port_configuration::AXI4;

    cfg.set_addr_range(0, 'h0, `SVT_AXI_MAX_ADDR_WIDTH'(64'h1_FFFF_FFFF));

    $display("%0t [DPI_AXI] num_masters=%0d num_slaves=%0d data_width=%0d id_width=%0d",
             $time, cfg.num_masters, cfg.num_slaves,
             cfg.master_cfg[0].data_width, cfg.master_cfg[0].id_width);

    uvm_config_db#(svt_axi_system_configuration)::set(this, "axi_system_env", "cfg", cfg);
    axi_system_env = svt_axi_system_env::type_id::create("axi_system_env", this);

    uvm_config_db#(uvm_object_wrapper)::set(this, "axi_system_env.slave*.sequencer.run_phase",
                                            "default_sequence", axi_slave_mem_response_sequence::type_id::get());
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    sm = axi_system_env.master[0].sequencer;
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "hold axi vip alive");
    rx_ready = 1;
    forever begin
      #1;
    end
  endtask

endclass

// =============================================================================
// Single-transfer sequence usable on the master sequencer.  Used by the
// DPI-C bridge so completion and read data go through the standard VIP
// response mechanism (get_response), matching the SVT reference sequences.
// =============================================================================
class dpi_axi_seq extends svt_axi_master_base_sequence;

  `uvm_object_utils(dpi_axi_seq)

  bit          is_write;
  bit [63:0]   addr;
  bit [63:0]   wdata;
  int unsigned burst_length;
  bit [63:0]   result;
  bit          done;

  function new(string name = "dpi_axi_seq");
    super.new(name);
  endfunction

  virtual task pre_body();
  endtask

  virtual task post_body();
  endtask

  virtual task body();
    svt_axi_master_transaction txn;
    svt_axi_master_transaction rsp;

    super.body();
    if (burst_length == 0)
      burst_length = 1;

    txn = svt_axi_master_transaction::type_id::create("txn");
    txn.port_cfg     = cfg;
    txn.xact_type    = is_write ? svt_axi_transaction::WRITE : svt_axi_transaction::READ;
    txn.addr         = addr;
    txn.burst_type   = svt_axi_transaction::INCR;
    txn.burst_size   = svt_axi_transaction::BURST_SIZE_64BIT;
    txn.atomic_type  = svt_axi_transaction::NORMAL;
    txn.burst_length = burst_length;
    txn.data         = new[burst_length];
    txn.wstrb        = new[burst_length];
    foreach (txn.data[i]) begin
      txn.data[i]  = wdata + i;
      txn.wstrb[i] = 8'hFF;
    end
    if (!is_write) begin
      txn.rresp        = new[burst_length];
      txn.rready_delay = new[burst_length];
      foreach (txn.rready_delay[i])
        txn.rready_delay[i] = i;
    end
    txn.id = 'h1;

    start_item(txn);
    finish_item(txn);
    get_response(rsp);

    result = (rsp != null) ? rsp.data[0] : 64'hFFFF_FFFF_FFFF_FFFF;
    $display("%0t [DPI_AXI] %s addr=0x%08x len=%0d data=0x%016x rsp=0x%016x",
             $time, is_write ? "WRITE" : "READ", addr[31:0], burst_length, wdata, result);
    done = 1;
  endtask

endclass

// =============================================================================
// DPI-C bridge: drives the AXI VIP master from C code.
// =============================================================================
module dpi_axi #(
    parameter int  AXI_TIMEOUT_CYCLES = 1000000,
    parameter bit  CONNECT_SLAVE      = 1'b1,
    parameter bit  ENABLE             = 1'b1
)(
    input wire ACLK,
    input wire ARESETn,
    axi4   DRAM_AXI
);

    svt_axi_if axi_if ();
    axi4_svt_adapter #(.CONNECT_SLAVE(CONNECT_SLAVE)) u_axi4_adapter(axi_if, DRAM_AXI);

    assign axi_if.common_aclk          = ACLK;
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
        if (ENABLE) begin
            uvm_config_db#(svt_axi_vif)::set(uvm_root::get(), "uvm_test_top.axi_system_env", "vif", axi_if);
            run_test("dpi_axi_test");
        end
    end

endmodule