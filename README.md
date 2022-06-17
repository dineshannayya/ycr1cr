# ycr1
Open Source Single RISCV 32 bit core

# Running Standalone iverilog compile
## 1. Go to test directory inside the build

cd build/iverilog_wf_WB_MAX_imc_IPIC_1_TCM_0_VIRQ_1_TRACE_0

## 2. Run the iverilog compile command, add waveform dump with "-D WFDUMP"

iverilog -g2012 \
-D WFDUMP     \
-D FUNCTIONAL \
-D RTL \
-I $PDK_ROOT \
-I ../../src/ \
-I ../../synth/ \
-I ../../src/includes \
-I ../../src/cache/src/core \
-I ../../tb/ \
-D YCR1_CFG_RV32IMC_MAX \
-D RTL \
../../tb/ycr_top_tb_wb.sv \
-o ycr_top_tb_wb.vvp


## 3. In Build test directory, keep required number of test file in test_info file and run below command
vvp -M. -msystem ycr1_top_tb_wb.vvp +test_info=test_info +test_results=test_results.txt +imem_pattern=FFFFFFFF +dmem_pattern=FFFFFFFF | tee sim_results.txt
