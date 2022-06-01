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
////  yifive Wishbone interface for Instruction memory                    ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     integrated wishbone i/f to instruction memory                    ////
////                                                                      ////
////  To Do:                                                              ////
////    nothing                                                           ////
////                                                                      ////
////  Author(s):                                                          ////
////      - Dinesh Annayya, dinesha@opencores.org                         ////
////                                                                      ////
////  Revision :                                                          ////
////     v0:    June 7, 2021, Dinesh A                                    ////
////             wishbone integration                                     ////
////     v1:    June 9, 2021, Dinesh A                                    ////
////              On power up, wishbone output are unkown as it           ////
////              driven from fifo output. To avoid unknown               ////
////              propgation, we are driving 'h0 when fifo empty          ////
////     v2:    June 18, 2021, Dinesh A                                   ////
////            core and wishbone is made async and async fifo            ////
////            added to take care of domain cross-over                   ////
////                                                                      ////
//////////////////////////////////////////////////////////////////////////////

`include "ycr_wb.svh"
`include "ycr_memif.svh"

module ycr_imem_wb (
    // Control Signals
    input   logic                           core_rst_n, // core reset
    input   logic                           core_clk,   // Core clock

    // Core Interface
    output  logic                           imem_req_ack,
    input   logic                           imem_req,
    input   logic   [YCR_WB_WIDTH-1:0]     imem_addr,
    output  logic   [YCR_WB_WIDTH-1:0]     imem_rdata,
    output  logic [1:0]                     imem_resp,

    // WB Interface
    input   logic                           wb_rst_n,   // wishbone reset
    input   logic                           wb_clk,     // wishbone clock
    output  logic                           wbd_stb_o, // strobe/request
    output  logic   [YCR_WB_WIDTH-1:0]     wbd_adr_o, // address
    output  logic                           wbd_we_o,  // write
    output  logic   [YCR_WB_WIDTH-1:0]     wbd_dat_o, // data output
    output  logic   [3:0]                   wbd_sel_o, // byte enable
    input   logic   [YCR_WB_WIDTH-1:0]     wbd_dat_i, // data input
    input   logic                           wbd_ack_i, // acknowlegement
    input   logic                           wbd_err_i  // error

);

//-------------------------------------------------------------------------------
// Local parameters declaration
//-------------------------------------------------------------------------------

//-------------------------------------------------------------------------------
// Local types declaration
//-------------------------------------------------------------------------------

typedef struct packed {
    logic   [YCR_WB_WIDTH-1:0]    haddr;
} type_ycr_req_fifo_s;

typedef struct packed {
    logic                           hresp;
    logic   [YCR_WB_WIDTH-1:0]    hrdata;
} type_ycr_resp_fifo_s;

//-------------------------------------------------------------------------------
// Local signal declaration
//-------------------------------------------------------------------------------

//-------------------------------------------------------------------------------
// Request FIFO
// ------------------------------------------------------------------------------
logic                                       req_fifo_rd;
logic                                       req_fifo_wr;
logic                                       req_fifo_empty;
logic                                       req_fifo_full;


//-----------------------------------------------------
// Response FIFO (READ PATH
// ----------------------------------------------------
logic                                      resp_fifo_empty;
logic                                      resp_fifo_rd;



//-------------------------------------------------------------------------------
// REQ_FIFO
//-------------------------------------------------------------------------------
type_ycr_req_fifo_s    req_fifo_din;
type_ycr_req_fifo_s    req_fifo_dout;

assign req_fifo_wr  = ~req_fifo_full & imem_req;
assign imem_req_ack = ~req_fifo_full;

assign req_fifo_din.haddr = imem_addr;

 async_fifo #(
      .W(YCR_WB_WIDTH), // Data Width
      .DP(4),            // FIFO DEPTH
      .WR_FAST(1),       // We need FF'ed Full
      .RD_FAST(1)        // We need FF'ed Empty
     )   u_req_fifo(
     // Writc Clock
	.wr_clk      (core_clk       ),
        .wr_reset_n  (core_rst_n     ),
        .wr_en       (req_fifo_wr    ),
        .wr_data     (req_fifo_din   ),
        .full        (req_fifo_full  ),
        .afull       (               ),                 

    // RD Clock
        .rd_clk     (wb_clk          ),
        .rd_reset_n (wb_rst_n        ),
        .rd_en      (req_fifo_rd     ),
        .empty      (req_fifo_empty  ),                
        .aempty     (                ),                
        .rd_data    (req_fifo_dout   )
      );


always_comb begin
    req_fifo_rd = 1'b0;
    if (wbd_ack_i) begin
         req_fifo_rd = ~req_fifo_empty;
    end
end

assign wbd_stb_o    = ~req_fifo_empty;
// On Power, to avoid unknow propgating the value
assign wbd_adr_o    = (req_fifo_empty) ? 'h0 : req_fifo_dout.haddr; 
assign wbd_we_o     = 0; // Only Read supported
assign wbd_dat_o    = 32'h0; // No Write
assign wbd_sel_o    = 4'b1111; // Only Read allowed in imem i/f
//-------------------------------------------------------------------------------
// Response path - Used by Read path logic
//-------------------------------------------------------------------------------
type_ycr_resp_fifo_s                       resp_fifo_din;
type_ycr_resp_fifo_s                       resp_fifo_dout;

assign resp_fifo_din.hresp  = (wbd_err_i) ? 1'b0 : 1'b1;
assign resp_fifo_din.hrdata = wbd_dat_i;

 async_fifo #(
      .W(YCR_WB_WIDTH+1), // Data Width
      .DP(4),            // FIFO DEPTH
      .WR_FAST(1),       // We need FF'ed Full
      .RD_FAST(1)        // We need FF'ed Empty
     )   u_res_fifo(
     // Writc Clock
	.wr_clk      (wb_clk                 ),
        .wr_reset_n  (wb_rst_n               ),
        .wr_en       (wbd_ack_i              ),
        .wr_data     (resp_fifo_din          ),
        .full        (                       ), // Assmed FIFO will never be full as it's Response a Single Request
        .afull       (                       ),                 

    // RD Clock
        .rd_clk     (core_clk                ),
        .rd_reset_n (core_rst_n              ),
        .rd_en      (resp_fifo_rd            ),
        .empty      (resp_fifo_empty         ),                
        .aempty     (                        ),                
        .rd_data    (resp_fifo_dout          )
      );


assign resp_fifo_rd = !resp_fifo_empty;
assign imem_rdata   = resp_fifo_dout.hrdata;

assign imem_resp = (resp_fifo_rd)
                    ? (resp_fifo_dout.hresp == 1'b1)
                        ? YCR_MEM_RESP_RDY_OK
                        : YCR_MEM_RESP_RDY_ER
                    : YCR_MEM_RESP_NOTRDY ;


`ifdef YCR_TRGT_SIMULATION
//-------------------------------------------------------------------------------
// Assertion
//-------------------------------------------------------------------------------

// Check Core interface
YCR_SVA_IMEM_WB_BRIDGE_REQ_XCHECK : assert property (
    @(negedge core_clk) disable iff (~core_rst_n)
    !$isunknown(imem_req)
    ) else $error("IMEM WB bridge Error: imem_req has unknown values");

YCR_IMEM_WB_BRIDGE_ADDR_XCHECK : assert property (
    @(negedge core_clk) disable iff (~core_rst_n)
    imem_req |-> !$isunknown(imem_addr)
    ) else $error("IMEM WB bridge Error: imem_addr has unknown values");

YCR_IMEM_WB_BRIDGE_ADDR_ALLIGN : assert property (
    @(negedge core_clk) disable iff (~core_rst_n)
    imem_req |-> (imem_addr[1:0] == '0)
    ) else $error("IMEM WB bridge Error: imem_addr has unalign values");

// Check WB interface
YCR_IMEM_WB_BRIDGE_HREADY_XCHECK : assert property (
    @(negedge core_clk) disable iff (~core_rst_n)
    !$isunknown(imem_req_ack)
    ) else $error("IMEM WB bridge Error: imem_req_ack has unknown values");

YCR_IMEM_WB_BRIDGE_HRESP_XCHECK : assert property (
    @(negedge core_clk) disable iff (~core_rst_n)
    !$isunknown(imem_resp)
    ) else $error("IMEM WB bridge Error: imem_resp has unknown values");

`endif // YCR_TRGT_SIMULATION

endmodule : ycr_imem_wb
