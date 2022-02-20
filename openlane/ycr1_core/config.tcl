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

set ::env(DESIGN_NAME) ycr1_core_top
set ::env(DESIGN_IS_CORE) 0

set ::env(RUN_KLAYOUT) 0

set ::env(CLOCK_PERIOD) "25"
set ::env(CLOCK_PORT) "clk"

set ::env(RESET_PORT) "rst_n"

set ::env(BASE_SDC_FILE) $script_dir/base.sdc 

## Synthesis
set ::env(SYNTH_STRATEGY) "DELAY 1"
set ::env(SYNTH_MAX_FANOUT) 8
set ::env(SYNTH_READ_BLACKBOX_LIB) 1

set ::env(STA_REPORT_POWER) 1

## Floorplan
set ::env(FP_PIN_ORDER_CFG) $script_dir/pin_order.cfg
set ::env(FP_SIZING) absolute
set ::env(DIE_AREA) "0 0 400 1400 "

#set ::env(MACRO_PLACEMENT_CFG) $script_dir/macro_placement.cfg
set ::env(PL_TARGET_DENSITY) 0.40
set ::env(CELL_PAD) 0


## PDN
set ::env(FP_PDN_CORE_RING) 0

## CTS
set ::env(CTS_CLK_BUFFER_LIST) "sky130_fd_sc_hd__clkbuf_4 sky130_fd_sc_hd__clkbuf_8 sky130_fd_sc_hd__clkbuf_16"

## Placement
set ::env(PL_RESIZER_DESIGN_OPTIMIZATIONS) 1
set ::env(PL_RESIZER_TIMING_OPTIMIZATIONS) 1


set ::env(GLB_RT_MINLAYER) 1
set ::env(GLB_RT_MAXLAYER) 6

	
## Diode Insertion
set ::env(DIODE_INSERTION_STRATEGY) 4



set ::env(VERILOG_FILES) "\
	$script_dir/../../src/core/pipeline/ycr1_pipe_top.sv           \
	$script_dir/../../src/core/ycr1_core_top.sv                    \
	$script_dir/../../src/core/ycr1_dm.sv                          \
	$script_dir/../../src/core/ycr1_tapc_synchronizer.sv           \
	$script_dir/../../src/core/ycr1_clk_ctrl.sv                    \
	$script_dir/../../src/core/ycr1_scu.sv                         \
	$script_dir/../../src/core/ycr1_tapc.sv                        \
	$script_dir/../../src/core/ycr1_tapc_shift_reg.sv              \
	$script_dir/../../src/core/ycr1_dmi.sv                         \
	$script_dir/../../src/core/primitives/ycr1_reset_cells.sv      \
	$script_dir/../../src/core/pipeline/ycr1_pipe_ifu.sv           \
	$script_dir/../../src/core/pipeline/ycr1_pipe_idu.sv           \
	$script_dir/../../src/core/pipeline/ycr1_pipe_exu.sv           \
	$script_dir/../../src/core/pipeline/ycr1_pipe_mprf.sv          \
	$script_dir/../../src/core/pipeline/ycr1_pipe_csr.sv           \
	$script_dir/../../src/core/pipeline/ycr1_pipe_ialu.sv          \
	$script_dir/../../src/core/pipeline/ycr1_pipe_mul.sv           \
	$script_dir/../../src/core/pipeline/ycr1_pipe_div.sv           \
	$script_dir/../../src/core/pipeline/ycr1_pipe_lsu.sv           \
	$script_dir/../../src/core/pipeline/ycr1_pipe_hdu.sv           \
	$script_dir/../../src/core/pipeline/ycr1_pipe_tdu.sv           \
	$script_dir/../../src/core/pipeline/ycr1_ipic.sv               \
	"
set ::env(VERILOG_INCLUDE_DIRS) [glob $script_dir/../../src/includes ]



########## DO NOT QUIT ON THE FOLLOWING
set ::env(QUIT_ON_MAGIC_DRC) 1
set ::env(QUIT_ON_TIMING_VIOLATIONS) 0
set ::env(QUIT_ON_HOLD_VIOLATIONS) 0
set ::env(QUIT_ON_SETUP_VIOLATIONS) 0
