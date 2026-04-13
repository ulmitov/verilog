.ONESHELL:
#SHELL := /bin/bash
pwd := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
SHELL := $(pwd)vvp.sh

#export UVM_HOME := $(HOME)/dev/sda6/UVM/1800.2-2020/src
export UVM_HOME := $(HOME)/dev/sda6/UVM/UVM1.2/src

VERILATOR_ARGS := 	-Wno-lint -Wno-TIMESCALEMOD --assert --coverage --public-flat-rw --pins-inout-enables \
					--trace-vcd --timing -y ../modules +incdir+$(pwd)modules -j 0 --build --cc

define get_coverage
	verilator_coverage --write merged_coverage.dat $$(ls *.dat | xargs)
	verilator_coverage --write-info merged.info merged_coverage.dat
	genhtml -o "html" merged.info
	find . -type f -name "*.html" -exec sed -i 's|../../../|../|g' {} +
endef

define verilator_tb
	verilator $(VERILATOR_ARGS) --binary --top $(1) $(2) && ./obj_dir/V$(1)
	mv coverage.dat $(1).dat || true
endef

define iverilog_tb
	cd modules || true; iverilog -Wall -g2005 -gspecify -o ./vcd/$(1)_tb.vvp -s $(1)_tb $(if $(2),$(2),testbench/$(1)_tb.v) $(if $(2),,$(1).v) && vvp ./vcd/$(1)_tb.vvp
endef

define iverilog
	iverilog -Wall -gspecify -o $(1).vvp -s $(1) $(2) && vvp $(1).vvp
endef

define sverilog_tb
	iverilog -Wall -g2012 -gspecify -y ../modules -I ../modules/ -o ./dir/$(1).vvp -s $(1) $(2) && vvp ./dir/$(1).vvp
endef

confirm:
	@read -p "Continue to next test? [y/N] " ans && [ $${ans:-N} = y ] || (echo "Aborted."; exit 1)

clean:
	find . -type f -name "*.vvp" -delete
	find . -type f -name "dsim.*" -delete
	find . -type f -name "dvlcom.*" -delete

ver:
	$(call verilator_tb,$(ARG),$(SRC))

vvp:
	$(call iverilog,$(ARG),$(SRC))

lint:
	verilator --lint-only -Wall -I./modules/ $(ARG)

lint-modules:
	cd modules; verilator --lint-only -Wall $$(ls *.*v* | xargs)

lint-risc:
	cd RISCV_SingleCycle;
	verilator --lint-only -Wall -I../modules/ $(risc_src)

lint-uart:
	cd UART;
	verilator --lint-only -Wall -I../modules/ $(uart_src)


# Modules Regression suite
grep_err := 2>&1 |grep -a -v -E 'timescale|dangling' |grep -a -i -E 'error|end of|warning' || true
all:
	$(MAKE) -s regression uart risc
regression:
	$(MAKE) -s adder half_adder mux mux_cmos decoder priority_enc sequence $(grep_err)
	$(MAKE) -s counter fastadder fifo memory shift_reg shift $(grep_err)
uart:
	$(MAKE) -s baud_tb uart_rx_tb uart_tx_tb uart_tb uart_top_tb uartcpp $(grep_err)
risc:
	$(MAKE) -s risc_tb_arr risc_tb_bub risc_tb_fib $(grep_err)
uartver:
	$(MAKE) -s uart_rx_tb_ver uart_tx_tb_ver uart_tb_ver uartcpp $(grep_err)
	cd UART; $(call get_coverage)

	
# Modules Testbenches
adder:
	$(call iverilog_tb,adder)
fastadder:
	$(call iverilog_tb,fast_adder,testbench/adder_tb.v adder.v)
counter:
	$(call iverilog_tb,counter_dff,testbench/counter_tb.v counter.v)
	$(call iverilog_tb,counter_jkff,testbench/counter_tb.v counter.v)
	$(call iverilog_tb,counter_tff_sync,testbench/counter_tb.v counter.v)
	$(call iverilog_tb,counter_tff_async,testbench/counter_tb.v counter.v)
fifo:
	$(call iverilog_tb,fifo)
half_adder:
	$(call iverilog_tb,half_adder,testbench/half_adder_tb.v adder.v)
mux:
	$(call iverilog_tb,mux)
mux_cmos:
	$(call iverilog_tb,mux_cmos)
decoder:
	$(call iverilog_tb,decoder,testbench/decoder_tb.v mux.v)
priority_enc:
	$(call iverilog_tb,priority_enc,testbench/priority_enc_tb.v mux.v)
sequence:
	$(call iverilog_tb,sequence)
shift_reg:
	$(call iverilog_tb,shift_reg)
shift:
	$(call iverilog_tb,shift,testbench/shift_tb.v shift.v mux.v)

memory:
	mem_src="../RISCV_SingleCycle/risc_pkg.sv memory.sv";
	cd modules; tb=memory_tb; verilator --lint-only -Wall -Wno-IMPORTSTAR $$mem_src;
	iverilog -Wall -g2012 -o ./vcd/$$tb.vvp -s $$tb testbench/$$tb.v $$mem_src && vvp ./vcd/$$tb.vvp

# UART
uart_src := uart_top.sv uart.sv clock_divider.sv uart_tx.sv uart_rx.sv
baud_tb:
	cd UART; $(call sverilog_tb,baud_tb,testbench/testbench.sv clock_divider.sv)

uart_rx_tb:
	cd UART; $(call sverilog_tb,uart_rx_tb,testbench/testbench.sv ${uart_src})
uart_rx_tb_ver:
	cd UART; $(call verilator_tb,uart_rx_tb,testbench/testbench.sv ${uart_src})

uart_tx_tb:
	cd UART; $(call sverilog_tb,uart_tx_tb,testbench/testbench.sv ${uart_src})
uart_tx_tb_ver:
	cd UART; $(call verilator_tb,uart_tx_tb,testbench/testbench.sv ${uart_src})

uart_tb:
	cd UART; $(call sverilog_tb,uart_tb,testbench/testbench.sv ${uart_src})
uart_tb_ver:
	cd UART; $(call verilator_tb,uart_tb,testbench/testbench.sv ${uart_src})

uart_top_tb:
	cd UART; $(call sverilog_tb,uart_top_tb,testbench/testbench.sv ${uart_src})
uart_top_tb_ver:
	cd UART; $(call verilator_tb,uart_top_tb,testbench/testbench.sv ${uart_src})

uartcpp:
	cd UART; tb=uart_top;
	tb_cpp="testbench/uart_tb.cpp driver/uart_driver.cpp testbench/uart_verilated.cpp";
	verilator $(ARG) -DCONST_DELAYS_OFF -CFLAGS "-I../driver/" $(VERILATOR_ARGS) --exe --top $$tb $$tb_cpp $(uart_src) && ./obj_dir/V$$tb
	mv coverage.dat uartcpp.dat || true
	# for debugging add: ARG='-CFLAGS "-g -DDEBUG_MODE"'

# RISCV
risc_src := risc_pkg.sv riscv.sv fetch.sv decode.sv register_file.sv branch_control.sv control.sv alu.sv data_memory.sv ../modules/memory.sv ../modules/adder.v ../modules/shift.v ../modules/mux.v
riscvvp:
	cd RISCV_SingleCycle; $(call sverilog_tb,tb_riscv,tb_riscv.sv ${risc_src})
riscver:
	cd RISCV_SingleCycle; $(call verilator_tb,tb_riscv,tb_riscv.sv ${risc_src})
risc_tb_arr:
	cd RISCV_SingleCycle; $(call sverilog_tb,tb_asm_arr,tb_riscv.sv ${risc_src})
risc_tb_bub:
	cd RISCV_SingleCycle; $(call sverilog_tb,tb_asm_bub,tb_riscv.sv ${risc_src})
risc_tb_fib:
	cd RISCV_SingleCycle; $(call sverilog_tb,tb_asm_fib,tb_riscv.sv ${risc_src})



# SystemVerilog ALU TB
alu:
	cd tb_sv_alu; tb=top_tb;
	alu_src="../modules/adder.v ../modules/shift.v ../modules/mux.v ../RISCV_SingleCycle/risc_pkg.sv ../RISCV_SingleCycle/alu.sv top_tb.sv";
	verilator $(VERILATOR_ARGS) --top $$tb $$alu_src && ./obj_dir/V$$tb


# FIFO UVM TB
uvm-fifo:
	cd tb_uvm_fifo;
	verilator $(VERILATOR_ARGS) --binary --top-module top_tb \
	+define+UVM_NO_DPI \+incdir+$(UVM_HOME)+$$(pwd)+../RISCV_SingleCycle \
	$(UVM_HOME)/uvm_pkg.sv ../modules/fifo.v top_tb.sv 
