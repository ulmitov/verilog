`define PINS vif.mp_drv.cb_drv


class driver_pin extends uvm_driver#(pin_sample);
    `uvm_component_utils(driver_pin)
    virtual interface_pin vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase ph);
        super.build_phase(ph);
        req = pin_sample::type_id::create("REQ");
        if (!uvm_config_db#(virtual interface_pin)::get(this, "", "vif_pin", vif))
            uvm_report_fatal(get_name(), "vif_pin is not in db");
    endfunction

    task run_phase(uvm_phase ph);
        super.run_phase(ph);
        `PINS.sin <= 1'b1;
        forever begin
            seq_item_port.get_next_item(req);
            drive();
            seq_item_port.item_done();
        end
    endtask

    task drive();
        @(`PINS);
        //uvm_report_info(get_name(), req.convert2string(), UVM_FULL);
        `PINS.sin  <= req.sin;
    endtask
endclass
