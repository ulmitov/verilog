`include "ral/regs.sv"
`include "ral/fcr_reg.sv"
`include "ral/ier_reg.sv"
`include "ral/iir_reg.sv"
`include "ral/lcr_reg.sv"
`include "ral/lsr_reg.sv"
`include "ral/mcr_reg.sv"
`include "ral/csr_adapter.sv"
`include "ral/csr_block.sv"


class ral_env extends uvm_env;
    `uvm_component_utils(ral_env)

    csr_block csr;
    csr_adapter adapter;
    uvm_reg_predictor #(transaction) predictor;

    function new(string name="ral_env", uvm_component parent);
        super.new (name, parent);
    endfunction

    function void build_phase(uvm_phase ph);
        super.build_phase(ph);
        csr         = csr_block::type_id::create("csr", this);
        adapter     = csr_adapter::type_id::create("adapter");
        predictor  	= uvm_reg_predictor#(transaction)::type_id::create("predictor", this);
        predictor.adapter = adapter;
        csr.build();
        set_default_map();
    endfunction

    function void connect_phase(uvm_phase ph);
        super.connect_phase(ph);
    endfunction

    function void set_default_map();
        predictor.map = csr.default_map;
    endfunction

    function void set_dlab_map();
        predictor.map = csr.dlab_map;
    endfunction
endclass
