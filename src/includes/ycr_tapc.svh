//////////////////////////////////////////////////////////////////////////////
// SPDX-FileCopyrightText: 2021, Dinesh Annayya                           ////
//                                                                        ////
// Licensed under the Apache License, Version 2.0 (the "License");        ////
// you may not use this file except in compliance with the License.       ////
// You may obtain a copy of the License at                                ////
//                                                                        ////
//      http://www.apache.org/licenses/LICENSE-2.0                        ////
//                                                                        ////
// Unless required by applicable law or agreed to in writing, software    ////
// distributed under the License is distributed on an "AS IS" BASIS,      ////
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.///
// See the License for the specific language governing permissions and    ////
// limitations under the License.                                         ////
// SPDX-License-Identifier: Apache-2.0                                    ////
// SPDX-FileContributor: Dinesh Annayya <dinesha@opencores.org>           ////
//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
////                                                                      ////
////  yifive TAPC header file                                             ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     TAPC header file                                                 ////
////                                                                      ////
////  To Do:                                                              ////
////    nothing                                                           ////
////                                                                      ////
////  Author(s):                                                          ////
////      - Dinesh Annayya, dinesha@opencores.org                         ////
////                                                                      ////
////  Revision :                                                          ////
////     v0:    Jan 2021- Initial version picked from syntacore/scr1      ////
////     v1:    June 7, 2021, Dinesh A                                    ////
////             opentool(iverilog/yosys) related cleanup                 ////
////                                                                      ////
//////////////////////////////////////////////////////////////////////////////

`ifndef YCR_INCLUDE_TAPC_DEFS
`define YCR_INCLUDE_TAPC_DEFS

`include "ycr_arch_description.svh"

`ifdef YCR_DBG_EN

//==============================================================================
// Parameters
//==============================================================================
localparam int unsigned                         YCR_TAP_STATE_WIDTH            = 4;
localparam int unsigned                         YCR_TAP_INSTRUCTION_WIDTH      = 5;
localparam int unsigned                         YCR_TAP_DR_IDCODE_WIDTH        = 32;
localparam int unsigned                         YCR_TAP_DR_BLD_ID_WIDTH        = 32;
localparam int unsigned                         YCR_TAP_DR_BYPASS_WIDTH        = 1;
//localparam bit [YCR_TAP_DR_IDCODE_WIDTH-1:0]   YCR_TAP_IDCODE_RISCV_SC        = `YCR_TAP_IDCODE;
localparam bit [YCR_TAP_DR_BLD_ID_WIDTH-1:0]   YCR_TAP_BLD_ID_VALUE           = `YCR_MIMPID;

//==============================================================================
// Types
//==============================================================================
typedef enum logic [YCR_TAP_STATE_WIDTH-1:0] {
    YCR_TAP_STATE_RESET,
    YCR_TAP_STATE_IDLE,
    YCR_TAP_STATE_DR_SEL_SCAN,
    YCR_TAP_STATE_DR_CAPTURE,
    YCR_TAP_STATE_DR_SHIFT,
    YCR_TAP_STATE_DR_EXIT1,
    YCR_TAP_STATE_DR_PAUSE,
    YCR_TAP_STATE_DR_EXIT2,
    YCR_TAP_STATE_DR_UPDATE,
    YCR_TAP_STATE_IR_SEL_SCAN,
    YCR_TAP_STATE_IR_CAPTURE,
    YCR_TAP_STATE_IR_SHIFT,
    YCR_TAP_STATE_IR_EXIT1,
    YCR_TAP_STATE_IR_PAUSE,
    YCR_TAP_STATE_IR_EXIT2,
    YCR_TAP_STATE_IR_UPDATE
`ifdef YCR_XPROP_EN
    ,
    YCR_TAP_STATE_XXX       = 'X
`endif // YCR_XPROP_EN
} type_ycr_tap_state_e;

typedef enum logic [YCR_TAP_INSTRUCTION_WIDTH - 1:0] {
    YCR_TAP_INSTR_IDCODE            = 5'h01,
    YCR_TAP_INSTR_BLD_ID            = 5'h04,
    YCR_TAP_INSTR_SCU_ACCESS        = 5'h09,

    YCR_TAP_INSTR_DTMCS             = 5'h10,
    YCR_TAP_INSTR_DMI_ACCESS        = 5'h11,

    YCR_TAP_INSTR_BYPASS            = 5'h1F
`ifdef YCR_XPROP_EN
    ,
    YCR_TAP_INSTR_XXX               = 'X
`endif // YCR_XPROP_EN
} type_ycr_tap_instr_e;

`endif // YCR_DBG_EN
`endif // YCR_INCLUDE_TAPC_DEFS
