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
////  yifive Instruction memory router                                    ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     Instruction cache router                                         ////
////     Map the instruction and Data Memory request to icache            ////
////                                                                      ////
////  To Do:                                                              ////
////    nothing                                                           ////
////                                                                      ////
////  Author(s):                                                          ////
////      - Dinesh Annayya, dinesha@opencores.org                         ////
////                                                                      ////
////  Revision :                                                          ////
////     v0:    20 Jan 2022,  Dinesh A                                    ////
////             Initial Version                                          ////
////                                                                      ////
//////////////////////////////////////////////////////////////////////////////

`include "ycr_memif.svh"
`include "ycr_arch_description.svh"

module ycr_icache_router (
    // Control signals
    input   logic                           rst_n,
    input   logic                           clk,

    // imem interface
    output  logic                           imem_req_ack,
    input   logic                           imem_req,
    input   logic                           imem_cmd,
    input   logic [1:0]                     imem_width,
    input   logic [`YCR_IMEM_AWIDTH-1:0]   imem_addr,
    input   logic [`YCR_IMEM_BSIZE-1:0]    imem_bl,
    output  logic [`YCR_IMEM_DWIDTH-1:0]   imem_rdata,
    output  logic [1:0]                     imem_resp,

    // dmem interface
    output  logic                           dmem_req_ack,
    input   logic                           dmem_req,
    input   logic                           dmem_cmd,
    input   logic [1:0]                     dmem_width,
    input   logic [`YCR_DMEM_AWIDTH-1:0]   dmem_addr,
    output  logic [`YCR_DMEM_DWIDTH-1:0]   dmem_rdata,
    output  logic [1:0]                     dmem_resp,


    // icache interface
    input   logic                           icache_req_ack,
    output  logic                           icache_req,
    output  logic                           icache_cmd,
    output  logic [1:0]                     icache_width,
    output  logic [`YCR_IMEM_AWIDTH-1:0]   icache_addr,
    output  logic [`YCR_IMEM_BSIZE-1:0]    icache_bl,
    input   logic [`YCR_IMEM_DWIDTH-1:0]   icache_rdata,
    input   logic [1:0]                     icache_resp

);


wire icache_ack = (icache_resp == YCR_MEM_RESP_RDY_LOK);

// Arbitor to select between external wb vs uart wb
wire [1:0] grnt;

ycr_arb u_arb(
	.clk      (clk                ), 
	.rstn     (rst_n              ), 
	.req      ({dmem_req,imem_req}), 
	.ack      (icache_ack         ), 
	.gnt      (grnt               )
        );

// Select  the master based on the grant
assign icache_req   = (grnt == 2'b00) ? imem_req    : (grnt == 2'b01) ? dmem_req   : 1'b0; 
assign icache_cmd   = (grnt == 2'b00) ? imem_cmd    : (grnt == 2'b01) ? dmem_cmd   : '0; 
assign icache_width = (grnt == 2'b00) ? imem_width  : (grnt == 2'b01) ? dmem_width : '0; 
assign icache_addr  = (grnt == 2'b00) ? imem_addr   : (grnt == 2'b01) ? dmem_addr  : '0; 
assign icache_bl    = (grnt == 2'b00) ? imem_bl     : (grnt == 2'b01) ? 'h1        : '0; 

assign imem_req_ack    = (grnt == 2'b00) ? icache_req_ack : 'h0;
assign imem_rdata      = (grnt == 2'b00) ? icache_rdata   : 'h0;
// Manipulate the propgation of last ack,
// As Risc core support only ACK, So we are passing only ack towards core
// we are using last ack to help in grant switching
assign imem_resp       = (grnt == 2'b00) ? ((icache_resp == YCR_MEM_RESP_RDY_LOK) ?  YCR_MEM_RESP_RDY_OK : icache_resp)  : 'h0;

assign dmem_req_ack    = (grnt == 2'b01) ? icache_req_ack : 'h0;
assign dmem_rdata      = (grnt == 2'b01) ? icache_rdata   : 'h0;
assign dmem_resp       = (grnt == 2'b01) ? ((icache_resp == YCR_MEM_RESP_RDY_LOK) ?  YCR_MEM_RESP_RDY_OK : icache_resp)    : 'h0;


endmodule : ycr_icache_router
