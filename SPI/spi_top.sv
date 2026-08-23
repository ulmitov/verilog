/*
Relevant SPI spec: https://www.ti.com/lit/ug/sprug72/sprug72.pdf
*/
`include "spi.vh"


module spi_top #(LEFT_JUSTIFY = 1, SLAVES_NUM = 1) (
    input logic lspclk,
    input logic res_n,
    input logic  ss_n,
    //input logic [SLAVES_NUM-1:0] SPISTE_n,
    input logic pwrite,
    input logic [15:0] paddr,
    input logic [15:0] pwdata,
    input logic miso,
    inout logic spiclk,
    output logic mosi,
    output logic [15:0] prdata
);
    logic [15:0] SPIRXBUF;
    logic [15:0] SPITXBUF;
    logic [15:0] spidat;
    logic [7:0] SPICCR;
    logic [7:0] SPICTL;
    logic [7:0] SPIST;
    logic [7:0] SPIBRR;
    logic [3:0] dlen;
    logic [3:0] counter;
    logic [3:0] next_count;
    logic loopback;
    logic polarity;
    logic baud_res;
    logic data_end;
    logic rd_rxbuf;
    logic wr_ist;
    logic sdat_clk;
    logic rx_overr;
    logic tx_full;
    logic baudout;
    logic load_en;
    logic sreg_en;
    logic mos_buf;
    logic master;
    logic spi_en;
    logic wr_brr;
    logic sw_res_n;
    logic wr_ccr;
    logic spi_res;
    logic phase;
    logic somi;
    logic wen;
    logic ren;
    logic local_clk;
    logic sreg_off_ok;
    logic post_loaden;
    logic spidat_nout;
    logic session_end;
    logic count_limit;


    clock_divider #(.DIV_WIDTH(7)) baud_spi (
        .clk_in(lspclk),
        .res(baud_res),
        .polarity(polarity),
        .phase(phase),
        .div(SPIBRR[6:0]),
        .clk_out(baudout)
    );


    shift_reg_msb #(.N(16)) SPIDAT (
        .clk(sdat_clk),
        .res_n(sw_res_n),
        .en(sreg_en),
        .din(somi),
        .dout(SPIRXBUF),
        .load_en(load_en),
        .load(spidat),
        .dout_n(spidat_nout)
    );


    generate
        if (LEFT_JUSTIFY)
            assign spidat = pwdata << ~dlen; // 15 - dlen is 1's compl
        else
            assign spidat = pwdata;
    endgenerate

    assign dlen         = SPICCR[3:0];
    assign polarity     = spi_res ? 0 : SPICCR[`SPICCR_POL];
    assign loopback     = SPICCR[`SPICCR_LOOPBACK];
    assign phase        = SPICTL[`SPICTL_PHASE];
    assign master       = SPICTL[`SPICTL_MASTER];
    assign sw_res_n     = ~SPICCR[`SPICCR_SW_RES] ? 0 : res_n;
    assign spi_en       = ~ss_n & SPICTL[`SPICTL_SPI_EN];
    assign wen          = ~ss_n & pwrite;
    assign ren          = ~ss_n & ~pwrite;
    assign wr_brr       = wen && paddr == `SPIBRR;
    assign wr_ist       = wen && paddr == `SPIST;
    assign wr_ccr       = wen && paddr == `SPICCR;
    assign load_en      = wen && paddr == `SPIDAT;
    assign rd_rxbuf     = ren && paddr == `SPIRXBUF;
    assign rx_overr     = SPIST[`SPIST_SPI_INT] & sreg_en & ~data_end;
    assign baud_res     = spi_res | ss_n | wr_brr | ~sreg_en;
    assign spi_res      = ~sw_res_n;
    assign session_end  = data_end & sreg_en;
    assign sreg_off_ok  = data_end & ~sdat_clk;
    assign data_end     = spi_en & count_limit;
    assign somi         = loopback ? mosi : miso;
    assign spiclk       = master ? baudout : 'bZ;
    assign mosi         = spi_en ? (master & ~loopback ? mos_buf : spidat_nout) : 'bZ;
    assign next_count   = counter + 1;
    assign #1 count_limit  = next_count == dlen + 2;    // simulating combinational delay here

    // must be a constant combinational delay bigger than setup time (for correct loading)
    assign #`FORCED_COMB_DELAY sdat_clk  = load_en ? load_en : local_clk;

    // buffering mosi, since tx will be shifted on the first tick, before rx will capture it
    always_ff @(posedge sdat_clk) mos_buf <= spidat_nout;

    always_comb begin
        if (master)
            local_clk = polarity ? ~spiclk : spiclk;
        else
            local_clk = polarity ? spiclk : ~spiclk;
    end

    always_ff @(posedge sdat_clk or posedge spi_res) begin
        if (spi_res | data_end | load_en)    // for master it is load en for slave it is data end
            counter <= 0;
        else if (sreg_en)
            counter <= next_count;
    end

    // without this extra clock, spi_en might be right after changing baud settings
    always_ff @(posedge lspclk or posedge spi_res) begin
        if (spi_res | ~load_en)
            post_loaden <= 0;
        else if (load_en)
            post_loaden <= 1;
        //$display("m=%0b, b=%0b spiclk=%0b, local_clk=%0b, pol=%0b", master, baudout, spiclk, local_clk, polarity);
    end

    always_latch begin
        if (spi_res)
            sreg_en = 0;
        else if (~master) begin
            if (spi_en)
                sreg_en = 1;
            else
                sreg_en = 0;
        end
        else if (post_loaden)
            sreg_en = 1;
        else if (sreg_off_ok)
            sreg_en = 0;
    end


    /* --- Read csrs --- */
    always_comb begin
        if (ren) begin
            case (paddr)
                `SPIST:     prdata = SPIST;
                `SPICCR:    prdata = SPICCR;
                `SPICTL:    prdata = SPICTL;
                `SPIBRR:    prdata = SPIBRR;
                `SPITXBUF:  prdata = SPITXBUF;
                default:    prdata = SPIRXBUF & ('hFFFF >> (15 - dlen)); // invalid addr and SPIRXBUF and SPIRXEMU
            endcase
        end
    end


    /* --- All below are Write csrs.
    Actually slave should write without lspclk
    can replace with latches or use wen tick later --- */
    always_ff @(posedge lspclk or negedge res_n) begin
        if (~res_n)
            SPICCR <= 0;
        else if (wr_ccr)
            SPICCR <= pwdata;
    end

    always_ff @(posedge lspclk or negedge res_n) begin
        if (~res_n)
            SPICTL <= 0;
        else if (wen && paddr == `SPICTL)
            SPICTL <= pwdata;
    end

    always_ff @(posedge lspclk or negedge res_n) begin
        if (~res_n)
            SPIBRR <= 0;
        else if (wr_brr)
            SPIBRR <= {1'b0, pwdata[6:0]};
    end

    always_ff @(posedge lspclk or negedge res_n) begin
        if (~res_n)
            SPITXBUF <= 0;
        else if (wen && paddr == `SPITXBUF)
            SPITXBUF <= pwdata;
    end

    // SPIST bits are latches, slave can use it without lspclk
    // TXFULL bit
    always_latch begin
        if (~res_n | sreg_off_ok)
            SPIST[`SPIST_TX_FULL] = 0;
        else if (load_en)
            SPIST[`SPIST_TX_FULL] = 1;
    end

    // SPI INT FLAG
    always_latch begin
        if (spi_res | rd_rxbuf)
            SPIST[`SPIST_SPI_INT] = 0;
        else if (session_end & ~SPIST[`SPIST_SPI_INT])
            SPIST[`SPIST_SPI_INT] = 1;
    end

    // RECEIVER OVERRUN FLAG
    always_latch begin
        if (spi_res)
            SPIST[`SPIST_RX_OVERRUN] = 0;
        else if (wr_ist & pwdata[`SPIST_RX_OVERRUN])
            SPIST[`SPIST_RX_OVERRUN] = 0;
        else if (rx_overr)
            SPIST[`SPIST_RX_OVERRUN] = 1;
    end

    // SPIIST reserved
    always_latch if (~res_n) SPIST[4:0] = 0;
endmodule
