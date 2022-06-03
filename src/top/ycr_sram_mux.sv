//////////////////////////////////////////////////////////////////////////////
// SPDX-FileCopyrightText: 2021, Dinesh Annayya                           ////
//                                                                        ////
// Licenseunder the Apache License, Vers2.0(the "License");               ////
// you maynot use this file except in compliance with the License.       ////
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
//----------------------------------------------------------------
// As there SRAM timing model is not correct. we have created
// additional position drive data in negedge
// ----------------------------------------------------------------
module ycr_sram_mux (
   input logic                              rst_n                ,
   input logic                              cfg_mem_lphase       , // 0 - Posedge (Default), 1 - Negedge
   // SRAM Memory I/F, PORT-0
   input logic                              mem_clk0_i           , // CLK
   input logic                              mem_csb0_i           , // CS#
   input logic                              mem_web0_i           , // WE#
   input logic   [8:0]                      mem_addr0_i          , // Address
   input logic   [3:0]                      mem_wmask0_i         , // WMASK#
   input logic   [31:0]                     mem_din0_i           , // Write Data
   
   // SRAM-0 PORT-1, 
   input logic                              mem_clk1_i           , // CLK
   input logic                              mem_csb1_i           , // CS#
   input logic  [8:0]                       mem_addr1_i          , // Address

   // SRAM Memory I/F, PORT-0
   output logic                             mem_csb0_o           , // CS#
   output logic                             mem_web0_o           , // WE#
   output logic   [8:0]                     mem_addr0_o          , // Address
   output logic   [3:0]                     mem_wmask0_o         , // WMASK#
   output logic   [31:0]                    mem_din0_o           , // Write Data
   
   // SRAM-0 PORT-1, 
   output logic                            mem_csb1_o            , // CS#
   output logic  [8:0]                     mem_addr1_o             // Address
);

//----------------------------------------------------------------
// As there SRAM timing model is not correct. we have created
// additional position drive data in negedge
// ----------------------------------------------------------------

logic                       mem_csb1_neg;
logic   [8:0]               mem_addr1_neg;

logic                       mem_csb0_neg;
logic                       mem_web0_neg;
logic   [3:0]               mem_wmask0_neg;
logic   [8:0]               mem_addr0_neg;
logic   [31:0]              mem_din0_neg;

always @(negedge rst_n or negedge mem_clk1_i) begin
   if(rst_n == 0) begin
      mem_csb1_neg  <= '1;
      mem_addr1_neg <= '0;
   end else begin
      mem_csb1_neg  <= mem_csb1_i;
      mem_addr1_neg <= mem_addr1_i;
   end
end

always @(negedge rst_n or negedge mem_clk0_i) begin
   if(rst_n == 0) begin
       mem_csb0_neg    <= '1;
       mem_web0_neg    <= '1;
       mem_wmask0_neg  <= '0;
       mem_addr0_neg   <= '0;
       mem_din0_neg    <= '0;
   end else begin
       mem_csb0_neg    <= mem_csb0_i;
       mem_web0_neg    <= mem_web0_i;
       mem_wmask0_neg  <= mem_wmask0_i;
       mem_addr0_neg   <= mem_addr0_i;
       mem_din0_neg    <= mem_din0_i;
   end
end

//assign mem_csb1_o   = (cfg_mem_lphase == 0) ?  mem_csb1_i  : mem_csb1_neg;
ctech_mux2x1_4 #(.WB(1)) u_mem_csb1 (.A0 (mem_csb1_i), .A1(mem_csb1_neg), .S(cfg_mem_lphase),.X(mem_csb1_o));

//assign mem_addr1_o  = (cfg_mem_lphase == 0) ?  mem_addr1_i : mem_addr1_neg;
ctech_mux2x1_4 #(.WB(9)) u_mem_addr1 (.A0 (mem_addr1_i), .A1(mem_addr1_neg), .S(cfg_mem_lphase),.X(mem_addr1_o));

//assign mem_csb0_o    = (cfg_mem_lphase == 0) ?  mem_csb0_i   : mem_csb0_neg;
ctech_mux2x1_4 #(.WB(1)) u_mem_csb0 (.A0 (mem_csb0_i), .A1(mem_csb0_neg), .S(cfg_mem_lphase),.X(mem_csb0_o));

//assign mem_web0_o    = (cfg_mem_lphase == 0) ?  mem_web0_i   : mem_web0_neg;
ctech_mux2x1_4 #(.WB(1)) u_mem_web0 (.A0 (mem_web0_i), .A1(mem_web0_neg), .S(cfg_mem_lphase),.X(mem_web0_o));

//assign mem_wmask0_o  = (cfg_mem_lphase == 0)?  mem_wmask0_i : mem_wmask0_neg;
ctech_mux2x1_4 #(.WB(4)) u_mem_wmask0 (.A0 (mem_wmask0_i), .A1(mem_wmask0_neg), .S(cfg_mem_lphase),.X(mem_wmask0_o));

//assign mem_addr0_o   = (cfg_mem_lphase == 0) ?  mem_addr0_i  : mem_addr0_neg;
ctech_mux2x1_4 #(.WB(9)) u_mem_addr0 (.A0 (mem_addr0_i), .A1(mem_addr0_neg), .S(cfg_mem_lphase),.X(mem_addr0_o));

//assign mem_din0_o    = (cfg_mem_lphase == 0) ?  mem_din0_i   : mem_din0_neg;
ctech_mux2x1_4 #(.WB(32)) u_mem_din0 (.A0 (mem_din0_i), .A1(mem_din0_neg), .S(cfg_mem_lphase),.X(mem_din0_o));


endmodule

