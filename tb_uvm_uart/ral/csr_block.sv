class csr_block extends uvm_reg_block;
    `uvm_object_utils(csr_block)

    uvm_reg_map apb_map;
    uvm_reg_map dlab_map;
    lsr_reg lsr;
    iir_reg iir;
    rbr_reg rbr;
    rand dll_reg dll;
    rand dlh_reg dlh;
    rand thr_reg thr;
    rand fcr_reg fcr;
    rand ier_reg ier;
    rand lcr_reg lcr;
    rand mcr_reg mcr;
    //rand spr_reg spr;

    function new(string name = "uart_csr");
        super.new(name, build_coverage(UVM_CVR_ADDR_MAP));
    endfunction

    virtual function void build();
        fcr = fcr_reg::type_id::create();
        ier = ier_reg::type_id::create();
        iir = iir_reg::type_id::create();
        lcr = lcr_reg::type_id::create();
        lsr = lsr_reg::type_id::create();
        dll = dll_reg::type_id::create();
        dlh = dlh_reg::type_id::create();
        //spr = spr_reg::type_id::create();
        rbr = rbr_reg::type_id::create();
        thr = thr_reg::type_id::create();
        mcr = mcr_reg::type_id::create();

        fcr.configure(this, null, "");
        ier.configure(this, null, "");
        iir.configure(this, null, "");
        lcr.configure(this, null, "");
        lsr.configure(this, null, "");
        dll.configure(this, null, "");
        dlh.configure(this, null, "");
        //spr.configure(this, null, "");
        rbr.configure(this, null, "");
        thr.configure(this, null, "");
        mcr.configure(this, null, "");
/*
        fcr.build();
        ier.build();
        iir.build();
        lcr.build();
        lsr.build();
        //dll.build();
        //dlh.build();
        //spr.build();
        //rbr.build();
        //thr.build();
        */
        dlab_map = create_map("dlab_map", UART_BASE_ADDRESS, `UART_DATA_WIDTH / 8, UVM_LITTLE_ENDIAN);
        dlab_map.add_reg(dll, `UART_REG_DLL, "RW");
        dlab_map.add_reg(dlh, `UART_REG_DLM, "RW");

        apb_map = create_map("apb_map", UART_BASE_ADDRESS, `UART_DATA_WIDTH / 8, UVM_LITTLE_ENDIAN);
        apb_map.add_reg(fcr, `UART_REG_FCR, "WO");
        apb_map.add_reg(ier, `UART_REG_IER, "RW");
        apb_map.add_reg(iir, `UART_REG_IIR, "RO");
        apb_map.add_reg(lcr, `UART_REG_LCR, "RW");
        apb_map.add_reg(lsr, `UART_REG_LSR, "RO");
        apb_map.add_reg(rbr, `UART_REG_RBR, "RO");
        apb_map.add_reg(thr, `UART_REG_THR, "WO");
        apb_map.add_reg(mcr, `UART_REG_MCR, "RW");
        //apb_map.add_reg(spr, `UART_REG_SPR, "RW");

        //default_map.configure(.parent(this), .base_addr(), .n_bytes(`UART_DATA_WIDTH / 8), .endian(UVM_LITTLE_ENDIAN));
        //default_map.build();
        //default_map= create_map("default_map", 'h0, 4, UVM_BIG_ENDIAN, 1);
        set_default_map(apb_map);
        default_map.set_auto_predict(0);    // set to 1 if there is no predictor class
        lock_model();
        //uvm_reg::include_coverage("*", UVM_CVR_ALL);
    endfunction
endclass
