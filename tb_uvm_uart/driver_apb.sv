`define DCB vif_apb.mp_drv.cb_drv


class driver_apb extends uvm_driver#(transaction);
    `uvm_component_utils(driver_apb)

    virtual interface_apb vif_apb;
    longint count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        count = 0;
    endfunction

    function void build_phase(uvm_phase ph);
        super.build_phase(ph);
        req = transaction::type_id::create("REQ");
        rsp = transaction::type_id::create("RSP");
        if (!uvm_config_db#(virtual interface_apb)::get(this, "", "vif_apb", vif_apb))
            uvm_report_fatal(get_name(), "vif_apb is not in db");
    endfunction

    task run_phase(uvm_phase ph);
        super.run_phase(ph);
        
        forever begin
            seq_item_port.get_next_item(req);
            drive();
            // Return response to sequencer
            if (req.presetn & req.psel) begin
                rsp = req;
                rsp.set_id_info(req);
                rsp.penable = `DCB.pready;
                rsp.pready  = `DCB.pready;
                rsp.pslverr = `DCB.pslverr;
                rsp.prdata  = `DCB.prdata;
                uvm_report_info("APB_RSP", rsp.convert2string(), UVM_FULL);
                rsp_port.write(rsp);
            end
            seq_item_port.item_done();
        end
    endtask

    task drive();
        // SETUP PHASE
        uvm_report_info(get_name(), req.convert2string(), UVM_FULL);
        `DCB.psel   <= req.psel;
        `DCB.paddr  <= req.paddr;
        `DCB.pwrite <= req.pwrite;
        `DCB.pwdata <= req.pwdata;
        `DCB.presetn <= req.presetn;
        `DCB.penable <= 1'b0;
        repeat(req.delay_cycles) @(`DCB);       // injecting cycles delay via sequence
        if (~req.presetn | ~req.psel) @(`DCB) return;
        count++;

        // ACCESS PHASE
        @(`DCB) `DCB.penable <= 1'b1;
        while (`DCB.pready !== 1'b1) @(`DCB);
        // IDLE PHASE
        `DCB.penable <= 1'b0;
        //`DCB.psel <= 1'b0;
    endtask
endclass
