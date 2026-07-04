class csr_adapter extends uvm_reg_adapter;
    `uvm_object_utils(csr_adapter)
    transaction req;

    function new(string name = "ADP");
        super.new(name);
        provides_responses = 1;
    endfunction

    function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
        req = transaction::type_id::create();
        req.pwrite = rw.kind == UVM_WRITE;
        req.paddr = rw.addr;
        req.psel = 1;
        req.presetn = 1;
        if (req.pwrite)
            req.pwdata = rw.data;
        else
            req.prdata = rw.data;
        uvm_report_info("reg2bus", req.convert2string(), UVM_FULL);
        return req;
    endfunction

    function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
        if (!$cast(req, bus_item)) begin
            uvm_report_fatal(get_name(), "Bus item type is incorrect");
            return;
        end
        rw.kind = req.pwrite ? UVM_WRITE : UVM_READ;
        rw.addr = req.paddr;
        rw.data = req.pwrite ? req.pwdata : req.prdata;
        rw.status = req.pready & ~req.pslverr ? UVM_IS_OK : UVM_NOT_OK;
        uvm_report_info("bus2reg", req.convert2string(), UVM_FULL);
    endfunction
endclass
