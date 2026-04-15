`include "regmap.vh"
`timescale 1ns / 1ns
`define TCLK 5  // 100Mhz


/*
src="testbench/testbench.sv clock_divider.sv"
iverilog -Wall -g2012 -o vcd/baud_tb.vvp -s baud_tb ${src};
vvp vcd/baud_tb.vvp
*/
module baud_tb;
    logic clk;
    logic res_n;
    logic clk_out2, clk_out3, clk_out4, clk_out5, clk_out6, clk_out7, clk_out8, clk_out9, clk_out10;
    integer cnt2 = 0, cnt3 = 0, cnt4 = 0, cnt5 = 0, cnt6 = 0, cnt7 = 0, cnt8 = 0, cnt9 = 0, cnt10 = 0;

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
    always @(posedge clk_out2) cnt2 = cnt2 + 1;
    always @(posedge clk_out3) cnt3 = cnt3 + 1;
    always @(posedge clk_out4) cnt4 = cnt4 + 1;
    always @(posedge clk_out5) cnt5 = cnt5 + 1;
    always @(posedge clk_out6) cnt6 = cnt6 + 1;
    always @(posedge clk_out7) cnt7 = cnt7 + 1;
    always @(posedge clk_out8) cnt8 = cnt8 + 1;
    always @(posedge clk_out9) cnt9 = cnt9 + 1;
    always @(posedge clk_out10) cnt10 = cnt10 + 1;

    initial begin
        $dumpfile("vcd/baud_tb.vcd");
        $dumpvars(0);
        clk = 1'b1;
        res_n = 1'b1;
        @(posedge clk) res_n = 1'b0;
        @(posedge clk);
        @(posedge clk) res_n = 1'b1;
        repeat(24) @(posedge clk);
        // each clock initial state is 1, so adding 1 to counters
        if (cnt2 != 13) $display("*** [baud_tb] ERROR: cnt2 %0d is not 13", cnt2);
        if (cnt3 != 9) $display("*** [baud_tb] ERROR: cnt3 %0d is not 9", cnt3);
        if (cnt4 != 7) $display("*** [baud_tb] ERROR: cnt4 %0d is not 7", cnt4);
        if (cnt5 != 5) $display("*** [baud_tb] ERROR: cnt5 %0d is not 5", cnt5);
        if (cnt6 != 5) $display("*** [baud_tb] ERROR: cnt6 %0d is not 5", cnt6);
        if (cnt7 != 4) $display("*** [baud_tb] ERROR: cnt7 %0d is not 4", cnt7);
        if (cnt8 != 4) $display("*** [baud_tb] ERROR: cnt8 %0d is not 4", cnt8);
        if (cnt9 != 3) $display("*** [baud_tb] ERROR: cnt9 %0d is not 3", cnt9);
        if (cnt10 != 3) $display("*** [baud_tb] ERROR: cnt10 %0d is not 3", cnt10);
        $display("End of testbench: baud_tb.vcd");
        $finish;
    end
endmodule


/*
src="testbench/testbench.sv uart_rx.sv clock_divider.sv ../modules/shift_reg.v"
iverilog -Wall -g2012 -I ../modules/ -o vcd/uart_rx_tb.vvp -s uart_rx_tb ${src};
vvp vcd/uart_rx_tb.vvp
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
    logic [DATA_WIDTH+1:0] uart_rx_out;
    localparam DIV = 16'h4;
    localparam baud_wait = `TCLK*2*16*DIV;

    clock_divider rx_baud (.clk_in(clk), .res_n(res_n), .div(DIV), .clk_out(b_tick));

    uart_rx dut (
        .clk(clk),
        .res_n(res_n),
        .rx_baud(b_tick),
        .rx_din(din),
        .lcreg(8'b00001111),
        .rx_out(uart_rx_out),
        .rx_ready(valid)
    );

    always #`TCLK clk  = ~clk;
    assign err_par = uart_rx_out[8];
    assign err_fr = uart_rx_out[9];

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
            if (uart_rx_out != {err_fr, err_par, tx_data})
                $display("*** [uart_rx_tb] ERROR: uart_rx_out %0h is not as expected %0h", uart_rx_out, {err_fr, err_par, tx_data});
            if (^uart_rx_out[8:0])
                $display("*** [uart_rx_tb] ERROR: parity bit %0b is not correct", err_par);
            // some wait
            #baud_wait;
            #baud_wait;
        end
    endtask

    initial begin
        $dumpfile("vcd/uart_rx_tb.vcd");
        $dumpvars(0);
        $monitor("%t RX: din=%0b dout=%10b, rx_ready=%0b, err_par=%0b, err_fr=%0b", $time, din, uart_rx_out, valid, err_par, err_fr);
        clk = 1'b1;
        res_n = 1'b1;
        @(posedge clk) res_n = 1'b0;
        repeat(2) @(posedge clk);
        res_n = 1'b1;
        din = 1'b1;
        driver(8'hB2);
        driver(8'hAA);
        driver(8'h95);
        $display("End of testbench: uart_rx_tb.vcd");
        $finish;
    end
endmodule


/*
src="testbench/testbench.sv uart_tx.sv clock_divider.sv ../modules/shift_reg.v"
iverilog -Wall -g2012 -I ../modules/ -o vcd/uart_tx_tb.vvp -s uart_tx_tb ${src};
vvp vcd/uart_tx_tb.vvp
*/
module uart_tx_tb;
    logic clk;
    logic res_n;
    logic en;
    logic uart_tx_out;
    logic valid;
    logic b_tick;
    logic [7:0] din;
    localparam DIV = 16'd4;
    logic [11:0] tsr_data;
    logic sreg_clk;
    logic [3:0] cnt;

    clock_divider tx_baud (.clk_in(clk), .res_n(res_n), .div(DIV), .clk_out(b_tick));

    shift_reg #(.N(12)) tb_thr (
        .clk(sreg_clk),
        .res_n(res_n),
        .en(en),
        .din(uart_tx_out),
        .dout(tsr_data)
    );

    uart_tx dut (
        .clk(clk),
        .res_n(res_n),
        .tx_baud(b_tick),
        .tx_start(en),
        .tx_din(din),
        .lcreg(8'b0001_1111),
        .tx_dout(uart_tx_out),
        .tx_ready(valid),
        .tsr_data()
    );

    always #`TCLK clk  = ~clk;

    assign sreg_clk = cnt == 7;

    always_ff @(posedge b_tick or negedge res_n) begin
        if (~res_n | cnt == 15)
            cnt <= 0;
        else
            cnt <= cnt + 1;
    end

    initial begin
        $dumpfile("vcd/uart_tx_tb.vcd");
        $dumpvars(0);
        $monitor("%t TX: din=%0b dout=%0b", $time, din, uart_tx_out);
        clk = 1'b1;
        res_n = 1'b1;
        @(posedge clk) res_n = 1'b0;
        repeat(2) @(posedge clk);
        res_n = 1'b1;
        //@(posedge clk) res_n = 1'b0;
        repeat(16*DIV) @(posedge clk);
        din = 8'hC2;
        en = 1'b1;
        @(posedge valid);
        @(posedge valid);
        if (tsr_data !== 'b110110000100)
            $display("*** [uart_tx_tb] ERROR: tx dout %0b is not as expected", tsr_data);
        else
            $display("PASSED: tx dout %0h is correct!", tsr_data);
        din = 8'hA9;
        @(posedge valid);
        if (tsr_data !== 'b111101010010)
            $display("*** [uart_tx_tb] ERROR: tx dout %0b is not as expected", tsr_data);
        else 
            $display("PASSED: tx dout %0h is correct!", tsr_data);
        repeat(48*DIV) @(posedge clk);
        $display("End of testbench: uart_tx_tb.vcd");
        $finish;
    end
endmodule


/*
src="testbench/testbench.sv uart.sv clock_divider.sv uart_tx.sv uart_rx.sv ../modules/fifo.v ../modules/shift_reg.v"
iverilog -Wall -g2012 -I ../modules/ -o vcd/uart_tb.vvp -s uart_tb ${src};
vvp vcd/uart_tb.vvp
*/
module uart_tb;
    localparam DWIDTH = 8;
    int byte_wait;
    logic clk;
    logic res_n;
    logic [15:0] divisor;
    logic rd_uart;
    logic wr_uart;
    logic tx_ext;
    logic rx_empty;
    logic tx_full;
    logic [DWIDTH-1:0] wr_data;
    logic [DWIDTH-1:0] tsr_data;
    logic [DWIDTH-1:0] lcreg;
    logic [DWIDTH+1:0] rd_data;
    logic rx_ready;
    logic rx_full;
    logic tx_empty;
    logic tx_ready;

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
        .rd_data(rd_data),
        .tsr_data(tsr_data),
        .rx_ready(rx_ready),
        .rx_full(rx_full),
        .tx_empty(tx_empty),
        .tx_ready(tx_ready),
        .lcreg(lcreg),
        .fcreg(8'b0000_0001)
    );

    task expect_result;
        input integer exp_val;
        begin
            wait(rx_empty == 1'b0);
            wait(rx_empty == 1'b1);
            if (rd_data !== exp_val) $display("*** [uart_tb] ERROR: rd_data %0h is not %0h", rd_data, exp_val);
            else $display("PASSED: rd_data 0x%0h is correct!", rd_data);
        end
    endtask
    
    always #`TCLK clk = ~clk;
    assign rd_uart = ~rx_empty;

    initial begin
        $dumpfile("vcd/UART_VTB.vcd");
        $dumpvars();
        $monitor("%t [uart_tb] INFO: wr_data=%0h  rd_data=%0h  rx_ready=%0b", $time, wr_data, rd_data, rx_ready);
        clk = 0;
        res_n = 1;
        divisor = 430; // 100mhz / 16*(9600*12/8)
        byte_wait = divisor * 16 * 10;
        @(posedge clk) res_n = 0;
        @(posedge clk) res_n = 1;
        lcreg = 8'b0001_1111;  // even parity
        @(negedge clk) wr_uart = 1;
        wr_data = 'hAB;
        @(negedge clk) wr_uart = 0;
        expect_result(wr_data);
        
        $display("Pausing before next tx");
        repeat(byte_wait) @(negedge clk);
        $display("Proceeding");
        lcreg = 8'b0000_1111; // odd parity

        @(negedge clk) wr_uart = 1;
        wr_data = 'hDA;
        @(negedge clk) wr_data = 'hC2;
        @(negedge clk) wr_data = 'hB9;
        @(negedge clk) wr_data = 'hB2;
        @(negedge clk) wr_uart = 0;

        //repeat(byte_wait * 5) @(posedge clk);
        expect_result('hDA);
        expect_result('hC2);
        expect_result('hB9);
        expect_result('hB2);

        repeat(byte_wait) @(posedge clk);
        $display("End of testbench: UART_VTB.vcd");
        $finish;
    end
endmodule


/*
src="testbench/testbench.sv uart_top.sv uart.sv clock_divider.sv uart_tx.sv uart_rx.sv ../modules/fifo.v ../modules/shift_reg.v"
iverilog -Wall -g2012 -I ../modules/ -o vcd/uart_top_tb.vvp -s uart_top_tb ${src};
vvp vcd/uart_top_tb.vvp
*/
module uart_top_tb;
    logic clk = 1'b1;
    logic res = 1'b1;
    logic wr, rd, ddis;
    logic [`UART_ADDR_WIDTH-1:0] addr;
    wire [`UART_DATA_WIDTH-1:0] data_bus;
    logic [`UART_DATA_WIDTH-1:0] dutin, dutout;

    uart_top dut (
        .clk(clk),              // system clock pin
        .cs(1'b1),             // rx baud pin
        .res(res),              // master reset pin
        .wr(wr),               // write enable pin
        .rd(rd),               // read enable pin
        .ddis(ddis),             // Driver disable high when cpu is writing
        .addr(addr),
        .data_bus(data_bus)
    );
    assign data_bus = ddis ? dutin : {`UART_DATA_WIDTH{1'bZ}};
    assign dutout = data_bus;

    always #`TCLK clk = ~clk;
    initial begin
        $dumpfile("vcd/uart_top_tb.vcd");
        $dumpvars();
        $monitor("%t: addr=%0h  BUS=0x%0h", $time, addr, dutout);
        @(posedge clk) res = 0;
        @(negedge clk);

        // input to LCR:
        ddis = 1;
        wr = 1;
        addr = 3;   // lcr
        dutin = 'h80;
        @(negedge clk) if (dutout != 'h80)
            $display("*** [uart_top_tb] ERROR: uart_top data_bus is not 0x80");
        
        // input to DLL:
        addr = 0; dutin = 'h40;
        @(negedge clk) if (dutout != 'h40)
            $display("*** [uart_top_tb] ERROR: uart_top data_bus is not 0x80");
    
        // output LCR:
        ddis = 0;
        wr = 0;
        rd = 1;
        addr = 3;
        @(negedge clk) if (dutout != 'h80)
            $display("*** [uart_top_tb] ERROR: uart data_bus is not 0x80");
        $display("End of testbench: uart_top_tb.vcd");
        $finish;
    end
endmodule
