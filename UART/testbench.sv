`define TCLK 5  // 100Mhz
`timescale 1ns / 1ns

/*
src="testbench.sv clock_divider.sv"
iverilog -Wall -g2012 -I ../ -o dir/baud_tb.vvp -s baud_tb ${src};
vvp dir/baud_tb.vvp
*/
module baud_tb;
    logic clk;
    logic res_n = 1'b0;
    logic clk_out2, clk_out3, clk_out4, clk_out5, clk_out6, clk_out7, clk_out8, clk_out9, clk_out10;

    clock_divider uut2 (.clk_in(clk), .res_n(res_n), .div(16'd2), .clk_out(clk_out2));
    clock_divider uut3 (.clk_in(clk), .res_n(res_n), .div(16'd3), .clk_out(clk_out3));
    clock_divider uut4 (.clk_in(clk), .res_n(res_n), .div(16'd4), .clk_out(clk_out4));
    clock_divider uut5 (.clk_in(clk), .res_n(res_n), .div(16'd5), .clk_out(clk_out5));
    clock_divider uut6 (.clk_in(clk), .res_n(res_n), .div(16'd6), .clk_out(clk_out6));
    clock_divider uut7 (.clk_in(clk), .res_n(res_n), .div(16'd7), .clk_out(clk_out7));
    clock_divider uut8 (.clk_in(clk), .res_n(res_n), .div(16'd8), .clk_out(clk_out8));
    clock_divider uut9 (.clk_in(clk), .res_n(res_n), .div(16'd9), .clk_out(clk_out9));
    clock_divider uut10 (.clk_in(clk), .res_n(res_n), .div(16'd10), .clk_out(clk_out10));

    always #`TCLK clk = ~clk;
    initial begin
        $dumpfile("dir/baud_tb.vcd");
        $dumpvars(0, baud_tb);
        clk = 1'b1;
        res_n = 1'b1;
        @(posedge clk) res_n = 1'b0;
        @(posedge clk);
        @(posedge clk) res_n = 1'b1;
        #5000 $finish;
    end
endmodule


/*
src="testbench.sv uart_rx.sv clock_divider.sv ../shift_reg.v"
iverilog -Wall -g2012 -I ../ -o dir/uart_rx_tb.vvp -s uart_rx_tb ${src};
vvp dir/uart_rx_tb.vvp
*/
module uart_rx_tb;
    localparam DATA_WIDTH = 8;
    logic clk;
    logic res_n;
    logic valid;
    logic din;
    logic b_tick;
    logic err_par;
    logic err_fr;
    logic [DATA_WIDTH-1:0] uart_rx_out;
    localparam DIV = 16'h4;
    localparam baud_wait = `TCLK*2*16*DIV;

    clock_divider rx_baud (.clk_in(clk), .res_n(res_n), .div(DIV), .clk_out(b_tick));

    uart_rx #(DATA_WIDTH) dut (
        .clk(clk),
        .res_n(res_n),
        .rx_baud(b_tick),
        .rx_din(din),
        .rx_out(uart_rx_out),
        .rx_ready(valid),
        .err_par(err_par),
        .err_fr(err_fr)
    );

    always #`TCLK clk  = ~clk;

    task driver(input logic [DATA_WIDTH-1:0] tx_data);
        int i;
        begin
            // start bit
            #baud_wait din = 1'b0;
            // data bits
            for (i = 0; i < DATA_WIDTH; i = i + 1)    
                #baud_wait din = tx_data[i];
            // parity
            #baud_wait din = ^tx_data;
            // stop bits
            #baud_wait din = 1'b1;
            #baud_wait din = 1'b1;
            // some wait
            #baud_wait;
            #baud_wait;
        end
    endtask

    initial begin
        $dumpfile("dir/uart_rx_tb.vcd");
        $dumpvars(0);
        $monitor("%t RX: din=%0b dout=%0b, rx_ready=%0b, err_par=%0b, err_fr=%0b", $time, din, uart_rx_out, valid, err_par, err_fr);
        clk = 1'b1;
        res_n = 1'b1;
        @(posedge clk) res_n = 1'b0;
        repeat(2) @(posedge clk);
        res_n = 1'b1;
        din = 1'b1;
        driver(8'hB2);
        driver(8'hAA);
        driver(8'h95);
        $finish;
    end
endmodule


/*
src="testbench.sv uart_tx.sv clock_divider.sv ../shift_reg.v"
iverilog -Wall -g2012 -I ../ -o dir/uart_tx_tb.vvp -s uart_tx_tb ${src};
vvp dir/uart_tx_tb.vvp
*/
module uart_tx_tb;
    logic clk;
    logic res_n;
    logic en;
    logic uart_tx_out;
    logic valid;
    logic b_tick;
    logic [7:0] din;
    localparam DIV = 4;

    clock_divider tx_baud (.clk_in(clk), .res_n(res_n), .div(DIV), .clk_out(b_tick));

    uart_tx #(8) dut (
        .clk(clk),
        .res_n(res_n),
        .tx_baud(b_tick),
        .tx_start(en),
        .tx_din(din),
        .tx_dout(uart_tx_out),
        .tx_ready(valid)
    );

    always #`TCLK clk  = ~clk;
    initial begin
        $dumpfile("dir/uart_tx_tb.vcd");
        $dumpvars(0);
        $monitor("%t TX: din=%0b dout=%0b", $time, din, uart_tx_out);
        clk = 1'b1;
        res_n = 1'b1;
        @(posedge clk) res_n = 1'b0;
        repeat(2) @(posedge clk);
        res_n = 1'b1;
        //@(posedge clk) res_n = 1'b0;
        repeat(16*DIV) @(posedge clk);
        din = 8'hB2;
        en = 1'b1;
        repeat(2) @(posedge clk);
        @(posedge valid);
        din = 8'hAA;
        @(posedge valid);
        repeat(48*DIV) @(posedge clk);
        $finish;
    end
endmodule


/*
src="testbench.sv uart.sv clock_divider.sv uart_tx.sv uart_rx.sv ../fifo.v ../shift_reg.v"
iverilog -Wall -g2012 -I ../ -o dir/uart_tb.vvp -s uart_tb ${src};
vvp dir/uart_tb.vvp
*/
module uart_tb;
    localparam DATA_WIDTH = 8;
    logic clk;
    logic res_n;
    logic [11:0] divisor;
    logic rd_uart;
    logic wr_uart;
    logic tx_ext;
    logic rx_empty;
    logic tx_full;
    logic [DATA_WIDTH-1:0] rd_data, wr_data;
    int byte_wait;

    uart uut (
        .clk(clk),
        .res_n(res_n),
        .divisor(divisor),
        .wr_data(wr_data),
        .rd_uart(rd_uart),
        .wr_uart(wr_uart),
        .rx_ext(tx_ext),
        .tx_ext(tx_ext),
        .rx_empty(rx_empty),
        .tx_full(tx_full),
        .rd_data(rd_data)
    );
    
    always #5 clk = ~clk;
    assign rd_uart = ~rx_empty;

    initial begin
        $dumpfile("dir/UART_VTB.vcd");
        $dumpvars();
        $monitor("%t [TB INFO] wr_data=%0h rd_data=%0h", $time, wr_data, rd_data);
        clk = 0;
        res_n = 1;
        divisor = 430; // 100mhz / 16*(9600*12/8)
        byte_wait = divisor * 16 * 12;
        @(posedge clk) res_n = 0;
        @(posedge clk) res_n = 1;

        @(negedge clk) wr_uart = 1;
        wr_data = 'hAB;
        @(negedge clk) wr_uart = 0;
        wait(rd_data == 'hAB);
        repeat(byte_wait) @(negedge clk); // some pause before proceeding

        @(negedge clk) wr_uart = 1;
        wr_data = 'hDA;
        @(negedge clk) wr_data = 'hC2;
        @(negedge clk) wr_data = 'hB9;
        @(negedge clk) wr_data = 'hB2;
        @(negedge clk) wr_uart = 0;
        repeat(byte_wait*5) @(posedge clk);

        $display("UART TB FINISH");
        $finish;
    end
endmodule
