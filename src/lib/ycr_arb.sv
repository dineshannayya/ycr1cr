//////////////////////////////////////////////////////////////////////////////
// SPDX-FileCopyrightText: 2021 , Dinesh Annayya                          
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0
// SPDX-FileContributor: Created by Dinesh Annayya <dinesha@opencores.org>
//
//////////////////////////////////////////////////////////////////////
////                                                              ////
////  Arbitor                                                     ////
////                                                              ////
////  This file is part of the YIFive cores project               ////
////  https://github.com/dineshannayya/ycr.git                   ////
////  http://www.opencores.org/cores/yifive/                      ////
////                                                              ////
////  Description                                                 ////
////      This block implement simple round robine request        ////
//        arbitor for core interface.                             ////
////                                                              ////
////  To Do:                                                      ////
////    nothing                                                   ////
////                                                              ////
////  Author(s):                                                  ////
////      - Dinesh Annayya, dinesha@opencores.org                 ////
////                                                              ////
////  Revision :                                                  ////
////    0.1 - 20 Jan 2022, Dinesh A                               ////
////         Initial Version                                      ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2000 Authors and OPENCORES.ORG                 ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE.  See the GNU Lesser General Public License for more ////
//// details.                                                     ////
////                                                              ////
//// You should have received a copy of the GNU Lesser General    ////
//// Public License along with this source; if not, download it   ////
//// from http://www.opencores.org/lgpl.shtml                     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////


module ycr_arb(
	input logic        clk, 
	input logic        rstn, 
	input logic [1:0]  req,  // Request
	input logic        ack,  // Ack
	output logic [1:0] gnt   // Grant
       );

///////////////////////////////////////////////////////////////////////
//
// Parameters
//


parameter       FSM_GRANT0 = 2'b00,
                FSM_GRANT1 = 2'b01,
                WAIT_ACK   = 2'b10;

parameter       GRANT0     = 2'b00;
parameter       GRANT1     = 2'b01;
parameter       GRANTX     = 2'b11;

///////////////////////////////////////////////////////////////////////
// Local Registers and Wires
//////////////////////////////////////////////////////////////////////

reg [1:0]	state, gstate, next_state,next_gstate;
reg [1:0]       gnt_int;

///////////////////////////////////////////////////////////////////////
//  Misc Logic 
//////////////////////////////////////////////////////////////////////


always@(posedge clk or negedge rstn)
    if(!rstn) begin
       state <= FSM_GRANT0;
       gstate<= FSM_GRANT0;
       gnt <= GRANTX;
    end else begin		
            gnt    <= gnt_int;
	    state  <= next_state;
	    gstate <= next_gstate;
    end

///////////////////////////////////////////////////////////////////////
//
// Next State Logic 
//   - implements round robin arbitration algorithm
//   - switches grant if current req is dropped or next is asserted
//   - parks at last grant
//////////////////////////////////////////////////////////////////////

always_comb
   begin
      gnt_int       = gnt;
      next_state    = state;	// Default Keep State
      next_gstate   = gstate;       
      case(state)		
	 FSM_GRANT0: begin
      	// if this req is dropped or next is asserted, check for other req's
	     if(req[0] ) begin
	     	gnt_int      = GRANT0;
	     	next_gstate  = FSM_GRANT1; // Next Priority Grant State
	     	next_state   = WAIT_ACK;
	     end else if(req[1]) begin
	     	gnt_int      = GRANT1;
	     	next_gstate  = FSM_GRANT0;  // Next Priority Grant State
	     	next_state   = WAIT_ACK;
	     end else begin
	     	gnt_int      = GRANTX;
	     end
      	end
	FSM_GRANT1: begin
      	// if this req is dropped or next is asserted, check for other req's
	     if(req[1] ) begin
	     	gnt_int      = GRANT1;
	     	next_gstate  = FSM_GRANT0;  // Next Priority Grant State
	     	next_state   = WAIT_ACK;
	     end else if(req[0]) begin
	     	gnt_int      = GRANT0;
	     	next_gstate  = FSM_GRANT1;  // Next Priority Grant State
	     	next_state   = WAIT_ACK;
	     end else begin
	     	gnt_int      = GRANTX;
	     end
      	end
	WAIT_ACK : begin
		if(ack) begin
	     	    gnt_int      = GRANTX;
	     	    next_state   = next_gstate;
		end
	end
      endcase
   end

endmodule 
