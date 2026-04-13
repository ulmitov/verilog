/*
    UART top module with control block
*/
`include "regmap.vh"


module uart_top (
    input clk,              // system clock pin
    input rclk,             // rx baud pin
    input res,              // master reset pin
    input cs,               // chip select pin
    input wr,               // write enable pin
    input rd,               // read enable pin
    input sin,              // serial input to rx
    input ddis,             // Driver disable high when cpu is writing
    input [`UART_ADDR_WIDTH-1:0] addr,
    inout [`UART_DATA_WIDTH-1:0] data_bus,  // TRISTATE input/output lines
    output logic sout,      // serial output from tx
    output logic baudout,   // Tx baud
    output logic intr       // interrupt to cpu
);
    logic [`UART_DATA_WIDTH-1:0] lsr, lcr, iir, ier, fcr, dll, dlm, thr;
    logic [`UART_DATA_WIDTH+1:0] rx_fifo_out;
    logic [`UART_DATA_WIDTH-1:0] tsr_data;
    logic [`UART_DATA_WIDTH-1:0] rd_data;
    logic [`UART_DATA_WIDTH-1:0] data_in;
    logic ren, wen;
    logic dlab;
    logic fifo_en, lsr_rd;
    logic thr_wr, rbr_rd;
    logic rx_ready;
    logic rx_full;
    logic tx_empty;
    logic rx_empty;
    logic tx_ready;
    logic rx_pull;
    logic [`UART_DIV_WIDTH-1:0] divisor;

    assign divisor = {dlm, dll};

    uart #(
        .DWIDTH(`UART_DATA_WIDTH),
        .DIV_BITS(`UART_DIV_WIDTH),
        .TICKS_NUM(`UART_TICKS_NUM),
        .FIFO_ADDR_W(`UART_FIFO_ADDR_W)
    ) uart_uut(
        .clk(clk),
        .clk_rx(rclk),
        .res_n(~res),
        .lcreg(lcr),
        .fcreg(fcr),
        .divisor(divisor),
        .wr_data(data_in),
        .rd_uart(rbr_rd),
        .wr_uart(thr_wr),
        .rx_ext(sin),
        .tx_ext(sout),
        .rx_empty(rx_empty),
        .tx_full(),
        .rd_data(rx_fifo_out),
        .tx_baud(baudout),
        .tsr_data(tsr_data),
        .rx_ready(rx_ready),
        .rx_full(rx_full),
        .tx_empty(tx_empty),
        .tx_ready(tx_ready)
    );

    assign fifo_en = fcr[`UART_FCR_FIFOEN];
    assign dlab = lcr[`UART_LCR_DL];
    assign intr = ~iir[`UART_IIR_IPEND];
    assign wen = cs & wr;
    assign ren = cs & rd;
    assign thr_wr = (wen & ~dlab) && addr == `UART_REG_THR;
    assign rbr_rd = (ren & ~dlab) && addr == `UART_REG_RBR;
    assign rx_pull = rbr_rd & ~rx_empty;
    assign data_bus = (~ddis & ren) ? rd_data : {`UART_DATA_WIDTH{1'bZ}};
    assign data_in = (ddis & wen) ? data_bus : {`UART_DATA_WIDTH{1'bZ}};


    // LSR error flags
    always_ff @(posedge clk or posedge res) begin
        if (res)
            lsr[`UART_LSR_BI] <= 1'b0;
        else
            lsr[`UART_LSR_BI] <= 1'b0;  //TODO
    end

    always_ff @(posedge clk or posedge res) begin
        if (res | rbr_rd)
            lsr[`UART_LSR_DR] <= 1'b0;
        else if (fifo_en)
            lsr[`UART_LSR_DR] <= ~rx_empty;
        else if (rx_ready)
            lsr[`UART_LSR_DR] <= 1'b1;
    end

    always_ff @(posedge clk or posedge res) begin
        if (res)
            lsr[`UART_LSR_PE] <= 1'b0;
        else if (rx_pull)
            lsr[`UART_LSR_PE] <= rx_fifo_out[8];
    end

    always_ff @(posedge clk or posedge res) begin
        if (res)
            lsr[`UART_LSR_FE] <= 1'b0;
        else if (rx_pull)
            lsr[`UART_LSR_FE] <= rx_fifo_out[9];
    end

    always_ff @(posedge clk or posedge res) begin
        if (res)
            lsr[`UART_LSR_OE] <= 1'b0;
        else if (rbr_rd)
            lsr[`UART_LSR_OE] <= 1'b0;
        else if (rx_full & rx_ready)
            lsr[`UART_LSR_OE] <= 1'b1;
    end

    /*  In the 16450 Mode this is a 0. In the FIFO mode LSR7 is set if at least one parity error
        framing error or break indication in the FIFO.
        LSR7 is cleared when the CPU reads the LSR, if there are no subsequent errors in the FIFO. */
    always_ff @(posedge clk or posedge res) begin
        if (res)
            lsr[`UART_LSR_EI] <= 1'b0;
        else if (~fifo_en)
            lsr[`UART_LSR_EI] <= 1'b0;
        else if (rx_fifo_out[8])
            lsr[`UART_LSR_EI] <= 1'b1;
        else if (lsr_rd)
            lsr[`UART_LSR_EI] <= 1'b0;
    end

    /*  THRE is set when the THR is empty, indicating that the ACE is ready to accept a new character.
        If the THRE interrupt is enabled when THRE is set, an interrupt is generated.
        THRE is set when the contents of the THR are transferred to the TSR.
        THRE is cleared concurrent with the loading of the THR by the CPU.
        In the FIFO mode, THRE is set when the transmit FIFO is empty;
        it is cleared when at least one byte is written to the transmit FIFO. */
    always_ff @(posedge clk or posedge res) begin
        if (res)
            lsr[`UART_LSR_TF] <= 1'b1;
        else if (fifo_en)
            lsr[`UART_LSR_TF] <= tx_empty;
        else if (tx_ready)
            lsr[`UART_LSR_TF] <= 1'b1;
        else if (thr_wr)
            lsr[`UART_LSR_TF] <= 1'b0;
    end

    /*  TEMT bit is set when the THR and the TSR are bothempty.
        When either the THR or the TSR contains a data character, TEMT is cleared.
        In the FIFO mode, TEMT is set when the transmitter FIFO and shift register are both empty.*/
    always_ff @(posedge clk or posedge res) begin
        if (res)
            lsr[`UART_LSR_TE] <= 1'b1;
        else if (fifo_en)
            lsr[`UART_LSR_TE] <= tx_empty & $isunknown(tsr_data);
        else if (thr_wr)
            lsr[`UART_LSR_TE] <= 1'b0;
        else if ($isunknown(tsr_data))
            lsr[`UART_LSR_TE] <= 1'b1;
    end
        

    // Read regs
    always_comb begin
        lsr_rd = 1'b0;
        if (ren) begin
            case (addr)
                `UART_REG_LCR: rd_data = lcr;
                `UART_REG_LSR: begin
                    rd_data = lsr;
                    lsr_rd = 1'b1;
                end
                `UART_REG_IIR: rd_data = iir;  // IIR and FCR share one address
                `UART_REG_IER: begin
                    if (dlab)
                        rd_data = dlm;
                    else
                        rd_data = ier;
                end
                `UART_REG_RBR: begin
                    if (dlab)
                        rd_data = dll;
                    else if (rbr_rd)
                        rd_data = rx_fifo_out[`UART_DATA_WIDTH-1:0];
                end
            endcase
        end
    end


    // Write regs
    always_ff @(posedge clk) begin
        if (wen) begin
            case (addr)
                `UART_REG_IER: ier <= data_in;
                `UART_REG_LCR: lcr <= data_in;
                `UART_REG_FCR: fcr <= data_in;
            endcase
        end else begin
            // self clearing bits
            fcr[`UART_FCR_TXCLR] <= 1'b0;
            fcr[`UART_FCR_RXCLR] <= 1'b0;

            // consts. should always write them together with data!
            iir[`UART_IIR_FIOEN] <= {fifo_en, fifo_en};
            iir[`UART_IIR_UNUSED] <= 2'b0;
            ier[`UART_IER_UNUSED] <= 4'b0;

            // Set Interrups Priorities
            if (ier[`UART_IER_ELSI] && (lsr[`UART_LSR_OE] | lsr[`UART_LSR_PE] | lsr[`UART_LSR_FE] | lsr[`UART_LSR_BI])) begin
                iir[`UART_IIR_INTID] <= `UART_IIR_RLS;
                iir[`UART_IIR_IPEND] <= 1'b0;
            end else if(ier[`UART_IER_ERBFI] && (lsr[`UART_LSR_DR])) begin // TODO: or receiver character time-out UART_IIR_TI
                iir[`UART_IIR_INTID] <= `UART_IIR_RDA;
                iir[`UART_IIR_IPEND] <= 1'b0;
            end else if(ier[`UART_IER_ETBEI] && (lsr[`UART_LSR_TF])) begin
                iir[`UART_IIR_INTID] <= `UART_IIR_THRE;
                iir[`UART_IIR_IPEND] <= 1'b0;
            end else if (ier[`UART_IER_EDSSI] & 1'b0) begin
                iir[`UART_IIR_INTID] <= `UART_IIR_MS;
                iir[`UART_IIR_IPEND] <= 1'b0;
            end else
                iir[`UART_IIR_IPEND] <= 1'b1;
        end
    end

    // Write divisor latches
    always_comb begin
        if (wen & dlab) begin
            case (addr)
                `UART_REG_THR: dll = data_in;
                `UART_REG_IER: dlm = data_in;
            endcase
        end
    end
endmodule
