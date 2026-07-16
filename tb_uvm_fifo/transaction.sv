class transaction extends uvm_sequence_item;
    rand bit push;
    rand bit pull;
    rand bit [fifo_config::DATA_WIDTH-1:0] din;
    bit [fifo_config::DATA_WIDTH-1:0] dout;
    bit empty;
    bit full;

    function new(string name="seq_item");
        super.new(name);
    endfunction

    virtual function string convert2string();
        string s = "push=%0b pull=%0b din=0x%0h dout=0x%0h empty=%0b full=%0b";
        return $sformatf(s, push, pull, din, dout, empty, full);
    endfunction
endclass
