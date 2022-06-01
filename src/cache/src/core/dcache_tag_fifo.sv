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
/*********************************************************************
                                                              
  This file is part of the 
  https://github.com/dineshannayya/cache.git 
                                                              
  Description: TAG FIFO 
  Tag Memory Will be once written to all the location, 
  it does only update function and there is no decrement
  function, only flush will clear the fifo ptr and cnt

  Parameters:
      WD : Width (integer)
      DP : Depth (integer, power of 2, 4 to 256)
                                                              
  To Do:                                                      
    nothing                                                   
                                                              
  Author(s):  Dinesh Annayya, dinesha@opencores.org                 
                                                             
 Copyright (C) 2000 Authors and OPENCORES.ORG                
                                                             
 This source file may be used and distributed without         
 restriction provided that this copyright statement is not    
 removed from the file and that any derivative work contains  
 the original copyright notice and the associated disclaimer. 
                                                              
 This source file is free software; you can redistribute it   
 and/or modify it under the terms of the GNU Lesser General   
 Public License as published by the Free Software Foundation; 
 either version 2.1 of the License, or (at your option) any   
later version.                                               
                                                              
 This source is distributed in the hope that it will be       
 useful, but WITHOUT ANY WARRANTY; without even the implied   
 warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      
 PURPOSE.  See the GNU Lesser General Public License for more 
 details.                                                     
                                                              
 You should have received a copy of the GNU Lesser General    
 Public License along with this source; if not, download it   
 from http://www.opencores.org/lgpl.shtml                     
                                                              
*******************************************************************/

// CPU pipeline monitors

`include "ycr_cache_defs.svh"

module dcache_tag_fifo #(parameter WD=8, parameter DP=4) ( 
	input logic                       clk,
	input logic                       reset_n,
	input logic                       flush,        // FIFO flush

        input logic 	                  tag_wr,       // Tag Write Indication
        input logic 	                  tag_uwr,   // Tag Update
        input logic [$clog2(DP)-1:0]	  tag_uptr,     // Tag Memory Write Update Location
	input type_dcache_tag_mem_s 	  tag_wdata,
	output logic [$clog2(DP)-1:0]     tag_wptr,     // Tag Memory Write Current Location
	output logic                      tag_hdirty,   // Hit location Dirty indication


	input logic  [`TAG_XLEN-1:0]      tag_cmp_data,   // Tag Compare Data
        output logic [DP-1:0]             tag_hit,       // Tag Compare Hit 
	output logic [$clog2(DP)-1:0]     tag_hindex,    // Tag Hit Index
	output logic [`TAG_XLEN-1:0]      tag_ctag,      // Current location Tag
	output logic                      tag_cdirty,    // Current location Dirty indication
	output logic                      tag_cval,      // Current location Valid


	output logic             	  full,          // FIFO full
	output logic             	  empty          // FIFO Empty
	  );


   parameter AW = $clog2(DP);
   
   logic [$clog2(DP)-1:0]     tag_wcnt;
   logic [WD-1 : 0]           tag_mem[DP-1 : 0];

   //// synopsys translate_off
   //initial begin
   //   if (AW == 0) begin
   //      $display ("%m : ERROR!!! Fifo depth %d not in range 4 to 256", DP);
   //      $finish;
   //   end // if (AW == 0)
   //end // initial begin

   //// synopsys translate_on
   ////
   ////


   // Find any valid location matches with tag
   generate
   genvar tcnt;
   for (tcnt = 0; $unsigned(tcnt) < DP; tcnt=tcnt+1) begin : g_tag_check
       logic [WD-1:0] mem_data;
       assign mem_data = tag_mem[tcnt];
       //assign tag_hit[tcnt] = mem_data.valid && (mem_data.tag == tag_cmp_data); - Yosys fix
       assign tag_hit[tcnt] = mem_data[WD-1] && (mem_data[WD-3:0] == tag_cmp_data);
   end
   endgenerate

   // Get the tag Hit index
   integer index;
   always_comb
   begin
      tag_hindex = 0;
      for(index=0;index  < DP;index=index+1)
      begin
         if(tag_hit[index]==1)
            tag_hindex=index;
      end
   end

// Dirty bit in Tag hit location
type_dcache_tag_mem_s  tag_hrdata;   // Tag Hit Read Data
assign tag_hrdata =  tag_mem[tag_hindex];
assign tag_hdirty = tag_hrdata.dirty;  

// Dirty bit in Currently over-written tag locaton
type_dcache_tag_mem_s  tag_crdata;   // Tag Hit Read Data
assign tag_crdata  = tag_mem[tag_wptr];
assign tag_cdirty = tag_crdata.dirty;  
assign tag_cval = tag_crdata.valid;  
assign tag_ctag = tag_crdata.tag;  



   // Hold the tag write ptr
   always @ (posedge clk or negedge reset_n) 
      if (reset_n == 1'b0) begin
         tag_wptr <= {AW{1'b0}} ;
      end
      else begin
	 if(flush)
            tag_wptr <= {AW{1'b0}} ;
         else if (tag_wr) begin
            tag_wptr <= tag_wptr + 1'b1 ;
         end
      end


   // Note: This FF does not have decrement function
   // Once all the location are Full, DP-1 Address will be
   // over-written
   always @ (posedge clk or negedge reset_n) 
      if (reset_n == 1'b0) begin
         full  <= 1'b0 ;
         empty <= 1'b1 ;
	 tag_wcnt <= '0;
      end
      else begin
	  if(flush) begin
              full  <= 1'b0 ;
              empty <= 1'b1 ;
	      tag_wcnt <= '0;
	  end else begin
	     if(tag_wr && !full) begin
	        tag_wcnt <= tag_wcnt + 1;
	        empty <= 1'b0;
	        if(tag_wcnt == (DP-1))
	           full <= 1'b1;
	     end
	  end
      end


   // TAG memory write and update operation
   integer i;
   always @ (posedge clk or negedge reset_n) 
      if (reset_n == 1'b0) begin
	 // Invalidate all location
	 for(i = 0; i < DP; i = i+1)
	     tag_mem[i] <= '0; 
      end else if (tag_wr) begin
	 tag_mem[tag_wptr] <= tag_wdata;
      end else if (tag_uwr) begin
	 tag_mem[tag_uptr] <= tag_wdata;
      end



//// synopsys translate_off
//   always @(posedge clk) begin
//      if (tag_wr && full) begin
//         $display("%m : Error! tag fifo overflow!");
//	 $finish;
//      end
//   end
//// synopsys translate_on
//---------------------------------------

endmodule


