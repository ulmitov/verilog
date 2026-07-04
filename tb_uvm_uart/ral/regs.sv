virtual class base_reg extends uvm_reg;
    function new(string name = "REG");
        super.new(name, `UART_DATA_WIDTH, UVM_NO_COVERAGE);
        add_coverage(build_coverage(UVM_NO_COVERAGE));
        build();
    endfunction
    function void do_predict(uvm_reg_item     rw,
                            uvm_predict_e     kind = UVM_PREDICT_DIRECT,
                            uvm_reg_byte_en_t be = -1);
        if (rw.status == UVM_IS_OK)
            super.do_predict(rw, kind, be);
    endfunction
    pure virtual function void build();
endclass


class common_reg #(parameter string access_policy = "RW") extends base_reg;
    rand uvm_reg_field value;
    function new(string name = "REG");
        super.new(name);
    endfunction
    virtual function void build();
        value = uvm_reg_field::type_id::create("value");
        value.configure(
            .parent(this), .size(`UART_DATA_WIDTH), .lsb_pos(0),
            .access(access_policy), .volatile(0), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
    endfunction
endclass



class rbr_reg extends common_reg#("RO");
    `uvm_object_utils(rbr_reg)
    function new(string name="RBR");
        super.new(name);
    endfunction
endclass


class thr_reg extends common_reg#("WO");
    `uvm_object_utils(thr_reg)
    function new(string name="THR");
        super.new(name);
    endfunction
endclass


class dll_reg extends common_reg;
    `uvm_object_utils(dll_reg)
    function new(string name="DLL");
        super.new(name);
    endfunction
endclass


class dlh_reg extends common_reg;
    `uvm_object_utils(dlh_reg)
    function new(string name="DLH");
        super.new(name);
    endfunction
endclass


class spr_reg extends common_reg;
    `uvm_object_utils(spr_reg)
    function new(string name="SPR");
        super.new(name);
    endfunction
endclass
