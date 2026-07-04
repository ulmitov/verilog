class iir_reg extends base_reg;
    `uvm_object_utils(iir_reg)

    uvm_reg_field IPEND;
    uvm_reg_field INTID;
    uvm_reg_field FIOEN;

    function new(string name = "IIR");
        super.new(name);
    endfunction

    virtual function void build();
        IPEND = uvm_reg_field::type_id::create("IPEND");
        INTID = uvm_reg_field::type_id::create("INTID");
        FIOEN = uvm_reg_field::type_id::create("FIOEN");

        IPEND.configure(
            .parent(this), .size(1), .lsb_pos(`UART_IIR_IPEND),
            .access("RO"), .volatile(0), .reset(1),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
        INTID.configure(
            .parent(this), .size(3), .lsb_pos(`UART_IIR_INTID),
            .access("RO"), .volatile(0), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
        FIOEN.configure(
            .parent(this), .size(2), .lsb_pos(`UART_IIR_FIFOEN),
            .access("RO"), .volatile(0), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
    endfunction
endclass
