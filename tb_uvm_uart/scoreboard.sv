class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)

    top_config cfg;
    transaction req;
    pin_sample pins;
    uvm_tlm_analysis_fifo #(transaction) scb_fifo;
    uvm_tlm_analysis_fifo #(pin_sample) pin_fifo;
    bit [DWIDTH-1:0] tx_mem [$];
    bit [DWIDTH-1:0] rx_mem [$];
    op_states rx_state;
    longint count = 0;
    int dlab_en;
    int fifo_en;
    int rx_dout;
    int tx_dout;
    int baud_counter;
    int baud_status;
    int prev_sout;
    int tx_bit_count;
    int tx_bit;
    int count_samples;
    int skip_pin_sample;
    int rbr;
    int overrun;
    int parity_bit;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase ph);
        super.build_phase(ph);
        scb_fifo = new("APB_Q", this);
        pin_fifo = new("PIN_Q", this);
        cfg = top_config::type_id::create("SCB_CFG");
        //if (!uvm_config_db#(top_config)::get(null, "", "cfg", cfg))
        //    uvm_report_fatal(get_name(), "cfg is not in db");
        flush();
    endfunction

    function void flush();
        uvm_report_info(get_name(), "RESET in progress...");
        tx_mem.delete();
        rx_mem.delete();
        scb_fifo.flush();
        pin_fifo.flush();
        dlab_en = 0;
        fifo_en = 0;
        overrun = 0;
        set_rx_state(IDLE);
        cfg.init();
    endfunction

    function void set_rx_state(op_states state);
        //rx_state = op_states'(state);
        rx_state = state;
        count_samples = 0;
        uvm_report_info(cfg.LOOPBACK ? "FSM_Tx" : "FSM_Rx",
            $sformatf("switched to state %s", rx_state.name()), UVM_HIGH
        );
    endfunction

    task run_phase(uvm_phase ph);
        forever begin
            check_apb();    // non blocking
            check_pins();   // blocking
        end
    endtask

    task check_apb;
        int value;
        if (scb_fifo.try_peek(req)) begin
            scb_fifo.get(req);
            if (~req.presetn) begin
                flush();
                return;
            end
        end else return;
        if (~req.pready | req.pslverr) return;

        if (req.pwrite) begin
            case(req.paddr)
                `UART_REG_MCR: cfg.LOOPBACK = req.pwdata[`UART_MCR_LOOP];
                `UART_REG_FCR: fifo_en = req.pwdata[`UART_FCR_FIFOEN];
                `UART_REG_DLL: if (dlab_en) cfg.DIVISOR[`UART_DATA_WIDTH-1:0] = req.pwdata; //cfg.DIVISOR = (cfg.DIVISOR & 'hFFFF_FF00) | req.pwdata;
                `UART_REG_DLM: if (dlab_en) cfg.DIVISOR[`UART_DIV_WIDTH-1:`UART_DATA_WIDTH] = req.pwdata; //cfg.DIVISOR = (cfg.DIVISOR & 'hFFFF_00FF) | (req.pwdata << DWIDTH);
                `UART_REG_LCR: begin
                    dlab_en = req.pwdata[`UART_LCR_DL];
                    cfg.WORD_LEN = req.pwdata[`UART_LCR_WLS +: 2] + 5;
                    cfg.PARITY_EN = req.pwdata[`UART_LCR_PEN];
                    cfg.EVEN_PARITY = req.pwdata[`UART_LCR_EPS];
                    cfg.STICK_PARITY = req.pwdata[`UART_LCR_SP];
                    cfg.STOP_BITS = req.pwdata[`UART_LCR_STB] + 1;
                    uvm_report_info(get_name(),
                        $sformatf("LCR update: WL=%0d SB=%0d PEN=%0d EP=%0d SP=%0d",
                        cfg.WORD_LEN, cfg.STOP_BITS, cfg.PARITY_EN, cfg.EVEN_PARITY, cfg.STICK_PARITY),
                        UVM_HIGH
                    );
                end
            endcase
        end else begin
            if (req.paddr == `UART_REG_LSR && req.prdata[`UART_LSR_OE])
                overrun = 1;
            //if (req.paddr == `UART_REG_LSR && !req.prdata[`UART_LSR_DR])
        end

        uvm_report_info(get_name(), req.convert2string(), UVM_HIGH);
        if (cfg.DIVISOR < 1)    return;
        if (dlab_en)            return;
        if (req.paddr)          return;
        count++;
        

        // WRITE
        if (req.pwrite) begin
            value = req.pwdata & ((1 << cfg.WORD_LEN) - 1);
            if (!fifo_en) begin
                // if overrun means did not read yet, so previous tx can be removed
                if (overrun) begin
                    uvm_report_warning(get_name(),
                        $sformatf("Rx fifo popped back %0h", rx_mem.pop_back())
                    );
                    if (cfg.LOOPBACK)
                        uvm_report_warning(get_name(),
                            $sformatf("Tx fifo popped back %0h", tx_mem.pop_back())
                        );
                end
                tx_mem.push_back(value);
                uvm_report_info(get_name(), $sformatf("*** THR PUSH %0h ***", value));
            end
            else if (fifo_en && tx_mem.size() < FIFO_DEPTH) begin
                tx_mem.push_back(value);
                uvm_report_info(get_name(), $sformatf("*** THR PUSH %0h ***", value));
            end else
                uvm_report_error(get_name(), $sformatf("TRIED TO WRITE WHEN TX QUEUE IS FULL"));
            return;
        end

        // READ
        if (!rx_mem.size()) begin
            uvm_report_warning(get_name(), $sformatf("TRIED TO READ WHEN RX QUEUE IS EMPTY"));
            assert(req.prdata == 0) else uvm_report_error(get_name(),
                $sformatf("prdata %0h is not 0", req.prdata)
            );
            return;
        end

        rx_dout = rx_mem.pop_front();
        assert(rx_dout == req.prdata)
        uvm_report_info(get_name(), $sformatf("PASSED: rx_dout MATCH %0h", rx_dout)); 
        else uvm_report_error(get_name(),
            $sformatf("--- FAILED rx_dout MATCH: Exp=0x%0h | Rec=0x%0h", rx_dout, req.prdata)
        );

        if (cfg.LOOPBACK) begin
            tx_dout = tx_mem.pop_front();
            assert(tx_dout == req.prdata)
            uvm_report_info(get_name(), $sformatf("PASSED: tx_dout MATCH %0h", tx_dout)); 
            else uvm_report_error(get_name(),
                $sformatf("--- FAILED tx_dout MATCH: Exp=0x%0h | Rec=0x%0h", tx_dout, req.prdata)
            );
        end

        if (overrun) begin
            while (rx_mem.size() > 1)
                uvm_report_warning(get_name(),
                    $sformatf("Rx fifo overrun pop front %0h", rx_mem.pop_front())
                );
            if (cfg.LOOPBACK) begin
                while (tx_mem.size() > 1)
                    uvm_report_warning(get_name(),
                        $sformatf("Tx fifo overrun pop front %0h", tx_mem.pop_front())
                    );
            end
            overrun = 0;
        end
    endtask

    task check_pins;
        pin_fifo.get(pins);
        uvm_report_info(get_name(), pins.convert2string(), UVM_FULL);
        check_baudout();
        count_samples++;

        case(rx_state)
            IDLE:       check_state_idle();
            START:      check_state_start();
            DATA:       check_state_data();
            PARITY:     check_state_parity();
            STOP:       check_state_stop();
            STOP2:      check_state_stop();
            STOP_HALF:  check_state_stop();
        endcase
    endtask

    function void check_baudout;
        if (pins.res_n | dlab_en) begin // TODO: dlab might be missed by the thread
            baud_counter = 1;
            baud_status = 1;
            skip_pin_sample = 1;
            return;
        end
        if (skip_pin_sample) begin
            skip_pin_sample = 0;
            return;
        end
        if ($isunknown(cfg.DIVISOR)) begin
            assert(pins.baudout == 1) else uvm_report_error(get_name(),
                "Tx Baud is not constant 1 when divisor is not set"
            );
            return;
        end

        if (baud_counter && baud_status == 0 && pins.baudout == 1) begin
            assert(baud_counter == cfg.DIVISOR) else uvm_report_error(get_name(),
                $sformatf("Tx Baud count %0d is not %0d", baud_counter, cfg.DIVISOR)
            );
            baud_counter = 0;
        end

        if (cfg.DIVISOR > 1) begin
            assert(baud_counter < cfg.DIVISOR) else begin
                uvm_report_error(get_name(),
                    $sformatf("Tx Baud %0d exceeded %0d", baud_counter, cfg.DIVISOR)
                );
                baud_counter = 0;
            end
            baud_counter++;
        end else begin
            baud_counter = 0;
            if (cfg.DIVISOR == 1) begin
                // monitor before posedge will return baud 0
                assert(pins.baudout == 0) else
                uvm_report_error(get_name(), "Tx Baud is not 0 when divisor is 1");
            end else begin
                assert(pins.baudout == 1) else
                uvm_report_error(get_name(), "Tx Baud is not constant 1 when divisor is 0");
            end
        end
        baud_status = pins.baudout;
    endfunction

    function int get_input;
        return cfg.LOOPBACK ? pins.sout : pins.sin;
    endfunction

    function void check_state_idle;
        /* FSM follows sin, so will be behind actual RxFSM by 1 baud */
        count_samples = 0;
        tx_bit_count = 0;
        prev_sout = get_input();
        if (!prev_sout) begin
            set_rx_state(START);
            if (cfg.LOOPBACK) count_samples = 1;  // already one clock after START state
        end
    endfunction

    function void check_state_start;
        if (prev_sout & get_input()) begin
            // still idle or stop state lasts too long
            prev_sout = get_input();
            assert(count_samples <= phase_len())
            else uvm_report_error(get_name(), 
                $sformatf("IDLE state exceeded count_samples %0d", count_samples)
            );
            return;
        end

        // just switched to start:
        if (prev_sout & ~get_input()) begin
            prev_sout = get_input();
            count_samples = 0;
        end

        if (count_samples == phase_len()) begin
            set_rx_state(DATA);
            rbr = 0;
        end else
        if (cfg.LOOPBACK && count_samples > 1 && count_samples <= (cfg.DIVISOR * (NUM_TICKS - 1)))   // skipping edges
            assert(get_input() == 0) else
            uvm_report_error(get_name(), "START state: sample is not 0");
        else
        if (!cfg.LOOPBACK && (count_samples % cfg.DIVISOR == 0))
            assert(get_input() == 0) else
            uvm_report_warning(get_name(), "START state: sample is not 0");
    endfunction

    function void check_state_data;
        if (count_samples == (phase_len() / 2)) begin
            rbr = rbr | (get_input() << tx_bit_count);
            uvm_report_info(get_name(),
                $sformatf("Current RBR=%0h, rx_bit=%0d", rbr, get_input()), UVM_HIGH
            );
        end
        if (count_samples == phase_len()) begin
            count_samples = 0;
            tx_bit_count++;
            //uvm_report_info(get_name(), pins.convert2string());
        end
        if (tx_bit_count == cfg.WORD_LEN)
            set_rx_state(cfg.PARITY_EN ? PARITY : STOP);
    endfunction

    function void check_state_parity;
        // TODO: for all prev_sout sampling, maybe better to take the vote sampling from 0 to DIV ?
        if (count_samples == cfg.DIVISOR) prev_sout = get_input();

        // verify it is constant
        if (count_samples >= cfg.DIVISOR && count_samples <= (cfg.DIVISOR * (NUM_TICKS - 1)))  // skipping edges
            assert(prev_sout == get_input())
            else uvm_report_error(get_name(),
                $sformatf("PARITY state: sample is not %0d", prev_sout)
            );

        if (count_samples == phase_len()) begin
            parity_bit = prev_sout;
            set_rx_state(STOP);
        end
    endfunction

    function void check_state_stop;
        bit parity_val;

        if (count_samples == cfg.DIVISOR) begin
            prev_sout = get_input();
            uvm_report_info(get_name(),
                $sformatf("STOP state: stored sample %0d", prev_sout), UVM_HIGH
            );
        end

        if (rx_state == STOP && count_samples == 1) begin
            uvm_report_info(get_name(), $sformatf("*** RBR PUSH %0h ***", rbr), UVM_LOW);
            /*
            if (!fifo_en && rx_mem.size() > 1)
                uvm_report_warning(get_name(),
                    $sformatf("Rx fifo popped back %0h", rx_mem.pop_back())
                );
            */
            rx_mem.push_back(rbr);
        end

        // check stop bit is constant value:
        if (rx_state == STOP_HALF) begin
            if (count_samples < (cfg.DIVISOR * NUM_TICKS / 2))
                assert_stop_steady(prev_sout);
        end
        if (rx_state == STOP2) begin
            if (count_samples < (cfg.DIVISOR * (NUM_TICKS - 1)))
                assert_stop_steady(prev_sout);
        end
        if (rx_state == STOP) begin
            if (count_samples >= cfg.DIVISOR && (cfg.STOP_BITS || count_samples < (cfg.DIVISOR * (NUM_TICKS - 1))))
                assert_stop_steady(prev_sout);
        end

        // switch to next state:
        if (rx_state == STOP_HALF && count_samples == cfg.DIVISOR * (NUM_TICKS / 2))
            set_rx_state(IDLE);
        else
        if (count_samples == phase_len()) begin
            if (rx_state == STOP && cfg.STOP_BITS == 2)
                set_rx_state(cfg.WORD_LEN == 5 ? STOP_HALF : STOP2);
            else
                set_rx_state(IDLE);
        end

        // BREAK state
        if (rbr == 0 && count_samples <= (cfg.DIVISOR * (NUM_TICKS - 1))) begin  // but DR is set when ticks are 3/4, after that test might change settings
            if (!cfg.PARITY_EN || (cfg.PARITY_EN && parity_bit == 0)) begin
                if (get_input() == 0) begin
                    if (count_samples >= cfg.DIVISOR && prev_sout)
                        uvm_report_warning(get_name(),
                            "Expected BREAK state, but previous sample was 1"
                        );
                    prev_sout = get_input();
                    return;
                end
                if (count_samples >= cfg.DIVISOR && !prev_sout)
                    uvm_report_warning(get_name(),
                        "Expected BREAK state, but suddenly got 1"
                    );
                prev_sout = get_input();
            end
        end

        // if not BREAK state then check stop bit is 1
        if (count_samples == ((phase_len() / 2) - 1)) begin  // suites for all stop bits
            assert(get_input() == 1) else if (cfg.LOOPBACK)
                uvm_report_error(get_name(), "STOP state: sample is not 1");
            else
                uvm_report_warning(get_name(), "STOP state: sample is not 1");
        end

        // if not BREAK state then check parity in the begining of stop state
        if (rx_state == STOP && count_samples == 1 && cfg.PARITY_EN) begin
            parity_val = cfg.get_parity_bit(rbr);
            assert(parity_bit == parity_val) uvm_report_info(get_name(), 
                $sformatf("PASSED: parity bit is %0d", parity_val)
            );
            else if (cfg.LOOPBACK) uvm_report_error(get_name(),
                $sformatf("parity bit is not %0d", parity_val)
            );
            else uvm_report_warning(get_name(),
                $sformatf("parity bit is not %0d", parity_val)
            );
        end
    endfunction

    function int phase_len;
        return cfg.DIVISOR * NUM_TICKS;
    endfunction

    function int state_on;
        return count_samples >= cfg.DIVISOR;
    endfunction

    function void assert_stop_steady(bit val);
        assert(get_input() == val)
        else if (cfg.LOOPBACK)
            uvm_report_error(get_name(),
                $sformatf("STOP state: sample not equal to previous %0d", val)
            );
        else
            uvm_report_warning(get_name(),
                $sformatf("STOP state: sample not equal to previous %0d", val)
            );
    endfunction
endclass
