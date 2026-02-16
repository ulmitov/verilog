# FIFO UVM testbench

Single agent enviroment with configuration class

Run via Dsim studio

```
dsim -top work.top_tb -genimage image -uvm 1.2 +acc+b
dsim -image image -waves waves.mxd -uvm 1.2 +UVM_NO_RELNOTES +UVM_CONFIG_DB_TRACE +UVM_TESTNAME=test_full
```

## Test plan:
 - Random push and pull (including parallel push+pull)
 - Consecutive single push + pull
 - Push until full then pull until empty


## Results:
![log](./dsim.log)