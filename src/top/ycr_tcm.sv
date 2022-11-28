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
////  yifive Tightly-Coupled Memory (TCM)                                 ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     Tightly-Coupled Memory (TCM)                                     ////
////                                                                      ////
////  To Do:                                                              ////
////    nothing                                                           ////
////                                                                      ////
////  Author(s):                                                          ////
////     - syntacore, https://github.com/syntacore/scr1                   ////
////     - Dinesh Annayya, dinesha@opencores.org                          ////
////                                                                      ////
////  Revision :                                                          ////
////     v0:    Jan 2021- Initial version picked from                     ////
////            https://github.com/syntacore/scr1                         ////
////     v1:    June 7, 2021, Dinesh A                                    ////
////             opentool(iverilog/yosys) related cleanup                 ////
////     v2:    June 7, 2021, Dinesh A                                    ////
////             2KB SRAM Integration                                     ////
////                                                                      ////
//////////////////////////////////////////////////////////////////////////////


`include "ycr_memif.svh"
`include "ycr_arch_description.svh"

`ifdef YCR_TCM_EN
module ycr_tcm
#(
    parameter YCR_TCM_SIZE = `YCR_IMEM_AWIDTH'h00010000
)
(
    // Control signals
    input   logic                           clk,
    input   logic                           clk_src,
    input   logic                           rst_n,

`ifndef YCR_TCM_MEM
    // SRAM0 PORT-0
    output  logic                          sram0_clk0,
    output  logic                          sram0_csb0,
    output  logic                          sram0_web0,
    output  logic   [8:0]                  sram0_addr0,
    output  logic   [3:0]                  sram0_wmask0,
    output  logic   [31:0]                 sram0_din0,
    input   logic   [31:0]                 sram0_dout0,

    // SRAM-0 PORT-1
    output  logic                          sram0_clk1,
    output  logic                          sram0_csb1,
    output  logic  [8:0]                   sram0_addr1,
    input   logic  [31:0]                  sram0_dout1,

    // SRAM1 PORT-0
    output  logic                          sram1_clk0,
    output  logic                          sram1_csb0,
    output  logic                          sram1_web0,
    output  logic   [8:0]                  sram1_addr0,
    output  logic   [3:0]                  sram1_wmask0,
    output  logic   [31:0]                 sram1_din0,
    input   logic   [31:0]                 sram1_dout0,

    // SRAM-1 PORT-1
    output  logic                          sram1_clk1,
    output  logic                          sram1_csb1,
    output  logic  [8:0]                   sram1_addr1,
    input   logic  [31:0]                  sram1_dout1,

`endif

    // Core instruction interface
    output  logic                          imem_req_ack,
    input   logic                          imem_req,
    input   logic [`YCR_IMEM_AWIDTH-1:0]   imem_addr,
    output  logic [`YCR_IMEM_DWIDTH-1:0]   imem_rdata,
    output  logic [1:0]                    imem_resp,

    // Core data interface
    output  logic                          dmem_req_ack,
    input   logic                          dmem_req,
    input   logic                          dmem_cmd,
    input   logic [1:0]                    dmem_width,
    input   logic [`YCR_DMEM_AWIDTH-1:0]   dmem_addr,
    input   logic [`YCR_DMEM_DWIDTH-1:0]   dmem_wdata,
    output  logic [`YCR_DMEM_DWIDTH-1:0]   dmem_rdata,
    output  logic [1:0]                    dmem_resp
);

//-------------------------------------------------------------------------------
// Local signal declaration
//-------------------------------------------------------------------------------
logic                               imem_rd;
logic                               dmem_rd;
logic                               dmem_wr;
logic [`YCR_DMEM_DWIDTH-1:0]       dmem_writedata;
logic [`YCR_DMEM_DWIDTH-1:0]       dmem_rdata_local;
logic [3:0]                        dmem_byteen;
logic [1:0]                        dmem_rdata_shift_reg;

// As SRAM Read data is launched at negedge, to meet the read path timing we
// are registering read path
logic [`YCR_IMEM_DWIDTH-1:0]       imem_rdata_int;
logic [1:0]                        imem_resp_int;

logic [`YCR_IMEM_DWIDTH-1:0]       dmem_rdata_int;
logic [1:0]                        dmem_resp_int;
//-------------------------------------------------------------------------------
// Core interface
//-------------------------------------------------------------------------------


// Two cycle response generation to match the SRAM read response delay
always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        imem_resp_int <= YCR_MEM_RESP_NOTRDY;
	imem_req_ack <= '0;
    end else if (imem_req && !imem_req_ack) begin
	imem_req_ack <= '1;
        imem_resp_int    <= YCR_MEM_RESP_NOTRDY;
    end else if (imem_req_ack) begin
	imem_req_ack <= '0;
        imem_resp_int    <= YCR_MEM_RESP_RDY_OK;
    end else begin
        imem_resp_int    <= YCR_MEM_RESP_NOTRDY;
    end
end

// Two cycle response generation to match the SRAM read response delay
always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        dmem_resp_int <= YCR_MEM_RESP_NOTRDY;
	dmem_req_ack <= '0;
    end else if (dmem_req && !dmem_req_ack) begin
	dmem_req_ack <= '1;
        dmem_resp_int    <= YCR_MEM_RESP_NOTRDY;
    end else if (dmem_req_ack) begin
	dmem_req_ack <= '0;
        dmem_resp_int    <= YCR_MEM_RESP_RDY_OK ;
    end else begin
        dmem_resp_int    <= YCR_MEM_RESP_NOTRDY;
    end
end

// Registering SRAM Read path to break half cycle path
always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        imem_resp     <= YCR_MEM_RESP_NOTRDY;
	imem_rdata    <= 'h0;

        dmem_resp     <= YCR_MEM_RESP_NOTRDY;
	dmem_rdata    <= 'h0;
    end else begin
        imem_resp     <= imem_resp_int;
	imem_rdata    <= imem_rdata_int;

        dmem_resp     <= dmem_resp_int;
	dmem_rdata    <= dmem_rdata_int;
    end
end
//-------------------------------------------------------------------------------
// Memory data composing
//-------------------------------------------------------------------------------
`ifndef YCR_TCM_MEM
// IMEM SRAM Read Path Selection - To break timing loop
logic imem_sram_sel;
always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        imem_sram_sel <= '0;
    end else begin
        imem_sram_sel <= imem_addr[11];
    end
end

// DMEM SRAM Read Path Selection - To break timing loop
logic dmem_sram_sel;
always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        dmem_sram_sel        <= '0;
        dmem_rdata_shift_reg <= '0;
    end else begin
        dmem_sram_sel        <= dmem_addr[11];
        dmem_rdata_shift_reg <= dmem_addr[1:0];
    end
end
// connect the TCM memory to SRAM-0
assign sram0_clk1 = clk_src;
assign sram0_csb1 =!(imem_req & dmem_req_ack & imem_addr[11] == 1'b0);
assign sram0_addr1 = imem_addr[10:2];

// connect the TCM memory to SRAM-1
assign sram1_clk1 = clk_src;
assign sram1_csb1 =!(imem_req & dmem_req_ack & imem_addr[11] == 1'b1);
assign sram1_addr1 = imem_addr[10:2];

// IMEM Read Data Selection Based on Address bit[11]
assign imem_rdata_int  = (imem_sram_sel == 1'b0) ?  sram0_dout1: sram1_dout1;

// SRAM-0 Port 0 Control Generation
assign sram0_clk0 = clk_src;
assign sram0_csb0   = !(dmem_req & dmem_req_ack & (dmem_addr[11] == 1'b0) & ((dmem_cmd == YCR_MEM_CMD_RD) | (dmem_cmd == YCR_MEM_CMD_WR)));
assign sram0_web0   = !(dmem_req & dmem_req_ack & (dmem_cmd == YCR_MEM_CMD_WR));
assign sram0_addr0  = dmem_addr[10:2];
assign sram0_wmask0 =  dmem_byteen;
assign sram0_din0   =  dmem_writedata;

// SRAM-1 Port 0 Control Generation
assign sram1_clk0 = clk_src;
assign sram1_csb0   = !(dmem_req & dmem_req_ack & (dmem_addr[11] == 1'b1) & ((dmem_cmd == YCR_MEM_CMD_RD) | (dmem_cmd == YCR_MEM_CMD_WR)));
assign sram1_web0   = !(dmem_req & dmem_req_ack & (dmem_cmd == YCR_MEM_CMD_WR));
assign sram1_addr0  = dmem_addr[10:2];
assign sram1_wmask0 =  dmem_byteen;
assign sram1_din0   =  dmem_writedata;


// DMEM Read Data Selection Based on Address bit[11]
assign dmem_rdata_local = (dmem_sram_sel == 1'b0) ? sram0_dout0: sram1_dout0;

`endif

//------------------------------
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
//-------------------------------------------------------------------------------
// Memory instantiation
//-------------------------------------------------------------------------------
`ifdef YCR_TCM_MEM
ycr_dp_memory #(
    .YCR_WIDTH ( 32            ),
    .YCR_SIZE  ( YCR_TCM_SIZE )
) i_dp_memory (
    .clk    ( clk                                   ),
    // Instruction port
    // Port A
    .rena   ( imem_rd                               ),
    .addra  ( imem_addr[$clog2(YCR_TCM_SIZE)-1:2]  ),
    .qa     ( imem_rdata                            ),
    // Data port
    // Port B
    .renb   ( dmem_rd                               ),
    .wenb   ( dmem_wr                               ),
    .webb   ( dmem_byteen                           ),
    .addrb  ( dmem_addr[$clog2(YCR_TCM_SIZE)-1:2]  ),
    .qb     ( dmem_rdata_local                      ),
    .datab  ( dmem_writedata                        )
);
`endif

//-------------------------------------------------------------------------------
// Data memory output generation
//-------------------------------------------------------------------------------

assign dmem_rdata_int = dmem_rdata_local >> ( 8 * dmem_rdata_shift_reg );

endmodule : ycr_tcm

`endif // YCR_TCM_EN
