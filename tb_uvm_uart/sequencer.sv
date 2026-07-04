class sequencer_apb extends uvm_sequencer#(transaction);
    `uvm_component_utils(sequencer_apb)
    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass


class sequencer_pins extends uvm_sequencer#(pin_sample);
    `uvm_component_utils(sequencer_pins)
    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass


class virtual_sequencer extends uvm_sequencer;
  `uvm_component_utils(virtual_sequencer)

  sequencer_apb sqr_apb;
  sequencer_pins sqr_pin;

  function new(string name, uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass
