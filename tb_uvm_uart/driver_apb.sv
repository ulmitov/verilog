`define DCB vif.mp_drv.cb_drv
`define APB_SKIP_SETUP


class driver_apb extends uvm_driver#(transaction);
    `uvm_component_utils(driver_apb)
    virtual interface_apb vif;
    longint count = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase ph);
        super.build_phase(ph);
        req = transaction::type_id::create("REQ");
        rsp = transaction::type_id::create("RSP");
        if (!uvm_config_db#(virtual interface_apb)::get(this, "", "vif_apb", vif))
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
        uvm_report_info(get_name(), req.convert2string(), UVM_FULL);
        `DCB.psel   <= req.psel;
        `DCB.paddr  <= req.paddr;
        `DCB.pwrite <= req.pwrite;
        `DCB.pwdata <= req.pwdata;
        `DCB.presetn <= req.presetn;
        if (req.delay_cycles | ~req.presetn | ~req.psel)
            `DCB.penable <= 1'b0;

        // forcing delay via sequences
        repeat(req.delay_cycles) @(`DCB);
        if (~req.presetn | ~req.psel) @(`DCB) return;
        count++;

        // APB inserts additional clock phase which makes testing too much tolerant
        `ifdef APB_SKIP_SETUP
            `DCB.penable <= 1'b1;
            @(`DCB) `DCB.penable <= 1'b0;
            return;
        `endif

        // SETUP PHASE
        `DCB.penable <= 1'b0;

        // ACCESS PHASE
        @(`DCB) `DCB.penable <= 1'b1;
        while (`DCB.pready !== 1'b1) @(`DCB);

        // IDLE PHASE
        `DCB.penable <= 1'b0;
    endtask
endclass
