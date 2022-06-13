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
////  data cache top                                                   
////                                                              
////  This file is part of the riscduino cores project            
////  https://github.com/dineshannayya/riscduino.git              
////  
////                                                              
////  Description                                                 
////
////    This a 16-way set associative cache module. 
//// 	The cache can be used between a CPU Data Memory and Main Memory or
//// 	Secondary Cache. 
//// 	The cache uses following policies:
//// 	1. Module is configured to be used in Look-through Architecture
//// 	2. Cache is designed with 'write-back' policy during CPU writes, so data
//// 	   if ditry then will be written to main memory during  eviction 
////       else data in cache will be updated with setting dirty bit high.
//// 	3. The module implements Fist In First Out (FIFO) policy for eviction of valid or dirty blocks. 
////       i.e if the cache fill order is 0,1,2,3,4,5,5,6,7,8 ...  During the
////       cache refill will be over-written in same order 0,1,2,3 ...
////
//// 	   The module inferres 2KB cache Memory and 16 Location TAG Memory
//// 	   The TAG RAM stores tag data as well as Valid, Dirty Bits.
////
//// 	   The Most significant bit is Valid bit in tag data
//// 	   block, next is dirty bit, andall other are TAG data bits.
//// 		----------------------------------------------------------------------
//// 		|Valid bit | Dirty bit |          Tag Data
//// 		----------------------------------------------------------------------
////
//// 	States of Finite State Machine implemented for Cache
//// 	Controller and its basic explanation:
////
//// 	1. IDLE: This is a reset/default state of FSM. It waits for
//// 	         read or write command from CPU and when receives any,
//// 	         it latches the address and move to TAG_COMPARE state
////
//// 	2. TAG_COMPARE: 
////             This is a decision state for tag hit or miss in cache. 
////             If hit, 
////                  A1. If the current cpu cycle is write,
////                      A2. Update tag memory with dirty bit 
////                      B2. Update cache memory based on datavalid 
////                      C2. Move to IDLE
////                  B1. If the current cpu cycle is Read
////                      A2. Read the cache memory offset location.
////                      B2. Move to IDLE
////             If No hit,
////                  A1.  It checks if there free tag memory, 
////                      A2. If there is free space it move to cache refill
////                        state.
////                  B1. If there is no free tag memory, then it check the
////                      over-writting tag location's dirty bit set or not
////                     A2. If the over-writting tag location dirty bit is
////                         not set, then move to cache refill state 
////                     B2. If the current tag location dirty bit set, then 
////                         move to Cache Write back state.
//// 
////     3. CACHE_WRITE_BACK:
////             Write back the current over-writing cache location
////             data to main memory in busrt mode.
////             As RAM read data access is two cycle delay, additional
////             Pipeline stages are added to support burst ack.
////             Once all the location are written out, move to cache
////             refill state.
////     4. CACHE_REFILL:
//// 		In this state, data will be filled from Main memory
////            to cache memory. 
////                  A1. If current cpu access is write, corresponding cache memory 
////                      location will be over-written based on byte enable.
////                  B1. If current cpu access is read, cache memory will be
////                      loaded with main memory data and once cpu request
////                      address is available data will be fed back to cpu
////                       with ack 
//// Assumptions:
////            1. Wishbone Support Burst Write and Read access. 
////               To support is additional two signal added to wishbone i/f
////                  *_bl  - 8 Bit - Indicate Burst Word, 1 Indicate 1 word
////                          FF - 255 word
////                  *_lack- Indicate last ack of the busrt ack
////                  *_ack - Ack will be asserted for completion of each
////                  valid access
//// Memory organization
////       TAG Memory:
////              A1. Each location hold  20 bit of [26:7] cpu address
////              A2. Each location also has Valid bit + Dirty bit
////              A3. Dirtly bit indicate cache memory is locally modified. need
////                  to write back data during cache location flush.
////              A4. There are 16 Tag location corresponds to 16 cache line
////       Cache Memory: 2KB SRAM or 512 Word SRAM
////             16 Cache Line * 32 Cache Word = 512 Word = 2048 Byte
////             Cache Address : <tag offset[3:0]> <cache ptr[4:0]> 
////
//// CPU address decoding:
////      [1:0]   -  32 Bit Word
////      [6:2]   -  32 Cache Word
////      [26:7]  -  Tag comparsion
////      [31:27] - Unused
////      
////      With [26:0] access, cache can address up to 128MB Memory Space.
////
////  Note: Skywater SRAM has two port
////     port-0: Support both Write and Read - This port used for cache write
////             back and Refill purpose
////     port-1: Support Read access only - This port used to read tag hit
////             cache location data
////  To Do:                                                      
////    nothing
////                                                              
////  Author(s):                                                  
////      - Dinesh Annayya, dinesha@opencores.org                 
////                                                              
////  Revision :                                                  
////    0.1 - 19th Jan 2022, Dinesh A                             
////           Working initial version
////    0.2 - 20th Jan 2022, Dinesh A                             
////          moved the user cpu  wishbone interface to custom cpu interface and
////          bug fix around buswidth
////    0.3 - 22 Jan 2022, Dinesh A
////          mem2wb & wb2mem conversion function added to handled cpu
////           unaligned access
////    0.3 - 22 Jan 2022, Dinesh A
////          dmem cache write back bug fixes
//// ******************************************************************************************************

`include "ycr_cache_defs.svh"

module dcache_top #(
	 parameter DMEM_BASE  = 5'b00001,  // DMEM Base Address
	 parameter WB_AW      = 32,
	 parameter WB_DW      = 32,
	 parameter TAG_MEM_WD = 22,
	 parameter TAG_MEM_DP = 16,
         parameter CACHELINES = 16, // 16 Cache Line
         parameter CACHESIZE  = 32 // Each cacheline has  32 Word
        ) (
	input logic			   mclk,	  //Clock input 
	input logic			   rst_n,	  //Active Low Asynchronous Reset Signal Input

	input logic                        cfg_pfet_dis,      // To disable Next Pre data Pre fetch, default = 0
	input logic                        cfg_force_flush,   // Flush all the content to memory with dirty
	input logic                        cfg_bypass_dcache, // dcache disabled

	output logic                       force_flush_done,

	//  CPU I/F
        input logic                        cpu_mem_req, // strobe/request
        input logic                        cpu_mem_cmd, // strobe/request
        input logic   [WB_AW-1:0]          cpu_mem_addr, // address
        input logic   [1:0]                cpu_mem_width, // address
        input logic   [WB_DW-1:0]          cpu_mem_wdata, // data input

	output logic                       cpu_mem_req_ack, // Ack for Strob request accepted
        output logic   [WB_DW-1:0]         cpu_mem_rdata, // data input
        output logic  [1:0]                cpu_mem_resp, // acknowlegement


	// Wishbone Application I/F
        output logic                       wb_app_stb_o, // strobe/request
        output logic   [WB_AW-1:0]         wb_app_adr_o, // address
        output logic                       wb_app_we_o,  // write
        output logic   [WB_DW-1:0]         wb_app_dat_o, // data output
        output logic   [3:0]               wb_app_sel_o, // byte enable
        output logic   [9:0]               wb_app_bl_o,  // Burst Length

        input logic   [WB_DW-1:0]          wb_app_dat_i, // data input
        input logic                        wb_app_ack_i, // acknowlegement
        input logic                        wb_app_lack_i,// last acknowlegement
        input logic                        wb_app_err_i, // error

        // CACHE SRAM Memory I/F
        output logic                       cache_mem_clk0           , // CLK
        output logic                       cache_mem_csb0           , // CS#
        output logic                       cache_mem_web0           , // WE#
        output logic   [8:0]               cache_mem_addr0          , // Address
        output logic   [3:0]               cache_mem_wmask0         , // WMASK#
        output logic   [31:0]              cache_mem_din0           , // Write Data
        input  logic   [31:0]              cache_mem_dout0          , // Read Data
        
        // SRAM-0 PORT-1, IMEM I/F
        output logic                       cache_mem_clk1           , // CLK
        output logic                       cache_mem_csb1           , // CS#
        output logic  [8:0]                cache_mem_addr1          , // Address
        input  logic  [31:0]               cache_mem_dout1           // Read Data

);

// Parameters

// Total cache memory = 16 * 32 * 4 = 2048 (2KB)

// State Machine Parameters

localparam	IDLE		         = 4'h0,	//Please read Description for explanation of States and their operation
		TAG_COMPARE	         = 4'h1,
		CACHE_RDATA_FETCH1       = 4'h2,
		CACHE_RDATA_FETCH2       = 4'h3,
		CACHE_RDATA_FETCH3       = 4'h4,
		PREFETCH_START           = 4'h5,
		PREFETCH_WAIT            = 4'h6,
		CACHE_REFILL_REQ         = 4'h7,
		CACHE_REFILL_ACTION	 = 4'h8,
		CACHE_WRITE_BACK         = 4'h9,
		CACHE_WRITE_BACK_ACTION1 = 4'hA,
		CACHE_WRITE_BACK_ACTION2 = 4'hB,
	        CACHE_PREFILL_REQ        = 4'hC,
	        CACHE_PREFILL_ACTION     = 4'hD,
	        CACHE_FLUSH_ACTION       = 4'hE,
	        CACHE_FLUSH_ACTION1      = 4'hF;

//// CACHE SRAM Memory I/F
//logic                             cache_mem_clk0           ; // CLK
//logic                             cache_mem_csb0           ; // CS#
//logic                             cache_mem_web0           ; // WE#
//logic   [8:0]                     cache_mem_addr0          ; // Address
//logic   [3:0]                     cache_mem_wmask0         ; // WMASK#
//logic   [31:0]                    cache_mem_din0           ; // Write Data
//logic   [31:0]                    cache_mem_dout0          ; // Read Data
//
//// SRAM-0 PORT-1, IMEM I/F
//logic                             cache_mem_clk1           ; // CLK
//logic                             cache_mem_csb1           ; // CS#
//logic  [8:0]                      cache_mem_addr1          ; // Address
//logic  [31:0]                     cache_mem_dout1          ; // Read Data

// Tag Memory Wire decleration
logic 	                          tag_wr                   ; // Tag Write Indication
logic 	                          tag_uwr                  ; // Tag Update
logic [$clog2(TAG_MEM_DP)-1:0]	  tag_uptr                 ; // Tag Memory Write Update Location
type_dcache_tag_mem_s 	          tag_wdata                ; 
logic [$clog2(TAG_MEM_DP)-1:0]    tag_cur_loc              ; // Tag Memory Write Current Location
logic                             tag_hdirty               ; // Hit location Dirty indication
logic                             tag_full                 ;


logic  [`TAG_XLEN-1:0]            tag_cmp_data             ; // Tag Compare Data
logic [TAG_MEM_DP-1:0]            tag_hit                  ; // Tag Compare Hit 
logic [$clog2(TAG_MEM_DP)-1:0]    tag_hindex               ; // Tag Hit Index
logic                             tag_cdirty               ; // Current location Dirty indication
logic                             tag_cval                 ;
logic  [`TAG_XLEN-1:0]            tag_ctag                 ; // Tag Compare Data
logic  [`TAG_XLEN-1:0]            app_mem_offset           ; // Tag Compare Data

logic [$clog2(TAG_MEM_DP)-1:0]    cache_mem_offset         ; // Cache Memory Offset
logic [$clog2(CACHESIZE)-1:0]     cache_mem_ptr            ; // Cache Memory Pointer


// Internal Signals derived from respective data or address buses
logic	                          cache_hit                ;


logic [WB_AW-1:0]                 cpu_addr_l               ;
logic                             cpu_wr_l                 ;
logic [3:0]                       cpu_be_l                 ;
logic [1:0]                       cpu_width_l              ;

logic   [WB_DW-1:0]               prefetch_data            ; // Additional Prefetch on next location of current location
logic [$clog2(CACHESIZE)-1:0]     prefetch_ptr             ; // Prefetch Ptr
logic [$clog2(TAG_MEM_DP)-1:0]    prefetch_index           ; // Prefetch Index
logic                             prefetch_val             ;

logic   [WB_DW-1:0]               cache_mem_hdata          ; // Additional cache hold data
logic                             cache_mem_hval           ; // Holding Additional cache data valid

logic                             wb_app_ack_l             ; // Register check if the ack is back to back
logic                             cache_busy               ;


assign  cache_mem_clk0   = mclk;
assign  cache_mem_clk1   = mclk;

// State Variables
reg [3:0] state;
reg [3:0] next_state;
reg [5:0] flush_loc_cnt;

// Func

// Generate Wishbone Write Select
function automatic logic[3:0] ycr_conv_mem2wb_be (
	input logic [1:0] hwidth,
	input logic [1:0] haddr
);
logic [3:0] hbel_in;
begin
    hbel_in = 0;
    case (hwidth)
        2'b00 : begin
            hbel_in = 4'b0001 << haddr[1:0];
        end
        2'b01 : begin
            hbel_in = 4'b0011 << {haddr[1],1'b0};
        end
        2'b10 : begin
            hbel_in = 4'b1111;
        end
    endcase
    ycr_conv_mem2wb_be = hbel_in;
end
endfunction

function automatic logic[WB_DW-1:0] ycr_conv_mem2wb_wdata (
    input   logic [1:0]                    dmem_width,
    input   logic   [1:0]                  dmem_addr,
    input   logic   [WB_DW-1:0]    dmem_wdata
);
    logic   [WB_DW-1:0]  tmp;
begin
    tmp = 'x;
    case (dmem_width)
        2'b00 : begin
            case (dmem_addr)
                2'b00 : begin
                    tmp[7:0]   = dmem_wdata[7:0];
                end
                2'b01 : begin
                    tmp[15:8]  = dmem_wdata[7:0];
                end
                2'b10 : begin
                    tmp[23:16] = dmem_wdata[7:0];
                end
                2'b11 : begin
                    tmp[31:24] = dmem_wdata[7:0];
                end
                default : begin
                end
            endcase
        end
        2'b01 : begin
            case (dmem_addr[1])
                1'b0 : begin
                    tmp[15:0]  = dmem_wdata[15:0];
                end
                1'b1 : begin
                    tmp[31:16] = dmem_wdata[15:0];
                end
                default : begin
                end
            endcase
        end
        2'b10 : begin
            tmp = dmem_wdata;
        end
        default : begin
        end
    endcase
    ycr_conv_mem2wb_wdata = tmp;
end
endfunction


//Generate cpu read data based on width and address[1:0]
function automatic logic[WB_DW-1:0] ycr_conv_wb2mem_rdata (
    input   logic [1:0]                 hwidth,
    input   logic [1:0]                 haddr,
    input   logic [WB_DW-1:0]  hrdata
);
    logic   [WB_DW-1:0]  tmp;
begin
    tmp = 'x;
    case (hwidth)
        2'b00 : begin
            case (haddr)
                2'b00 : tmp[7:0] = hrdata[7:0];
                2'b01 : tmp[7:0] = hrdata[15:8];
                2'b10 : tmp[7:0] = hrdata[23:16];
                2'b11 : tmp[7:0] = hrdata[31:24];
                default : begin
                end
            endcase
        end
        2'b01 : begin
            case (haddr[1])
                1'b0 : tmp[15:0] = hrdata[15:0];
                1'b1 : tmp[15:0] = hrdata[31:16];
                default : begin
                end
            endcase
        end
        2'b10 : begin
            tmp = hrdata;
        end
        default : begin
        end
    endcase
    ycr_conv_wb2mem_rdata = tmp;
end
endfunction


// Combinational Logic

assign tag_cmp_data = cpu_addr_l[26:7];
assign cache_hit = |tag_hit;

wire [$clog2(CACHESIZE)-1:0]  next_prefetch_ptr = prefetch_ptr[4:0] + 1;


// Cache Controller State Machine and Logic

logic [31:0] mem2wb_data_l;

wire [31:0] mem2wb_data  = ycr_conv_mem2wb_wdata(cpu_mem_width,cpu_mem_addr[1:0], cpu_mem_wdata);
wire [31:0] wb2mem_data  = ycr_conv_wb2mem_rdata(cpu_width_l,cpu_addr_l[1:0], wb_app_dat_i);

always@(posedge mclk or negedge rst_n)
begin
   if(!rst_n)
   begin
      cpu_mem_req_ack   <= '0;
      cpu_mem_rdata      <= '0;
      cpu_mem_resp      <= 2'b00;

      wb_app_stb_o      <= '0;
      wb_app_we_o       <= '0;
      wb_app_adr_o      <= '0;
      wb_app_sel_o      <= '0;
      wb_app_bl_o       <= '0;
      wb_app_dat_o      <= '0;

      cache_mem_csb0    <= 1'b1;
      cache_mem_web0    <= 1'b0; 
      cache_mem_wmask0  <= '0;
      cache_mem_addr0   <= '0;
      cache_mem_din0    <= '0;

      cache_mem_addr1   <= '0;
      cache_mem_csb1    <= 1'b1;

      cache_mem_offset  <= '0;
      cache_mem_ptr     <= '0;
      cache_busy        <= 1'b1;

      tag_wr            <= 1'b0;
      tag_uwr           <= 1'b0;
      tag_uptr          <= '0;
      tag_wdata         <= '0;

      cpu_addr_l        <= '0;
      cpu_wr_l          <= '0;
      cpu_be_l          <= '0;
      cpu_width_l       <= '0;
      mem2wb_data_l     <= '0;

      prefetch_data     <= '0;
      prefetch_ptr      <= '0;
      prefetch_index    <= '0;
      prefetch_val      <= '0;
      cache_mem_hval    <= 1'b0;
      cache_mem_hdata   <= '0;
      flush_loc_cnt     <= 6'h0;
      force_flush_done  <= 1'b0;

      state             <= CACHE_PREFILL_REQ;
      next_state        <= IDLE; // This state used for special case only

   end else begin
      case(state)
      IDLE	:begin
	 wb_app_stb_o      <= '0;
	 wb_app_we_o       <= '0;
	 wb_app_adr_o       <= '0;
	 wb_app_sel_o      <= '0;
	 wb_app_bl_o       <= '0;
	 wb_app_dat_o      <= '0;
	 wb_app_ack_l      <= 1'b0;

	 cache_mem_csb0    <= 1'b1;
	 cache_mem_web0    <= 1'b0; 
	 cache_mem_wmask0  <= '0;
	 cache_mem_addr0   <= '0;
	 cache_mem_din0    <= '0;
         cache_busy        <= 1'b0;

         cache_mem_offset  <= '0;
	 cache_mem_ptr     <= '0;

	 tag_wr            <= 1'b0;
	 tag_uwr           <= 1'b0;
	 tag_uptr          <= '0;
	 tag_wdata         <= '0;

	 if(cfg_bypass_dcache) begin
	     state            <= IDLE;
	 end

	// Check if the current address is next location of same cache offset
	// if yes, pick the data from prefetch content
	 else if(!cfg_pfet_dis && cpu_mem_req && (!cpu_mem_cmd) && prefetch_val && 
	     (cpu_mem_addr[31:2] == {cpu_addr_l[31:7], prefetch_ptr[4:0]})) begin
	      cpu_mem_req_ack  <= 1'b1;
	      state            <= PREFETCH_START;

         end else begin
	    cpu_mem_resp      <= 2'b00;
	    cache_mem_addr1   <= '0;
	    cache_mem_csb1    <= 1'b1;

	    if(cpu_mem_req && (cpu_mem_resp == 2'b00)) begin
	        cpu_addr_l       <= cpu_mem_addr;
	        cpu_wr_l         <= cpu_mem_cmd;
	        cpu_width_l      <= cpu_mem_width;
		mem2wb_data_l    <= mem2wb_data;
	        cpu_be_l         <= ycr_conv_mem2wb_be(cpu_mem_width,cpu_mem_addr[1:0]);
		prefetch_val     <= 1'b0;
	        cpu_mem_req_ack  <= 1'b1;
	        state            <= TAG_COMPARE;
	     end else if(cfg_force_flush && !force_flush_done) begin
		flush_loc_cnt    <= 'h0;
		cache_mem_ptr    <= 'h0;
	        state            <= CACHE_FLUSH_ACTION;
	     end else if(!cfg_force_flush && force_flush_done) begin
                 force_flush_done <= 1'b0; // Deassert flush done, cone config de-asserted
	     end

	 end
      end

      TAG_COMPARE	:begin
	 cpu_mem_req_ack  <= 1'b0;
         case(cache_hit)
	 1'd0:begin // If there is no Tag Hit
	    cache_mem_offset <= tag_cur_loc;
	    app_mem_offset   <= tag_ctag;
	    // If there is free space
	    if(!tag_full) begin 
	       state  <= CACHE_REFILL_REQ;
	       cache_busy        <= 1'b1;
	    end else if(tag_cval && tag_cdirty) begin 
	    // If Tag Memory is already full, then replace last written
	    // location and check current modifying location data is modified, then do
	    // write back
                cache_mem_csb0    <= 1'b0;
                cache_mem_web0    <= 1'b1;
                cache_mem_wmask0  <= 4'b1111;
                cache_mem_addr0   <= {tag_cur_loc,cache_mem_ptr};
	        cache_mem_ptr     <= cache_mem_ptr+1;
		cache_busy        <= 1'b1;
	        state             <= CACHE_WRITE_BACK;
                next_state        <= CACHE_REFILL_REQ;
	    end else begin
	    // If current modifying location data is not modified, then do just refill
	        cache_busy        <= 1'b1;
		state <= CACHE_REFILL_REQ;
	    end
         end

	 1'd1:	begin
	     // If it's write access and previously dirty bit is not set
	     // Then do dirty bit update on tag hit location
	     if(cpu_wr_l && !tag_hdirty) begin
		 tag_uwr <= 1'b1;
	         tag_uptr <= tag_hindex;
		 tag_wdata <= {1'b1,1'b1,cpu_addr_l[26:7]};
	     end 
	     
	     if(cpu_wr_l) begin // cpu write access
	         cpu_mem_resp      <= 2'b01;
	         cache_mem_addr0  <= {tag_hindex,cpu_addr_l[6:2]};
                 cache_mem_csb0    <= 1'b0;
                 cache_mem_web0    <= 1'b0;
                 cache_mem_wmask0  <= cpu_be_l;
                 cache_mem_din0    <= mem2wb_data_l;
	         state             <= IDLE;
	     end else begin // cpu read access
	          cache_mem_addr1  <= {tag_hindex,cpu_addr_l[6:2]};
	          prefetch_index   <= tag_hindex;
	          prefetch_ptr     <=  cpu_addr_l[6:2]+1;
	         cache_mem_csb1    <= 1'b0;
	         state             <= CACHE_RDATA_FETCH1; // Read Cache
	     end
	  end
	  endcase
       end
       CACHE_RDATA_FETCH1: begin
	  cache_mem_addr1  <= {tag_hindex,prefetch_ptr[4:0]}; // Address for additional prefetch;
	  tag_uwr          <= 1'b0;
	  state            <= CACHE_RDATA_FETCH2;
       end

       CACHE_RDATA_FETCH2: begin
	  cache_mem_csb1   <= 1'b1;
          cpu_mem_rdata    <= ycr_conv_wb2mem_rdata(cpu_width_l,cpu_addr_l[1:0], cache_mem_dout1);
	  cpu_mem_resp     <= 2'b01;
	  state            <= CACHE_RDATA_FETCH3;
       end
       // Do Additial prefetech for next location
       CACHE_RDATA_FETCH3: begin
          prefetch_data    <= cache_mem_dout1;
          prefetch_val     <= 1'b1;
	  cpu_mem_resp     <= 2'b00;
	  state            <= IDLE;
       end

       PREFETCH_START: begin
	      cpu_mem_req_ack = 1'b0;
	     // Ack with Prefect data
              cpu_mem_rdata     <= ycr_conv_wb2mem_rdata(cpu_mem_width,cpu_mem_addr[1:0], prefetch_data);
	      cpu_mem_resp     <= 2'b01;

	      // Goahead for next data prefetech in same cache index
	      cache_mem_addr1  <= {prefetch_index,next_prefetch_ptr[4:0]}; // Address for additional prefetch;
	      cache_mem_csb1   <= 1'b0;
	      prefetch_ptr     <= next_prefetch_ptr;
	      state            <= PREFETCH_WAIT;
       end

       // Additional Prefetch delay do to RAM access is take effectly two
       // cycle
       PREFETCH_WAIT: begin
	  cpu_mem_resp     <= 2'b00;
	  cache_mem_csb1   <= 1'b1;
	  state            <= CACHE_RDATA_FETCH3;
      end

       // Request for Cache fetch from application memory
       CACHE_REFILL_REQ: begin
	  wb_app_stb_o <= 1'b1;
	  wb_app_we_o  <= 1'b0;
	  wb_app_adr_o <= {cpu_addr_l[31:7],cache_mem_ptr,2'b0};
	  wb_app_sel_o <= 4'b1111;
	  wb_app_bl_o  <= 32;	
	  state        <= CACHE_REFILL_ACTION;
       end

       // CACHE Refill action based on application ack
       // Based on ack increment for ptr, assumed that
       // application only send 32 ack
       CACHE_REFILL_ACTION: begin
          if(wb_app_ack_i) begin
	     cache_mem_csb0    <= 1'b0;
	     cache_mem_web0    <= 1'b0;
	     cache_mem_wmask0  <= 4'b1111;
	     cache_mem_addr0   <= {cache_mem_offset,cache_mem_ptr};
	     cache_mem_ptr     <= cache_mem_ptr+1;
	  end else begin
	     cache_mem_csb0    <= 1'b1;
	  end
	  // Check the Cache Refill Read Back address Matches with CPU
	  // Address request
	  if(wb_app_ack_i) begin 
	     if(cache_mem_ptr == cpu_addr_l[6:2]) begin
		cpu_mem_resp   <= 2'b01;
		// Check if the current cpu request is read 
		// then send read data to cpu and cache mem
		if(!cpu_wr_l) begin 
		    cpu_mem_rdata   <= wb2mem_data;
		    cache_mem_din0  <=  wb_app_dat_i;
		end else begin
		   // If the current cpu request is write
		   // then update the cache data based on the
		   // byte select value
		   if(cpu_be_l[0])
		      cache_mem_din0[7:0]  <= mem2wb_data_l[7:0];
		   else
		      cache_mem_din0[7:0]  <= wb_app_dat_i[7:0];

		   if(cpu_be_l[1])
		      cache_mem_din0[15:8]  <= mem2wb_data_l[15:8];
		   else
		      cache_mem_din0[15:8]  <= wb_app_dat_i[15:8];

		   if(cpu_be_l[2])
		      cache_mem_din0[23:16]  <= mem2wb_data_l[23:16];
		   else
		      cache_mem_din0[23:16]  <= wb_app_dat_i[23:16];

		   if(cpu_be_l[3])
		      cache_mem_din0[31:24]  <= mem2wb_data_l[31:24];
		   else
		      cache_mem_din0[31:24]  <= wb_app_dat_i[31:24];
	         end
	      end else begin
                  cpu_mem_resp   <= 2'b00;
		  cache_mem_din0 <= wb_app_dat_i;
	       end
            end else begin
                cpu_mem_resp   <= 2'b00;
            end

	  // Update the Tag Memory
	  if(wb_app_lack_i) begin
	      wb_app_stb_o    <= 1'b0;
	      // Over-write first content
	      tag_wr          <= 1'b1;
	     if(cpu_wr_l)
	         tag_wdata  <= {1'b1,1'b1,cpu_addr_l[26:7]};
	     else
	         tag_wdata  <= {1'b1,1'b0,cpu_addr_l[26:7]};
	     state      <= IDLE;
	  end
       end


       // Write back the cache memory data to application memory
       CACHE_WRITE_BACK: begin
	   tag_wr            <= 'h0;
           cache_mem_addr0   <= {cache_mem_offset,cache_mem_ptr};
	   cache_mem_ptr     <= cache_mem_ptr+1;
           state             <= CACHE_WRITE_BACK_ACTION1;
       end
       // Wait for first read data from cache memory
       CACHE_WRITE_BACK_ACTION1: begin
           wb_app_stb_o      <= 1'b1;
           wb_app_we_o       <= 1'b1;
           wb_app_sel_o      <= 4'b1111;
           wb_app_adr_o      <= {DMEM_BASE,app_mem_offset,5'b0,2'b0};
           wb_app_bl_o       <= 32;
           wb_app_dat_o      <= cache_mem_dout0;
	   wb_app_ack_l      <= 1'b1;
           cache_mem_addr0   <= {cache_mem_offset,cache_mem_ptr};
	   cache_mem_ptr     <= cache_mem_ptr+1;
           cache_mem_hval    <= 1'b0;
           state             <= CACHE_WRITE_BACK_ACTION2;
       end
       // Wait for Ack from application layer
       CACHE_WRITE_BACK_ACTION2: begin
           // If the not the last ack, update cach memory pointer
           // accordingly
	   wb_app_ack_l    <= wb_app_ack_i;
           if(wb_app_ack_i && !wb_app_lack_i) begin
              cache_mem_addr0  <= {cache_mem_offset,cache_mem_ptr};
              cache_mem_ptr    <= cache_mem_ptr+1;
	      if(wb_app_ack_l) begin // If back to back ack 
                 wb_app_dat_o     <= cache_mem_dout0;
                 cache_mem_hval   <= 1'b0;
	      end else begin // Pick from previous holding data
                 cache_mem_hval   <= 1'b1;
                 wb_app_dat_o     <= cache_mem_hdata;
                 cache_mem_hdata  <= cache_mem_dout0;
	      end
           end else begin // Hold the cach mem data
	      if(!cache_mem_hval) begin
                 cache_mem_hdata  <= cache_mem_dout0;
                 cache_mem_hval   <= 1'b1;
              end
              if(wb_app_lack_i) begin
	        cache_mem_csb0  <= 1'b1;
                 wb_app_stb_o   <= 1'b0;
                 cache_mem_ptr  <= '0;
                 state          <= next_state;
              end
           end
       
       end

       // Prefill all the cache location with 512 word burst command
       CACHE_PREFILL_REQ: begin
	 if(cfg_bypass_dcache) begin
	     state            <= IDLE;
	 end else begin
	      wb_app_stb_o      <= 1'b1;
	      wb_app_we_o       <= 1'b0;
	      wb_app_adr_o      <= {DMEM_BASE,20'h0,5'b0,2'b0};
	      wb_app_sel_o      <= 4'b1111;
	      wb_app_bl_o       <= 10'h200; // 512;	
              cache_mem_ptr     <= '0;
              cache_mem_offset  <= '0;
	      state             <= CACHE_PREFILL_ACTION;
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
	        tag_wdata  <= {1'b1,1'b0,16'h0,cache_mem_offset[3:0]};
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
	     state            <= IDLE;
	  end
       end

       // Flush the content based on dirty bit
       CACHE_FLUSH_ACTION: begin
	     if(flush_loc_cnt != 6'h20) begin
		  if(tag_cval && tag_cdirty) begin // If current loc data is modified
	            cache_mem_offset  <= tag_cur_loc;
	            app_mem_offset    <= tag_ctag;
	            tag_wr            <= 1'b0;	     
                    cache_mem_csb0    <= 1'b0;
                    cache_mem_web0    <= 1'b1;
                    cache_mem_wmask0  <= 4'b1111;
                    cache_mem_addr0   <= {tag_cur_loc,cache_mem_ptr};
	            cache_mem_ptr     <= cache_mem_ptr+1;
		    cache_busy        <= 1'b1;
		    state             <= CACHE_WRITE_BACK;
	            next_state        <= CACHE_FLUSH_ACTION1;
		    tag_wdata         <= {tag_cval,1'b0,tag_ctag}; // Remove Dirty Bit
	            tag_wr            <= 1'b1;
	         end else begin // Move to next tag
		     cache_mem_ptr    <= 'h0;
		     tag_wdata        <= {tag_cval,tag_cdirty,tag_ctag}; // Don't change current content
	             tag_wr           <= 1'b1;
		     state            <= CACHE_FLUSH_ACTION1;
	         end
	     end else begin
		   force_flush_done   <= 1'b1;
	           tag_wr             <= 1'b0;
                   state              <= IDLE;
	           next_state         <= IDLE;
             end
          end	     
	  CACHE_FLUSH_ACTION1: begin // Dummy cycle to tag update
	        tag_wr         <= 1'b0;
                flush_loc_cnt  <= flush_loc_cnt + 1;
		state          <= CACHE_FLUSH_ACTION;
	  end

       default:begin
          cpu_mem_rdata      <= '0;
          cpu_mem_resp       <= 2'b00;
       
          wb_app_stb_o      <= '0;
          wb_app_we_o       <= '0;
          wb_app_adr_o      <= '0;
          wb_app_sel_o      <= '0;
          wb_app_bl_o       <= '0;
          wb_app_dat_o      <= '0;
       
          cache_mem_csb0    <= 1'b1;
          cache_mem_web0    <= 1'b0; 
          cache_mem_wmask0  <= '0;
          cache_mem_addr0   <= '0;
          cache_mem_din0    <= '0;
       
          cache_mem_addr1   <= '0;
          cache_mem_csb1    <= 1'b1;
       
          cache_mem_offset  <= '0;
          cache_mem_ptr     <= '0;
       
          tag_uwr           <= 1'b0;
          tag_wr            <= 1'b0;
          tag_uptr          <= '0;
          tag_wdata         <= '0;
       
          cpu_addr_l        <= '0;
          cpu_wr_l          <= '0;
          cpu_be_l          <= '0;
          cpu_width_l       <= '0;
       
          state             <= IDLE;
       end
       endcase
   end
end


// Tag Memory
dcache_tag_fifo #(.WD(TAG_MEM_WD), .DP(TAG_MEM_DP)) u_tag_fifo ( 
	.clk                 (mclk),
	.reset_n             (rst_n),
	.flush               (1'b0),

        .tag_wr              (tag_wr),
	.tag_uwr             (tag_uwr),
	.tag_uptr            (tag_uptr),
	.tag_wdata           (tag_wdata),
	.tag_wptr            (tag_cur_loc),
	.tag_hdirty          (tag_hdirty),


	.tag_cmp_data        (tag_cmp_data),
        .tag_hit             (tag_hit),
	.tag_hindex          (tag_hindex),
	.tag_ctag            (tag_ctag),
	.tag_cdirty          (tag_cdirty),
	.tag_cval            (tag_cval),


	.full                (tag_full),
	.empty               ()
	  );

/***
// 2KB SRAM Cache memory
sky130_sram_2kbyte_1rw1r_32x512_8 u_cmem_2kb(
`ifdef USE_POWER_PINS
    .vccd1 (vccd1),// User area 1 1.8V supply
    .vssd1 (vssd1),// User area 1 digital ground
`endif
// Port 0: RW
    .clk0     (mclk),
    .csb0     (cache_mem_csb0),
    .web0     (cache_mem_web0),
    .wmask0   (cache_mem_wmask0),
    .addr0    (cache_mem_addr0),
    .din0     (cache_mem_din0),
    .dout0    (cache_mem_dout0),
// Port 1: R
    .clk1     (mclk),
    .csb1     (cache_mem_csb1),
    .addr1    (cache_mem_addr1),
    .dout1    (cache_mem_dout1)
  );
***/

// END OF MODULE
endmodule

