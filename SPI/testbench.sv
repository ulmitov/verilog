`include "spi.vh"
`timescale 1ns / 1ns


module spi_tb;
    string vcd = "vcd/spi_tb.vcd";
    logic clk = 1;
    logic res_n;
    logic ss_n;
    logic pwrite;
    logic [15:0] paddr;
    logic [15:0] pwdata;
    logic mosi;
    logic [15:0] prdata;
    logic [3:0] dlen;
    logic [6:0] count_ticks;
    int div;
    int data;

    always #10 clk = ~clk;

    spi_top #(.LEFT_JUSTIFY(1)) dut (
        .lspclk(clk),
        .res_n(res_n),
        .ss_n(ss_n),
        .pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),
        .miso(),
        //outputs
        .mosi(mosi),
        .prdata(prdata)
    );

    task drive(input bit rx_int = 1);
        $display("--- Sending data 0x%0h ---", data);
        #1;
        pwrite = 1;
        paddr = `SPIDAT;
        pwdata = data;
        @(posedge clk);

        $display("[%0t] Polling SPIST", $time);
        #1;
        pwrite = 0;
        paddr = `SPIST;
        
        repeat(div * dlen) begin
            #1;
            @(posedge clk);
            if (rx_int & prdata[`SPIST_SPI_INT]) $error("[%0t]: SPIST_SPI_INT is set", $time);
        end
        repeat(div * 2) begin
            #1;
            @(posedge clk);   // still sending the last bit
            if (~prdata[`SPIST_TX_FULL]) break;
        end
        if (prdata[`SPIST_TX_FULL]) $error("[%0t]: SPIST_TX_FULL is set: %0h", $time, prdata);
        if (~prdata[`SPIST_SPI_INT]) $error("[%0t]: SPIST_SPI_INT is not set: %0h", $time, prdata);
    endtask

    task read;
        paddr = `SPIRXBUF;
        pwrite = 0;
        @(posedge clk);
        if (prdata === data)
            $display("PASSED: PRDATA is %0h", prdata);
        else
            $error("[%0t]: recieved data %0h is not as expected %0h", $time, prdata, data);
    endtask


    initial begin
        $dumpfile(vcd);
        $dumpvars(0);
        ss_n = 1;
        res_n = 0;
        repeat(2) @(posedge clk);
        res_n = 1;
        div = 4;
        dlen = 7;
        ss_n = 0;
        pwrite = 1;

        paddr = `SPIBRR;
        pwdata = div;
        @(posedge clk) #1;

        paddr = `SPICTL;
        pwrite = 1;
        pwdata = 6; // master and spi en
        @(posedge clk) #1;

        paddr = `SPICCR;
        pwrite = 1;
        pwdata = 'h90 + dlen;   // loopback + sw_res
        @(posedge clk) #1;

        data = 'hAD;
        drive(1);
        read();

        #1;
        pwrite = 0;
        paddr = `SPIST;
        @(posedge clk);
        if (prdata) $error("[%0t]: #1: SPIST %0h is not zero", $time, prdata);

        data = 'h59;
        drive();
        read();
        pwrite = 0;
        paddr = `SPIST;
        @(posedge clk);
        if (prdata) $error("[%0t]: #2: SPIST %0h is not zero", $time, prdata);


        // Overrun
        data = 'hFF;
        drive();
        data = 'h42;
        drive(0);

        pwrite = 0;
        paddr = `SPIST;
        @(posedge clk);
        if (prdata !== ((1 << `SPIST_RX_OVERRUN) | (1 << `SPIST_SPI_INT)))
            $error("[%0t]: SPIST %0h is not OR+INT", $time, prdata);

        read();

        #1;
        pwrite = 0;
        paddr = `SPIST;
        @(posedge clk);
        if (prdata !== (1 << `SPIST_RX_OVERRUN))
            $error("[%0t]: SPIST_RX_OVERRUN %0h is not 1", $time, prdata);
        #1;
        pwrite = 1;
        pwdata = 'hFF;
        @(posedge clk);
        #1;
        pwrite = 0;
        @(posedge clk);
        if (prdata !== 0)
            $error("[%0t]: SPIST_RX_OVERRUN %0h is not 0", $time, prdata);

        $display("[%0t] End of testbench %s", $time, vcd);
        $finish;
    end
endmodule



module spi_single_slave_tb(inout logic spiclk_master);
    string vcd = "vcd/spi_single_slave_tb.vcd";
    logic [15:0] paddr;
    logic [15:0] pwdata;
    logic [15:0] sl_out_prev;
    logic [15:0] prdata;
    logic [15:0] prdata_sl;
    logic [6:0] count_ticks;
    logic [3:0] dlen;
    logic clk = 1;
    logic res_n;
    logic ss_n;
    logic ms_n;
    logic mosi;
    logic miso;
    logic pwrite;
    int div;
    
    always #10 clk = ~clk;
    
    spi_top #(.LEFT_JUSTIFY(1)) dut_master (
        .lspclk(clk),
        .res_n(res_n),
        .ss_n(ms_n),
        .pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),
        .miso(miso),
        //outputs
        .spiclk(spiclk_master),
        .mosi(mosi),
        .prdata(prdata)
    );

    spi_top #(.LEFT_JUSTIFY(1)) dut_slave (
        .lspclk(clk),
        .res_n(res_n),
        .ss_n(ss_n),
        .pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),
        .miso(mosi),
        //outputs
        .spiclk(spiclk_master),
        .mosi(miso),
        .prdata(prdata_sl)
    );


    task drive(input int data, input bit rx_int = 1);
        #1;
        $display("INFO: [%0t] driving data 0x%0h", $time, data);
        ms_n = 0;
        ss_n = 1;
        pwrite = 1;
        paddr = `SPIDAT;
        pwdata = data;
        @(posedge clk);

        #1;
        ss_n = 0;
        $display("INFO: [%0t] Polling SPIST", $time);
        pwrite = 0;
        paddr = `SPIST;
        
        repeat(div * (dlen + 2)) begin
            #1;
            @(posedge clk);
            if (~prdata[`SPIST_TX_FULL]) break;
        end
        if (prdata[`SPIST_TX_FULL]) $error("[%0t]: SPIST_TX_FULL is set: %0h", $time, prdata);
        if (~prdata[`SPIST_SPI_INT]) $error("[%0t]: SPIST_SPI_INT is not set: %0h", $time, prdata);
    endtask

    task read(input int expected_prdata);
        expected_prdata = expected_prdata & ((1 << (dlen + 1)) - 1);
        paddr = `SPIRXBUF;
        pwrite = 0;
        @(posedge clk) #1;
        if (prdata === expected_prdata)
            $display("INFO: [%0t] PASSED: PRDATA is %0h", $time, prdata);
        else
            $error("[%0t]: *** recieved data %0h is not as expected %0h ***", $time, prdata, expected_prdata);
    endtask

    task stimulus;
        drive('hADAD);
        repeat(10) @(posedge clk); // just a dummy delay
        read(sl_out_prev);

        pwrite = 0;
        paddr = `SPIST;
        @(posedge clk);
        if (prdata) $error("[%0t]: #1: SPIST %0h is not zero", $time, prdata);
        //sl_out_prev = (sl_out_prev << dlen) + (('hADAD & (2**dlen)) >> dlen);

        drive('h5959);
        read(sl_out_prev);    // also second byte from slave should be 0
    
        pwrite = 0;
        paddr = `SPIST;
        @(posedge clk);
        if (prdata) $error("[%0t]: #2: SPIST %0h is not zero", $time, prdata);


        drive('hFFFF);
        read('hADAD);

        drive('h4242, 0);
        read('h5959);

        pwrite = 0;
        paddr = `SPIST;
        @(posedge clk);
        if (prdata !== 0) $error("[%0t]: SPIST %0h is not zero", $time, prdata);
    endtask

    initial begin
        $dumpfile(vcd);
        $dumpvars(0);
        sl_out_prev = 0;

        for (int pol = 0; pol < 2; pol = pol + 1) begin
            for (int ph = 0; ph < 2; ph = ph + 1) begin
                $display("INFO: --- POLARITY = %0b, PHASE = %0b ---", pol, ph);
                ms_n = 1;
                ss_n = 1;
                res_n = 0;
                repeat(2) @(posedge clk);
                #1;
                res_n = 1;
                div = 4;
                dlen = 7;
                ms_n = 0;

                pwrite = 1;
                paddr = `SPIBRR;
                pwdata = div;
                @(posedge clk) #1;

                paddr = `SPICTL;
                pwrite = 1;
                pwdata = 6 + (ph << `SPICTL_PHASE); // master and spi en
                @(posedge clk) #1;

                ms_n = 1;
                ss_n = 0;

                paddr = `SPICTL;
                pwrite = 1;
                pwdata = 2 + (ph << `SPICTL_PHASE); // slave and spi en
                @(posedge clk) #1;

                // write to both units
                ms_n = 0;
                ss_n = 0;
                paddr = `SPICCR;
                pwrite = 1;
                pwdata = dlen + (pol << `SPICCR_POL) + (1 << `SPICCR_SW_RES);
                @(posedge clk) #1;

                //for (int i = 0; i < 20; i = i + 1)
                stimulus();
            end
        end
        $display("[%0t] End of testbench %s", $time, vcd);
        $finish;
    end
endmodule



module spi_daisy_chain_tb(inout logic spiclk_master);
    string vcd = "vcd/spi_daisy_chain_tb.vcd";
    logic [15:0] paddr;
    logic [15:0] pwdata;
    logic [15:0] prdata;
    logic [15:0] prdata_sl1, prdata_s2;
    logic [6:0] count_ticks;
    logic [3:0] dlen;
    logic clk = 1;
    logic res_n;
    logic ss_n;
    logic ms_n;
    logic mosi;
    logic miso1;
    logic miso2;
    logic pwrite;
    int div;
    
    always #10 clk = ~clk;
    
    spi_top #(.LEFT_JUSTIFY(1)) dut_master (
        .lspclk(clk),
        .res_n(res_n),
        .ss_n(ms_n),
        .pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),
        .miso(miso2),
        //outputs
        .spiclk(spiclk_master),
        .mosi(mosi),
        .prdata(prdata)
    );

    spi_top #(.LEFT_JUSTIFY(1)) dut_slave1 (
        .lspclk(clk),
        .res_n(res_n),
        .ss_n(ss_n),
        .pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),
        .miso(mosi),
        //outputs
        .spiclk(spiclk_master),
        .mosi(miso1),
        .prdata(prdata_sl1)
    );

    spi_top #(.LEFT_JUSTIFY(1)) dut_slave2 (
        .lspclk(clk),
        .res_n(res_n),
        .ss_n(ss_n),
        .pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),
        .miso(miso1),
        //outputs
        .spiclk(spiclk_master),
        .mosi(miso2),
        .prdata(prdata_sl2)
    );


    task drive(input int data, input bit rx_int = 1);
        #1;
        $display("INFO: [%0t] driving data 0x%0h", $time, data);
        ms_n = 0;
        ss_n = 1;
        pwrite = 1;
        paddr = `SPIDAT;
        pwdata = data;
        @(posedge clk);

        //#1;
        ss_n = 0;
        $display("INFO: [%0t] Polling SPIST", $time);
        pwrite = 0;
        paddr = `SPIST;
        
        repeat(div * dlen) begin 
            @(posedge clk);
            //if (rx_int & prdata[6]) $error("[%0t]: INT is set", $time);
        end
        repeat(div) @(posedge clk);   // still sending the last bit
        repeat(div) @(posedge clk);   // still sending the last bit
        if (~prdata[`SPIST_SPI_INT]) $error("[%0t]: INT is not set: %0h", $time, prdata);
    endtask

    task read(input int expected_prdata);
        expected_prdata = expected_prdata & ((1 << (dlen + 1)) - 1);
        paddr = `SPIRXBUF;
        pwrite = 0;
        @(posedge clk) #1;
        if (prdata === expected_prdata)
            $display("INFO: [%0t] PASSED: PRDATA is %0h", $time, prdata);
        else
            $error("[%0t]: *** recieved data %0h is not as expected %0h ***", $time, prdata, expected_prdata);
    endtask

    task stimulus;
        drive('hADAD);
        repeat(10) @(posedge clk); // just a dummy delay
        read(0);

        drive('h5959);
        read(0);

        drive('hFFFF);
        read(0);

        drive('h4242, 0);
        read(0);

        drive('hABCD, 0);
        read('hADAD);

        drive('hBCDE, 0);
        read('h5959);

        drive('hCDEF, 0);
        read('hFFFF);

        drive('hDEFA, 0);
        read('h4242);

        pwrite = 0;
        paddr = `SPIST;
        @(posedge clk);
        //if (prdata !== ((1 << `SPIST_RX_OVERRUN) | (1 << `SPIST_SPI_INT)))
        //    $error("[%0t]: SPIST %0h is not OR+INT", $time, prdata);
        if (prdata !== 0)
            $error("[%0t]: SPIST %0h is not zero", $time, prdata);
    endtask

    initial begin
        $dumpfile(vcd);
        $dumpvars(0);

        for (int pol = 0; pol < 2; pol = pol + 1) begin
            for (int ph = 0; ph < 2; ph = ph + 1) begin
                $display("INFO: --- POLARITY = %0b, PHASE = %0b ---", pol, ph);
                ms_n = 1;
                ss_n = 1;
                res_n = 0;
                repeat(2) @(posedge clk);
                #1;
                res_n = 1;
                div = 4;
                dlen = 7;
                ms_n = 0;

                pwrite = 1;
                paddr = `SPIBRR;
                pwdata = div;
                @(posedge clk) #1;

                paddr = `SPICTL;
                pwrite = 1;
                pwdata = 6 + (ph << `SPICTL_PHASE); // master and spi en
                @(posedge clk) #1;

                ms_n = 1;
                ss_n = 0;

                paddr = `SPICTL;
                pwrite = 1;
                pwdata = 2 + (ph << `SPICTL_PHASE); // slave and spi en
                @(posedge clk) #1;

                // write to both units
                ms_n = 0;
                ss_n = 0;
                paddr = `SPICCR;
                pwrite = 1;
                pwdata = dlen + (pol << `SPICCR_POL) + (1 << `SPICCR_SW_RES);
                @(posedge clk) #1;

                stimulus();
            end
        end
        $display("[%0t] End of testbench %s", $time, vcd);
        $finish;
    end
endmodule
