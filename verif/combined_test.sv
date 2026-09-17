`include "uvm_pkg.sv"
`include "svt_apb.uvm.pkg"
`include "svt_apb_if.svi"
`include "svt_axi.uvm.pkg"
`include "svt_axi_if.svi"

import uvm_pkg::*;
import svt_uvm_pkg::*;
import svt_apb_uvm_pkg::*;
import svt_axi_uvm_pkg::*;

`include "apb_shared_cfg.sv"
`include "axi_slave_mem_response_sequence.sv"

// =============================================================================
// UVM test that builds a single AXI system environment:
//   - axi_system_env : 1 active AXI master (no slave, since dram_wrapper
//     is the sole subordinate on DRAM_AXI).
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
    cfg.num_slaves           = 0;
    cfg.system_monitor_enable = 0;
    cfg.create_sub_cfgs(1, 0);
    cfg.bus_inactivity_timeout = 1024000;
    cfg.master_cfg[0].data_width = 64;
    cfg.master_cfg[0].id_width   = 8;
    cfg.master_cfg[0].axi_interface_type = svt_axi_port_configuration::AXI4;
    cfg.master_cfg[0].per_clock_cycle_signal_checks_enable = 0;
    cfg.master_cfg[0].protocol_checks_enable=0;

    uvm_config_db#(svt_axi_system_configuration)::set(this, "axi_system_env", "cfg", cfg);
    axi_system_env = svt_axi_system_env::type_id::create("axi_system_env", this);
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
    if (is_write) begin
      txn.wvalid_delay = new[burst_length];
      foreach (txn.wvalid_delay[i])
        txn.wvalid_delay[i] = 1;
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
// Combined test that runs both AXI and APB environments simultaneously.
// =============================================================================
class combined_test extends uvm_test;
    `uvm_component_utils(combined_test)

    dpi_apb_test apb_test;
    dpi_axi_test  axi_test;

    function new(string name = "combined_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        apb_test = dpi_apb_test::type_id::create("dpi_apb_test", this);
        axi_test = dpi_axi_test::type_id::create("dpi_axi_test", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // Disable X/Z signal validity checks on AXI master monitor
        // These checks produce spurious errors during integration
        if (axi_test.axi_system_env.master[0].monitor.checks != null) begin
            axi_test.axi_system_env.master[0].monitor.checks.disable_checks("AMBA:AXI3", "", "signal_valid_rvalid_check");
            axi_test.axi_system_env.master[0].monitor.checks.disable_checks("AMBA:AXI3", "", "signal_valid_bvalid_check");
            $display("%0t [COMBINED_TEST] Disabled AXI X/Z checks", $time);
        end else begin
            $display("%0t [COMBINED_TEST] WARNING: monitor.checks is null", $time);
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this, "hold combined test alive");
        forever begin
            #1;
        end
    endtask
endclass
