verilator -Wall --trace --binary --timing --top top_tb --cc ../adder.v top_tb.sv

verilator -Wall -Wno-UNDRIVEN -Wno-IGNOREDRETURN -Wno-UNUSEDSIGNAL -Wno-WIDTHTRUNC -Wno-IMPORTSTAR -Wno-TIMESCALEMOD -Wno-DECLFILENAME -Wno-PINCONNECTEMPTY -Wno-REDEFMACRO --trace --binary --timing -I../ --top top_tb --cc consts.v adder.v shift.v mux.v ../RISCV_SingleCycle/risc_pkg.sv ../RISCV_SingleCycle/alu.sv top_tb.sv



dcreport -out_dir dir metrics.db



-top work.top_tb -build-all -cs-randc-max 31 +acc+b -code-cov a -incdir ../ -waves waves.mxd



Now, set up the UVM_HOME environment variable to point to the extracted UVM sources.
 also need PATH to point to Verilator:


PATH="$(pwd)/verilator/bin:$PATH"
UVM_HOME="~/dev/VERILOG/uvm-core-2020.3.1/src"

To build the simulation, run:

verilator -Wno-fatal --binary -j $(nproc) --top-module tbench_top \
    +incdir+$UVM_HOME +define+UVM_NO_DPI +incdir+$(pwd) \
    $UVM_HOME/uvm_pkg.sv $(pwd)/sig_pkg.sv $(pwd)/tb.sv

Finally, run the simulation:

./obj_dir/Vtbench_top +UVM_TESTNAME=sig_model_test






make CXX=/usr/bin/g++-10 -C obj_dir -f Vtop_tb.mk



rm /usr/bin/gcc
rm /usr/bin/g++
ln -s /usr/bin/gcc-10 /usr/bin/gcc
ln -s /usr/bin/g++-10 /usr/bin/g++





3. Change the Default GCC Version System-Wide 
The update-alternatives system (used in Debian/Ubuntu) can manage which installed version is the default for the generic gcc command. 

    Add the installed GCC versions to the alternatives system:
    bash

sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-6 60 --slave /usr/bin/g++ g++ /usr/bin/g++-6
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 100 --slave /usr/bin/g++ g++ /usr/bin/g++-10
# The number at the end (60, 100) is the priority. Higher priority is used by default.

Interactively select the default version:
bash

sudo update-alternatives --config gcc

This command will present an interactive menu allowing you to choose the version to use. 


