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
    logic [`UART_DIV_WIDTH-1:0] divisor;
    logic [`UART_DATA_WIDTH-1:0] lsr;
    logic [`UART_DATA_WIDTH-1:0] lcr;
    logic [`UART_DATA_WIDTH-1:0] iir;
    logic [`UART_DATA_WIDTH-1:0] ier;
    logic [`UART_DATA_WIDTH-1:0] fcr;
    logic [`UART_DATA_WIDTH-1:0] dll;
    logic [`UART_DATA_WIDTH-1:0] dlm;
    logic [`UART_DATA_WIDTH-1:0] thr;
    logic [`UART_DATA_WIDTH-1:0] mcr;
    logic [`UART_DATA_WIDTH-1:0] data_out;
    logic [`UART_DATA_WIDTH-1:0] data_in;
    logic [`UART_DATA_WIDTH+1:0] rd_data;
    logic tsr_empty;
    logic ren;
    logic wen;
    logic dlab;
    logic baud_load;
    logic fifo_en;
    logic lsr_rd;
    logic thr_wr;
    logic rbr_rd;
    logic rx_ready;
    logic rx_full;
    logic tx_empty;
    logic rx_empty;
    logic tx_ready;
    logic rd_uart;
    logic addr_zero;
    logic rx_done;
    logic loopback;


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
        .loopback(loopback),
        .baud_res(baud_load),
        .divisor(divisor),
        .wr_data(data_in[7:0]),
        .rd_uart(rbr_rd),
        .wr_uart(thr_wr),
        .rx_ext(sin),
        .tx_ext(sout),
        .rx_empty(rx_empty),
        .tx_full(),
        .rd_data(rd_data),
        .baudout(baudout),
        .tsr_empty(tsr_empty),
        .rx_ready(rx_ready),
        .rx_full(rx_full),
        .tx_empty(tx_empty),
        .tx_ready(tx_ready)
        //,.rx_fifo_count(rx_counter)
    );


    assign loopback     = mcr[`UART_MCR_LOOP];
    assign divisor      = {dlm, dll};
    assign fifo_en      = fcr[`UART_FCR_FIFOEN];
    assign dlab         = lcr[`UART_LCR_DL];
    assign intr         = ~iir[`UART_IIR_IPEND];
    assign addr_zero    = ~|addr;
    assign wen          = cs & wr;
    assign ren          = cs & rd;
    assign thr_wr       = wen & ~dlab & addr_zero;
    assign rbr_rd       = ren & ~dlab & addr_zero;
    //assign rd_uart      = rbr_rd;
    assign data_bus     = ~ddis ? data_out : {`UART_DATA_WIDTH{1'bZ}};
    assign data_in      = ddis ? data_bus : {`UART_DATA_WIDTH{1'bZ}};
    assign baud_load    = wen & dlab;   // When either of the divisor latches is loaded, a 16-bit baud counter is also loaded to prevent long counts on initial load.

    // set rx_done one tick after data was pushed to fifo
    always_ff @(posedge clk) rx_done <= rx_ready;
    always_ff @(posedge clk) rd_uart <= rbr_rd;

    // LSR error flags
    always_ff @(posedge clk or posedge res) begin
        if (res)
            lsr[`UART_LSR_BI] <= 1'b0;
        else
            lsr[`UART_LSR_BI] <= 1'b0;  //TODO
    end

    always_ff @(posedge clk or posedge res) begin
        if (res)
            lsr[`UART_LSR_DR] <= 1'b0;
        else
        if (fifo_en)
            lsr[`UART_LSR_DR] <= ~rx_empty;
        else
        if (rx_done)
            lsr[`UART_LSR_DR] <= 1'b1;
        else
        if (rbr_rd)
            lsr[`UART_LSR_DR] <= 1'b0;
    end


    // rd_data is set on the next clock after rd_uart
    always_ff @(posedge clk or posedge res) begin
        if (res)
            lsr[`UART_LSR_PE] <= 1'b0;
        else
        if (rx_done | (fifo_en & rd_uart))
            lsr[`UART_LSR_PE] <= rd_data[8];
        else
        if (lsr_rd | rx_empty)
            lsr[`UART_LSR_PE] <= 1'b0;
    end

    always_ff @(posedge clk or posedge res) begin
        if (res)
            lsr[`UART_LSR_FE] <= 1'b0;
        else
        if (lsr_rd | rx_empty)
            lsr[`UART_LSR_FE] <= 1'b0;
        else
        if (rx_done | (fifo_en & rd_uart))
            lsr[`UART_LSR_FE] <= rd_data[9];
    end

    // When OE is set, it indicates that before the character in the RBR was read,
    // it was overwritten by the next character transferred into the register.
    always_ff @(posedge clk or posedge res) begin
        if (res)
            lsr[`UART_LSR_OE] <= 1'b0;
        else
        if (fifo_en & rx_full & rx_ready)
            lsr[`UART_LSR_OE] <= 1'b1;
        else
        if (~fifo_en & lsr[`UART_LSR_DR] & rx_done)
            lsr[`UART_LSR_OE] <= 1'b1;
        else
        if (lsr_rd)
            lsr[`UART_LSR_OE] <= 1'b0;
    end

    /*  Not implemented!!!
        In the 16450 Mode this is a 0. In the FIFO mode LSR7 is set if at least one parity error
        framing error or break indication in the FIFO.
        LSR7 is cleared when the CPU reads the LSR, if there are no subsequent errors in the FIFO. */
    always_ff @(posedge clk or posedge res) begin
        if (res)
            lsr[`UART_LSR_EI] <= 1'b0;
        else
        if (~fifo_en)
            lsr[`UART_LSR_EI] <= 1'b0;
        //else if (rx_done | rd_uart)   // TODO: or BI. Add a counter of fifo errors.
        //    lsr[`UART_LSR_EI] <= rd_data[8] | rd_data[9];
        else
        if (lsr_rd | rx_empty)
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
        else
        if (fifo_en)
            lsr[`UART_LSR_TF] <= tx_empty;
        else
        if (tx_ready)
            lsr[`UART_LSR_TF] <= 1'b1;
        else
        if (thr_wr)
            lsr[`UART_LSR_TF] <= 1'b0;
    end

    /*  TEMT is set when both THR + TSR are empty!
        When either THR or TSR contains data character, TEMT is cleared.
        In the FIFO mode, TEMT is set when the transmitter FIFO and shift register are both empty.*/
    always_ff @(posedge clk or posedge res) begin
        if (res)
            lsr[`UART_LSR_TE] <= 1'b1;
        else
        if (fifo_en)
            lsr[`UART_LSR_TE] <= tx_empty & tsr_empty;
        else
        if (thr_wr)
            lsr[`UART_LSR_TE] <= 1'b0;
        else
        if (tx_empty & tsr_empty)
            lsr[`UART_LSR_TE] <= 1'b1;
    end

    // Receiver data available interrupt
    /*
    logic rx_threshold_reached;
    always_comb begin
        case({|ier, fcr[`UART_FCR_RXFIFTL +: 2]})
            3'b100: rx_threshold_reached = rx_counter > 0;
            3'b101: rx_threshold_reached = rx_counter > 3;
            3'b110: rx_threshold_reached = rx_counter > 7;
            3'b111: rx_threshold_reached = rx_counter > 13;
            default: rx_threshold_reached = lsr[`UART_LSR_DR];  // polling mode (Interrupts disabled)
        endcase
    end
    */
    assign lsr_rd = ren & addr == `UART_REG_LSR;

    // Read regs
    always_latch begin
        if (ren) begin
            case (addr)
                `UART_REG_LCR: data_out = lcr;
                `UART_REG_LSR: data_out = lsr;
                `UART_REG_IIR: data_out = iir;
                `UART_REG_MCR: data_out = mcr;
                `UART_REG_IER: begin
                    if (dlab)
                        data_out = dlm;
                    else
                        data_out = ier;
                end
                `UART_REG_RBR: begin
                    if (dlab)
                        data_out = dll;
                    else begin
                        case (lcr[`UART_LCR_WLS +: 2])
                            2'b00: data_out = {{(`UART_DATA_WIDTH - 5){1'b0}}, rd_data[4:0]};
                            2'b01: data_out = {{(`UART_DATA_WIDTH - 6){1'b0}}, rd_data[5:0]};
                            2'b10: data_out = {{(`UART_DATA_WIDTH - 7){1'b0}}, rd_data[6:0]};
                            2'b11: data_out = {{(`UART_DATA_WIDTH - 8){1'b0}}, rd_data[7:0]};
                        endcase
                    end
                end
                default: data_out = 0;   // invalid address
            endcase
        end
    end

    // Write regs
    always_ff @(posedge clk) begin
        if (res) begin
            ier <= 0;
            fcr <= 0;
            lcr <= 0;
            mcr <= 0;
        end else
        if (wen) begin
            case (addr)
                `UART_REG_IER: ier <= (data_in & 'h0F);
                `UART_REG_LCR: lcr <= data_in;
                `UART_REG_FCR: fcr <= data_in;
                `UART_REG_MCR: mcr <= (data_in & 'h3F);
            endcase
        end else begin
            // self clearing bits
            fcr[`UART_FCR_TXCLR] <= 1'b0;
            fcr[`UART_FCR_RXCLR] <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        iir[`UART_IIR_UNUSED +: 2] <= 2'b0;
        iir[`UART_IIR_FIFOEN +: 2] <= {fifo_en, fifo_en};

        // Set Interrups Priorities  // TODO: receiver character time-out UART_IIR_TI
        if (ier[`UART_IER_ELSI] & (lsr[`UART_LSR_OE] | lsr[`UART_LSR_PE] | lsr[`UART_LSR_FE] | lsr[`UART_LSR_BI])) begin
            iir[`UART_IIR_INTID +: 3] <= `UART_IIR_RLS;
            iir[`UART_IIR_IPEND] <= 1'b0;
        end else
        if(ier[`UART_IER_ERBFI] & lsr[`UART_LSR_DR]) begin
            iir[`UART_IIR_INTID +: 3] <= `UART_IIR_RDA;
            iir[`UART_IIR_IPEND] <= 1'b0;
        end else
        if(ier[`UART_IER_ETBEI] & lsr[`UART_LSR_TF]) begin
            iir[`UART_IIR_INTID +: 3] <= `UART_IIR_THRE;
            iir[`UART_IIR_IPEND] <= 1'b0;
        end else
        if (ier[`UART_IER_EDSSI] & 1'b0) begin
            iir[`UART_IIR_INTID +: 3] <= `UART_IIR_MS;
            iir[`UART_IIR_IPEND] <= 1'b0;
        end else
        begin
            iir[`UART_IIR_INTID +: 3] <= 3'b0;
            iir[`UART_IIR_IPEND] <= 1'b1;
        end
    end

    // Divisor latches
    always_latch begin
        if (baud_load) begin
            case (addr)
                `UART_REG_DLL: dll = data_in;
                `UART_REG_DLM: dlm = data_in;
            endcase
        end
    end
endmodule
