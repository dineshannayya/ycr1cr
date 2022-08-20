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
////  yifive Memory interface definitions file                            ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     Memory interface definitions file                                ////
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

`ifndef YCR_MEMIF_SVH
`define YCR_MEMIF_SVH

`include "ycr_arch_description.svh"

//-------------------------------------------------------------------------------
// Memory command enum
//-------------------------------------------------------------------------------
//typedef enum logic {
parameter    YCR_MEM_CMD_RD     = 1'b0;
parameter    YCR_MEM_CMD_WR     = 1'b1;
//`ifdef YCR_XPROP_EN
//    ,
parameter     YCR_MEM_CMD_ERROR  = 'x;
//`endif // YCR_XPROP_EN
//} type_ycr_mem_cmd_e;

//-------------------------------------------------------------------------------
// Memory data width enum
//-------------------------------------------------------------------------------
//typedef enum logic[1:0] {
parameter    YCR_MEM_WIDTH_BYTE     = 2'b00;
parameter    YCR_MEM_WIDTH_HWORD    = 2'b01;
parameter    YCR_MEM_WIDTH_WORD     = 2'b10;
//`ifdef YCR_XPROP_EN
//    ,
parameter    YCR_MEM_WIDTH_ERROR    = 'x;
//`endif // YCR_XPROP_EN
//} type_ycr_mem_width_e;

//-------------------------------------------------------------------------------
// Memory response enum
//-------------------------------------------------------------------------------
//typedef enum logic[1:0] {
parameter    YCR_MEM_RESP_NOTRDY    = 2'b00;
parameter    YCR_MEM_RESP_RDY_OK    = 2'b01;
parameter    YCR_MEM_RESP_RDY_ER    = 2'b10;
parameter    YCR_MEM_RESP_RDY_LOK   = 2'b11; // LAST ACK
//`ifdef YCR_XPROP_EN
//    ,
parameter    YCR_MEM_RESP_ERROR     = 'x;
//`endif // YCR_XPROP_EN
//} type_ycr_mem_resp_e;

`endif // YCR_MEMIF_SVH
