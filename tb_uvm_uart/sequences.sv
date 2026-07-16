/* Data patterns to fill CSR's (includes 32 bits) and send via uart */
function patterns_arr get_patterns;
    int val;
    int patterns[SEQ_REPEAT];
    patterns[0:4] = '{
        'hFFFF_FFFF, 0, 'hFFFF_FFFF,
        'hAAAA_AAAA, 'h5555_5555
    };
    for (int i = 5; i < SEQ_REPEAT; i = i + 1) begin
        if (!std::randomize(val) with { !(val inside {patterns}); })
            uvm_report_fatal("uvm_test_top", "FAILED TO RANDOMIZE");
        patterns[i] = val;
    end
    return patterns;
endfunction



/*
Base Sequence object
*/
class base_sequence extends uvm_sequence#(transaction);
    `uvm_object_utils(base_sequence)

    uvm_event_pool ev_pool;
    top_config cfg;
    ral_env ral;
    uvm_status_e status;
    patterns_arr patterns;
    int fifo [$] = {};
    int result;
    bit check_interrupts = 0;

    function new(string name = "SEQ");
        super.new(name);
        set_response_queue_error_report_disabled(1);
        ev_pool = uvm_event_pool::get_global_pool();
        req = transaction::type_id::create();
        cfg = top_config::type_id::create("SEQ_CFG");
        uvm_config_db#(top_config)::set(null, "*", "cfg", cfg);
    endfunction

    virtual task pre_start();
        if (!uvm_config_db#(ral_env)::get(null, "", "ral", ral))
            uvm_report_fatal(get_name(), "RAL object is not in DB");
        seq_reset();    // reset before each test and check registers after reset
        seq_read_regs();
    endtask

    virtual task post_start;
        seq_read_regs();
    endtask

    task seq_reset;
        uvm_report_info(get_name(), "--- RESET START ---", UVM_HIGH);
        repeat(2) begin
            start_item(req);
            req.presetn = 1'b0;
            finish_item(req);
        end
        uvm_report_info(get_name(), "--- RESET FINISH ---");
        start_item(req);
        req.presetn = 1'b1;
        finish_item(req);
        cfg.init();
        ral.csr.reset();
    endtask

    task seq_set_dlab(input int en);
        ral.csr.lcr.DL.set(en);
        ral.csr.lcr.update(status);
        assert(status == UVM_IS_OK) else
        uvm_report_fatal(get_name(), "DLAB update failed");
    endtask

    task seq_set_divisor(input int divisor);
        seq_set_dlab(1);
        seq_set_dll(divisor & ((1 << DWIDTH) - 1));
        if (DWIDTH < 32)
            seq_set_dlh((divisor >> DWIDTH) & ((1 << DWIDTH) - 1));
        seq_set_dlab(0);
        cfg.DIVISOR = divisor;
    endtask

    task seq_set_loopback(input bit en);
        ral.csr.mcr.LOOP.set(en);
        ral.csr.mcr.update(status);
        assert(status == UVM_IS_OK) else
        uvm_report_fatal(get_name(), "LOOPBACK update failed");
        cfg.LOOPBACK = 1;
        if (en) uvm_report_info(get_name(), "--- LOOPBACK ENBALED ---");
    endtask

    task seq_set_word_len(input int word_len_2b);
        int value = word_len_2b << `UART_LCR_WLS;
        value = value + (ral.csr.lcr.get_mirrored_value() & ~(3 << `UART_LCR_WLS));
        ral.csr.lcr.set(value);
        ral.csr.lcr.update(status);
        assert(status == UVM_IS_OK) else
        uvm_report_fatal(get_name(), "LCR update failed");
        cfg.WORD_LEN = word_len_2b + 5;
    endtask

    task seq_set_parity(input int parity_3b);
        parity_3b = parity_3b << `UART_LCR_PEN;
        ral.csr.lcr.set(
            parity_3b + (ral.csr.lcr.get_mirrored_value() & ~(7 << `UART_LCR_PEN))
        );
        ral.csr.lcr.update(status);
        assert(status == UVM_IS_OK) else
        uvm_report_fatal(get_name(), "LCR update failed");
        cfg.PARITY_EN = (parity_3b >> `UART_LCR_PEN) & 1;
        cfg.EVEN_PARITY = (parity_3b >> `UART_LCR_EPS) & 1;
        cfg.STICK_PARITY = (parity_3b >> `UART_LCR_SP) & 1;
    endtask

    task seq_set_stop_bits(input int en);
        if (en)
            ral.csr.lcr.set(ral.csr.lcr.get_mirrored_value() | (1 << `UART_LCR_STB));
        else
            ral.csr.lcr.set(ral.csr.lcr.get_mirrored_value() & ~(1 << `UART_LCR_STB));
        ral.csr.lcr.update(status);
        assert(status == UVM_IS_OK) else
        uvm_report_fatal(get_name(), "LCR update failed");
        cfg.STOP_BITS = en + 1;    
    endtask

    task seq_set_fcr(input int value);
        int val;
        ral.csr.fcr.write(status, value);
        assert(status == UVM_IS_OK) else
        uvm_report_fatal(get_name(), "FCR write failed");
        // update IIR
        val = value & (1 << `UART_FCR_FIFOEN) ? 3 << `UART_IIR_FIFOEN : 0;
        if (!ral.csr.iir.predict(val))
            uvm_report_error(get_name(), "PREDICT IIR FAILED");
    endtask

    task seq_set_dll(input int value);
        ral.set_dlab_map();
        ral.csr.dll.write(status, value, .map(ral.csr.dlab_map), .parent(this));
        assert(status == UVM_IS_OK) else
        uvm_report_error(get_name(), "Write DLL failed");
        //ral.dll.write(status, req.pwdata, .map(ral.dlab_map), .parent(this));
        //if (~ral.dll.predict(req.pwdata))
        //    uvm_report_error(get_name(), "PREDIC FAILED");
        //else
        //    uvm_report_info(get_name(), "PREDIC PASSED");
        //ral.dll.mirror(status, UVM_CHECK);
        //ral.dll.read(status, val, .map(ral.dlab_map), .parent(this));
        //value = value & ((1 << DWIDTH) - 1);

        ral.csr.dll.read(status, result, .map(ral.csr.dlab_map), .parent(this));
        assert(status == UVM_IS_OK) else
        uvm_report_error(get_name(), "Read DLL failed");
        assert(result == ral.csr.dll.get_mirrored_value()) else
        uvm_report_error(get_name(),
            $sformatf("DLL Result %0h is not %0h", result, ral.csr.dll.get_mirrored_value())
        );
        // the status and second bus2reg come from do_bus_write and do_bus_read   !!!
        ral.set_default_map();
    endtask

    task seq_set_dlh(input int value);
        ral.set_dlab_map();
        ral.csr.dlh.write(status, value, .map(ral.csr.dlab_map), .parent(this));
        value = value & ((1 << DWIDTH) - 1);
        assert(status == UVM_IS_OK) else
        uvm_report_error(get_name(), "Write DLH failed");

        ral.csr.dlh.read(status, result, .map(ral.csr.dlab_map), .parent(this));
        assert(status == UVM_IS_OK) else
        uvm_report_error(get_name(), "Read DLH failed");
        assert(result == ral.csr.dlh.get_mirrored_value()) else
        uvm_report_error(get_name(),
            $sformatf("DLH Result %0h is not %0h", result, ral.csr.dlh.get_mirrored_value())
        );
        ral.set_default_map();
    endtask

    task seq_set_ier(input int value, output int res);
        uvm_report_info(get_name(), $sformatf("--- IER set to %0h ---", value));
        ral.csr.ier.write(status, value);
        assert(status == UVM_IS_OK) else
        uvm_report_error(get_name(), "Write IER failed");

        ral.csr.ier.read(status, res);
        assert(status == UVM_IS_OK) else
        uvm_report_error(get_name(), "Read IER failed");

        assert(res == ral.csr.ier.get_mirrored_value()) else
        uvm_report_error(get_name(),
            $sformatf("IER Result %0h is not %0h", res, ral.csr.ier.get_mirrored_value())
        );
    endtask

    task seq_set_lcr(input int value, output int res);
        ral.csr.lcr.write(status, value);
        assert(status == UVM_IS_OK) else
        uvm_report_error(get_name(), "Write LCR failed");

        ral.csr.lcr.read(status, res);
        assert(status == UVM_IS_OK) else
        uvm_report_error(get_name(), "Read LCR failed");
        assert(res == ral.csr.lcr.get_mirrored_value()) else
        uvm_report_error(get_name(),
            $sformatf("LCR Result %0h is not %0h", res, ral.csr.lcr.get_mirrored_value())
        );
    endtask

    task seq_set_mcr(input int value, output int res);
        ral.csr.mcr.write(status, value);
        //value = value & ((1 << DWIDTH) - 1);
        assert(status == UVM_IS_OK) else
        uvm_report_error(get_name(), "Write MCR failed");

        ral.csr.mcr.read(status, res);
        assert(status == UVM_IS_OK) else
        uvm_report_error(get_name(), "Read MCR failed");
        assert(res == ral.csr.mcr.get_mirrored_value()) else
        uvm_report_error(get_name(),
            $sformatf("MCR Result %0h is not %0h", res, ral.csr.mcr.get_mirrored_value())
        );
    endtask

    task seq_get_lsr(output integer value);
        ral.csr.lsr.read(status, value);
        assert(status == UVM_IS_OK) else
        uvm_report_error(get_name(), "Read LSR failed");
    endtask

    task seq_get_iir(
        output int value,
        input bit elsi = 0,
        input bit erbfi = 0,
        input int etbei = 0
    );
        bit etbei_set = 0;
        int ier = ral.csr.ier.get_mirrored_value();
        int val = ral.csr.iir.get_mirrored_value();
        int other_bits = val & (3 << `UART_IIR_FIFOEN) | (1 << `UART_IIR_IPEND);    // ipend 1 if etbei is cleared

        ral.csr.iir.read(status, value);
        assert(status == UVM_IS_OK) else
        uvm_report_error(get_name(), "Read IIR failed");

        if (ier) begin
            if (elsi && (ier & (1 << `UART_IER_ELSI)))
                val = (other_bits & ~(1 << `UART_IIR_IPEND)) | `UART_IIR_RLS << `UART_IIR_INTID;
            else
            if (erbfi && (ier & (1 << `UART_IER_ERBFI)))
                val = (other_bits & ~(1 << `UART_IIR_IPEND)) | `UART_IIR_RDA << `UART_IIR_INTID;
            else
            if (etbei == 1 && (ier & (1 << `UART_IER_ETBEI))) begin
                val = (other_bits & ~(1 << `UART_IIR_IPEND)) | `UART_IIR_THRE << `UART_IIR_INTID;
                etbei_set = 1;
            // all places where x is set should be probably 0 if etbei clearing is implemented
            // for now treat as dont care, later remove and uncomment the last line
            end else if (etbei == 2 && (ier & (1 << `UART_IER_ETBEI))) begin
                if ((value & ((1 << `UART_IIR_IPEND))) == 0)
                    val = ((other_bits & ~(1 << `UART_IIR_IPEND))) | (`UART_IIR_THRE << `UART_IIR_INTID);
            end else    // no interrupt expected
                val = other_bits;
            if (!ral.csr.iir.predict(val)) uvm_report_error(get_name(), "IIR PREDICT FAILED");
        end
        assert(value == ral.csr.iir.get_mirrored_value())
        uvm_report_info(get_name(), $sformatf("IIR Result %0h is OK", value), UVM_HIGH);
        else uvm_report_error(get_name(),
            $sformatf("IIR value %0h is not as mirrored %0h", value, ral.csr.iir.get_mirrored_value())
        );
        //if (etbei_set) void'(ral.csr.iir.predict(other_bits));  // ETBEI is cleared after IIR read
    endtask

    task seq_read_regs;
        // LCR
        ral.csr.lcr.read(status, result);
        assert(status == UVM_IS_OK) else
        uvm_report_error(get_name(), "Read LCR failed");
        assert(result == ral.csr.lcr.get_mirrored_value()) else
        uvm_report_error(get_name(),
            $sformatf("LCR Result %0h is not %0h", result, ral.csr.lcr.get_mirrored_value())
        );
        // LSR
        seq_get_lsr(result);
        assert(result == ral.csr.lsr.get_mirrored_value()) else
        uvm_report_error(get_name(),
            $sformatf("LSR Result %0h is not %0h", result, ral.csr.lsr.get_mirrored_value())
        );
        // IER
        ral.csr.ier.read(status, result);
        assert(status == UVM_IS_OK) else
        uvm_report_error(get_name(), "Read IER failed");
        assert(result == ral.csr.ier.get_mirrored_value()) else
        uvm_report_error(get_name(),
            $sformatf("IER Result %0h is not %0h", result, ral.csr.ier.get_mirrored_value())
        );
        // IIR
        seq_get_iir(result, .etbei(2));
        // MCR
        ral.csr.mcr.read(status, result);
        assert(status == UVM_IS_OK) else
        uvm_report_error(get_name(), "Read MCR failed");
        assert(result == ral.csr.mcr.get_mirrored_value()) else
        uvm_report_error(get_name(),
            $sformatf("MCR Result %0h is not %0h", result, ral.csr.mcr.get_mirrored_value())
        );
    endtask

    task seq_uart_write(input int value);
        value = value & 'hFF;
        uvm_report_info(get_name(), $sformatf("--- UART TX %0h ---", value));
        ral.csr.thr.write(status, value);
        assert(status == UVM_IS_OK) else
        uvm_report_error(get_name(), "Write THR failed");
    endtask

    task seq_uart_read;
        input integer expected_val;
        output int res;
        ral.csr.rbr.read(status, res);
        assert(status == UVM_IS_OK) else
        uvm_report_error(get_name(), "Read RBR failed");

        if (!$isunknown(expected_val)) begin
            expected_val = expected_val & ((1 << cfg.WORD_LEN) - 1);
            assert(res == expected_val) else
            uvm_report_error(get_name(), $sformatf("RBR value %0h is not %0h", res, expected_val));
        end
    endtask

    task seq_wait_clk_ticks(input int wait_ticks);
        start_item(req);
        req.presetn = 1;
        req.psel = 0;
        req.pready = 0;
        req.delay_cycles = wait_ticks;
        uvm_report_info(get_name(), $sformatf("Wait %0d clocks", wait_ticks), UVM_FULL);
        finish_item(req);
        req.delay_cycles = 0;
    endtask

    task poll_lsr_tf;
        output int res;
        repeat(`UART_TICKS_NUM * 12) begin   // 12 bits await
            uvm_report_info(get_name(), "Polling TF...", UVM_HIGH);
            seq_wait_clk_ticks(cfg.DIVISOR);
            seq_get_lsr(res);
            if (res & (1 << `UART_LSR_TF)) break;
        end
        assert(res & (1 << `UART_LSR_TF)) else
        uvm_report_error(get_name(),
            $sformatf("LSR is %0h but expected TF", result)
        );
    endtask

    task poll_lsr_dr(
        output int res,
        input int wait_ticks = cfg.DIVISOR
    );
        repeat(`UART_TICKS_NUM * 12) begin          // 12 bits await
            uvm_report_info(get_name(), "Polling DR...", UVM_HIGH);
            if (wait_ticks) seq_wait_clk_ticks(wait_ticks);
            seq_get_lsr(res);
            if (res & (1 << `UART_LSR_DR)) break;
        end
        assert(res & (1 << `UART_LSR_DR)) else
        uvm_report_error(get_name(), $sformatf("LSR is %0h but expected DR", res));
    endtask

    task poll_lsr_oe;
        output int res;
        repeat(`UART_TICKS_NUM * 12) begin          // 12 bits await
            uvm_report_info(get_name(), "Polling OE...", UVM_HIGH);
            seq_wait_clk_ticks(cfg.DIVISOR);// width of baud tick
            seq_get_lsr(res);
            if (res & (1 << `UART_LSR_OE)) break;
        end
        assert(res & (1 << `UART_LSR_OE)) else
        uvm_report_error(get_name(), $sformatf("LSR is %0h but expected OE", res));
    endtask

    task poll_lsr_te(
        output int res,
        input int wait_ticks = cfg.DIVISOR
    );
        repeat(`UART_TICKS_NUM * 12) begin          // 12 bits await
            uvm_report_info(get_name(), "Polling TE...", UVM_HIGH);
            if (wait_ticks) seq_wait_clk_ticks(wait_ticks);
            seq_get_lsr(res);
            if (res & (1 << `UART_LSR_TE)) break;
        end
        assert(res & (1 << `UART_LSR_TE)) else
        uvm_report_error(get_name(), $sformatf("LSR is %0h but expected TE", res));
    endtask

    task wait_for_irq(
        output int res,
        input bit elsi = 0,
        input bit erbfi = 0,
        input bit etbei = 0,
        input int wait_ticks = cfg.DIVISOR   // width of baud tick
    );
        int val = 0;
        int ier = ral.csr.ier.get_mirrored_value();
        if (!ier) return;
        if (elsi && (ier & (1 << `UART_IER_ELSI)))
            val = `UART_IIR_RLS;
        else if (erbfi && (ier & (1 << `UART_IER_ERBFI)))
            val = `UART_IIR_RDA;
        else if (etbei && (ier & (1 << `UART_IER_ETBEI)))
            val = `UART_IIR_THRE;
        else begin
            uvm_report_warning(get_name(),
                $sformatf("Not waiting for IRQ due to irrelevant IER setting %0h", ral.csr.ier.get_mirrored_value()),
                UVM_HIGH
            );
            return;
        end

        uvm_report_info(get_name(), $sformatf("Waiting for IRQ %3b", val));
        repeat(`UART_TICKS_NUM * 12) begin          // 12 bits await
            if (wait_ticks) seq_wait_clk_ticks(wait_ticks);
            ral.csr.iir.read(status, res);
            assert(status == UVM_IS_OK) else
            uvm_report_error(get_name(), "Read IIR failed");
            if (!(res & (1 << `UART_IIR_IPEND)) && (((res >> `UART_IIR_INTID) & 'h7) == val))
                break;
        end

        assert(!(res & (1 << `UART_IIR_IPEND))) else
        uvm_report_error(get_name(), $sformatf("IIR is %0h but expected IPEND to be set", res));

        assert(((res >> `UART_IIR_INTID) & 'h7) == val)
            uvm_report_info(get_name(), "IRQ recieved", UVM_HIGH);
        else
            uvm_report_error(get_name(),
                $sformatf("IIR is 0x%0h but expected interrupt type %3b", res, val)
            );
    endtask

    task fill_fifo_randomly;
        bit [7:0] val;
        for (int i = 0; i < FIFO_DEPTH; i = i + 1) begin
            val = $urandom_range(255);
            seq_uart_write(val);
            val = val & ((1 << cfg.WORD_LEN) - 1);
            fifo.push_back(val);
        end
    endtask

    /* Sub Body iterates over all settings, to be run by test sequences. 40 iterations in total. */
    task sub_body;
        int disabled_parity;

        //for (int wl = 1; wl < 2; wl = wl + 1) begin
        for (int wl = 0; wl < 4; wl = wl + 1) begin
            seq_set_word_len(wl);

            //for (int sb = 0; sb < 1; sb = sb + 1) begin
            for (int sb = 0; sb < 2; sb = sb + 1) begin
                seq_set_stop_bits(sb);
                disabled_parity = $urandom_range(3); // not running on all parity values if zero bit is 0

                //for (int pb = 1; pb < 2; pb = pb + 1) begin
                for (int pb = 0; pb < 8; pb = pb + 1) begin
                    if (!(pb & 1) && ((pb >> 1) != disabled_parity))
                        continue;
                    seq_set_parity(pb);
                    uvm_report_info(get_name(),
                        $sformatf("--- WL[%0d] SB[%0d] PEN[%0d] EP[%0d] SP[%0d] ---",
                        cfg.WORD_LEN, cfg.STOP_BITS, cfg.PARITY_EN, cfg.EVEN_PARITY, cfg.STICK_PARITY)
                    );
                    seq_test();
                end
            end
        end
    endtask

    virtual task seq_test;
        uvm_report_info(get_name(), "Test logic to be implemented here");
    endtask

    /* 7 iterations with sub_body (300 iterations total) */
    virtual task body;
        //seq_set_ier(0, result);
        //sub_body();
        if (!check_interrupts) return;

        seq_set_ier(1 << `UART_IER_ETBEI, result);
        sub_body();

        seq_set_ier(1 << `UART_IER_ERBFI, result);
        sub_body();

        seq_set_ier(1 << `UART_IER_ELSI, result);
        sub_body();

        seq_set_ier((1 << `UART_IER_ERBFI) | (1 << `UART_IER_ETBEI), result);
        sub_body();

        seq_set_ier((1 << `UART_IER_ERBFI) | (1 << `UART_IER_ELSI), result);
        sub_body();

        seq_set_ier((1 << `UART_IER_ETBEI) | (1 << `UART_IER_ELSI), result);
        sub_body();

        seq_set_ier((1 << `UART_IER_ERBFI) | (1 << `UART_IER_ETBEI) | (1 << `UART_IER_EDSSI) | (1 << `UART_IER_ELSI), result);
        sub_body();
    endtask
endclass


class seq_lib extends uvm_sequence_library #(transaction);
    `uvm_object_utils(seq_lib)
    `uvm_sequence_library_utils(seq_lib)
    function new(string name = "SEQ_LIB");
        super.new(name);
        selection_mode = UVM_SEQ_LIB_USER;
        min_random_count = 1;
        max_random_count = 20;
        sequence_count = 14;

        add_sequence(sequence_csr::get_type());
        add_sequence(sequence_baud::get_type());

        add_sequence(sequence_loopback::get_type());
        add_sequence(sequence_loopback_fifo::get_type());

        add_sequence(sequence_write_string_read_each_dr::get_type());
        add_sequence(sequence_write_string_read_after_te::get_type());

        add_sequence(sequence_send_sin::get_type());
        add_sequence(sequence_send_sin_fifo_en::get_type());
        add_sequence(sequence_send_sin_fifo_en_consecutive_errors::get_type());

        add_sequence(sequence_polling_mode_fifo_dis_oe_case_read_before_oe::get_type());
        add_sequence(sequence_polling_mode_fifo_dis_oe_case_read_after_oe::get_type());
        add_sequence(sequence_polling_mode_fifo_dis_oe_case_read_after_multiple_oe::get_type());

        add_sequence(sequence_polling_mode_fifo_en_oe_case::get_type());
        add_sequence(sequence_send_sin_fifo_dis_glitch::get_type());

        init_sequence_library();
    endfunction
    // Overriding, since for some reason uvm 1.2 passes max minus 1
    // so last index will never run! UVM 1.8 does not have this issue
    `ifdef UVM_MAJOR_VERSION_1_2
    function int unsigned select_sequence(int unsigned max);
        static int unsigned counter = 0;
        select_sequence = counter;
        counter++;
        if (counter > max) counter = 0;
        uvm_report_info(get_name(), "+++++ NEXT TEST STARTED +++++");
    endfunction
    `endif
endclass



class sequence_baud extends base_sequence;
    `uvm_object_utils(sequence_baud)
    function new(string name = "SEQ_BR");
        super.new(name);
    endfunction

    task body;
        const int num = 19 + 8;
        int unsigned patterns [];
        int unsigned baud_patterns [];
        bit [`UART_DIV_WIDTH-1:0] val;
        uvm_report_info(get_name(), "--- Baud generator seuqences ---");

        baud_patterns = new[num + SEQ_REPEAT];
        patterns = new[num];
        patterns = '{
            `UART_DIV_WIDTH'h1,
            `UART_DIV_WIDTH'h2,
            `UART_DIV_WIDTH'h3,
            `UART_DIV_WIDTH'h4,
            `UART_DIV_WIDTH'h5,
            `UART_DIV_WIDTH'h6,
            `UART_DIV_WIDTH'h7,
            `UART_DIV_WIDTH'h8,
            `UART_DIV_WIDTH'h9,
            `UART_DIV_WIDTH'hA,
            `UART_DIV_WIDTH'hB,
            `UART_DIV_WIDTH'hC,
            `UART_DIV_WIDTH'hD,
            `UART_DIV_WIDTH'hE,
            `UART_DIV_WIDTH'hF,
            `UART_DIV_WIDTH'h10,
            `UART_DIV_WIDTH'h20,
            `UART_DIV_WIDTH'h40,
            `UART_DIV_WIDTH'h80, //  + 19
            cfg.get_divisor(9.6),
            cfg.get_divisor(19.2),
            cfg.get_divisor(38.4),
            cfg.get_divisor(57.6),
            cfg.get_divisor(115.2),
            cfg.get_divisor(230.4),
            cfg.get_divisor(460.8),
            cfg.get_divisor(921.6) // + 8
        };

        for (int i = 0; i < num + SEQ_REPEAT; i = i + 1) begin
            if (i < num)
                baud_patterns[i] = patterns[i];
            else begin
                void'(std::randomize(val) with { 
                    !(val inside {baud_patterns});
                });
                baud_patterns[i] = val;
            end
        end
        foreach (baud_patterns[i]) begin
            uvm_report_info(get_name(), $sformatf("--- SET DIVISOR 0x%0h ---", baud_patterns[i]));
            seq_set_divisor(baud_patterns[i]);
            seq_wait_clk_ticks(baud_patterns[i] * 5 + 30);  // 5 cycles and some delay
            seq_reset();
            seq_wait_clk_ticks(baud_patterns[i] * 1 + 30);
        end
    endtask
endclass


class sequence_csr extends base_sequence;
    `uvm_object_utils(sequence_csr)
    function new(string name = "SEQ_CSR");
        super.new(name);
    endfunction

    task seq_set_lsr(int value);
        // lsr is RO
        ral.csr.lsr.write(status, value);
        value = value & ((1 << DWIDTH) - 1);
        assert(status == UVM_IS_OK) else
        uvm_report_error(get_name(), "Write LSR failed");
        seq_get_lsr(result);
        assert(result == ral.csr.lsr.get_mirrored_value()) else
        uvm_report_error(get_name(),
            $sformatf("LSR Result %0h is not %0h", result, ral.csr.lsr.get_mirrored_value())
        );
    endtask

    task seq_csr();
        seq_get_iir(result);
        seq_set_lsr('hFFFF_FFFF);

        patterns = get_patterns();
        foreach (patterns[i]) seq_set_fcr(patterns[i]);

        patterns = get_patterns();
        foreach (patterns[i]) seq_set_ier(patterns[i], result);
        seq_set_ier(0, result);

        patterns = get_patterns();
        foreach (patterns[i]) seq_set_mcr(patterns[i], result);

        // this one is last as it holds dlab
        patterns = get_patterns();
        foreach (patterns[i]) seq_set_lcr(patterns[i], result);
    endtask

    task body;
        uvm_report_info(get_name(), "--- Write read CSR seuqences ---");
        // Dlab is on
        seq_set_dlab(1);
        patterns = get_patterns();
        foreach (patterns[i]) seq_set_dlh(patterns[i]);

        patterns = get_patterns();
        foreach (patterns[i]) seq_set_dll(patterns[i]);
        seq_csr();

        // Dlab is off
        seq_set_dlab(0);
        seq_csr();
    endtask
endclass


/*
No fifo, write+read byte by byte in loopback mode
*/
class sequence_loopback extends base_sequence;
    `uvm_object_utils(sequence_loopback)
    function new(string name = "SEQ");
        super.new(name);
    endfunction

    virtual task pre_start;
        super.pre_start();
        seq_set_loopback(1);
        seq_set_divisor($urandom_range(32, 2));
    endtask

    virtual task seq_test;
        patterns = get_patterns();
        foreach (patterns[i]) seq_write_read(patterns[i]);
    endtask

    task seq_write_read(input int value);
        seq_uart_write(value);
        poll_lsr();
        seq_uart_read(value, result);
    endtask

    task poll_lsr;
        // after write TF should be 0.
        // then after up to 16 baud ticks goes to 1.
        // TE should be 0 then go to 1 after tx finished, i.e 4*16*8.
        seq_get_lsr(result);
        assert(result == 0) else
        uvm_report_error(get_name(), $sformatf("LSR is %0h but expected 0", result));
        seq_get_iir(result);

        poll_lsr_tf(result);
        seq_get_iir(result, .etbei(1));
        seq_get_iir(result, .etbei(2));

        poll_lsr_te(result);
        assert(result & ((1 << `UART_LSR_TF) | (1 << `UART_LSR_TE))) else
        uvm_report_error(get_name(), $sformatf("LSR is %0h but expected TE", result));
        seq_get_iir(result, .etbei(1));

        poll_lsr_dr(result);
        assert(result == ((1 << `UART_LSR_DR) | (1 << `UART_LSR_TF) | (1 << `UART_LSR_TE))) else
        uvm_report_error(get_name(), $sformatf("LSR is %0h but expected DR+TF+TE", result));
        seq_get_iir(result, .etbei(2), .erbfi(1));
    endtask
endclass


class sequence_loopback_fifo extends sequence_loopback;
    `uvm_object_utils(sequence_loopback_fifo)
    function new(string name = "SEQ");
        super.new(name);
    endfunction
    task pre_start;
        super.pre_start();
        seq_set_fcr(1 << `UART_FCR_FIFOEN);
        uvm_report_info(get_name(), "--- FIFO ENBALED ---");
    endtask
endclass


class sequence_write_string_read_each_dr extends sequence_loopback_fifo;
    `uvm_object_utils(sequence_write_string_read_each_dr)
    function new(string name = "SEQ");
        super.new(name);
    endfunction
    task seq_test;
        int val;
        uvm_report_info(get_name(), "--- WRITE AND READ STRING EACH DATA_READY ---");
        fill_fifo_randomly();
        seq_get_iir(result);

        for (int i = 0; i < FIFO_DEPTH; i = i + 1) begin
            poll_lsr_dr(result, cfg.get_ticks_per_bit());

            if (i == FIFO_DEPTH - 1) begin
                assert(result == ((1 << `UART_LSR_DR) | (1 << `UART_LSR_TF) | (1 << `UART_LSR_TE))) else
                uvm_report_error(get_name(), $sformatf("LSR is %0h but expected DR+TF+TE", result));
                seq_get_iir(result, .etbei(1), .erbfi(1));
            end else begin
                assert(result == (1 << `UART_LSR_DR)) else
                uvm_report_error(get_name(), $sformatf("LSR is %0h but expected DR", result));
                seq_get_iir(result, .erbfi(1));
            end

            val = fifo.pop_front();
            seq_uart_read(val, result);
        end

        seq_get_iir(result, .etbei(1));
        seq_get_iir(result, .etbei(2));
        seq_get_lsr(result);
        assert(result == ((1 << `UART_LSR_TF) | (1 << `UART_LSR_TE))) else
        uvm_report_error(get_name(), $sformatf("LSR is %0h but expected TF+TE", result));
    endtask
endclass



class sequence_write_string_read_after_te extends sequence_loopback_fifo;
    `uvm_object_utils(sequence_write_string_read_after_te)
    function new(string name = "SEQ");
        super.new(name);
    endfunction
    task seq_test;
        int val;
        uvm_report_info(get_name(), "--- READ STRING AFTER TX FINISHED ---");
        fill_fifo_randomly();
        seq_get_iir(result);

        poll_lsr_te(result, cfg.get_ticks_per_word() * (FIFO_DEPTH + 1));
        assert(result == ((1 << `UART_LSR_DR) | (1 << `UART_LSR_TF) | (1 << `UART_LSR_TE))) else
        uvm_report_error(get_name(), $sformatf("LSR is %0h but expected DR+TF+TE", result));

        seq_get_iir(result, .etbei(1), .erbfi(1));

        for (int i = 0; i < FIFO_DEPTH; i = i + 1) begin
            poll_lsr_dr(result);
            assert(result == ((1 << `UART_LSR_DR) | (1 << `UART_LSR_TF) | (1 << `UART_LSR_TE))) else
            uvm_report_error(get_name(), $sformatf("LSR is %0h but expected DR+TF+TE", result));
            seq_get_iir(result, .etbei(1), .erbfi(1));
            val = fifo.pop_front();
            seq_uart_read(val, result);
        end
        seq_get_lsr(result);
        assert(result == ((1 << `UART_LSR_TF) | (1 << `UART_LSR_TE))) else
        uvm_report_error(get_name(), $sformatf("LSR is %0h but expected TF+TE", result));
        seq_get_iir(result, .etbei(1));
        seq_get_iir(result, .etbei(2));
    endtask
endclass


/*
Write then read before OE is set
*/
class sequence_polling_mode_fifo_dis_oe_case_read_before_oe extends sequence_loopback;
    `uvm_object_utils(sequence_polling_mode_fifo_dis_oe_case_read_before_oe)
    function new(string name = "SEQ");
        super.new(name);
        check_interrupts = 1;
    endfunction
    task seq_test;
        bit [7:0] val;
        bit [7:0] oe_val;

        uvm_report_info(get_name(), "***** Polling mode, FIFO DISABLED: No Override *****");
        if (!std::randomize(val))
            uvm_report_fatal(get_name(), "FAILED TO RANDOMIZE");
        if (!(std::randomize(oe_val) with { oe_val != val; }))
            uvm_report_fatal(get_name(), "FAILED TO RANDOMIZE");

        seq_uart_write(val);
        poll_lsr_tf(result);

        seq_uart_write(oe_val);

        seq_wait_clk_ticks(1);  // need one clock delay for iir to update
        seq_get_iir(result);

        seq_get_lsr(result);
        assert(result == 0) else uvm_report_error(get_name(),
            $sformatf("LSR is %0h but expected NULL", result)
        );

        poll_lsr_dr(result);
        assert(result == ((1 << `UART_LSR_DR))) else
        uvm_report_error(get_name(), $sformatf("LSR is %0h but expected DR", result));

        seq_get_iir(result, .erbfi(1));

        poll_lsr_te(result);
        assert(result == ((1 << `UART_LSR_DR) | (1 << `UART_LSR_TF) | (1 << `UART_LSR_TE))) else
        uvm_report_error(get_name(), $sformatf("LSR is %0h but expected DR+TF+TE", result));

        seq_get_iir(result, .etbei(1), .erbfi(1));
        seq_uart_read(val, result);

        poll_lsr_dr(result);
        assert(result == ((1 << `UART_LSR_DR) | (1 << `UART_LSR_TF) | (1 << `UART_LSR_TE))) else
        uvm_report_error(get_name(), $sformatf("LSR is %0h but expected DR+TF+TE", result));
        seq_get_iir(result, .etbei(1), .erbfi(1));
        
        seq_uart_read(oe_val, result);
        seq_get_iir(result, .etbei(1));
        seq_get_iir(result, .etbei(2));
        seq_get_lsr(result);
        assert(result == ((1 << `UART_LSR_TF) | (1 << `UART_LSR_TE))) else
        uvm_report_error(get_name(), $sformatf("LSR is %0h but expected DR+TF+TE", result));
    endtask
endclass


/*
Write then read after OE was set
*/
class sequence_polling_mode_fifo_dis_oe_case_read_after_oe extends sequence_loopback;
    `uvm_object_utils(sequence_polling_mode_fifo_dis_oe_case_read_after_oe)
    uvm_event ev_scb;

    function new(string name = "SEQ");
        super.new(name);
        ev_scb = ev_pool.get("EV_FLUSH_QUEUES");
        ev_scb.reset();
        check_interrupts = 1;
    endfunction

    task seq_test;
        bit [7:0] val;
        bit [7:0] oe_val;

        uvm_report_info(get_name(), "*** Polling mode, FIFO DISABLED: Override 1 byte ***");
        if (!std::randomize(val))
            uvm_report_fatal(get_name(), "FAILED TO RANDOMIZE");
        if (!(std::randomize(oe_val) with { oe_val != val; }))
            uvm_report_fatal(get_name(), "FAILED TO RANDOMIZE");

        seq_uart_write(val);
        poll_lsr_tf(result);

        seq_uart_write(oe_val);
        seq_get_lsr(result);
        assert(result == 0) else uvm_report_error(get_name(),
            $sformatf("LSR is %0h but expected NULL", result)
        );

        if (ral.csr.ier.get_mirrored_value()) begin
            wait_for_irq(result, .erbfi(1));
            wait_for_irq(result, .elsi(1));

            poll_lsr_oe(result);
            assert(result == ((1 << `UART_LSR_DR) | (1 << `UART_LSR_TF) | (1 << `UART_LSR_TE) | (1 << `UART_LSR_OE)))
            else uvm_report_error(get_name(),
                $sformatf("LSR is %0h but expected DR+TF+TE+OE", result)
            );
            wait_for_irq(result, .erbfi(1));
        end else begin
            poll_lsr_dr(result);
            assert(result == (1 << `UART_LSR_DR)) else
            uvm_report_error(get_name(), $sformatf("LSR is %0h but expected DR", result));

            poll_lsr_oe(result);
            assert(result == ((1 << `UART_LSR_DR) | (1 << `UART_LSR_TF) | (1 << `UART_LSR_TE) | (1 << `UART_LSR_OE)))
            else uvm_report_error(get_name(),
                $sformatf("LSR is %0h but expected DR+TF+TE+OE", result)
            );
            seq_get_iir(result);
        end
        // in this case scoreboard recieves all bytes, then sees OE, and should remove all bytes except top one
        seq_uart_read(val, result);

        seq_get_lsr(result);
        assert(result == ((1 << `UART_LSR_TF) | (1 << `UART_LSR_TE))) else
        uvm_report_error(get_name(), $sformatf("LSR is %0h but expected TF+TE", result));
        seq_get_iir(result, .etbei(1));
        seq_get_iir(result, .etbei(2));
        ev_scb.trigger();   // clear scb queue as last byte was lost
    endtask
endclass


/*
Write multiple then read after OE was set
*/
class sequence_polling_mode_fifo_dis_oe_case_read_after_multiple_oe extends sequence_loopback;
    `uvm_object_utils(sequence_polling_mode_fifo_dis_oe_case_read_after_multiple_oe)
    function new(string name = "SEQ");
        super.new(name);
    endfunction
    task seq_test;
        bit [7:0] val;
        bit [7:0] oe_val;
        bit [7:0] lost_byte;

        uvm_report_info(get_name(), "***** Polling mode, FIFO DISABLED: Override 2 bytes *****");
        if (!std::randomize(val))
            uvm_report_fatal(get_name(), "FAILED TO RANDOMIZE");
        if (!(std::randomize(oe_val) with { oe_val != val; }))
            uvm_report_fatal(get_name(), "FAILED TO RANDOMIZE");
        if (!(std::randomize(lost_byte) with { lost_byte != val; lost_byte != oe_val; }))
            uvm_report_fatal(get_name(), "FAILED TO RANDOMIZE");

        seq_uart_write(val);
        poll_lsr_tf(result);

        seq_uart_write(lost_byte);
        poll_lsr_tf(result);

        seq_uart_write(oe_val);

        // wait until lost byte received, OE should be 1 and tx is still sending
        poll_lsr_oe(result);
        assert(result == ((1 << `UART_LSR_DR) | (1 << `UART_LSR_OE))) else
        uvm_report_error(get_name(),
            $sformatf("LSR is %0h but expected DR+OE", result)
        );
        seq_get_iir(result);

        // TE will raise in start of Tx third byte STOP state
        poll_lsr_te(result);
        assert(result == ((1 << `UART_LSR_DR) | (1 << `UART_LSR_TF) | (1 << `UART_LSR_TE))) else
        uvm_report_error(get_name(), $sformatf("LSR is %0h but expected DR+TF+TE", result));
        
        // first byte is recieved anyway
        // in this case scoreboard recieves all bytes, then sees OE, and should remove all middle bytes
        seq_uart_read(val, result);

        // third byte is still being sent and should be recieved
        poll_lsr_dr(result);
        assert(result == ((1 << `UART_LSR_DR) | (1 << `UART_LSR_TF) | (1 << `UART_LSR_TE))) else
        uvm_report_error(get_name(), $sformatf("LSR is %0h but expected DR+TF+TE", result));
        seq_uart_read(oe_val, result);

        // no more bytes
        seq_get_lsr(result);
        assert(result == ((1 << `UART_LSR_TF) | (1 << `UART_LSR_TE))) else
        uvm_report_error(get_name(), $sformatf("LSR is %0h but expected TF+TE", result));
    endtask
endclass


class sequence_polling_mode_fifo_en_oe_case extends sequence_loopback;
    `uvm_object_utils(sequence_polling_mode_fifo_en_oe_case)
    uvm_event ev_scb;

    function new(string name = "SEQ");
        super.new(name);
        ev_scb = ev_pool.get("EV_FLUSH_QUEUES");
        ev_scb.reset();
        check_interrupts = 1;
    endfunction

    task pre_start;
        super.pre_start();
        seq_set_fcr(1 << `UART_FCR_FIFOEN);
        uvm_report_info(get_name(), "--- FIFO ENBALED ---");
        uvm_report_info(get_name(), "***** Polling mode, FIFO ENABLED: Override 1 byte *****");
    endtask

    task seq_test;
        bit [7:0] val;

        fill_fifo_randomly();
        seq_get_iir(result);

        poll_lsr_te(result, cfg.get_ticks_per_word() * FIFO_DEPTH);
        assert(result == ((1 << `UART_LSR_DR) | (1 << `UART_LSR_TF) | (1 << `UART_LSR_TE))) else
        uvm_report_error(get_name(),
            $sformatf("LSR is %0h but expected DR+TF+TE", result)
        );

        val = $urandom_range(255);
        seq_uart_write(val);

        seq_wait_clk_ticks(1);  // etbei will clear after one clock delay
        seq_get_iir(result, .erbfi(1));
        wait_for_irq(result, .elsi(1));

        poll_lsr_oe(result);
        assert(result == ((1 << `UART_LSR_DR) | (1 << `UART_LSR_TF) | (1 << `UART_LSR_TE) | (1 << `UART_LSR_OE)))
        else uvm_report_error(get_name(),
            $sformatf("LSR is %0h but expected DR+TF+TE+OE", result)
        );
        seq_get_iir(result, .etbei(1), .erbfi(1));

        seq_get_lsr(result);
        assert(result == ((1 << `UART_LSR_DR) | (1 << `UART_LSR_TF) | (1 << `UART_LSR_TE))) else
        uvm_report_error(get_name(), $sformatf("LSR is %0h but expected DR+TF+TE", result));

        val = $urandom_range(255);
        seq_uart_write(val);
        seq_get_iir(result, .etbei(2), .erbfi(1));
        wait_for_irq(result, .elsi(1));

        poll_lsr_oe(result);
        assert(result == ((1 << `UART_LSR_DR) | (1 << `UART_LSR_TF) | (1 << `UART_LSR_TE) | (1 << `UART_LSR_OE)))
        else uvm_report_error(get_name(),
            $sformatf("LSR is %0h but expected DR+TF+TE+OE", result)
        );
        seq_get_iir(result, .etbei(1), .erbfi(1));

        seq_get_lsr(result);
        assert(result == ((1 << `UART_LSR_DR) | (1 << `UART_LSR_TF) | (1 << `UART_LSR_TE))) else
        uvm_report_error(get_name(), $sformatf("LSR is %0h but expected DR+TF+TE", result));

        for (int i = 0; i < FIFO_DEPTH; i = i + 1) begin
            seq_get_iir(result, .etbei(1), .erbfi(1));
            poll_lsr_dr(result);
            assert(result == ((1 << `UART_LSR_DR) | (1 << `UART_LSR_TF) | (1 << `UART_LSR_TE))) else
            uvm_report_error(get_name(), $sformatf("LSR is %0h but expected DR+TF+TE", result));
            val = fifo.pop_front();
            seq_uart_read(val, result);
        end

        seq_get_lsr(result);
        assert(result == ((1 << `UART_LSR_TF) | (1 << `UART_LSR_TE))) else
        uvm_report_error(get_name(), $sformatf("LSR is %0h but expected TF+TE", result));
        seq_get_iir(result, .etbei(1));
        seq_get_iir(result, .etbei(2));

        ev_scb.trigger();   // clear scb queue as last byte was lost
    endtask
endclass


class sequence_external extends uvm_sequence #(pin_sample);
    `uvm_object_utils(sequence_external)

    top_config cfg;
    rand bit stop_bit_valid;
    rand bit parity_bit_valid;
    rand bit idle;
    rand int value;
    int max_glitch_rate = 0;// glitches percantage per byte (out of 100% sys clock ticks)
    int max_glitch_len = 0; // glitch clocks duration

    function new(string name = "SEQ_EXT");
        super.new(name);
    endfunction

    task pre_start;
        req = pin_sample::type_id::create();
        if (!uvm_config_db#(top_config)::get(null, "", "cfg", cfg))
            uvm_report_fatal(get_name(), "cfg is not in db");
    endtask

    task send_sin(input bit din);
        start_item(req);
        req.sin = din;
        // this if can be used in each state to force rx_clock
        //if (i == 0) req.rclk = 1; else
        //if (i % (cfg.DIVISOR / 2) == 0) req.rclk = ~req.rclk;
        finish_item(req);
    endtask

    task send_bit(input bit din, input int clk_num = 0);
        int glithes_arr [$];
        int unsigned val;
        int max_glitches = 0;
        int TICK_DELTA = `UART_TICKS_NUM > 8 ? 2 : 1;

        TICK_DELTA = TICK_DELTA * cfg.DIVISOR;
        if (!clk_num) clk_num = cfg.get_ticks_per_bit();

        if (max_glitch_rate) begin
            max_glitches = clk_num * max_glitch_rate / 100;

            for (int i = 0; i < max_glitches; i = i + 1) begin
                if (max_glitch_len < 2) begin
                    if (!std::randomize(val) with {
                        val > 0;
                        val < clk_num;
                        !(val inside {glithes_arr});
                        !(val % (max_glitch_len + 2));    // ensure no consecutive glitches
                    }) begin
                        uvm_report_warning(get_name(), "Looks like no more space for glitches");
                        continue;
                    end
                end else begin
                    // IF GLITCH DURATION LASTS LONGER THAN 1 SYS CLOCK THEN NO GLITCHES AROUND THE MIDDLE (FOR NOW) !
                    if (!std::randomize(val) with {
                        val > 0;
                        val < clk_num;
                        !(val inside {glithes_arr});
                        !(val % (max_glitch_len + 2));
                        val > ((clk_num / 2) + TICK_DELTA) || val < ((clk_num / 2) - TICK_DELTA);
                    }) begin
                        uvm_report_warning(get_name(), "Looks like no more space for glitches?");
                        continue;
                    end
                end

                uvm_report_info(get_name(),
                    $sformatf("Glitch #%0d on clock %0d", i, val), UVM_FULL
                );
                for (int j = 0; j < max_glitch_len; j = j + 1)
                    glithes_arr.push_back(val + j);
            end
        end

        for (int i = 0; i < clk_num; i = i + 1) begin
            if (max_glitch_rate && (i inside {glithes_arr}))
                send_sin(~din);
            else
                send_sin(din);
        end
    endtask

    task body;
        int val;
        int clocks_per_bit = cfg.get_ticks_per_bit();

        value = value & ((1 << cfg.WORD_LEN) - 1);
        val = value;

        uvm_report_info(get_name(),
            $sformatf("*** SEND via SIN [%2h] :: DIV[%0d] :: WSL[%0d] :: SB[%0d] :: PE[%0d] :: EP[%0d] ***",
                val, cfg.DIVISOR, cfg.WORD_LEN, cfg.STOP_BITS, cfg.PARITY_EN, cfg.EVEN_PARITY
            )
        );
        if (!stop_bit_valid)
            uvm_report_info(get_name(), $sformatf("*** SEND INVALID STOP BIT ***"));
        if (cfg.PARITY_EN && !parity_bit_valid)
            uvm_report_info(get_name(), $sformatf("*** SEND INVALID PARITY BIT ***"));

        // IDLE state
        if (idle) send_bit(1);

        // START state
        send_bit(0);

        // DATA state
        for (int i = 0; i < cfg.WORD_LEN; i = i + 1) begin
            send_bit(val & 1);
            val = val >> 1;
        end

        // PARITY state
        if (cfg.PARITY_EN) begin
            val = cfg.get_parity_bit(value);
            val = parity_bit_valid ? val : ~val;
            send_bit(val);
        end

        // STOP state
        send_bit(stop_bit_valid, clocks_per_bit - 1);
        if (cfg.STOP_BITS == 2) begin
            if (cfg.WORD_LEN == 5)
                send_bit(1, clocks_per_bit / 2);
            else
                send_bit(1);
                // second bit must be 1 so that our rx fsm stays synced for test purpose
                // TODO: add test to send 2 zero stop bits and see rx fsm returns to idle after that.
                // But maybe it is still a bug and rx fsm should wait for both bits before switching to next state?
        end
        send_sin(1);    // lastly send 1, in case parent sequence delays next send
    endtask
endclass


class sequence_send_sin extends base_sequence;
    `uvm_object_utils(sequence_send_sin)

    sequencer_pins sqr_pin;
    sequence_external seq_ext;

    function new(string name = "SEQ");
        super.new(name);
    endfunction

    task pre_start;
        super.pre_start();
        seq_ext = sequence_external::type_id::create();
        if (!uvm_config_db#(sequencer_pins)::get(null, "", "sqr_pin", sqr_pin))
            uvm_report_fatal(get_name(), "sqr_pin is not in db");
        if (sqr_pin == null) uvm_report_fatal(get_name(), "PIN sequencer is null");
        seq_set_divisor($urandom_range(32, 2) & 'hFFFE);    // even divisor
    endtask

    virtual task seq_test;
        send_valid_byte();
        send_invalid_byte();
    endtask

    task send_valid_byte;
        /*
        seq_ext.value = value;
        seq_ext.stop_bit_valid = 1;
        seq_ext.parity_bit_valid = 1;
        seq_ext.idle = 1;
        */
        if (!(seq_ext.randomize() with { stop_bit_valid == 1; parity_bit_valid == 1; idle == 1; }))
            uvm_report_fatal(get_name(), "FAILED TO RANDOMIZE");
        seq_ext.start(sqr_pin);

        poll_lsr_dr(result, cfg.get_ticks_per_bit());
        assert(result == ((1 << `UART_LSR_DR) | (1 << `UART_LSR_TF) | (1 << `UART_LSR_TE))) else
        uvm_report_error(get_name(), $sformatf("LSR is %0h but expected DR+TF+TE", result));
        seq_get_iir(result);

        seq_uart_read(seq_ext.value, result);

        seq_get_lsr(result);
        assert(result == ((1 << `UART_LSR_TF) | (1 << `UART_LSR_TE))) else
        uvm_report_error(get_name(), $sformatf("LSR is %0h but expected TF+TE", result));
        seq_get_iir(result);
    endtask

    task send_invalid_byte;
        int value;
        if (cfg.PARITY_EN)
            void'(seq_ext.randomize() with { parity_bit_valid == 0; idle == 0; });
        else
            void'(seq_ext.randomize() with { stop_bit_valid == 0; idle == 0; });
        seq_ext.start(sqr_pin);

        value = (1 << `UART_LSR_DR) | (1 << `UART_LSR_TF) | (1 << `UART_LSR_TE);
        if (cfg.PARITY_EN)
            value = value | (1 << `UART_LSR_PE);
        if (!seq_ext.stop_bit_valid)
            value = value | (1 << `UART_LSR_FE);

        poll_lsr_dr(result, cfg.get_ticks_per_bit());
        assert(result == value) else
        uvm_report_error(get_name(), $sformatf("LSR is %0h but expected %0h", result, value));
        seq_get_iir(result);

        seq_uart_read(seq_ext.value, result);
        seq_get_lsr(result);
        assert(result == ((1 << `UART_LSR_TF) | (1 << `UART_LSR_TE))) else
        uvm_report_error(get_name(), $sformatf("LSR is %0h but expected TF+TE", result));
        seq_get_iir(result);
    endtask
endclass


class sequence_send_sin_fifo_en extends sequence_send_sin;
    `uvm_object_utils(sequence_send_sin_fifo_en)
    function new(string name = "SEQ");
        super.new(name);
        check_interrupts = 1;
    endfunction

    task pre_start;
        super.pre_start();
        seq_set_fcr(1 << `UART_FCR_FIFOEN);
        uvm_report_info(get_name(), "--- FIFO ENBALED ---");
    endtask

    task seq_test;
        send_data();
        get_data();
    endtask

    task send_data;
        int value;
        for (int i = 0; i < FIFO_DEPTH / 2; i = i + 1) begin
            // send valid:
            if (!(seq_ext.randomize() with { stop_bit_valid == 1; parity_bit_valid == 1; idle == 1; }))
                uvm_report_fatal(get_name(), "FAILED TO RANDOMIZE");
            seq_ext.start(sqr_pin);
            fifo.push_back(seq_ext.value);

            // send invalid
            if (cfg.PARITY_EN) begin
                if (!(seq_ext.randomize() with { parity_bit_valid == 0; idle == 0; }))
                    uvm_report_fatal(get_name(), "FAILED TO RANDOMIZE");
            end else begin
                if (!(seq_ext.randomize() with { stop_bit_valid == 0; idle == 0; }))
                    uvm_report_fatal(get_name(), "FAILED TO RANDOMIZE");
            end
            seq_ext.start(sqr_pin);
            value = seq_ext.value;
            if (!seq_ext.stop_bit_valid) value = value | 'h200;
            if (cfg.PARITY_EN && !seq_ext.parity_bit_valid)  value = value | 'h100;
            fifo.push_back(value);
        end
    endtask

    task get_data;
        int value;
        int lsr;
        for (int i = 0; i < FIFO_DEPTH / 2; i = i + 1) begin
            // expected first value to be valid:
            poll_lsr_dr(result);
            lsr = (1 << `UART_LSR_DR) | (1 << `UART_LSR_TF) | (1 << `UART_LSR_TE);
            assert(result == lsr) else uvm_report_error(get_name(),
                $sformatf("LSR is %0h but expected DR+TF+TE", result)
            );

            seq_get_iir(result, .etbei(2), .erbfi(1));

            value = fifo.pop_front();
            seq_uart_read(value, result);

            // expect next value to be invalid:
            value = fifo.pop_front();
            wait_for_irq(result, .elsi(1));
            if (i == ((FIFO_DEPTH / 2) - 1) && ral.csr.ier.get_mirrored_value()) begin
                // in this case we can first fetch the last one then read LSR to check the bit was not cleared
                seq_uart_read(value, result);
                wait_for_irq(result, .elsi(1));
                seq_get_lsr(result);
                lsr = (1 << `UART_LSR_TF) | (1 << `UART_LSR_TE);
                if (value & 'h100) lsr = lsr | (1 << `UART_LSR_PE);
                if (value & 'h200) lsr = lsr | (1 << `UART_LSR_FE);
                assert(result == lsr) else uvm_report_error(get_name(),
                    $sformatf("Last byte: LSR is %0h but expected %0h", result, lsr)
                );
            end else begin
                seq_get_iir(result, .etbei(2), .erbfi(1), .elsi(1));
                poll_lsr_dr(result);
                lsr = (1 << `UART_LSR_DR) | (1 << `UART_LSR_TF) | (1 << `UART_LSR_TE);
                if (value & 'h100) lsr = lsr | (1 << `UART_LSR_PE);
                if (value & 'h200) lsr = lsr | (1 << `UART_LSR_FE);
                assert(result == lsr) else uvm_report_error(get_name(),
                    $sformatf("LSR is %0h but expected %0h", result, lsr)
                );
                seq_get_iir(result, .etbei(2), .erbfi(1));
                seq_uart_read(value, result);
            end
        end

        if (ral.csr.ier.get_mirrored_value() != (1 << `UART_IER_ETBEI)) begin
            //seq_wait_clk_ticks(1);  // for now need one clock delay
            seq_get_iir(result, .etbei(1));
        end

        seq_get_iir(result, .etbei(2));
        seq_get_lsr(result);
        assert(result == ((1 << `UART_LSR_TF) | (1 << `UART_LSR_TE))) else
        uvm_report_error(get_name(), $sformatf("Rx end: LSR is %0h but expected TF+TE", result));
    endtask
endclass



class sequence_send_sin_fifo_en_consecutive_errors extends sequence_send_sin;
    `uvm_object_utils(sequence_send_sin_fifo_en_consecutive_errors)
    function new(string name = "SEQ");
        super.new(name);
    endfunction

    task pre_start;
        super.pre_start();
        seq_set_fcr(1 << `UART_FCR_FIFOEN);
        uvm_report_info(get_name(), "--- FIFO ENBALED ---");
    endtask

    task seq_test;
        if (cfg.STOP_BITS != 2) return;
        send_data();
        get_data();
    endtask

    task send_data;
        int value;
        for (int i = 0; i < FIFO_DEPTH; i = i + 1) begin
            if (cfg.PARITY_EN) begin
                if (!(seq_ext.randomize() with { parity_bit_valid == 0; stop_bit_valid == 1; idle == 0; }))
                    uvm_report_fatal(get_name(), "FAILED TO RANDOMIZE");
            end else begin
                if (!(seq_ext.randomize() with { parity_bit_valid == 1; stop_bit_valid == 0; idle == 0; }))
                    uvm_report_fatal(get_name(), "FAILED TO RANDOMIZE");
            end
            if (i == 0) seq_ext.idle = 1;
            seq_ext.start(sqr_pin);
            value = seq_ext.value;
            if (!seq_ext.stop_bit_valid)    value = value | 'h200;
            if (!seq_ext.parity_bit_valid)  value = value | 'h100;
            fifo.push_back(value);
        end
    endtask

    task get_data;
        int value;
        int lsr;
        uvm_report_info(get_name(), "--- GET DATA START ---");
        for (int i = 0; i < FIFO_DEPTH; i = i + 1) begin
            value = fifo.pop_front();
            if (i == (FIFO_DEPTH - 1) && ral.csr.ier.get_mirrored_value()) begin
                // in this case we can first fetch the last one then read LSR to check the bit was not cleared
                seq_uart_read(value, result);
                poll_lsr_dr(result);
                lsr = (1 << `UART_LSR_TF) | (1 << `UART_LSR_TE);
                if (value & 'h100) lsr = lsr | (1 << `UART_LSR_PE);
                if (value & 'h200) lsr = lsr | (1 << `UART_LSR_FE);
                assert(result == lsr) else uvm_report_error(get_name(),
                    $sformatf("Last byte: LSR is %0h but expected %0h", result, lsr)
                );
            end else begin
                if (i == 0)
                    poll_lsr_tf(result);
                else
                    poll_lsr_dr(result);
                lsr = (1 << `UART_LSR_DR) | (1 << `UART_LSR_TF) | (1 << `UART_LSR_TE);
                if (value & 'h100) lsr = lsr | (1 << `UART_LSR_PE);
                if (value & 'h200) lsr = lsr | (1 << `UART_LSR_FE);
                assert(result == lsr) else uvm_report_error(get_name(),
                    $sformatf("LSR is %0h but expected %0h", result, lsr)
                );
                seq_uart_read(value, result);
            end
        end

        seq_get_iir(result, .etbei(1));
        seq_get_lsr(result);
        assert(result == ((1 << `UART_LSR_TF) | (1 << `UART_LSR_TE))) else
        uvm_report_error(get_name(), $sformatf("Rx end: LSR is %0h but expected TF+TE", result));
    endtask
endclass


/* Glitch test */
class sequence_send_sin_fifo_dis_glitch extends sequence_send_sin;
    `uvm_object_utils(sequence_send_sin_fifo_dis_glitch)
    uvm_event ev_scb;

    function new(string name = "SEQ");
        super.new(name);
        ev_scb = ev_pool.get("EV_SKIP_CHECKS");
        ev_scb.reset();
    endfunction

    task pre_start;
        super.pre_start();
        seq_ext.max_glitch_len = 1; // for now not supporting glitches longer than one clock !!
        seq_ext.max_glitch_rate = 10;   // 10% glitchness !!
        ev_scb.trigger();
    endtask

    task post_start;
        super.post_start();
        ev_scb.reset();
    endtask

    task seq_test;
        seq_set_divisor($urandom_range(cfg.get_divisor(921.6), 4) & 'hFFFE);    // even divisor, bigger than 4
        send_valid_byte();
    endtask
endclass
