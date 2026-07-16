import config_pkg::*;


interface interface_apb (input logic pclk);
    logic psel;
    logic presetn;
    logic penable;
    logic pwrite;
    logic [AWIDTH-1:0] paddr;
    logic [APB_DATA_WIDTH-1:0] prdata;
    logic [APB_DATA_WIDTH-1:0] pwdata;
    // outputs:
    logic pready;
    logic pslverr;


    clocking cb_drv @(posedge pclk);
        //default input #SETUP_TIME output #HOLDTIME;
        input pready;
        input pslverr;
        input prdata;
        output presetn;
        output paddr;
        output psel;
        output pwdata;
        output penable;
        output pwrite;
    endclocking

    clocking cb_mon @(posedge pclk);
        //default input #SETUP_TIME;
        input presetn;
        input prdata;
        input paddr;
        input psel;
        input pwdata;
        input penable;
        input pwrite;
        input pready;
        input pslverr;
    endclocking

    modport mp_drv(clocking cb_drv);
    modport mp_mon(clocking cb_mon);

    property prop_pready;
        @(posedge pclk) disable iff (~presetn | ~psel | $isunknown(paddr))
            ~$isunknown(pready);
    endproperty
    property prop_slverr;
        @(posedge pclk) pready |-> ~$isunknown(pslverr);
    endproperty
    property prop_prdata;
        @(posedge pclk) pready |-> ~$isunknown(prdata);
    endproperty

    cov_pready: cover property (prop_pready);
    cov_slverr: cover property (prop_slverr);
    cov_prdata: cover property (prop_prdata);

    assert property (prop_pready) else
    uvm_report_error("VIF", $sformatf("paddr %0h unknown pready", paddr));
    assert property (prop_slverr) else
    uvm_report_error("VIF", $sformatf("paddr %0h unknown pslverr", paddr));
    assert property (prop_prdata) else
    uvm_report_error("VIF", $sformatf("paddr %0h unknown prdata", paddr));
endinterface
