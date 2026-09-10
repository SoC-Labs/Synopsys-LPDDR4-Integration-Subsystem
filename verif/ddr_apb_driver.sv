
`include "uvm_pkg.sv"
`include "svt_apb.uvm.pkg"
`include "svt_apb_if.svi" //top-level APB interface
`include "apb_shared_cfg.sv"

import uvm_pkg::*;
import svt_uvm_pkg::*;
import svt_apb_uvm_pkg::*;

module ddr_apb_driver(
    input  wire     PCLK,
    input  wire     PRESETn,
    apb4.master     apb_bus
);

svt_apb_if apb_if();
assign apb_if.pclk = PCLK;
assign apb_if.presetn = PRESETn;
assign apb_bus.paddr=apb_if.paddr;
assign apb_bus.pwdata = apb_if.pwdata;
assign apb_bus.penable = apb_if.penable;
assign apb_bus.pwrite = apb_if.pwrite;
assign apb_bus.psel = apb_if.psel;
assign apb_bus.pprot = apb_if.pprot;
assign apb_bus.pstrb = apb_if.pstrb;
assign apb_if.prdata[0][31:0] = apb_bus.prdata[31:0];
assign apb_if.pready = apb_bus.pready;
assign apb_if.pslverr[0] = apb_bus.pslverr;

svt_apb_system_env apb_master_env;

/** APB System Configuration */
apb_shared_cfg cfg;


initial begin
    /**
     * Provide the APB SV interfaces to the APB System ENV. This step establishes the
     * connection between the APB System ENV and the HDL Interconnect wrapper, through the
     * APB interfaces.
     */
    /**
     * Check if the configuration is passed to the environment.
     * If not then create the configuration and pass it to the VIP ENV.
     */
    cfg = apb_shared_cfg::type_id::create("cfg", uvm_root::get());

    /** Apply the configuration to the Master ENV */
    uvm_config_db#(svt_apb_system_configuration)::set(uvm_root::get(), "apb_master_env", "cfg", cfg.master_cfg);

    uvm_config_db#(svt_apb_vif)::set(uvm_root::get(), "apb_master_env", "vif", apb_if);
    /** Construct the system agents */
    apb_master_env = svt_apb_system_env::type_id::create("apb_master_env", uvm_root::get());

end

endmodule
