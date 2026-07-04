class fcr_reg extends base_reg;
    `uvm_object_utils(fcr_reg)

    rand uvm_reg_field FIFOEN;
    rand uvm_reg_field RXCLR;
    rand uvm_reg_field TXCLR;
    rand uvm_reg_field DMAMODE;
    rand uvm_reg_field RXFIFTL;

    function new(string name = "FCR");
        super.new(name);
    endfunction

    virtual function void build();
        FIFOEN = uvm_reg_field::type_id::create("FIFOEN");
        RXCLR = uvm_reg_field::type_id::create("RXCLR");
        TXCLR = uvm_reg_field::type_id::create("TXCLR");
        DMAMODE = uvm_reg_field::type_id::create("DMAMODE");
        RXFIFTL = uvm_reg_field::type_id::create("RXFIFTL");

        FIFOEN.configure(
            .parent(this), .size(1), .lsb_pos(`UART_FCR_FIFOEN),
            .access("WO"), .volatile(0), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
        RXCLR.configure(
            .parent(this), .size(1), .lsb_pos(`UART_FCR_RXCLR),
            .access("WO"), .volatile(0), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
        TXCLR.configure(
            .parent(this), .size(1), .lsb_pos(`UART_FCR_TXCLR),
            .access("WO"), .volatile(0), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
        DMAMODE.configure(
            .parent(this), .size(1), .lsb_pos(`UART_FCR_DMAMODE),
            .access("WO"), .volatile(0), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
        RXFIFTL.configure(
            .parent(this), .size(2), .lsb_pos(`UART_FCR_RXFIFTL),
            .access("WO"), .volatile(0), .reset(0),
            .has_reset(1), .is_rand(1), .individually_accessible(0)
        );
    endfunction
endclass
