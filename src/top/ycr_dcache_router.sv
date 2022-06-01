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
////     Data cache router                                                ////
////     Map the instruction and Data Memory request to dcache            ////
////                                                                      ////
////  To Do:                                                              ////
////    nothing                                                           ////
////                                                                      ////
////  Author(s):                                                          ////
////      - Dinesh Annayya, dinesha@opencores.org                         ////
////                                                                      ////
////  Revision :                                                          ////
////     v0:    21 Jan 2022,  Dinesh A                                    ////
////             Initial Version                                          ////
////                                                                      ////
//////////////////////////////////////////////////////////////////////////////

`include "ycr_memif.svh"
`include "ycr_arch_description.svh"

module ycr_dcache_router (
    // Control signals
    input   logic                           rst_n,
    input   logic                           clk,

    // imem interface
    output  logic                           imem_req_ack,
    input   logic                           imem_req,
    input   logic                           imem_cmd,
    input   logic [1:0]                     imem_width,
    input   logic [`YCR_IMEM_AWIDTH-1:0]   imem_addr,
    input   logic [`YCR_IMEM_DWIDTH-1:0]   imem_wdata,
    output  logic [`YCR_IMEM_DWIDTH-1:0]   imem_rdata,
    output  logic [1:0]                     imem_resp,

    // dmem interface
    output  logic                           dmem_req_ack,
    input   logic                           dmem_req,
    input   logic                           dmem_cmd,
    input   logic [1:0]                     dmem_width,
    input   logic [`YCR_DMEM_AWIDTH-1:0]   dmem_addr,
    input   logic [`YCR_DMEM_DWIDTH-1:0]   dmem_wdata,
    output  logic [`YCR_DMEM_DWIDTH-1:0]   dmem_rdata,
    output  logic [1:0]                     dmem_resp,


    // dcache interface
    input   logic                           dcache_req_ack,
    output  logic                           dcache_req,
    output  logic                           dcache_cmd,
    output  logic [1:0]                     dcache_width,
    output  logic [`YCR_IMEM_AWIDTH-1:0]   dcache_addr,
    output  logic [`YCR_IMEM_DWIDTH-1:0]   dcache_wdata,
    input   logic [`YCR_IMEM_DWIDTH-1:0]   dcache_rdata,
    input   logic [1:0]                     dcache_resp

);


wire dcache_ack = (dcache_resp == YCR_MEM_RESP_RDY_OK);

// Arbitor to select between external wb vs uart wb
wire [1:0] grnt;

ycr_arb u_arb(
	.clk      (clk                ), 
	.rstn     (rst_n              ), 
	.req      ({dmem_req,imem_req}), 
	.ack      (dcache_ack         ), 
	.gnt      (grnt               )
        );

// Select  the master based on the grant
assign dcache_req   = (grnt == 2'b00) ? imem_req    : (grnt == 2'b01) ? dmem_req   : 1'b0; 
assign dcache_cmd   = (grnt == 2'b00) ? imem_cmd    : (grnt == 2'b01) ? dmem_cmd   : '0; 
assign dcache_width = (grnt == 2'b00) ? imem_width  : (grnt == 2'b01) ? dmem_width : '0; 
assign dcache_addr  = (grnt == 2'b00) ? imem_addr   : (grnt == 2'b01) ? dmem_addr  : '0; 
assign dcache_wdata = (grnt == 2'b00) ? imem_wdata  : (grnt == 2'b01) ? dmem_wdata : '0; 

assign imem_req_ack    = (grnt == 2'b00) ? dcache_req_ack : 'h0;
assign imem_rdata      = (grnt == 2'b00) ? dcache_rdata   : 'h0;
assign imem_resp       = (grnt == 2'b00) ? dcache_resp    : 'h0;

assign dmem_req_ack    = (grnt == 2'b01) ? dcache_req_ack : 'h0;
assign dmem_rdata      = (grnt == 2'b01) ? dcache_rdata   : 'h0;
assign dmem_resp       = (grnt == 2'b01) ? dcache_resp    : 'h0;


endmodule : ycr_dcache_router
