
PDK_PATH?=/opt/pdk/sky130A

# src_dir := $(dir $(lastword $(MAKEFILE_LIST)))
rtl_src_dir := $(root_dir)/src/
rtl_core_files ?= core.files
rtl_top_files ?= ahb_top.files
rtl_tb_files ?= ahb_tb.files
rtl_inc_dir ?= $(root_dir)/src/includes
cache_inc_dir ?= $(root_dir)/src/cache/src/core
rtl_dir ?= $(root_dir)/src/
synth_dir ?= $(root_dir)/synth/
rtl_inc_tb_dir ?= $(root_dir)/tb/
top_module ?= ycr_top_tb_ahb


ifeq ($(MAKECMDGOALS), $(filter $(MAKECMDGOALS),build_verilator build_verilator_wf))
ifeq ($(BUS),AHB)
export ycr_wrapper  := $(root_dir)/sim/verilator_wrap/ycr_ahb_wrapper.c
endif
ifeq ($(BUS),AXI)
export ycr_wrapper  := $(root_dir)/sim/verilator_wrap/ycr_axi_wrapper.c
endif
ifeq ($(BUS),WB)
export ycr_wrapper  := $(root_dir)/sim/verilator_wrap/ycr_wb_wrapper.c
endif
export verilator_ver ?= $(shell  expr `verilator --version | cut -f2 -d' '`)
endif

#Get to toplevel TB file
ifeq ($(BUS),AHB)
export ycr_tb_top  := $(root_dir)/tb/ycr_top_tb_ahb.sv
endif
ifeq ($(BUS),AXI)
export ycr_tb_top  := $(root_dir)/tb/ycr_top_tb_axi.sv
endif
ifeq ($(BUS),WB)
export ycr_tb_top  := $(root_dir)/tb/ycr_top_tb_wb.sv
endif

.PHONY: build_iverilog build_modelsim build_modelsim_wlf build_vcs build_ncsim build_verilator build_verilator_wf build_iverilog_wf

default: build_modelsim

build_iverilog: 
	cd $(bld_dir); \
	iverilog -g2012 \
	-D FUNCTIONAL \
	-D $(SIM) \
	-I $(PDK_PATH) \
	-I $(rtl_dir) \
	-I $(synth_dir) \
	-I $(rtl_inc_dir) \
	-I $(cache_inc_dir) \
	-I $(rtl_inc_tb_dir) \
	-D $(SIM_CFG_DEF) \
	$(SIM_BUILD_OPTS) \
	$(ycr_tb_top) \
	-o $(top_module).vvp

build_iverilog_wf: 
	cd $(bld_dir); \
	iverilog -g2012 \
	-D WFDUMP     \
	-D FUNCTIONAL \
	-D $(SIM) \
	-I $(PDK_PATH) \
	-I $(rtl_dir) \
	-I $(synth_dir) \
	-I $(rtl_inc_dir) \
	-I $(cache_inc_dir) \
	-I $(rtl_inc_tb_dir) \
	-D $(SIM_CFG_DEF) \
	-D $(SIM) \
	$(SIM_BUILD_OPTS) \
	$(ycr_tb_top) \
	-o $(top_module).vvp

build_modelsim: 
	cd $(bld_dir); \
	vlib work; \
	vmap work work; \
	vlog -work work -O1 -mfcu -sv \
	+incdir+$(PDK_PATH) \
	+incdir+$(rtl_dir) \
	+incdir+$(synth_dir) \
	+incdir+$(rtl_inc_dir) \
	+incdir+$(cache_inc_dir) \
	+incdir+$(rtl_inc_tb_dir) \
	+nowarnSVCHK  \
	+define+YCR_TRGT_SIMULATION \
	+define+FUNCTIONAL \
	+define+$(SIM) \
	+define+$(SIM_TRACE_DEF) \
	+define+$(SIM_CFG_DEF) \
	$(SIM_BUILD_OPTS) \
	$(ycr_tb_top)

build_modelsim_wlf: 
	cd $(bld_dir); \
	vlib work; \
	vmap work work; \
	vlog -work work -O1 -mfcu -sv \
	+incdir+$(PDK_PATH) \
	+incdir+$(rtl_dir) \
	+incdir+$(synth_dir) \
	+incdir+$(rtl_inc_dir) \
	+incdir+$(cache_inc_dir) \
	+incdir+$(rtl_inc_tb_dir) \
	+nowarnSVCHK  \
	+define+FUNCTIONAL \
	+define+YCR_TRGT_SIMULATION \
	+define+$(SIM) \
	+define+$(SIM_TRACE_DEF) \
	+define+$(SIM_CFG_DEF) \
	+define+WFDUMP \
	$(SIM_BUILD_OPTS) \
	$(ycr_tb_top)
build_vcs: 
	cd $(bld_dir); \
	vcs \
	-full64 \
	-lca \
	-sverilog \
	-notice \
	+lint=all,noVCDE,noSVA-DIU,noSVA-CE,noSVA-NSVU \
	-timescale=1ns/1ps \
	+incdir+$(PDK_PATH) \
	+incdir+$(rtl_dir) \
	+incdir+$(synth_dir) \
	+incdir+$(rtl_inc_dir) \
	+incdir+$(cache_inc_dir) \
	+incdir+$(rtl_inc_tb_dir) \
	+define+FUNCTIONAL \
	+define+YCR_TRGT_SIMULATION \
	+define+$(SIM) \
	+define+$(SIM_TRACE_DEF) \
	+define+$(SIM_CFG_DEF) \
	-nc \
	-debug_all \
	$(SIM_BUILD_OPTS) \
	$(ycr_tb_top)

build_ncsim: 
	cd $(bld_dir); \
	irun \
	-elaborate \
	-64bit \
	-disable_sem2009 \
	-verbose \
	-timescale 1ns/1ps \
	-incdir $(PDK_PATH) \
	-incdir $(rtl_dir) \
	-incdir $(synth_dir) \
	-incdir $(rtl_inc_dir) \
	-incdir $(cache_inc_dir) \
	-incdir $(rtl_inc_tb_dir) \
	-debug \
	+define+FUNCTIONAL \
	+define+YCR_TRGT_SIMULATION \
	+define+$(SIM_TRACE_DEF) \
	+define+$(SIM_CFG_DEF) \
	+define+$(SIM) \
	$(SIM_BUILD_OPTS) \
	$(ycr_tb_top) \
	-top $(top_module)

build_verilator: 
	cd $(bld_dir); \
	verilator \
	-cc \
	-sv \
	+1800-2017ext+sv \
	-Wno-fatal \
	--top-module $(top_module) \
	-DYCR_TRGT_SIMULATION \
	-D$(SIM_TRACE_DEF) \
	-D$(SIM_CFG_DEF) \
	+define+FUNCTIONAL \
	+define+$(SIM) \
	--clk clk \
	--exe $(ycr_wrapper) \
	--Mdir $(bld_dir)/verilator \
	-I$(PDK_PATH) \
	-I$(rtl_dir) \
	-I$(synth_dir) \
	-I$(rtl_inc_dir) \
	-I$(cache_inc_dir) \
	-I$(rtl_inc_tb_dir) \
	$(SIM_BUILD_OPTS) \
	$(ycr_tb_top); \
	cd verilator; \
	$(MAKE) -f V$(top_module).mk;

build_verilator_wf: 
	cd $(bld_dir); \
	verilator \
	-cc \
	-sv \
	+1800-2017ext+sv \
	-Wno-fatal \
	--top-module $(top_module) \
	-DFUNCTIONAL \
	-DYCR_TRGT_SIMULATION \
	-D$(SIM_TRACE_DEF) \
	-D$(SIM_CFG_DEF) \
	+define+$(SIM) \
	-CFLAGS -DVCD_TRACE -CFLAGS -DTRACE_LVLV=20 \
	-CFLAGS -DVCD_FNAME=simx.vcd \
	--clk clk \
	--exe $(ycr_wrapper) \
	--trace \
	--trace-params \
    --trace-structs \
    --trace-underscore \
	--Mdir $(bld_dir)/verilator \
	-I$(PDK_PATH) \
	-I$(rtl_dir) \
	-I$(synth_dir) \
	-I$(rtl_inc_dir) \
	-I$(cache_inc_dir) \
	-I$(rtl_inc_tb_dir) \
	$(SIM_BUILD_OPTS) \
	$(ycr_tb_top); \
	cd verilator; \
	$(MAKE) -f V$(top_module).mk;


