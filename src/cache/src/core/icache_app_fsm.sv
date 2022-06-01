
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
///////////////////////////////////////////////////////////////////
////                                                              
////  instruction application side fsm
////                                                              
////  This file is part of the riscduino cores project            
////  https://github.com/dineshannayya/riscduino.git              
////  
////  Description :
////      This fsm manages all the cache refill and Prefill operation
////      Prefill - During power up, with prefill command, complete
////                2KB Cache memory will be refreshed with applicaton
////                memory and corresponding tag memory is updated
////      refill -  With refill request only one cache line will be
////                refreshed
////                                                              
////  To Do:                                                      
////    nothing
////                                                              
////  Author(s):                                                  
////      - Dinesh Annayya, dinesha@opencores.org                 
////                                                              
////  Revision :                                                  
////    0.1 - 19th Jan 2022, Dinesh A                             
////           Working initial version
////
//// ******************************************************************************************************

`include "ycr_cache_defs.svh"

module icache_app_fsm  #(
	 parameter WB_AW      = 32,
	 parameter WB_DW      = 32,
	 parameter TAG_MEM_WD = 22,
	 parameter TAG_MEM_DP = 16,
         parameter CACHELINES = 16, // 16 Cache Line
         parameter CACHESIZE  = 32 // Each cacheline has  32 Word

        ) (
	input logic			          mclk,	  //Clock input 
	input logic			          rst_n,	  //Active Low Asynchronous Reset Signal Input

	// Wishbone CPU I/F
        input logic   [WB_AW-1:0]                 cpu_addr,     // address

        output logic   [WB_DW-1:0]                wb_cpu_dat_o, // data input
        output logic                              wb_cpu_ack_o, // acknowlegement

	// Wishbone Application I/F
        output logic                              wb_app_stb_o            , // strobe/request
        output logic   [WB_AW-1:0]                wb_app_adr_o            , // address
        output logic                              wb_app_we_o             , // write
        output logic   [WB_DW-1:0]                wb_app_dat_o            , // data output
        output logic   [3:0]                      wb_app_sel_o            , // byte enable
        output logic   [9:0]                      wb_app_bl_o             , // Burst Length

        input logic   [WB_DW-1:0]                 wb_app_dat_i            , // data input
        input logic                               wb_app_ack_i            , // acknowlegement
        input logic                               wb_app_lack_i           , // last acknowlegement

        input  logic [$clog2(TAG_MEM_DP)-1:0]     tag_cur_loc             , // Tag Memory Write Current Location
        output logic 	                          tag_wr                  , // Tag Write Indication
        output logic 	                          tag_uwr                 , // Tag Update
        output logic [$clog2(TAG_MEM_DP)-1:0]	  tag_uptr                , // Tag Memory Write Update Location
        output type_icache_tag_mem_s 	          tag_wdata               , 
	
	// CACHE SRAM Memory I/F
        output logic                              cache_mem_clk0           , // CLK
        output logic                              cache_mem_csb0           , // CS#
        output logic                              cache_mem_web0           , // WE#
        output logic   [8:0]                      cache_mem_addr0          , // Address
        output logic   [3:0]                      cache_mem_wmask0         , // WMASK#
        output logic   [31:0]                     cache_mem_din0           , // Write Data

        input  logic                              cache_refill_req         ,
        input  logic                              cache_prefill_req        ,
	output logic                              cache_busy               


     );
// State Machine Parameters

localparam	IDLE		         = 2'd0,	//Please read Description for explanation of States and their operation
		CACHE_REFILL_ACTION	 = 2'd1,
		CACHE_PREFILL_ACTION     = 2'd2,
		DONE                     = 2'd3;


logic [$clog2(TAG_MEM_DP)-1:0]    cache_mem_offset         ; // Cache Memory Offset
logic [$clog2(CACHESIZE)-1:0]     cache_mem_ptr            ; // Cache Memory Pointer

logic [1:0]                       state                    ;


assign   cache_mem_clk0   = mclk;

// in icache, there will not be no write back data
assign wb_app_dat_o  = 'h0;

always@(posedge mclk or negedge rst_n)
begin
   if(!rst_n)
   begin
      wb_cpu_dat_o      <= '0;
      wb_cpu_ack_o      <= 1'b0;

      wb_app_stb_o      <= '0;
      wb_app_we_o       <= '0;
      wb_app_adr_o      <= '0;
      wb_app_sel_o      <= '0;
      wb_app_bl_o       <= '0;

      cache_mem_csb0    <= 1'b1;
      cache_mem_web0    <= 1'b1; 
      cache_mem_wmask0  <= '0;
      cache_mem_addr0   <= '0;
      cache_mem_din0    <= '0;

      cache_mem_offset  <= '0;
      cache_mem_ptr     <= '0;

      tag_wr            <= 1'b0;
      tag_uwr           <= 1'b0;
      tag_uptr          <= '0;
      tag_wdata         <= '0;

      cache_busy        <= '0;

      state             <= IDLE;

   end else begin
      case(state)
       // Request for Cache fetch from application memory
       IDLE: begin
	  tag_wr                <= 1'b0;
	  wb_cpu_ack_o          <= 1'b0;
          if(cache_refill_req) begin
              cache_busy        <= 1'b1;
	      wb_app_stb_o      <= 1'b1;
	      wb_app_we_o       <= 1'b0;
	      wb_app_adr_o      <= {cpu_addr[31:7],5'b0,2'b0};
	      wb_app_sel_o      <= 4'b1111;
	      wb_app_bl_o       <= 32;	
              cache_mem_ptr     <= '0;
              // Invalidated current Tag Location
	      tag_uwr           <= 1'b1;
              tag_uptr          <= tag_cur_loc;
	      cache_mem_offset  <= tag_cur_loc;
	      tag_wdata         <= '0; // Invalidate Current Tag Location

	      state             <= CACHE_REFILL_ACTION;
          end else if(cache_prefill_req) begin
              cache_busy        <= 1'b1;
	      wb_app_stb_o      <= 1'b1;
	      wb_app_we_o       <= 1'b0;
	      wb_app_adr_o      <= {21'h0,4'b0,5'b0,2'b0};
	      wb_app_sel_o      <= 4'b1111;
	      wb_app_bl_o       <= 10'h200; // 512;	
              cache_mem_ptr     <= '0;
              cache_mem_offset  <= '0;

	      state             <= CACHE_PREFILL_ACTION;
          end else begin
              cache_busy <= 1'b0;
          end
       end

       // CACHE Refill action based on application ack
       // Based on ack increment for ptr, assumed that
       // application only send 32 ack
       CACHE_REFILL_ACTION: begin
	  tag_uwr       <= 1'b0;
          if(wb_app_ack_i) begin
	     cache_mem_csb0    <= 1'b0;
	     cache_mem_web0    <= 1'b0;
	     cache_mem_wmask0  <= 4'b1111;
	     cache_mem_addr0   <= {cache_mem_offset,cache_mem_ptr};
	     cache_mem_din0    <= wb_app_dat_i;
	     cache_mem_ptr     <= cache_mem_ptr+1;
	  end else begin
	     cache_mem_csb0    <= 1'b1;
	     cache_mem_web0    <= 1'b1;
	  end
	  // Check the Cache Refill Read Back address Matches with CPU
	  // Address request
	  if(wb_app_ack_i) begin 
	     if(cache_mem_ptr == cpu_addr[6:2]) begin
		wb_cpu_ack_o   <= 1'b1;
		//As the current cpu request is read 
		// then send read data to cpu and cache mem
		    wb_cpu_dat_o   <= wb_app_dat_i;
	      end else begin
                  wb_cpu_ack_o   <= 1'b0;
	       end
            end else begin
                wb_cpu_ack_o   <= 1'b0;
            end

	  // Update the Tag Memory
	  if(wb_app_lack_i) begin
	      wb_app_stb_o    <= 1'b0;
	      // Over-write first content
	      tag_wr          <= 1'b1;
	      tag_wdata  <= {1'b1,cpu_addr[26:7]};
	     state      <= DONE;
	  end
       end

       // CACHE Prefill action based on application ack
       // Based on ack increment for ptr, 
       // Once 32 ptr over increment cache_mem_loc
//     // assumed that application only send 32 * 16 ack
       CACHE_PREFILL_ACTION: begin
          if(wb_app_ack_i) begin
	     cache_mem_csb0    <= 1'b0;
	     cache_mem_web0    <= 1'b0;
	     cache_mem_wmask0  <= 4'b1111;
	     cache_mem_addr0   <= {cache_mem_offset,cache_mem_ptr};
	     cache_mem_din0    <= wb_app_dat_i;
	     cache_mem_ptr     <= cache_mem_ptr+1;
             if(cache_mem_ptr == 5'h1F) begin
                cache_mem_offset <= cache_mem_offset +1;
	        tag_wr           <= 1'b1;
	        tag_wdata  <= {1'b1,16'h0,cache_mem_offset[3:0]};
	     end else begin
	        tag_wr           <= 1'b0;
	     end
	  end else begin
	     tag_wr            <= 1'b0;
	     cache_mem_csb0    <= 1'b1;
	     cache_mem_web0    <= 1'b1;
	  end

	  // Update the Tag Memory
	  if(wb_app_lack_i) begin
	      wb_app_stb_o    <= 1'b0;
	     state      <= DONE;
	  end
       end


      // Additional state to make Sure that all the content are
      // update into tag and cache memory
      DONE: begin
          wb_cpu_ack_o      <= 1'b0;
	  tag_wr            <= 1'b0;
	  cache_mem_csb0    <= 1'b1;
	  cache_mem_web0    <= 1'b1;
          cache_busy        <= 1'b0;
	  state             <= IDLE;
      end
      endcase
   end
end

endmodule
