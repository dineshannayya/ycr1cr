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
////  yifive request retiming module                                      ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr2c.git                          ////
////                                                                      ////
////  Description:                                                        ////
////     This is retiming fifo to break the timing path                   ////
////                                                                      ////
////  To Do:                                                              ////
////    nothing                                                           ////
////                                                                      ////
////  Author(s):                                                          ////
////      - Dinesh Annayya, dinesha@opencores.org                         ////
////                                                                      ////
////  Revision :                                                          ////
////     v0:    May 23, 2022, Dinesh A                                    ////
////             Initial version                                          ////
////                                                                      ////
//////////////////////////////////////////////////////////////////////////////
module ycr_req_retiming #(parameter FIFO_WIDTH = 50)
   (
    input   logic                          clk                 ,  // Core clock
    input   logic                          rst_n               ,
    // Instruction Memory Interface
    output   logic                         req_ack             , // IMEM request acknowledge
    input    logic                         req                 , // IMEM request
    input    logic  [FIFO_WIDTH-1:0]       wdata               , // IMEM command

    input    logic                         req_ack_int         , // IMEM request acknowledge
    output   logic                         req_int             , // IMEM request
    output   logic [FIFO_WIDTH-1:0]        rdata                 // IMEM command

    );


//--------------------------------------------------------------
// Fifo is added to break the timing path 
// -------------------------------------------------------------
wire                         wen;
wire                         ren;
wire                         full;
wire                         empty;

// WRITE PATH
assign  wen      = (req & !full);
assign  req_ack  = wen;


// READ PATH
assign  ren     = req_ack_int & !empty;
assign  req_int = !empty;

sync_fifo2 #(.W(FIFO_WIDTH), .DP(2),.WR_FAST(1), .RD_FAST(1)) u_fifo
             (
	          .clk      (clk        ),
	          .reset_n  (rst_n      ),
		  .wr_en    (wen        ),
		  .wr_data  (wdata      ),
		  .full     (full       ),
                  .afull    (           ),                 
		  .empty    (empty      ),
                  .aempty   (           ),                
		  .rd_en    (ren        ),
		  .rd_data  (rdata      )
	         );


endmodule
