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
////  yifive TAPC shift register                                          ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     TAPC shift register                                              ////
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
////                                                                      ////
//////////////////////////////////////////////////////////////////////////////

`include "ycr_arch_description.svh"

`ifdef YCR_DBG_EN
module ycr_tapc_shift_reg #(
    parameter   int unsigned            YCR_WIDTH       = 8,   // Register width, bits
    parameter   logic [YCR_WIDTH-1:0]  YCR_RESET_VALUE = '0   // Register's value after reset
) (
    input  logic                    clk,            // Clock
    input  logic                    rst_n,          // Async reset
    input  logic                    rst_n_sync,     // Sync reset
                                                    // TAP FSM's control signals:
    input  logic                    fsm_dr_select,  //   - for this DR selection (operation enabling);
    input  logic                    fsm_dr_capture, //   - to capture parallel input's data into shift register;
    input  logic                    fsm_dr_shift,   //   - to enable data shifting;
                                                    // Inputs:
    input  logic                    din_serial,     //   - serial (shift_reg[msb/YCR_WIDTH]);
    input  logic [YCR_WIDTH-1:0]   din_parallel,   //   - parallel (shift register's input).
                                                    // Outputs:
    output logic                    dout_serial,    //   - serial (shift_reg[0]);
    output logic [YCR_WIDTH-1:0]   dout_parallel   //   - parallel (shift register's output).
);

//-------------------------------------------------------------------------------
// Local signals declaration
//-------------------------------------------------------------------------------
logic [YCR_WIDTH-1:0]   shift_reg;

//-------------------------------------------------------------------------------
// Shift register
//-------------------------------------------------------------------------------
generate
    if (YCR_WIDTH > 1)
    begin : dr_shift_reg

        always_ff @(posedge clk, negedge rst_n)
        begin
            if (~rst_n) begin
                shift_reg <= YCR_RESET_VALUE;
            end
            else if (~rst_n_sync) begin
                shift_reg <= YCR_RESET_VALUE;
            end
            else if (fsm_dr_select & fsm_dr_capture) begin
                shift_reg <= din_parallel;
            end
            else if (fsm_dr_select & fsm_dr_shift) begin
                shift_reg <= {din_serial, shift_reg[YCR_WIDTH-1:1]};
            end
        end

    end
    else begin : dr_shift_reg

        always_ff @(posedge clk, negedge rst_n)
        begin
            if (~rst_n) begin
                shift_reg <= YCR_RESET_VALUE;
            end
            else if (~rst_n_sync) begin
                shift_reg <= YCR_RESET_VALUE;
            end
            else if (fsm_dr_select & fsm_dr_capture) begin
                shift_reg <= din_parallel;
            end
            else if (fsm_dr_select & fsm_dr_shift) begin
                shift_reg <= din_serial;
            end
        end

    end
endgenerate

//-------------------------------------------------------------------------------
// Parallel output
//-------------------------------------------------------------------------------
assign dout_parallel = shift_reg;

//-------------------------------------------------------------------------------
// Serial output
//-------------------------------------------------------------------------------
assign dout_serial = shift_reg[0];

`ifdef YCR_TRGT_SIMULATION
//-------------------------------------------------------------------------------
// Assertion
//-------------------------------------------------------------------------------

// X checks
YCR_SVA_TAPC_SHIFTREG_XCHECK : assert property (
    @(negedge clk) disable iff (~rst_n)
    !$isunknown({
        rst_n_sync,
        fsm_dr_select,
        fsm_dr_capture,
        fsm_dr_shift,
        din_serial,
        din_parallel
    })
) else begin
    $error("TAPC Shift Reg error: unknown values");
end

`endif // YCR_TRGT_SIMULATION

endmodule : ycr_tapc_shift_reg

`endif // YCR_DBG_EN
