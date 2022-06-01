# SPDX-FileCopyrightText: 2020 Efabless Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# SPDX-License-Identifier: Apache-2.0

set script_dir [file dirname [file normalize [info script]]]

set ::env(ROUTING_CORES) "6"

set ::env(DESIGN_NAME) ycr_top_wb
set ::env(DESIGN_IS_CORE) 1

set ::env(RUN_KLAYOUT) 0

set ::env(CLOCK_PERIOD) "25"
set ::env(CLOCK_PORT) "wb_clk core_clk rtc_clk"

set ::env(RESET_PORT) "rst_n"

set ::env(BASE_SDC_FILE) $script_dir/base.sdc 

## Synthesis
set ::env(SYNTH_STRATEGY) "DELAY 1"
set ::env(SYNTH_MAX_FANOUT) 8
set ::env(SYNTH_READ_BLACKBOX_LIB) 1

set ::env(STA_REPORT_POWER) 0

## Floorplan
set ::env(FP_PIN_ORDER_CFG) $script_dir/pin_order.cfg
set ::env(FP_SIZING) absolute
set ::env(DIE_AREA) "0 0 1500 1100"

set ::env(MACRO_PLACEMENT_CFG) $script_dir/macro_placement.cfg
set ::env(PL_TARGET_DENSITY) 0.40
set ::env(CELL_PAD) 0

set ::env(LEFT_MARGIN_MULT) 22
set ::env(RIGHT_MARGIN_MULT) 22

## PDN
set ::env(FP_PDN_CORE_RING) 1
set ::env(FP_PDN_VPITCH) 50
set ::env(FP_PDN_HPITCH) 130

set ::env(FP_PDN_VWIDTH) 1.6
set ::env(FP_PDN_CORE_RING_VWIDTH) 1.6

## CTS
set ::env(CTS_CLK_BUFFER_LIST) "sky130_fd_sc_hd__clkbuf_4 sky130_fd_sc_hd__clkbuf_8 sky130_fd_sc_hd__clkbuf_16"
set ::env(CTS_SINK_CLUSTERING_MAX_DIAMETER) 50
set ::env(CTS_SINK_CLUSTERING_SIZE) 20

## Placement
set ::env(PL_RESIZER_DESIGN_OPTIMIZATIONS) 1
set ::env(PL_RESIZER_TIMING_OPTIMIZATIONS) 1

set ::env(PL_RESIZER_MAX_SLEW_MARGIN) 2
set ::env(PL_RESIZER_MAX_CAP_MARGIN) 2

## Routing
set ::env(GLB_RT_ADJUSTMENT) 0
set ::env(GLB_RT_L2_ADJUSTMENT) 0.21
set ::env(GLB_RT_L3_ADJUSTMENT) 0.21
set ::env(GLB_RT_L4_ADJUSTMENT) 0.1
set ::env(GLB_RT_L5_ADJUSTMENT) 0.1
set ::env(GLB_RT_L6_ADJUSTMENT) 0.1
set ::env(GLB_RT_ALLOW_CONGESTION) 0
set ::env(GLB_RT_OVERFLOW_ITERS) 200

set ::env(GLB_RT_MINLAYER) 2
set ::env(GLB_RT_MAXLAYER) 6

set ::env(PL_RESIZER_HOLD_SLACK_MARGIN) 0.0
set ::env(GLB_RESIZER_TIMING_OPTIMIZATIONS) 1
set ::env(GLB_RESIZER_HOLD_SLACK_MARGIN) 0.0

#set ::env(GLB_RT_OBS) "\
#	li1 0 0 10.16500 740.00,\
#	li1 0 0 2000 10.74000,\
#	li1 0 728.20000 2000.06000 740,\
#	li1 1988.99000 0 2000 740,\
#	met5 84.46000 88.23500 555.01500 94.50000,\
#	li1 75.19000 79.12500 778.05000 519.26500"
	
## Diode Insertion
set ::env(DIODE_INSERTION_STRATEGY) 4


## Internal Macros
set ::env(VERILOG_FILES_BLACKBOX) "\
	$::env(PDK_ROOT)/sky130A/libs.ref/sky130_sram_macros/verilog/sky130_sram_2kbyte_1rw1r_32x512_8.v"

set ::env(EXTRA_LEFS) "\
	$::env(PDK_ROOT)/sky130A/libs.ref/sky130_sram_macros/lef/sky130_sram_2kbyte_1rw1r_32x512_8.lef"

set ::env(EXTRA_GDS_FILES) "\
	$::env(PDK_ROOT)/sky130A/libs.ref/sky130_sram_macros/gds/sky130_sram_2kbyte_1rw1r_32x512_8.gds"

set ::env(EXTRA_LIBS) "\
	$::env(PDK_ROOT)/sky130A/libs.ref/sky130_sram_macros/lib/sky130_sram_2kbyte_1rw1r_32x512_8_TT_1p8V_25C.lib"

set ::env(VERILOG_FILES) "\
        $script_dir/../../src/lib/clk_skew_adjust.gv                   \
	$script_dir/../../src/core/pipeline/ycr_pipe_top.sv           \
	$script_dir/../../src/core/ycr_core_top.sv                    \
	$script_dir/../../src/core/ycr_dm.sv                          \
	$script_dir/../../src/core/ycr_tapc_synchronizer.sv           \
	$script_dir/../../src/core/ycr_clk_ctrl.sv                    \
	$script_dir/../../src/core/ycr_scu.sv                         \
	$script_dir/../../src/core/ycr_tapc.sv                        \
	$script_dir/../../src/core/ycr_tapc_shift_reg.sv              \
	$script_dir/../../src/core/ycr_dmi.sv                         \
	$script_dir/../../src/core/primitives/ycr_reset_cells.sv      \
	$script_dir/../../src/core/pipeline/ycr_pipe_ifu.sv           \
	$script_dir/../../src/core/pipeline/ycr_pipe_idu.sv           \
	$script_dir/../../src/core/pipeline/ycr_pipe_exu.sv           \
	$script_dir/../../src/core/pipeline/ycr_pipe_mprf.sv          \
	$script_dir/../../src/core/pipeline/ycr_pipe_csr.sv           \
	$script_dir/../../src/core/pipeline/ycr_pipe_ialu.sv          \
	$script_dir/../../src/core/pipeline/ycr_pipe_mul.sv           \
	$script_dir/../../src/core/pipeline/ycr_pipe_div.sv           \
	$script_dir/../../src/core/pipeline/ycr_pipe_lsu.sv           \
	$script_dir/../../src/core/pipeline/ycr_pipe_hdu.sv           \
	$script_dir/../../src/core/pipeline/ycr_pipe_tdu.sv           \
	$script_dir/../../src/core/pipeline/ycr_ipic.sv               \
	$script_dir/../../src/top/ycr_dmem_router.sv                  \
	$script_dir/../../src/top/ycr_imem_router.sv                  \
	$script_dir/../../src/top/ycr_icache_router.sv                \
	$script_dir/../../src/top/ycr_dcache_router.sv                \
	$script_dir/../../src/top/ycr_tcm.sv                          \
	$script_dir/../../src/top/ycr_timer.sv                        \
	$script_dir/../../src/top/ycr_top_wb.sv                       \
	$script_dir/../../src/top/ycr_dmem_wb.sv                      \
	$script_dir/../../src/top/ycr_imem_wb.sv                      \
	$script_dir/../../src/top/ycr_intf.sv                         \
        $script_dir/../../src/cache/src/core/icache_top.sv             \
        $script_dir/../../src/cache/src/core/icache_app_fsm.sv         \
        $script_dir/../../src/cache/src/core/icache_tag_fifo.sv        \
        $script_dir/../../src/cache/src/core/dcache_tag_fifo.sv        \
        $script_dir/../../src/cache/src/core/dcache_top.sv             \
        $script_dir/../../src/lib/ycr_async_wbb.sv                    \
        $script_dir/../../src/lib/ycr_arb.sv                          \
        $script_dir/../../src/lib/sync_fifo.sv                         \
        $script_dir/../../src/lib/async_fifo.sv                        \
        $script_dir/../../src/lib/ctech_cells.sv                       \
	"
set ::env(VERILOG_INCLUDE_DIRS) [glob $script_dir/../../src/includes ]


########## SET BELOW TO 0 TO AVOID OR SEGFAULT
set ::env(STA_REPORT_POWER) 0

########## DO NOT QUIT ON THE FOLLOWING
set ::env(MAGIC_DRC_USE_GDS) 0
set ::env(QUIT_ON_MAGIC_DRC) 0
set ::env(QUIT_ON_TIMING_VIOLATIONS) 0
set ::env(QUIT_ON_HOLD_VIOLATIONS) 0
set ::env(QUIT_ON_SETUP_VIOLATIONS) 0
