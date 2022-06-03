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
////  yifive tcm memory router                                            ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycrcr.git                         ////
////                                                                      ////
////  Description:                                                        ////
////     TCM memory router                                                ////
////     Map the instruction and Data Memory request to tcm memory        ////
////     TCM - Tightly coupled local memory
////                                                                      ////
////  To Do:                                                              ////
////    nothing                                                           ////
////                                                                      ////
////  Author(s):                                                          ////
////      - Dinesh Annayya, dinesha@opencores.org                         ////
////                                                                      ////
////  Revision :                                                          ////
////     v0:    15 Feb 2022,  Dinesh A                                    ////
////             Initial Version                                          ////
////                                                                      ////
//////////////////////////////////////////////////////////////////////////////

`include "ycr_memif.svh"
`include "ycr_arch_description.svh"

module ycr_tcm_router (
    // Control signals
    input   logic                           rst_n,
    input   logic                           clk,

    // imem interface
    output  logic                           imem_req_ack,
    input   logic                           imem_req,
    input   logic                           imem_cmd,
    input   logic [1:0]                     imem_width,
    input   logic [`YCR_IMEM_AWIDTH-1:0]   imem_addr,
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


    // DFFRAM I/F
    
    output  logic                       tcm_dffram_clk0        , // CLK
    output  logic                       tcm_dffram_cs0         , // Chip Select
    output  logic    [7:0]              tcm_dffram_addr0       , // Address
    output  logic    [3:0]              tcm_dffram_wmask0      , // Write Mask
    output  logic    [31:0]             tcm_dffram_din0        , // Write Data
    input   logic    [31:0]             tcm_dffram_dout0       , // Read Data
    
    output  logic                       tcm_dffram_clk1        , // CLK
    output  logic                       tcm_dffram_cs1         , // Chip Select
    output  logic    [7:0]              tcm_dffram_addr1       , // Address
    output  logic    [3:0]              tcm_dffram_wmask1      , // Write Mask
    output  logic    [31:0]             tcm_dffram_din1        , // Write Data
    input   logic    [31:0]             tcm_dffram_dout1        // Read Data

);

// TCM Variable decleration
logic        tcm_req;
logic        tcm_cmd;
logic [8:0]  tcm_addr;
logic [31:0] tcm_wdata;
logic [31:0] tcm_rdata;
logic [3:0]  tcm_wmask;
logic [1:0]  tcm_resp;

logic [31:0] dmem_writedata;
logic [3:0]  dmem_byteen;
logic [1:0]  dmem_rdata_shift_reg;


wire tcm_ack = (tcm_resp == YCR_MEM_RESP_RDY_LOK);

// Arbitor to select between external wb vs uart wb
wire [1:0] grnt;

ycr_arb2 u_arb(
	.clk      (clk                ), 
	.rstn     (rst_n              ), 
	.req      ({dmem_req,imem_req}), 
	.ack      (icache_ack         ), 
	.gnt      (grnt               )
        );

// Select  the master based on the grant

assign tcm_req    = (grnt == 2'b00) ? imem_req          : (grnt == 2'b01) ? dmem_req         : 1'b0; 
assign tcm_cmd    = (grnt == 2'b00) ? imem_cmd          : (grnt == 2'b01) ? dmem_cmd         : '0; 
assign tcm_addr   = (grnt == 2'b00) ? imem_addr[10:2]   : (grnt == 2'b01) ? dmem_addr[10:2]  : '0; 

// Only DMEM does the Write access and Write Mask control
assign tcm_wdata  = dmem_writedata;
assign tcm_wmask  = (grnt == 2'b00) ?  'h0 : (grnt == 2'b01) ? dmem_byteen : '0;

//----------------------------
// Towards IMEM 
// -------------------------------
assign imem_req_ack    = (grnt == 2'b00) ? tcm_req_ack : 'h0;
assign imem_rdata      = (grnt == 2'b00) ? tcm_rdata   : 'h0;
// Manipulate the propgation of last ack,
// As Risc core support only ACK, So we are passing only ack towards core
// we are using last ack to help in grant switching
assign imem_resp       = (grnt == 2'b00) ? ((tcm_resp == YCR_MEM_RESP_RDY_LOK) ?  YCR_MEM_RESP_RDY_OK : tcm_resp)  : 'h0;


//------------------------------------
// Towards DMEM
// -----------------------------------

assign dmem_req_ack         = (grnt == 2'b01) ? tcm_req_ack : 'h0;
assign dmem_rdata           = tcm_rdata >> ( 8 * dmem_rdata_shift_reg );
assign dmem_resp            = (grnt == 2'b01) ? ((tcm_resp == YCR_MEM_RESP_RDY_LOK) ?  YCR_MEM_RESP_RDY_OK : tcm_resp)    : 'h0;




//------------------------------
// DMEM only does the memory write
// ----------------------------
always_comb begin
    dmem_writedata = dmem_wdata;
    dmem_byteen    = 4'b1111;
    case ( dmem_width )
        YCR_MEM_WIDTH_BYTE : begin
            dmem_writedata  = {(`YCR_DMEM_DWIDTH /  8){dmem_wdata[7:0]}};
            dmem_byteen     = 4'b0001 << dmem_addr[1:0];
        end
        YCR_MEM_WIDTH_HWORD : begin
            dmem_writedata  = {(`YCR_DMEM_DWIDTH / 16){dmem_wdata[15:0]}};
            dmem_byteen     = 4'b0011 << {dmem_addr[1], 1'b0};
        end
        default : begin
        end
    endcase
end

// TCM Memory I/F

logic [8:0] mem_addr;
logic       mem_ack;
logic       mem_cs;
logic [1:0] state;
logic [3:0] mem_wmask;
logic [31:0]mem_rdata;
logic [31:0]mem_wdata;

parameter IDLE          = 2'b00;
parameter READ_ACTION1  = 2'b01;
parameter READ_ACTION2  = 2'b10;


assign tcm_req_ack = (state == IDLE) & tcm_req;
assign mem_ack    = (tcm_resp == YCR_MEM_RESP_RDY_OK);

always @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
       mem_addr         <= 'h0;
       mem_cs           <= 'b0;
       mem_wdata        <= 'h0;
       mem_wmask        <= 'h0;
       tcm_resp         <= 'h0;
       tcm_rdata        <= 'h0;
       dmem_rdata_shift_reg <= 'h0;
       state            <= IDLE;
    end else begin
	case(state)
	 IDLE: begin
	       mem_addr    <=  tcm_addr;
	       if(tcm_req && !tcm_cmd && !mem_ack) begin
	          mem_cs      <=  'b1;
                  mem_wmask   <=  'h0;
	          tcm_resp    <=  'b0;
                  dmem_rdata_shift_reg <= dmem_addr[1:0]; // unaligned access only happen in dmem interface
	          state       <=  READ_ACTION1;
	       end else if(tcm_req && tcm_cmd && !mem_ack) begin
	          mem_cs      <=  'b1;
                  mem_wmask   <=  tcm_wmask;
                  mem_wdata   <=  tcm_wdata;
		  tcm_resp    <=  YCR_MEM_RESP_RDY_OK;
	       end else begin
	          mem_cs      <=  1'b0;
	          tcm_resp    <=  'h0;
	       end
	    end

       // Wait for Ack from application layer
       READ_ACTION1: begin
           // If the not the last ack, update memory pointer
           // accordingly
	   mem_cs     <=  1'b0;
	   state      <=  READ_ACTION2;
       end
       READ_ACTION2: begin
           // If the not the last ack, update memory pointer
           // accordingly
	   tcm_resp   <= YCR_MEM_RESP_RDY_OK;
           tcm_rdata  <= mem_rdata;
	   state      <=  IDLE;
       end
       endcase
   end
end

// Decoding for two 1KB DFRAM

assign tcm_dffram_clk0        = clk; // CLK
assign tcm_dffram_cs0         = ((mem_addr[8] == 1'b0) & mem_cs);  // Chip Select
assign tcm_dffram_addr0       = mem_addr[7:0]; // Address
assign tcm_dffram_wmask0      = mem_wmask; // Write Mask
assign tcm_dffram_din0        = mem_wdata;  // Write Data
    
assign tcm_dffram_clk1        = clk; // CLK
assign tcm_dffram_cs1         = ((mem_addr[8] == 1'b1) & mem_cs); // Chip Select
assign tcm_dffram_addr1       = mem_addr[7:0];                    // Address
assign tcm_dffram_wmask1      = mem_wmask; // Write Mask
assign tcm_dffram_din1        = mem_wdata; // Write Data

assign  mem_rdata = (mem_addr[8] == 1'b0) ? tcm_dffram_dout0 : tcm_dffram_dout1;

endmodule : ycr_tcm_router
