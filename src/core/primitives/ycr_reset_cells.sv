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
////  yifive Cells for reset handling                                     ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     Cells for reset handling                                         ////
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

module ycr_reset_buf_cell (
    input   logic           rst_n,
    input   logic           clk,
    input   logic           test_mode,
    input   logic           test_rst_n,
    input   logic           reset_n_in,
    output  logic           reset_n_out,
    output  logic           reset_n_status
);

logic       reset_n_ff;
logic       reset_n_status_ff;
logic       rst_n_mux;

assign rst_n_mux = (test_mode == 1'b1) ? test_rst_n : rst_n;

always_ff @(negedge rst_n_mux, posedge clk) begin
    if (~rst_n_mux) begin
        reset_n_ff <= 1'b0;
    end else begin
        reset_n_ff <= reset_n_in;
    end
end

assign reset_n_out = (test_mode == 1'b1) ? test_rst_n : reset_n_ff;

always_ff @(negedge rst_n_mux, posedge clk) begin
    if (~rst_n_mux) begin
        reset_n_status_ff <= 1'b0;
    end else begin
        reset_n_status_ff <= reset_n_in;
    end
end
assign reset_n_status = reset_n_status_ff;

endmodule : ycr_reset_buf_cell

//--------------------------------------------------------------------
// Reset CDC Synchronization Cell
//--------------------------------------------------------------------
module ycr_reset_sync_cell #(
    parameter int unsigned STAGES_AMOUNT = 2
) (
    input   logic           rst_n,
    input   logic           clk,
    input   logic           test_rst_n,
    input   logic           test_mode,
    input   logic           rst_n_in,
    output  logic           rst_n_out
);

logic [STAGES_AMOUNT-1:0]   rst_n_dff;
logic                       local_rst_n_in;

assign local_rst_n_in = (test_mode == 1'b1) ? test_rst_n : rst_n;

generate

if (STAGES_AMOUNT == 1)

begin : gen_reset_sync_cell_single
    always_ff @(negedge local_rst_n_in, posedge clk) begin
        if (~local_rst_n_in) begin
            rst_n_dff <= 1'b0;
        end else begin
            rst_n_dff <= rst_n_in;
        end
    end
end : gen_reset_sync_cell_single

else // STAGES_AMOUNT > 1

begin : gen_reset_sync_cell_multi
    always_ff @(negedge local_rst_n_in, posedge clk)
    begin
        if (~local_rst_n_in) begin
            rst_n_dff <= '0;
        end else begin
            rst_n_dff <= {rst_n_dff[STAGES_AMOUNT-2:0], rst_n_in};
        end
    end
end : gen_reset_sync_cell_multi

endgenerate

assign rst_n_out = (test_mode == 1'b1) ? test_rst_n : rst_n_dff[STAGES_AMOUNT-1];

endmodule : ycr_reset_sync_cell

//--------------------------------------------------------------------
// Data CDC/RDC Synchronization Cell
//--------------------------------------------------------------------
module ycr_data_sync_cell #(
    parameter int unsigned  STAGES_AMOUNT = 1
) (
    input   logic           rst_n,
    input   logic           clk,
    input   logic           data_in,
    output  logic           data_out
);

logic [STAGES_AMOUNT-1:0] data_dff;

generate

if (STAGES_AMOUNT == 1)

begin : gen_data_sync_cell_single
    always_ff @(negedge rst_n, posedge clk)
    begin
        if (~rst_n) begin
            data_dff <= 1'b0;
        end else begin
            data_dff <= data_in;
        end
    end
end : gen_data_sync_cell_single

else // STAGES_AMOUNT > 1

begin : gen_data_sync_cell_multi
    always_ff @(negedge rst_n, posedge clk)
    begin
        if (~rst_n) begin
            data_dff <= '0;
        end else begin
            data_dff <= {data_dff[STAGES_AMOUNT-2:0], data_in};
        end
    end
end : gen_data_sync_cell_multi

endgenerate

assign data_out = data_dff[STAGES_AMOUNT-1];

endmodule : ycr_data_sync_cell

//--------------------------------------------------------------------
// Reset / RDC Qualifyer Adapter Cell
//   (Reset Generation Cell w/ RDC Qualifyer Adaptation circuitry)
//--------------------------------------------------------------------
// Total stages amount =
//    1 Front Sync stage \
//  + 1 (delay introduced by the reset output buffer register)
//--------------------------------------------------------------------
module ycr_reset_qlfy_adapter_cell_sync (
    input   logic           rst_n,
    input   logic           clk,
    input   logic           test_rst_n,
    input   logic           test_mode,
    input   logic           reset_n_in_sync,
    output  logic           reset_n_out_qlfy,
    output  logic           reset_n_out,
    output  logic           reset_n_status
);

logic rst_n_mux;
logic reset_n_front_ff;

// Front sync stage
assign rst_n_mux = (test_mode == 1'b1) ? test_rst_n : rst_n;

always_ff @(negedge rst_n_mux, posedge clk) begin
    if (~rst_n_mux) begin
        reset_n_front_ff    <= 1'b0;
    end else begin
        reset_n_front_ff    <= reset_n_in_sync;
    end
end

//   Sync reset output for all reset qualifier chains targeting this reset domain
// (for reset-domain-crossings with the given reset domain as a destination).
assign reset_n_out_qlfy = reset_n_front_ff;

// Reset output buffer
ycr_reset_buf_cell
i_reset_output_buf (
    .rst_n              (rst_n),
    .clk                (clk),
    .test_mode          (test_mode),
    .test_rst_n         (test_rst_n),
    .reset_n_in         (reset_n_front_ff),
    .reset_n_out        (reset_n_out),
    .reset_n_status     (reset_n_status)
);

endmodule : ycr_reset_qlfy_adapter_cell_sync

module ycr_reset_and2_cell (
    input   logic [1:0]     rst_n_in,
    input   logic           test_rst_n,
    input   logic           test_mode,
    output  logic           rst_n_out
);

assign rst_n_out = (test_mode == 1'b1) ? test_rst_n : (&rst_n_in);

endmodule : ycr_reset_and2_cell


module ycr_reset_and3_cell (
    input   logic [2:0]     rst_n_in,
    input   logic           test_rst_n,
    input   logic           test_mode,
    output  logic           rst_n_out
);

assign rst_n_out = (test_mode == 1'b1) ? test_rst_n : (&rst_n_in);

endmodule : ycr_reset_and3_cell


module ycr_reset_mux2_cell (
    input   logic [1:0]     rst_n_in,
    input   logic           select,
    input   logic           test_rst_n,
    input   logic           test_mode,
    output  logic           rst_n_out
);

assign rst_n_out = (test_mode == 1'b1) ? test_rst_n : rst_n_in[select];

endmodule : ycr_reset_mux2_cell


// Reset Sync Logic

module ycr_reset_sync   (
	      scan_mode  ,
          dclk       , // Destination clock domain
	      arst_n     , // active low async reset
          srst_n 
          );

parameter WIDTH = 1;

input    scan_mode  ; // test mode
input    dclk       ; // Destination clock
input    arst_n     ; // Async Reset
output   srst_n     ; // Sync Reset w.r.t dclk


reg      in_data_s  ; // One   Cycle sync 
reg      in_data_2s ; // two   Cycle sync 


always @(negedge arst_n  or posedge dclk)
begin
   if(arst_n == 1'b0)
   begin
      in_data_s  <= 1'b0;
      in_data_2s <= 1'b0;
   end
   else
   begin
      in_data_s  <= 1'b1;
      in_data_2s <= in_data_s;
   end
end
//assign srst_n =  (scan_mode) ? arst_n : in_data_2s;
ctech_mux2x1 u_buf  (.A0(in_data_2s), .A1(arst_n), .S(scan_mode), .X(srst_n));

endmodule

