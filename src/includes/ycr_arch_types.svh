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
////  yifive Pipeline types description file                              ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     Pipeline types description file                                  ////
////                                                                      ////
////  To Do:                                                              ////
////    nothing                                                           ////
////                                                                      ////
////  Author(s):                                                          ////
////     - syntacore, https://github.com/syntacore/scr1                   ////
////     - Dinesh Annayya, dinesha@opencores.org                          ////
////                                                                      ////
////  Revision :                                                          ////
////     v0:    Jan 2021- Initial version picked from syntacore/scr1      ////
////     v1:    June 7, 2021, Dinesh A                                    ////
////             opentool(iverilog/yosys) related cleanup                 ////
////                                                                      ////
//////////////////////////////////////////////////////////////////////////////

`ifndef YCR_ARCH_TYPES_SVH
`define YCR_ARCH_TYPES_SVH

`include "ycr_arch_description.svh"

//-------------------------------------------------------------------------------
// MPRF and CSR parameters
//-------------------------------------------------------------------------------

`ifdef YCR_RVE_EXT
  `define YCR_MPRF_AWIDTH    4
  `define YCR_MPRF_SIZE      16
`else // YCR_RVE_EXT
  `define YCR_MPRF_AWIDTH    5
  `define YCR_MPRF_SIZE      32
`endif // YCR_RVE_EXT

// Masked due to iverilog issue
//typedef logic [`YCR_XLEN-1:0]  type_ycr_mprf_v;
//typedef logic [`YCR_XLEN-1:0]  type_ycr_pc_v;

parameter int unsigned  YCR_CSR_ADDR_WIDTH             = 12;
parameter int unsigned  YCR_CSR_MTVEC_BASE_ZERO_BITS   = 6;
parameter int unsigned  YCR_CSR_MTVEC_BASE_VAL_BITS    = `YCR_XLEN-YCR_CSR_MTVEC_BASE_ZERO_BITS;
parameter bit [`YCR_XLEN-1:YCR_CSR_MTVEC_BASE_ZERO_BITS]  YCR_CSR_MTVEC_BASE_WR_RST_VAL    =
                                      YCR_CSR_MTVEC_BASE_VAL_BITS'(YCR_ARCH_MTVEC_BASE >> YCR_CSR_MTVEC_BASE_ZERO_BITS);
parameter int unsigned  YCR_CSR_MTVEC_BASE_RO_BITS = (`YCR_XLEN-(YCR_CSR_MTVEC_BASE_ZERO_BITS+YCR_MTVEC_BASE_WR_BITS));

`define YCR_MTVAL_ILLEGAL_INSTR_EN

//-------------------------------------------------------------------------------
// Exception and IRQ codes
//-------------------------------------------------------------------------------
parameter int unsigned YCR_EXC_CODE_WIDTH_E    = 4;

// Exceptions
typedef enum logic [YCR_EXC_CODE_WIDTH_E-1:0] {
    YCR_EXC_CODE_INSTR_MISALIGN        = 4'd0,     // from EXU
    YCR_EXC_CODE_INSTR_ACCESS_FAULT    = 4'd1,     // from IFU
    YCR_EXC_CODE_ILLEGAL_INSTR         = 4'd2,     // from IDU or CSR
    YCR_EXC_CODE_BREAKPOINT            = 4'd3,     // from IDU or BRKM
    YCR_EXC_CODE_LD_ADDR_MISALIGN      = 4'd4,     // from LSU
    YCR_EXC_CODE_LD_ACCESS_FAULT       = 4'd5,     // from LSU
    YCR_EXC_CODE_ST_ADDR_MISALIGN      = 4'd6,     // from LSU
    YCR_EXC_CODE_ST_ACCESS_FAULT       = 4'd7,     // from LSU
    YCR_EXC_CODE_ECALL_M               = 4'd11     // from IDU
} type_ycr_exc_code_e;

// IRQs, reset
parameter bit [YCR_EXC_CODE_WIDTH_E-1:0] YCR_EXC_CODE_IRQ_M_SOFTWARE      = 4'd3;
parameter bit [YCR_EXC_CODE_WIDTH_E-1:0] YCR_EXC_CODE_IRQ_M_TIMER         = 4'd7;
parameter bit [YCR_EXC_CODE_WIDTH_E-1:0] YCR_EXC_CODE_IRQ_M_EXTERNAL      = 4'd11;
parameter bit [YCR_EXC_CODE_WIDTH_E-1:0] YCR_EXC_CODE_RESET               = 4'd0;

//-------------------------------------------------------------------------------
// Operand width for BRKM
//-------------------------------------------------------------------------------
typedef enum logic [1:0] {
    YCR_OP_WIDTH_BYTE  = 2'b00,
    YCR_OP_WIDTH_HALF  = 2'b01,
    YCR_OP_WIDTH_WORD  = 2'b10
`ifdef YCR_XPROP_EN
    ,
    YCR_OP_WIDTH_ERROR = 'x
`endif // YCR_XPROP_EN
} type_ycr_op_width_e;

`endif //YCR_ARCH_TYPES_SVH

