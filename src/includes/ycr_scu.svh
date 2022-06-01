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
////  yifive SCU header file                                              ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     SCU header file                                                  ////
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


`ifndef YCR_INCLUDE_SCU_DEFS
`define YCR_INCLUDE_SCU_DEFS

//`include "ycr_arch_description.svh"

`ifdef YCR_DBG_EN

//==============================================================================
// Parameters
//==============================================================================
localparam int unsigned         YCR_SCU_DR_SYSCTRL_OP_WIDTH        = 2;
localparam int unsigned         YCR_SCU_DR_SYSCTRL_ADDR_WIDTH      = 2;
localparam int unsigned         YCR_SCU_DR_SYSCTRL_DATA_WIDTH      = 4;
localparam int unsigned         YCR_SCU_DR_SYSCTRL_WIDTH      = YCR_SCU_DR_SYSCTRL_OP_WIDTH+YCR_SCU_DR_SYSCTRL_ADDR_WIDTH+YCR_SCU_DR_SYSCTRL_DATA_WIDTH; // cp.3

//==============================================================================
// Types
//==============================================================================
typedef enum logic [YCR_SCU_DR_SYSCTRL_OP_WIDTH-1:0] {
    YCR_SCU_SYSCTRL_OP_WRITE       = 2'h0,
    YCR_SCU_SYSCTRL_OP_READ        = 2'h1,
    YCR_SCU_SYSCTRL_OP_SETBITS     = 2'h2,
    YCR_SCU_SYSCTRL_OP_CLRBITS     = 2'h3
`ifdef YCR_XPROP_EN
    ,
    YCR_SCU_SYSCTRL_OP_XXX         = 'X
`endif // YCR_XPROP_EN
} type_ycr_scu_sysctrl_op_e;

typedef enum logic [YCR_SCU_DR_SYSCTRL_ADDR_WIDTH-1:0] {
    YCR_SCU_SYSCTRL_ADDR_CONTROL   = 2'h0,
    YCR_SCU_SYSCTRL_ADDR_MODE      = 2'h1,
    YCR_SCU_SYSCTRL_ADDR_STATUS    = 2'h2,
    YCR_SCU_SYSCTRL_ADDR_STICKY    = 2'h3
`ifdef YCR_XPROP_EN
    ,
    YCR_SCU_SYSCTRL_ADDR_XXX       = 'X
`endif // YCR_XPROP_EN
} type_ycr_scu_sysctrl_addr_e;

typedef struct packed {
    logic [YCR_SCU_DR_SYSCTRL_DATA_WIDTH-1:0]  data;
    logic [YCR_SCU_DR_SYSCTRL_ADDR_WIDTH-1:0]  addr;
    logic [YCR_SCU_DR_SYSCTRL_OP_WIDTH-1:0]    op;
} type_ycr_scu_sysctrl_dr_s;

typedef enum int unsigned {
    YCR_SCU_DR_SYSCTRL_OP_BIT_R                  = 'h0,
    YCR_SCU_DR_SYSCTRL_OP_BIT_L                  = YCR_SCU_DR_SYSCTRL_OP_WIDTH-1,
    YCR_SCU_DR_SYSCTRL_ADDR_BIT_R                = YCR_SCU_DR_SYSCTRL_OP_WIDTH,
    YCR_SCU_DR_SYSCTRL_ADDR_BIT_L                = YCR_SCU_DR_SYSCTRL_OP_WIDTH +
                                                    YCR_SCU_DR_SYSCTRL_ADDR_WIDTH - 1,
    YCR_SCU_DR_SYSCTRL_DATA_BIT_R                = YCR_SCU_DR_SYSCTRL_OP_WIDTH +
                                                    YCR_SCU_DR_SYSCTRL_ADDR_WIDTH,
    YCR_SCU_DR_SYSCTRL_DATA_BIT_L                = YCR_SCU_DR_SYSCTRL_OP_WIDTH +
                                                    YCR_SCU_DR_SYSCTRL_ADDR_WIDTH +
                                                    YCR_SCU_DR_SYSCTRL_DATA_WIDTH - 1
} type_ycr_scu_sysctrl_dr_bits_e;

typedef struct packed {
    logic [1:0]                                     rsrv;
    logic                                           core_reset;
    logic                                           sys_reset;
} type_ycr_scu_sysctrl_control_reg_s;

typedef struct packed {
    logic [1:0]                                     rsrv;
    logic                                           hdu_rst_bhv;
    logic                                           dm_rst_bhv;
} type_ycr_scu_sysctrl_mode_reg_s;

localparam bit [31:0]    YCR_SCU_SYSCTRL_STATUS_REG_WIDTH        = 4; // cp.3
typedef struct packed {
    logic                                           hdu_reset;
    logic                                           dm_reset;
    logic                                           core_reset;
    logic                                           sys_reset;
} type_ycr_scu_sysctrl_status_reg_s;

`endif // YCR_DBG_EN
`endif // YCR_INCLUDE_SCU_DEFS
