class mcr_reg extends base_reg;
    `uvm_object_utils(mcr_reg)

    rand uvm_reg_field DTR;
    rand uvm_reg_field RTS;
    rand uvm_reg_field OUT1;
    rand uvm_reg_field OUT2;
    rand uvm_reg_field LOOP;
    rand uvm_reg_field AFE;

    function new(string name = "MCR");
        super.new(name);
    endfunction

    virtual function void build();
        DTR = uvm_reg_field::type_id::create("DTR");
        RTS = uvm_reg_field::type_id::create("RTS");
        OUT1 = uvm_reg_field::type_id::create("OUT1");
        OUT2 = uvm_reg_field::type_id::create("OUT2");
        LOOP = uvm_reg_field::type_id::create("LOOP");
        AFE = uvm_reg_field::type_id::create("AFE");

        DTR.configure(
            .parent(this), .size(1), .lsb_pos(`UART_MCR_DTR),
            .access("RW"), .volatile(0), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
        RTS.configure(
            .parent(this), .size(1), .lsb_pos(`UART_MCR_RTS),
            .access("RW"), .volatile(0), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
        OUT1.configure(
            .parent(this), .size(1), .lsb_pos(`UART_MCR_OUT1),
            .access("RW"), .volatile(0), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
        OUT2.configure(
            .parent(this), .size(1), .lsb_pos(`UART_MCR_OUT2),
            .access("RW"), .volatile(0), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
        LOOP.configure(
            .parent(this), .size(1), .lsb_pos(`UART_MCR_LOOP),
            .access("RW"), .volatile(0), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
        AFE.configure(
            .parent(this), .size(1), .lsb_pos(`UART_MCR_AFE),
            .access("RW"), .volatile(0), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
    endfunction
endclass
