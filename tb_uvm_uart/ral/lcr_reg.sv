class lcr_reg extends base_reg;
    `uvm_object_utils(lcr_reg)

    rand uvm_reg_field WLS;
    rand uvm_reg_field STB;
    rand uvm_reg_field PEN;
    rand uvm_reg_field EPS;
    rand uvm_reg_field SP;
    //rand uvm_reg_field PS;
    rand uvm_reg_field BC;
    rand uvm_reg_field DL;

    function new(string name = "LCR");
        super.new(name);
    endfunction

    virtual function void build();
        WLS = uvm_reg_field::type_id::create("WLS");
        STB = uvm_reg_field::type_id::create("STB");
        PEN = uvm_reg_field::type_id::create("PEN");
        EPS = uvm_reg_field::type_id::create("EPS");
        SP = uvm_reg_field::type_id::create("SP");
        //PS = uvm_reg_field::type_id::create("PS");
        BC = uvm_reg_field::type_id::create("BC");
        DL = uvm_reg_field::type_id::create("DL");

        WLS.configure(
            .parent(this), .size(2), .lsb_pos(`UART_LCR_WLS),
            .access("RW"), .volatile(0), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
        STB.configure(
            .parent(this), .size(1), .lsb_pos(`UART_LCR_STB),
            .access("RW"), .volatile(0), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
        PEN.configure(
            .parent(this), .size(1), .lsb_pos(`UART_LCR_PEN),
            .access("RW"), .volatile(0), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
        EPS.configure(
            .parent(this), .size(1), .lsb_pos(`UART_LCR_EPS),
            .access("RW"), .volatile(0), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
        SP.configure(
            .parent(this), .size(1), .lsb_pos(`UART_LCR_SP),
            .access("RW"), .volatile(0), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
        BC.configure(
            .parent(this), .size(1), .lsb_pos(`UART_LCR_BC),
            .access("RW"), .volatile(0), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
        DL.configure(
            .parent(this), .size(1), .lsb_pos(`UART_LCR_DL),
            .access("RW"), .volatile(0), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
    endfunction
endclass
