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
////  yifive dual port memory                                             ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     Dual-port synchronous memory with byte enable inputs             ////
////                                                                      ////
////  To Do:                                                              ////
////    nothing                                                           ////
////                                                                      ////
////  Author(s):                                                          ////
////      - Dinesh Annayya, dinesha@opencores.org                         ////
////                                                                      ////
////  Revision :                                                          ////
////     v0:    Jan 2021- Initial version picked from syntacore/scr1      ////
////     v1:    June 7, 2021, Dinesh A                                    ////
////             opentool(iverilog/yosys) related cleanup                 ////
////                                                                      ////
//////////////////////////////////////////////////////////////////////////////

`include "ycr_arch_description.svh"

`ifdef YCR_TCM_EN
module ycr_dp_memory
#(
    parameter YCR_WIDTH    = 32,
    parameter YCR_SIZE     = `YCR_IMEM_AWIDTH'h00010000,
    parameter YCR_NBYTES   = YCR_WIDTH / 8
)
(
    input   logic                           clk,
    // Port A
    input   logic                           rena,
    input   logic [$clog2(YCR_SIZE)-1:2]   addra,
    output  logic [YCR_WIDTH-1:0]          qa,
    // Port B
    input   logic                           renb,
    input   logic                           wenb,
    input   logic [YCR_NBYTES-1:0]         webb,
    input   logic [$clog2(YCR_SIZE)-1:2]   addrb,
    input   logic [YCR_WIDTH-1:0]          datab,
    output  logic [YCR_WIDTH-1:0]          qb
);

`ifdef YCR_TRGT_FPGA_INTEL
//-------------------------------------------------------------------------------
// Local signal declaration
//-------------------------------------------------------------------------------
 `ifdef YCR_TRGT_FPGA_INTEL_MAX10
(* ramstyle = "M9K" *)    logic [YCR_NBYTES-1:0][7:0]  memory_array  [0:(YCR_SIZE/YCR_NBYTES)-1];
 `elsif YCR_TRGT_FPGA_INTEL_ARRIAV
(* ramstyle = "M10K" *)   logic [YCR_NBYTES-1:0][7:0]  memory_array  [0:(YCR_SIZE/YCR_NBYTES)-1];
 `endif
logic [3:0] wenbb;
//-------------------------------------------------------------------------------
// Port B memory behavioral description
//-------------------------------------------------------------------------------
assign wenbb = {4{wenb}} & webb;
always_ff @(posedge clk) begin
    if (wenb) begin
        if (wenbb[0]) begin
            memory_array[addrb][0] <= datab[0+:8];
        end
        if (wenbb[1]) begin
            memory_array[addrb][1] <= datab[8+:8];
        end
        if (wenbb[2]) begin
            memory_array[addrb][2] <= datab[16+:8];
        end
        if (wenbb[3]) begin
            memory_array[addrb][3] <= datab[24+:8];
        end
    end
    qb <= memory_array[addrb];
end
//-------------------------------------------------------------------------------
// Port A memory behavioral description
//-------------------------------------------------------------------------------
always_ff @(posedge clk) begin
    qa <= memory_array[addra];
end

`else // YCR_TRGT_FPGA_INTEL

// CASE: OTHERS - YCR_TRGT_FPGA_XILINX, SIMULATION, ASIC etc

localparam int unsigned RAM_SIZE_WORDS = YCR_SIZE/YCR_NBYTES;

//-------------------------------------------------------------------------------
// Local signal declaration
//-------------------------------------------------------------------------------
 `ifdef YCR_TRGT_FPGA_XILINX
(* ram_style = "block" *)  logic  [YCR_WIDTH-1:0]  ram_block  [RAM_SIZE_WORDS-1:0];
 `else  // ASIC or SIMULATION
logic  [YCR_WIDTH-1:0]  ram_block  [RAM_SIZE_WORDS-1:0];
 `endif
//-------------------------------------------------------------------------------
// Port A memory behavioral description
//-------------------------------------------------------------------------------
always_ff @(posedge clk) begin
    if (rena) begin
        qa <= ram_block[addra];
    end
end

//-------------------------------------------------------------------------------
// Port B memory behavioral description
//-------------------------------------------------------------------------------
always_ff @(posedge clk) begin
    if (wenb) begin
        for (int i=0; i<YCR_NBYTES; i++) begin
            if (webb[i]) begin
                ram_block[addrb][i*8 +: 8] <= datab[i*8 +: 8];
            end
        end
    end
    if (renb) begin
        qb <= ram_block[addrb];
    end
end

`endif // YCR_TRGT_FPGA_INTEL

endmodule : ycr_dp_memory

`endif // YCR_TCM_EN
