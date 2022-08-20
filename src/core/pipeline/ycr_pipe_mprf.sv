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
////  yifive Multi Port Register File (MPRF)                              ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     Multi Port Register File (MPRF)                                  ////
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
////     v2:     June 7, 2021, Dinesh A                                   ////
////               added additional stage FF to break timing path         ////
////               additional define YCRC1_MPRF_STAGE added               ////
////                                                                      ////
//////////////////////////////////////////////////////////////////////////////

`include "ycr_arch_description.svh"
`include "ycr_arch_types.svh"

module ycr_pipe_mprf (
    // Common
`ifdef YCR_MPRF_RST_EN
    input   logic                               rst_n,                      // MPRF reset
`endif // YCR_MPRF_RST_EN
    input   logic                               clk,                        // MPRF clock

    // EXU <-> MPRF interface
    input   logic [`YCR_MPRF_AWIDTH-1:0]       exu2mprf_rs1_addr_i,        // MPRF rs1 read address
    output  logic [`YCR_XLEN-1:0]              mprf2exu_rs1_data_o,        // MPRF rs1 read data
    input   logic [`YCR_MPRF_AWIDTH-1:0]       exu2mprf_rs2_addr_i,        // MPRF rs2 read address
    output  logic [`YCR_XLEN-1:0]              mprf2exu_rs2_data_o,        // MPRF rs2 read data
    input   logic                               exu2mprf_w_req_i,           // MPRF write request
    input   logic [`YCR_MPRF_AWIDTH-1:0]       exu2mprf_rd_addr_i,         // MPRF rd write address
    input   logic [`YCR_XLEN-1:0]              exu2mprf_rd_data_i,         // MPRF rd write data

    output  logic [`YCR_XLEN-1:0]              func_return_val    // Debug Purpose
);

//-------------------------------------------------------------------------------
// Local types declaration
//-------------------------------------------------------------------------------

logic                        wr_req_vd;

logic                        rs1_addr_vd;
logic                        rs2_addr_vd;

`ifdef YCRC1_MPRF_STAGE
logic                        rs1_addr_vd_ff;
logic                        rs2_addr_vd_ff;

logic                        rs1_new_data_req;
logic                        rs2_new_data_req;
logic                        rs1_new_data_req_ff;
logic                        rs2_new_data_req_ff;
logic                        read_new_data_req;

logic    [`YCR_XLEN-1:0]    rd_data_ff;

logic    [`YCR_XLEN-1:0]    rs1_data_ff;
logic    [`YCR_XLEN-1:0]    rs2_data_ff;


`endif

`ifdef  YCR_MPRF_RAM
logic                        rs1_addr_vd_ff;
logic                        rs2_addr_vd_ff;

logic                        rs1_new_data_req;
logic                        rs2_new_data_req;
logic                        rs1_new_data_req_ff;
logic                        rs2_new_data_req_ff;
logic                        read_new_data_req;

logic    [`YCR_XLEN-1:0]    rd_data_ff;

logic    [`YCR_XLEN-1:0]    rs1_data_ff;
logic    [`YCR_XLEN-1:0]    rs2_data_ff;

// when using RAM, 2 memories are needed because 3 simultaneous independent
// write/read operations can occur
 `ifdef YCR_TRGT_FPGA_INTEL_MAX10
(* ramstyle = "M9K" *)      logic   [`YCR_XLEN-1:0]    mprf_int   [1:`YCR_MPRF_SIZE-1];
(* ramstyle = "M9K" *)      logic   [`YCR_XLEN-1:0]    mprf_int2  [1:`YCR_MPRF_SIZE-1];
 `elsif YCR_TRGT_FPGA_INTEL_ARRIAV
(* ramstyle = "M10K" *)     logic   [`YCR_XLEN-1:0]    mprf_int   [1:`YCR_MPRF_SIZE-1];
(* ramstyle = "M10K" *)     logic   [`YCR_XLEN-1:0]    mprf_int2  [1:`YCR_MPRF_SIZE-1];
 `else
logic   [`YCR_XLEN-1:0]    mprf_int   [1:`YCR_MPRF_SIZE-1];
logic   [`YCR_XLEN-1:0]    mprf_int2  [1:`YCR_MPRF_SIZE-1];
 `endif
`else  // distributed logic implementation
logic [`YCR_XLEN-1:0]      mprf_int [1:`YCR_MPRF_SIZE-1];
`endif

// Location[0] hold the function return value
assign  func_return_val = mprf_int[10];

//------------------------------------------------------------------------------
// MPRF control logic
//------------------------------------------------------------------------------

// control signals common for distributed logic and RAM implementations
assign  rs1_addr_vd  =   |exu2mprf_rs1_addr_i;
assign  rs2_addr_vd  =   |exu2mprf_rs2_addr_i;

assign  wr_req_vd  =   exu2mprf_w_req_i & |exu2mprf_rd_addr_i;

// RAM implementation specific control signals
`ifdef YCR_MPRF_RAM
assign  rs1_new_data_req    =   wr_req_vd & ( exu2mprf_rs1_addr_i == exu2mprf_rd_addr_i );
assign  rs2_new_data_req    =   wr_req_vd & ( exu2mprf_rs2_addr_i == exu2mprf_rd_addr_i );
assign  read_new_data_req   =   rs1_new_data_req | rs2_new_data_req;

always_ff @( posedge clk ) begin
    rs1_addr_vd_ff          <=  rs1_addr_vd;
    rs2_addr_vd_ff          <=  rs2_addr_vd;
    rs1_new_data_req_ff     <=  rs1_new_data_req;
    rs2_new_data_req_ff     <=  rs2_new_data_req;
end
`endif // YCR_MPRF_RAM

`ifdef  YCR_MPRF_RAM
//-------------------------------------------------------------------------------
// RAM implementation
//-------------------------------------------------------------------------------

// RAM is implemented with 2 simple dual-port memories with sync read operation;
// logic for "write-first" RDW behavior is implemented externally to the embedded
// memory blocks

// bypass new wr_data to the read output if write/read collision occurs
assign  mprf2exu_rs1_data_o   =   ( rs1_new_data_req_ff ) ? rd_data_ff
                                : (( rs1_addr_vd_ff )   ? rs1_data_ff
                                                        : '0 );

assign  mprf2exu_rs2_data_o   =   ( rs2_new_data_req_ff ) ? rd_data_ff
                                : (( rs2_addr_vd_ff )   ? rs2_data_ff
                                                        : '0 );

always_ff @( posedge clk ) begin
    if ( read_new_data_req ) begin
        rd_data_ff     <=  exu2mprf_rd_data_i;
    end
end

// synchronous read operation
always_ff @( posedge clk ) begin
    rs1_data_ff   <=   mprf_int[exu2mprf_rs1_addr_i];
    rs2_data_ff   <=   mprf_int2[exu2mprf_rs2_addr_i];
end

// write operation
always_ff @( posedge clk ) begin
    if ( wr_req_vd ) begin
        mprf_int[exu2mprf_rd_addr_i]  <= exu2mprf_rd_data_i;
        mprf_int2[exu2mprf_rd_addr_i] <= exu2mprf_rd_data_i;
    end
end
`else   // distributed logic implementation
//------------------------------------------------------------------------------
// distributed logic implementation
//------------------------------------------------------------------------------

// asynchronous read operation
//
`ifdef YCRC1_MPRF_STAGE
   assign  rs1_new_data_req    =   wr_req_vd & ( exu2mprf_rs1_addr_i == exu2mprf_rd_addr_i );
   assign  rs2_new_data_req    =   wr_req_vd & ( exu2mprf_rs2_addr_i == exu2mprf_rd_addr_i );
   assign  read_new_data_req   =   rs1_new_data_req | rs2_new_data_req;

// bypass new wr_data to the read output if write/read collision occurs
   assign  mprf2exu_rs1_data_o   =   ( rs1_new_data_req_ff ) ? rd_data_ff
                                   : (( rs1_addr_vd_ff )     ? rs1_data_ff
                                                               : '0 );
   
   assign  mprf2exu_rs2_data_o   =   ( rs2_new_data_req_ff ) ? rd_data_ff
                                   : (( rs2_addr_vd_ff )     ? rs2_data_ff
                                                               : '0 );

   
   always_ff @( posedge clk ) begin
      if ( read_new_data_req ) begin
          rd_data_ff     <=  exu2mprf_rd_data_i;
      end
   end

   always_ff @( posedge clk ) begin
       rs1_addr_vd_ff          <=  rs1_addr_vd;
       rs2_addr_vd_ff          <=  rs2_addr_vd;
       rs1_new_data_req_ff     <=  rs1_new_data_req;
       rs2_new_data_req_ff     <=  rs2_new_data_req;
   end
   always_ff @( posedge clk ) begin
      rs1_data_ff   <=   mprf_int[exu2mprf_rs1_addr_i];
      rs2_data_ff   <=   mprf_int[exu2mprf_rs2_addr_i];
   end

`else 
    assign  mprf2exu_rs1_data_o = ( rs1_addr_vd ) ? mprf_int[exu2mprf_rs1_addr_i] : '0;
    assign  mprf2exu_rs2_data_o = ( rs2_addr_vd ) ? mprf_int[exu2mprf_rs2_addr_i] : '0;
`endif

// write operation
 `ifdef YCR_MPRF_RST_EN
always_ff @( posedge clk, negedge rst_n ) begin
    if ( ~rst_n ) begin
        mprf_int <= '{default: '0};
    end else if ( wr_req_vd ) begin
        mprf_int[exu2mprf_rd_addr_i] <= exu2mprf_rd_data_i;
    end
end
 `else // ~YCR_MPRF_RST_EN
always_ff @( posedge clk ) begin
    if ( wr_req_vd ) begin
        mprf_int[exu2mprf_rd_addr_i] <= exu2mprf_rd_data_i;
    end
end
 `endif // ~YCR_MPRF_RST_EN
`endif

`ifdef YCR_TRGT_SIMULATION
//-------------------------------------------------------------------------------
// Assertion
//-------------------------------------------------------------------------------
`ifdef YCR_MPRF_RST_EN
YCR_SVA_MPRF_WRITEX : assert property (
    @(negedge clk) disable iff (~rst_n)
    exu2mprf_w_req_i |-> !$isunknown({exu2mprf_rd_addr_i, (|exu2mprf_rd_addr_i ? exu2mprf_rd_data_i : `YCR_XLEN'd0)})
    ) else $error("MPRF error: unknown values");
`endif // YCR_MPRF_RST_EN

`endif // YCR_TRGT_SIMULATION

endmodule : ycr_pipe_mprf
