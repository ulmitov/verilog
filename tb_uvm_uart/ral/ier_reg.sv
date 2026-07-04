class ier_reg extends base_reg;
    `uvm_object_utils(ier_reg)

    rand uvm_reg_field ERBI;
    rand uvm_reg_field ETBEI;
    rand uvm_reg_field ELSI;
    rand uvm_reg_field EDSSI;
    rand uvm_reg_field reserved;

    function new(string name = "IER");
        super.new(name);
    endfunction

    virtual function void build();
        ERBI = uvm_reg_field::type_id::create("ERBI");
        ETBEI = uvm_reg_field::type_id::create("ETBEI");
        ELSI = uvm_reg_field::type_id::create("ELSI");
        EDSSI = uvm_reg_field::type_id::create("EDSSI");

        ERBI.configure(
            .parent(this), .size(1), .lsb_pos(`UART_IER_ERBFI),
            .access("RW"), .volatile(0), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
        ETBEI.configure(
            .parent(this), .size(1), .lsb_pos(`UART_IER_ETBEI),
            .access("RW"), .volatile(0), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
        ELSI.configure(
            .parent(this), .size(1), .lsb_pos(`UART_IER_ELSI),
            .access("RW"), .volatile(0), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
        EDSSI.configure(
            .parent(this), .size(1), .lsb_pos(`UART_IER_EDSSI),
            .access("RW"), .volatile(0), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
        reserved = uvm_reg_field::type_id::create("reserved");
        reserved.configure(
            .parent(this), .size(4), .lsb_pos(`UART_IER_EDSSI + 1),
            .access("RW"), .volatile(0), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
    endfunction
endclass
