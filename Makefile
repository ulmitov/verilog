.ONESHELL:
#SHELL := /bin/bash
SHELL := ./vvp.sh

.PHONY: all

#export UVM_HOME := $(HOME)/dev/sda6/UVM/1800.2-2020/src
export UVM_HOME := $(HOME)/dev/sda6/UVM/UVM1.2/src

VERILATOR_ARGS := 	-Wno-lint --assert --coverage --public-flat-rw --pins-inout-enables \
					--trace-vcd --timing +incdir+../modules/ -j 0 --build --cc

define iverilog_tb
	cd modules; iverilog -Wall -g2005 -gspecify -o ./vcd/$(1)_tb.vvp -s $(1)_tb testbench/$(1)_tb.v $(if $(strip $(2)),$(2),$(1).v) && vvp ./vcd/$(1)_tb.vvp
endef

define sverilog_tb
	iverilog -Wall -g2012 -gspecify -o ./dir/$(1).vvp -s $(1) -I ../modules/ $(2) && vvp ./dir/$(1).vvp
endef

define verilator_tb
	verilator $(VERILATOR_ARGS) --binary --top $(1) $(2) && ./obj_dir/V$(1)
endef

confirm:
	@read -p "Continue to next test? [y/N] " ans && [ $${ans:-N} = y ] || (echo "Aborted."; exit 1)

clean:
	rm ./vcd/*.vvp
	rm ./modules/vcd/*.vvp

ver:
	$(call verilator_tb,$(ARG)_tb, $(ARG).v testbench/$(ARG)_tb.v)

vvp:
	$(call iverilog_tb,$(ARG))

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
grep_err := 2>&1 |grep -v timescale |grep -i error || true
all:
	$(MAKE) -s adder half_adder mux mux_cmos priority_enc decoder sequence memory $(grep_err)
	$(MAKE) -s fifo counter shift_reg shift $(grep_err)
	$(MAKE) -s baud_tb uart_rx_tb uart_tx_tb uart_tb uart_top_tb uartcpp $(grep_err)

	
# Modules Testbenches
adder:
	$(call iverilog_tb,adder)
counter:
	$(call iverilog_tb,counter)
fifo:
	$(call iverilog_tb,fifo)
half_adder:
	$(call iverilog_tb,half_adder,adder.v)
mux:
	$(call iverilog_tb,mux)
mux_cmos:
	$(call iverilog_tb,mux_cmos)
decoder:
	$(call iverilog_tb,decoder,mux.v)
priority_enc:
	$(call iverilog_tb,priority_enc,mux.v)
sequence:
	$(call iverilog_tb,sequence)
shift_reg:
	$(call iverilog_tb,shift_reg)
shift:
	$(call iverilog_tb,shift,shift.v mux.v)

memory:
	mem_src="../RISCV_SingleCycle/risc_pkg.sv memory.sv";
	cd modules; tb=memory_tb; verilator --lint-only -Wall -Wno-IMPORTSTAR $$mem_src;
	iverilog -Wall -g2012 -o ./vcd/$$tb.vvp -s $$tb testbench/$$tb.v $$mem_src && vvp ./vcd/$$tb.vvp

# SystemVerilog ALU TB
alu:
	cd tb_sv_alu;
	alu_src="../modules/adder.v ../modules/shift.v ../modules/mux.v ../RISCV_SingleCycle/risc_pkg.sv ../RISCV_SingleCycle/alu.sv top_tb.sv";
	verilator $(VERILATOR_ARGS) -Wno-TIMESCALEMOD --top top_tb $$alu_src && ./obj_dir/Vtop_tb

# UART
uart_src := uart_top.sv uart.sv clock_divider.sv uart_tx.sv uart_rx.sv ../modules/fifo.v ../modules/shift_reg.v
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

uartcpp:
	cd UART; tb=uart_top;
	tb_cpp="testbench/uart_tb.cpp driver/uart_driver.cpp testbench/uart_verilated.cpp";
	verilator $(ARG) -DCONST_DELAYS_OFF -CFLAGS "-I../driver/" $(VERILATOR_ARGS) --exe --top $$tb $$tb_cpp $(uart_src) && ./obj_dir/V$$tb
	# for debugging add: ARG='-CFLAGS "-g -DDEBUG_MODE"''

# RISCV
risc_src := risc_pkg.sv riscv.sv fetch.sv decode.sv register_file.sv branch_control.sv control.sv alu.sv ../modules/memory.sv ../modules/adder.v ../modules/shift.v ../modules/mux.v
riscvvp:
	cd RISCV_SingleCycle; tb=tb_riscv;
	iverilog -Wall -g2012 -I ../modules/ -o vcd/$$tb.vvp -s $$tb $$tb.sv $(risc_src) && vvp vcd/$$tb.vvp
riscver:
	cd RISCV_SingleCycle; tb=tb_riscv;
	verilator $(VERILATOR_ARGS) --binary --top $$tb $$tb.sv $(risc_src) && ./obj_dir/V$$tb

# FIFO UVM TB
uvm-fifo:
	cd tb_uvm_fifo;
	verilator $(VERILATOR_ARGS) --binary --top-module top_tb \
	+define+UVM_NO_DPI \+incdir+$(UVM_HOME)+$$(pwd)+../RISCV_SingleCycle \
	$(UVM_HOME)/uvm_pkg.sv ../modules/fifo.v top_tb.sv 
