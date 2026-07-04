`define PINS_MCB vif_pin.mp_mon.cb_mon


class monitor_pin extends uvm_monitor;
    `uvm_component_utils(monitor_pin)

    pin_sample req;
    virtual interface_pin vif_pin;
    uvm_analysis_port #(pin_sample) mon_port;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase ph);
        super.build_phase(ph);
        mon_port = new("PIN_MON", this);
        if (!uvm_config_db#(virtual interface_pin)::get(this, "", "vif_pin", vif_pin))
            uvm_report_fatal(get_name(), "vif_pin is not in db");
    endfunction

    task run_phase(uvm_phase ph);
        super.run_phase(ph);
        forever begin
            monitor();
        end
    endtask

    task monitor;
        @(`PINS_MCB);
        req = pin_sample::type_id::create();
        req.rclk    = `PINS_MCB.rclk;
        req.sin     = `PINS_MCB.sin;
        req.sout    = `PINS_MCB.sout;
        req.baudout = `PINS_MCB.baudout;
        req.intr    = `PINS_MCB.intr;
        req.res_n   = `PINS_MCB.res_n;
        uvm_report_info(get_name(), req.convert2string(), UVM_FULL);
        mon_port.write(req);
    endtask
endclass
