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
////  yifive AHB header file                                              ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     AHB header file                                                  ////
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

`ifndef YCR_AHB_SVH
`define YCR_AHB_SVH

`include "ycr_arch_description.svh"

parameter YCR_AHB_WIDTH  = 32;

// Encoding for HTRANS signal
parameter logic [1:0] YCR_HTRANS_IDLE   = 2'b00;
parameter logic [1:0] YCR_HTRANS_NONSEQ = 2'b10;
`ifdef YCR_XPROP_EN
parameter logic [1:0] YCR_HTRANS_ERR    = 'x;
`else // YCR_XPROP_EN
parameter logic [1:0] YCR_HTRANS_ERR    = '0;
`endif // YCR_XPROP_EN

// Encoding for HBURST signal
parameter logic [2:0] YCR_HBURST_SINGLE = 3'b000;
`ifdef YCR_XPROP_EN
parameter logic [2:0] YCR_HBURST_ERR    = 'x;
`else // YCR_XPROP_EN
parameter logic [1:0] YCR_HBURST_ERR    = '0;
`endif // YCR_XPROP_EN

// Encoding for HSIZE signal
parameter logic [2:0] YCR_HSIZE_8B    = 3'b000;
parameter logic [2:0] YCR_HSIZE_16B   = 3'b001;
parameter logic [2:0] YCR_HSIZE_32B   = 3'b010;
`ifdef YCR_XPROP_EN
parameter logic [2:0] YCR_HSIZE_ERR   = 'x;
`else // YCR_XPROP_EN
parameter logic [1:0] YCR_HSIZE_ERR   = '0;
`endif // YCR_XPROP_EN

// Encoding HPROT signal
// HPROT[0] : 0 - instr;      1 - data
// HPROT[1] : 0 - user;       1 - privilege
// HPROT[2] : 0 - not buffer; 1 - buffer
// HPROT[3] : 0 - cacheable;  1 - cacheable
parameter YCR_HPROT_DATA  = 0;
parameter YCR_HPROT_PRV   = 1;
parameter YCR_HPROT_BUF   = 2;
parameter YCR_HPROT_CACHE = 3;

// Encoding HRESP signal
parameter logic YCR_HRESP_OKAY  = 1'b0;
parameter logic YCR_HRESP_ERROR = 1'b1;
`ifdef YCR_XPROP_EN
parameter logic YCR_HRESP_ERR   = 1'bx;
`else // YCR_XPROP_EN
parameter logic YCR_HRESP_ERR   = 1'b0;
`endif // YCR_XPROP_EN

`endif // YCR_AHB_SVH
