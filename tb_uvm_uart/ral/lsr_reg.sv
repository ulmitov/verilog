class lsr_reg extends base_reg;
    `uvm_object_utils(lsr_reg)

    uvm_reg_field DR;
    uvm_reg_field OE;
    uvm_reg_field PE;
    uvm_reg_field FE;
    uvm_reg_field BI;
    uvm_reg_field TF;
    uvm_reg_field TE;
    uvm_reg_field EI;

    function new(string name = "LSR");
        super.new(name);
    endfunction

    virtual function void build();
        DR = uvm_reg_field::type_id::create("DR");
        OE = uvm_reg_field::type_id::create("OE");
        PE = uvm_reg_field::type_id::create("PE");
        FE = uvm_reg_field::type_id::create("FE");
        BI = uvm_reg_field::type_id::create("BI");
        TF = uvm_reg_field::type_id::create("TF");
        TE = uvm_reg_field::type_id::create("TE");
        EI = uvm_reg_field::type_id::create("EI");
//field_a.set_compare(UVM_NO_CHECK);
        DR.configure(
            .parent(this), .size(1), .lsb_pos(`UART_LSR_DR),
            .access("RO"), .volatile(1), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
        OE.configure(
            .parent(this), .size(1), .lsb_pos(`UART_LSR_OE),
            .access("RC"), .volatile(1), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
        PE.configure(
            .parent(this), .size(1), .lsb_pos(`UART_LSR_PE),
            .access("RC"), .volatile(1), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
        FE.configure(
            .parent(this), .size(1), .lsb_pos(`UART_LSR_FE),
            .access("RC"), .volatile(1), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
        BI.configure(
            .parent(this), .size(1), .lsb_pos(`UART_LSR_BI),
            .access("RC"), .volatile(1), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
        TF.configure(
            .parent(this), .size(1), .lsb_pos(`UART_LSR_TF),
            .access("RO"), .volatile(1), .reset(1),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
        TE.configure(
            .parent(this), .size(1), .lsb_pos(`UART_LSR_TE),
            .access("RO"), .volatile(1), .reset(1),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
        EI.configure(
            .parent(this), .size(1), .lsb_pos(`UART_LSR_EI),
            .access("RC"), .volatile(1), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
    endfunction
endclass
