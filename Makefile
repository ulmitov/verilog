.ONESHELL:
pwd := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
SHELL := $(pwd)vvp.sh
#SHELL := /bin/bash
SIM ?= iverilog
RM_OBJDIR := false
DEBUG_ARG := -CFLAGS \"-g -DDEBUG_MODE\"
RUNTIME_DBG := --prof-cfuncs -CFLAGS -DVL_DEBUG --stats --debug --runtime-debug
_mkvcdir := $(shell mkdir -p vcd)
#export UVM_HOME := $(HOME)/dev/sda6/UVM/1800.2-2020/src
export UVM_HOME := $(HOME)/dev/sda6/UVM/UVM1.2/src

VERILATOR_ARGS := 	-Wno-lint -Wno-TIMESCALEMOD -Wno-SELRANGE -Wno-UNOPTFLAT -Wno-SPLITVAR \
					--coverage --pins-inout-enables \
					--trace --timing -y modules -Imodules -j 1 --build --cc

define get_coverage
	pwd
	verilator_coverage --write coverage_merged.dat $$(find ./vcd -type f -name "cov_*.dat" | xargs)
	grep -v -E "UVM/|testbench|verilated_std.sv|tb_sv_alu|tb_uvm_fifo" coverage_merged.dat > coverage_merged_notb.dat
	verilator_coverage --write-info coverage_merged.info coverage_merged_notb.dat
	# sed -i 's|../modules|modules|g' coverage_merged.info
	# verilator_coverage --annotate-all obj_dir_merged merged_coverage.dat
	genhtml -o "covhtml" coverage_merged.info
	# find . -type f -name "*.html" -exec sed -i 's|../../../|../|g' {} +
endef

define run_verilator
	if [ "$(RM_OBJDIR)" = "true" ]; then find . -type d -name "obj_dir" -exec rm -rf {} +; fi
	cmd="verilator $(ARG) $(VERILATOR_ARGS) --binary --top $(1) $(2) && ./obj_dir/V$(1) +verilator+coverage+file+vcd/cov_$(1).dat"
	echo $$cmd; eval "$$cmd"
endef

define run_sim
	# out param can be used to specify output to non vcd folder using 3rd arg
	if [[ "$(SIM)" == "iverilog" ]]; then
		if [[ "$(2)" == *".sv"* ]]; then sysv="-g2012"; else sysv=""; fi
		out=$(if $(3),$(3)$(1).vvp,vcd/$(1).vvp)
		cmd="iverilog $(ARG) -Wall $$sysv -gspecify -y modules -Imodules -o $$out -s $(1) $(2) && vvp $$out"
		echo $$cmd; eval $$cmd
	else
		$(call run_verilator,$(1),$(2))
	fi
endef

define run_module
	$(call run_sim,$(1),modules/testbench/$(2) $(foreach x,$(3),modules/$(x)))
endef


clean:
	find . -type f -name "*.vvp" -delete
	find . -type f -name "dsim.*" -delete
	find . -type f -name "dvlcom.*" -delete
	find . -type f -name "cov*.dat" -delete
	find . -type f -name "*.info" -delete
	find . -type f -name "*.log" -delete
	find . -type d -name "obj_dir" -exec rm -rf {} +
	find . -type d -name "dsim_work" -exec rm -rf {} +
	find . -type d -name "covhtml" -exec rm -rf {} +

ver:
	$(call run_verilator,$(TOP),$(SRC))
vvp:
	$(call run_sim,$(TOP),$(SRC),"")

get_coverage:
	$(call get_coverage)
dsim_report:
	dcreport -out_dir dir metrics.db


lint:
	verilator --lint-only -Wall -y $(pwd)modules -I$(pwd)modules/ $(ARG)
lint-modules:
	cd modules; verilator --lint-only -Wall $$(ls *.*v* | xargs)
lint-risc:
	cd RISCV_SingleCycle;
	verilator --lint-only -Wall -y $(pwd)modules -I$(pwd)modules/ $(risc_src)
lint-uart:
	cd UART; verilator --lint-only -Wall -y $(pwd)modules -I$(pwd)modules/ $(uart_src)


# Regression suites
grep_err:
	grep -H -a -i -E 'error|end of|warning|assertion|segmentation|fatal|fail' ./*.log | grep -a -v -i -E 'timescale|time unit|dangling|Not enough words|Part select'
all:
	$(MAKE) -s regression uart risc
regression:
	$(MAKE) -s adder half_adder fastadder mux decoder priority_enc mux_cmos mux_behavioral_tb
	$(MAKE) -s sequence counters fifo memory shift_reg shift
uart:
	$(MAKE) -s uart_baud_tb uart_rx_tb uart_tx_tb uart_tb uart_top_tb uartcpp
risc:
	$(MAKE) -s risc_tb_arr risc_tb_bub risc_tb_fib
coverage:
	$(MAKE) -s regression uart risc alu SIM=verilator RM_OBJDIR=true
	$(call get_coverage)


# Modules Testbenches
adder:
	$(call run_module,adder_tb,adder_tb.v,adder.v)
fastadder:
	$(call run_module,fast_adder_tb,adder_tb.v,adder.v)
counters:
	$(call run_module,counter_dff_tb,counter_tb.v,counter.v)
	$(call run_module,counter_jkff_tb,counter_tb.v,counter.v)
	$(call run_module,counter_tff_sync_tb,counter_tb.v,counter.v)
	$(call run_module,counter_tff_async_tb,counter_tb.v,counter.v)
fifo:
	$(call run_module,fifo_tb,fifo_tb.v,fifo.v)
half_adder:
	$(call run_module,half_adder_tb,half_adder_tb.v,adder.v)
mux:
	$(call run_module,mux_tb,mux_tb.v,mux.v)
mux_behavioral_tb:
	$(eval ARG = -DBEHAVIORAL)
	$(call run_module,mux_behavioral_tb,mux_tb.v,mux.v)
decoder:
	$(call run_module,decoder_tb,decoder_tb.v,mux.v)
priority_enc:
	$(call run_module,priority_enc_tb,priority_enc_tb.v,mux.v)
sequence:
	$(call run_module,sequence_tb,sequence_tb.v,sequence.v)
shift_reg:
	$(call run_module,shift_reg_tb,shift_reg_tb.v,shift_reg.v)
shift:
	$(call run_module,shift_tb,shift_tb.v,shift.v mux.v)
memory:
	$(call run_module,memory_tb,memory_tb.v,../RISCV_SingleCycle/risc_pkg.sv memory.sv)
ifeq ($(SIM), iverilog)
mux_cmos:
	$(call run_module,mux_cmos_tb,mux_cmos_tb.v,mux_cmos.v)
endif

apb:
	$(call run_sim,apb_slave_tb,./AMBA/apb_slave.sv)


# UART
uart_src := $(foreach x,testbench/testbench.sv uart_top.sv uart.sv clock_divider.sv uart_tx.sv uart_rx.sv,UART/$(x))
uart_baud_tb:
	$(call run_sim,baud_tb,-I./UART UART/testbench/testbench.sv UART/clock_divider.sv)
uart_rx_tb:
	$(call run_sim,uart_rx_tb,-I./UART ${uart_src})
uart_tx_tb:
	$(call run_sim,uart_tx_tb,-I./UART ${uart_src})
uart_tb:
	$(call run_sim,uart_tb,-I./UART ${uart_src})
uart_top_tb:
	$(call run_sim,uart_top_tb,-I./UART ${uart_src})
uartcpp:
	tb=uart_top
	src="./UART/testbench/uart_tb.cpp ./UART/driver/uart_driver.cpp ./UART/testbench/uart_verilated.cpp"
	args="$(VERILATOR_ARGS) $(ARG) --public-flat-rw -DCONST_DELAYS_OFF -CFLAGS "-I../UART/driver" -IUART --exe"
	verilator $$args --top $$tb $$src $(uart_src) && ./obj_dir/V$$tb
	mv coverage.dat vcd/cov_uartcpp.dat
	# for debugging add: ARG='-CFLAGS "-g -DDEBUG_MODE"'


# RISCV
risc_src := risc_pkg.sv tb_riscv.sv riscv.sv riscv_core.sv fetch.sv decode.sv register_file.sv branch_control.sv control.sv alu.sv data_memory.sv
risc_mod := memory.sv adder.v shift.v mux.v
define run_risc
	$(call run_sim,$(1),$(foreach x,$(risc_src),RISCV_SingleCycle/$(x)) $(foreach x,$(risc_mod),modules/$(x)))
endef
risc_tb_arr:
	$(call run_risc,tb_asm_arr)
risc_tb_bub:
	$(call run_risc,tb_asm_bub)
risc_tb_fib:
	$(call run_risc,tb_asm_fib)


# SystemVerilog ALU TB
alu_src := RISCV_SingleCycle/risc_pkg.sv tb_sv_alu/top_tb.sv modules/mux.v modules/shift.v modules/adder.v RISCV_SingleCycle/alu.sv
alu:
	$(call run_verilator,top_tb,-DBEHAVIORAL=1 -DCONST_DELAYS_OFF -Itb_sv_alu $(alu_src))


# FIFO UVM TB
uvm-fifo:
	find . -type d -name "obj_dir" -exec rm -rf {} +
	verilator $(VERILATOR_ARGS) $(ARG) --top-module top_tb --exe --main \
	-DUVM_NO_DPI -I$(UVM_HOME) -Itb_uvm_fifo \
	$(UVM_HOME)/uvm_pkg.sv modules/fifo.v tb_uvm_fifo/top_tb.sv;
	./obj_dir/Vtop_tb +UVM_VERBOSITY=UVM_HIGH +UVM_TESTNAME=test_regression
	mv coverage.dat vcd/cov_uvmfifo.dat
