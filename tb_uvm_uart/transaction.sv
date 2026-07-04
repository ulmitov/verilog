import config_pkg::*;


class transaction extends uvm_sequence_item;
    `uvm_object_utils(transaction)
    rand bit presetn;
    rand bit psel;
    rand bit penable;
    rand bit pwrite;
    rand bit [AWIDTH-1:0] paddr;
    rand bit [DWIDTH-1:0] pwdata;
    bit [31:0] delay_cycles;
    bit [DWIDTH-1:0] prdata;
    // outputs:
    bit pready;
    bit pslverr;

    constraint c_psel { psel == 1; };
    constraint c_presetn { presetn == 1; };

    function new(string name="seq_item");
        super.new(name);
    endfunction
    function string convert2string;
        string tpl = "presetn[%0d]  psel[%0d]  penable[%0d]  pready[%0d]  pwrite[%0d]  pslverr[%0d]  paddr[%0x]  pwdata[%0x]  prdata[%0x]\n";
        return $sformatf(tpl, presetn, psel, penable, pready, pwrite, pslverr, paddr, pwdata, prdata);
    endfunction
    task display(input string name = "");
        if (name == "") name = get_name();
        $display("%0t [%s] %s", $time, name, convert2string());
    endtask
endclass


class pin_sample extends uvm_sequence_item;
    `uvm_object_utils(pin_sample)
    // uart in-ports:
    rand bit sin;
    bit rclk;
    bit res_n;
    // uart out-ports:
    bit baudout;
    bit sout;
    bit intr;

    function new(string name="pin_item");
        super.new(name);
    endfunction
    function string convert2string;
        string tpl = "res_n[%0d] rclk[%0d]  sin[%0d]  sout[%0d]  baudout[%0d]  intr[%0d]\n";
        return $sformatf(tpl, res_n, rclk, sin, sout, baudout, intr);
    endfunction
    task display(input string name = "");
        if (name == "") name = get_name();
        $display("%0t [%s] %s", $time, name, convert2string());
    endtask
endclass
