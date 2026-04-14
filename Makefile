.ONESHELL:
#SHELL := /bin/bash
pwd := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
SHELL := $(pwd)vvp.sh
SIM ?= iverilog
RM_OBJDIR := false
DEBUG_ARG := -CFLAGS \"-g -DDEBUG_MODE\"

#export UVM_HOME := $(HOME)/dev/sda6/UVM/1800.2-2020/src
export UVM_HOME := $(HOME)/dev/sda6/UVM/UVM1.2/src

VERILATOR_ARGS := 	-Wno-lint -Wno-TIMESCALEMOD -Wno-SELRANGE -Wno-UNOPTFLAT -Wno-SPLITVAR \
					--assert --coverage --public-flat-rw --pins-inout-enables \
					--trace-vcd --timing -y $(pwd)modules +incdir+$(pwd)modules -j 1 --build --cc

define get_coverage
	pwd
	verilator_coverage --write coverage_merged.dat $$(find . -type f -name "cov_*.dat" | xargs)
	grep -v "testbench" coverage_merged.dat > coverage_merged_notb.dat
	verilator_coverage --write-info coverage_merged.info coverage_merged_notb.dat
	sed -i 's|../modules|modules|g' coverage_merged.info
	genhtml -o "covhtml" coverage_merged.info
	# find . -type f -name "*.html" -exec sed -i 's|../../../|../|g' {} +
endef

define run_verilator
	if [ "$(RM_OBJDIR)" = "true" ]; then find . -type d -name "obj_dir" -exec rm -rf {} +; fi
	cmd="verilator $(ARG) $(VERILATOR_ARGS) --binary --top $(1) $(2) && ./obj_dir/V$(1)"
	echo $$cmd; eval "$$cmd" && mv coverage.dat cov_$(1).dat || true
endef

define run_sim
	if [[ "$(SIM)" == "iverilog" ]]; then
		if [[ "$(2)" == *".sv"* ]]; then sysv="-g2012"; else sysv=""; fi
		cmd="iverilog $(ARG) -Wall $$sysv -gspecify -y $(pwd)modules -I $(pwd)modules -o $(if $(3), $(3), "vcd/")$(1).vvp -s $(1) $(2) && vvp $(if $(3), $(3), "vcd/")$(1).vvp"
		echo $$cmd; eval $$cmd
	else
		$(call run_verilator,$(1),$(2))
	fi
endef
define run_module
	cd modules || true;
	$(call run_sim,$(1),$(2))
endef
define sverilog_tb
	$(call run_sim,$(1),$(2),"dir/")
endef


ver:
	$(call run_verilator,$(TOP),$(SRC))
vvp:
	$(call sverilog_tb,$(TOP),$(SRC),"")

clean:
	find . -type f -name "*.vvp" -delete
	find . -type f -name "dsim.*" -delete
	find . -type f -name "dvlcom.*" -delete
	find . -type f -name "cov*.dat" -delete
	find . -type f -name "*.info" -delete
	find . -type d -name "obj_dir" -exec rm -rf {} +
	find . -type d -name "covhtml" -exec rm -rf {} +


lint:
	verilator --lint-only -Wall -y $(pwd)modules -I$(pwd)modules/ $(ARG)
lint-modules:
	cd modules; verilator --lint-only -Wall $$(ls *.*v* | xargs)
lint-risc:
	cd RISCV_SingleCycle;
	verilator --lint-only -Wall -y $(pwd)modules -I$(pwd)modules/ $(risc_src)
lint-uart:
	cd UART;
	verilator --lint-only -Wall -y $(pwd)modules -I$(pwd)modules/ $(uart_src)

coverage:
	$(MAKE) -s regression SIM=verilator RM_OBJDIR=true
	#uart risc
	$(call get_coverage)


# Modules Regression suite
grep_err := 2>&1 |grep -a -v -E 'timescale|dangling' |grep -a -i -E 'error|end of|warning' || true
all:
	$(MAKE) -s regression uart risc $(grep_err)
regression:
	$(MAKE) -s adder half_adder fastadder mux decoder priority_enc sequence mux_cmos
	$(MAKE) -s counter fifo memory shift_reg shift
uart:
	$(MAKE) -s baud_tb uart_rx_tb uart_tx_tb uart_tb uart_top_tb uartcpp
risc:
	$(MAKE) -s risc_tb_arr risc_tb_bub risc_tb_fib


# Modules Testbenches
adder:
	$(call run_module,adder_tb,testbench/adder_tb.v adder.v)
fastadder:
	$(call run_module,fast_adder_tb,testbench/adder_tb.v adder.v)
counter: csrc = testbench/counter_tb.v counter.v
counter:
	$(call run_module,counter_dff_tb,$(csrc))
	$(call run_module,counter_jkff_tb,$(csrc))
	$(call run_module,counter_tff_sync_tb,$(csrc))
	$(call run_module,counter_tff_async_tb,$(csrc))
fifo:
	$(call run_module,fifo_tb,testbench/fifo_tb.v fifo.v)
half_adder:
	$(call run_module,half_adder_tb,testbench/half_adder_tb.v adder.v)
mux:
	$(call run_module,mux_tb,testbench/mux_tb.v mux.v)
	$(call run_module,mux_tb,-DBEHAVIORAL testbench/mux_tb.v mux.v)
ifeq ($(SIM), iverilator)
mux_cmos:
	$(call run_module,mux_cmos_tb,testbench/mux_cmos_tb.v mux_cmos.v)
endif
decoder:
	$(call run_module,decoder_tb,testbench/decoder_tb.v mux.v)
priority_enc:
	$(call run_module,priority_enc_tb,testbench/priority_enc_tb.v mux.v)
sequence:
	$(call run_module,sequence_tb,testbench/sequence_tb.v sequence.v)
shift_reg:
	$(call run_module,shift_reg_tb,testbench/shift_reg_tb.v shift_reg.v)
shift:
	$(call run_module,shift_tb,testbench/shift_tb.v shift.v mux.v)
memory:
	$(call run_module,memory_tb,testbench/memory_tb.v ../RISCV_SingleCycle/risc_pkg.sv memory.sv)


# UART
uart_src := uart_top.sv uart.sv clock_divider.sv uart_tx.sv uart_rx.sv
baud_tb:
	cd UART; $(call sverilog_tb,baud_tb,testbench/testbench.sv clock_divider.sv)
uart_rx_tb:
	cd UART; $(call sverilog_tb,uart_rx_tb,testbench/testbench.sv ${uart_src})
uart_tx_tb:
	cd UART; $(call sverilog_tb,uart_tx_tb,testbench/testbench.sv ${uart_src})
uart_tb:
	cd UART; $(call sverilog_tb,uart_tb,testbench/testbench.sv ${uart_src})
uart_top_tb:
	cd UART; $(call sverilog_tb,uart_top_tb,testbench/testbench.sv ${uart_src})
uartcpp: ARG := $(VERILATOR_ARGS) $(ARG) -DCONST_DELAYS_OFF -CFLAGS "-I../driver/" --exe 
uartcpp: SRC := testbench/uart_tb.cpp driver/uart_driver.cpp testbench/uart_verilated.cpp
uartcpp:
	cd UART; tb=uart_top;
	tb_cpp="testbench/uart_tb.cpp driver/uart_driver.cpp testbench/uart_verilated.cpp";
	verilator $(ARG) -DCONST_DELAYS_OFF -CFLAGS "-I../driver/" $(VERILATOR_ARGS) --exe --top $$tb $$tb_cpp $(uart_src) && ./obj_dir/V$$tb
	mv coverage.dat cov_uartcpp.dat || true
	# for debugging add: ARG='-CFLAGS "-g -DDEBUG_MODE"'



# RISCV
risc_src := risc_pkg.sv riscv.sv fetch.sv decode.sv register_file.sv branch_control.sv control.sv alu.sv data_memory.sv ../modules/memory.sv ../modules/adder.v ../modules/shift.v ../modules/mux.v
riscvvp:
	cd RISCV_SingleCycle; $(call sverilog_tb,tb_riscv,tb_riscv.sv ${risc_src})
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
