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
////  yifive IPIC header file                                             ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     IPIC header file                                                 ////
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
////     v2:    Aug 20, 2022, Dinesh A                                    ////
///             changed YCR_IRQ_VECT_NUM value from 16 to 32              ////
////                                                                      ////
//////////////////////////////////////////////////////////////////////////////


`ifndef YCR_IPIC_SVH
`define YCR_IPIC_SVH

`include "ycr_arch_description.svh"

`ifdef YCR_IPIC_EN
//-------------------------------------------------------------------------------
// Parameters declaration
//-------------------------------------------------------------------------------
parameter                                   YCR_IRQ_VECT_NUM       = 32;   // must be power of 2 in the current implementation
parameter                                   YCR_IRQ_VECT_WIDTH     = $clog2(YCR_IRQ_VECT_NUM+1);
parameter                                   YCR_IRQ_LINES_NUM      = YCR_IRQ_VECT_NUM;
parameter                                   YCR_IRQ_LINES_WIDTH    = $clog2(YCR_IRQ_LINES_NUM);
parameter   logic [YCR_IRQ_VECT_WIDTH-1:0] YCR_IRQ_VOID_VECT_NUM  = YCR_IRQ_VECT_WIDTH'(YCR_IRQ_VECT_NUM);
parameter                                   YCR_IRQ_IDX_WIDTH      = $clog2(YCR_IRQ_VECT_NUM);

// Address decoding parameters
parameter   logic [2:0]                     YCR_IPIC_CISV          = 3'h0;    // RO
parameter   logic [2:0]                     YCR_IPIC_CICSR         = 3'h1;    // {IP, IE}
parameter   logic [2:0]                     YCR_IPIC_IPR           = 3'h2;    // RW1C
parameter   logic [2:0]                     YCR_IPIC_ISVR          = 3'h3;    // RO
parameter   logic [2:0]                     YCR_IPIC_EOI           = 3'h4;    // RZW
parameter   logic [2:0]                     YCR_IPIC_SOI           = 3'h5;    // RZW
parameter   logic [2:0]                     YCR_IPIC_IDX           = 3'h6;    // RW
parameter   logic [2:0]                     YCR_IPIC_ICSR          = 3'h7;    // RW

parameter                                   YCR_IPIC_ICSR_IP       = 0;
parameter                                   YCR_IPIC_ICSR_IE       = 1;
parameter                                   YCR_IPIC_ICSR_IM       = 2;
parameter                                   YCR_IPIC_ICSR_INV      = 3;
parameter                                   YCR_IPIC_ICSR_IS       = 4;
parameter                                   YCR_IPIC_ICSR_PRV_LSB  = 8;
parameter                                   YCR_IPIC_ICSR_PRV_MSB  = 9;
parameter                                   YCR_IPIC_ICSR_LN_LSB   = 12;
parameter                                   YCR_IPIC_ICSR_LN_MSB   = YCR_IPIC_ICSR_LN_LSB
                                                                    + YCR_IRQ_LINES_WIDTH;

parameter   logic [1:0]                     YCR_IPIC_PRV_M         = 2'b11;

//-------------------------------------------------------------------------------
// Types declaration
//-------------------------------------------------------------------------------
typedef enum logic {
    YCR_CSR2IPIC_RD,
    YCR_CSR2IPIC_WR
`ifdef YCR_XPROP_EN
    ,
    YCR_CSR2IPIC_ERROR = 'x
`endif // YCR_XPROP_EN
} type_ycr_csr2ipic_wr_e;

`endif // YCR_IPIC_EN
`endif // YCR_IPIC_SVH
