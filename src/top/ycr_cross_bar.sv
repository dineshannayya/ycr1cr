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
////  ycr2  cross bar                                                     ////
////                                                                      ////
////  This file is part of the ycr cores project                          ////
////  https://github.com/dineshannayya/ycr2c.git                          ////
////                                                                      ////
////  Description:                                                        ////
////     map  the two core imem/dmem Memory request one of the 5 port    ////
////     cross-bar feature in enabled.
////                                                                      ////
////  To Do:                                                              ////
////    nothing                                                           ////
////                                                                      ////
////  Author(s):                                                          ////
////      - Dinesh Annayya, dinesha@opencores.org                         ////
////                                                                      ////
////  Revision :                                                          ////
////     v0:    19 Mar 2022,  Dinesh A                                    ////
////             Initial Version                                          ////
////                                                                      ////
//////////////////////////////////////////////////////////////////////////////
`include "ycr_memif.svh"
`include "ycr_arch_description.svh"

module ycr_cross_bar (
    // Control signals
    input   logic                           rst_n,
    input   logic                           clk,

    input   logic                           cfg_bypass_icache,  // 1 => Bypass icache
    input   logic                           cfg_bypass_dcache,  // 1 => Bypass dcache

    // Core-0 imem interface
    output  logic                          core0_imem_req_ack,
    input   logic                          core0_imem_req,
    input   logic                          core0_imem_cmd,
    input   logic [1:0]                    core0_imem_width,
    input   logic [`YCR_IMEM_AWIDTH-1:0]   core0_imem_addr,
    input   logic [`YCR_IMEM_BSIZE-1:0]    core0_imem_bl,             // IMEM burst size
    input   logic [`YCR_IMEM_DWIDTH-1:0]   core0_imem_wdata,
    output  logic [`YCR_IMEM_DWIDTH-1:0]   core0_imem_rdata,
    output  logic [1:0]                    core0_imem_resp,

    // Core-0 dmem interface
    output  logic                          core0_dmem_req_ack,
    input   logic                          core0_dmem_req,
    input   logic                          core0_dmem_cmd,
    input   logic [1:0]                    core0_dmem_width,
    input   logic [`YCR_IMEM_AWIDTH-1:0]   core0_dmem_addr,
    input   logic [`YCR_IMEM_BSIZE-1:0]    core0_dmem_bl,             
    input   logic [`YCR_IMEM_DWIDTH-1:0]   core0_dmem_wdata,
    output  logic [`YCR_IMEM_DWIDTH-1:0]   core0_dmem_rdata,
    output  logic [1:0]                    core0_dmem_resp,

    // PORT0 interface - dmem
    input   logic                          port0_req_ack,
    output  logic                          port0_req,
    output  logic                          port0_cmd,
    output  logic [1:0]                    port0_width,
    output  logic [`YCR_IMEM_AWIDTH-1:0]   port0_addr,
    output  logic [`YCR_IMEM_BSIZE-1:0]    port0_bl,             
    output  logic [`YCR_IMEM_DWIDTH-1:0]   port0_wdata,
    input   logic [`YCR_IMEM_DWIDTH-1:0]   port0_rdata,
    input   logic [1:0]                    port0_resp,

    // PORT1 interface - icache
    input   logic                          port1_req_ack,
    output  logic                          port1_req,
    output  logic                          port1_cmd,
    output  logic [1:0]                    port1_width,
    output  logic [`YCR_IMEM_AWIDTH-1:0]   port1_addr,
    output  logic [`YCR_IMEM_BSIZE-1:0]    port1_bl,             
    output  logic [`YCR_IMEM_DWIDTH-1:0]   port1_wdata,
    input   logic [`YCR_IMEM_DWIDTH-1:0]   port1_rdata,
    input   logic [1:0]                    port1_resp,

    // PORT2 interface - dcache
    input   logic                          port2_req_ack,
    output  logic                          port2_req,
    output  logic                          port2_cmd,
    output  logic [1:0]                    port2_width,
    output  logic [`YCR_IMEM_AWIDTH-1:0]   port2_addr,
    output  logic [`YCR_IMEM_BSIZE-1:0]    port2_bl,             
    output  logic [`YCR_IMEM_DWIDTH-1:0]   port2_wdata,
    input   logic [`YCR_IMEM_DWIDTH-1:0]   port2_rdata,
    input   logic [1:0]                    port2_resp,
    
    // PORT3 interface - tcm
    input   logic                          port3_req_ack,
    output  logic                          port3_req,
    output  logic                          port3_cmd,
    output  logic [1:0]                    port3_width,
    output  logic [`YCR_IMEM_AWIDTH-1:0]   port3_addr,
    output  logic [`YCR_IMEM_BSIZE-1:0]    port3_bl,             
    output  logic [`YCR_IMEM_DWIDTH-1:0]   port3_wdata,
    input   logic [`YCR_IMEM_DWIDTH-1:0]   port3_rdata,
    input   logic [1:0]                    port3_resp,

    // PORT4 interface - timer
    input   logic                          port4_req_ack,
    output  logic                          port4_req,
    output  logic                          port4_cmd,
    output  logic [1:0]                    port4_width,
    output  logic [`YCR_DMEM_AWIDTH-1:0]   port4_addr,
    output  logic [`YCR_IMEM_BSIZE-1:0]    port4_bl,             
    output  logic [`YCR_DMEM_DWIDTH-1:0]   port4_wdata,
    input   logic [`YCR_DMEM_DWIDTH-1:0]   port4_rdata,
    input   logic [1:0]                    port4_resp
);

typedef enum logic [2:0] {
    YCR_SEL_PORT0,
    YCR_SEL_PORT1,
    YCR_SEL_PORT2,
    YCR_SEL_PORT3,
    YCR_SEL_PORT4
} type_ycr_sel_e;


// P0
wire                        core0_imem_req_ack_p0;
wire                        core0_imem_lack_p0;
wire [`YCR_IMEM_DWIDTH-1:0] core0_imem_rdata_p0;
wire [1:0]                  core0_imem_resp_p0;

wire                        core0_dmem_req_ack_p0;
wire                        core0_dmem_lack_p0;
wire [`YCR_IMEM_DWIDTH-1:0] core0_dmem_rdata_p0;
wire [1:0]                  core0_dmem_resp_p0;



// P1
wire                        core0_imem_req_ack_p1;
wire                        core0_imem_lack_p1;
wire [`YCR_IMEM_DWIDTH-1:0] core0_imem_rdata_p1;
wire [1:0]                  core0_imem_resp_p1;

wire                        core0_dmem_req_ack_p1;
wire                        core0_dmem_lack_p1;
wire [`YCR_IMEM_DWIDTH-1:0] core0_dmem_rdata_p1;
wire [1:0]                  core0_dmem_resp_p1;


// P2
wire                        core0_imem_req_ack_p2;
wire                        core0_imem_lack_p2;
wire [`YCR_IMEM_DWIDTH-1:0] core0_imem_rdata_p2;
wire [1:0]                  core0_imem_resp_p2;

wire                        core0_dmem_req_ack_p2;
wire                        core0_dmem_lack_p2;
wire [`YCR_IMEM_DWIDTH-1:0] core0_dmem_rdata_p2;
wire [1:0]                  core0_dmem_resp_p2;


// P3
wire                        core0_imem_req_ack_p3;
wire                        core0_imem_lack_p3;
wire [`YCR_IMEM_DWIDTH-1:0] core0_imem_rdata_p3;
wire [1:0]                  core0_imem_resp_p3;

wire                        core0_dmem_req_ack_p3;
wire                        core0_dmem_lack_p3;
wire [`YCR_IMEM_DWIDTH-1:0] core0_dmem_rdata_p3;
wire [1:0]                  core0_dmem_resp_p3;


// P4
wire                        core0_imem_req_ack_p4;
wire                        core0_imem_lack_p4;
wire [`YCR_IMEM_DWIDTH-1:0] core0_imem_rdata_p4;
wire [1:0]                  core0_imem_resp_p4;

wire                        core0_dmem_req_ack_p4;
wire                        core0_dmem_lack_p4;
wire [`YCR_IMEM_DWIDTH-1:0] core0_dmem_rdata_p4;
wire [1:0]                  core0_dmem_resp_p4;



// dmem if
logic                          core_dmem_req_ack;
logic                          core_dmem_req;
logic                          core_dmem_cmd;
logic [1:0]                    core_dmem_width;
logic [`YCR_IMEM_AWIDTH-1:0]   core_dmem_addr;
logic [`YCR_IMEM_BSIZE-1:0]    core_dmem_bl;             
logic [`YCR_IMEM_DWIDTH-1:0]   core_dmem_wdata;
logic [`YCR_IMEM_DWIDTH-1:0]   core_dmem_rdata;
logic [1:0]                    core_dmem_resp;

// As RISC request are pipe lined and address is not hold during complete
// trasaction, we need to hold the target id untill the last ack is received
// for current trasaction and avoid out of order flows, we need block request
// to next block, when current transaction is pending

// CORE- 0
logic       core0_imem_lack,core0_dmem_lack;
logic       core0_imem_lock,core0_dmem_lock;
logic [2:0] core0_imem_tid,core0_imem_tid_h,core0_imem_tid_t;
logic [2:0] core0_dmem_tid,core0_dmem_tid_h,core0_dmem_tid_t;

assign core0_imem_tid_t = func_taget_id(core0_imem_addr);
assign core0_imem_tid = (core0_imem_lock) ? core0_imem_tid_h: core0_imem_tid_t;

always_ff @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
        core0_imem_lock  <= 1'b0;
        core0_imem_tid_h   <= 3'h0;
    end else if(core0_imem_req && core0_imem_req_ack) begin
        core0_imem_lock  <= 1'b1;
        core0_imem_tid_h <= core0_imem_tid_t;
     end else if(core0_imem_lack) begin
        core0_imem_lock  <= 1'b0;
    end
end

assign core0_dmem_tid_t = func_taget_id(core0_dmem_addr);
assign core0_dmem_tid = (core0_dmem_lock) ? core0_dmem_tid_h: core0_dmem_tid_t;
always_ff @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
        core0_dmem_lock  <= 1'b0;
        core0_dmem_tid_h   <= 3'h0;
    end else if(core0_dmem_req && core0_dmem_req_ack) begin
        core0_dmem_lock  <= 1'b1;
        core0_dmem_tid_h <= core0_dmem_tid_t;
     end else if(core0_dmem_lack) begin
        core0_dmem_lock  <= 1'b0;
    end
end


//------------------ End of tid generation ---------------------------------
// CORE0 IMEM
assign core0_imem_req_ack = 
	                      (core0_imem_tid == 3'b000) ? core0_imem_req_ack_p0 :
	                      (core0_imem_tid == 3'b001) ? core0_imem_req_ack_p1 :
	                      (core0_imem_tid == 3'b010) ? core0_imem_req_ack_p2 :
	                      (core0_imem_tid == 3'b011) ? core0_imem_req_ack_p3 :
	                      (core0_imem_tid == 3'b100) ? core0_imem_req_ack_p4 :
			      'h0;
assign core0_imem_lack = 
	                      (core0_imem_tid == 3'b000) ? core0_imem_lack_p0 :
	                      (core0_imem_tid == 3'b001) ? core0_imem_lack_p1 :
	                      (core0_imem_tid == 3'b010) ? core0_imem_lack_p2 :
	                      (core0_imem_tid == 3'b011) ? core0_imem_lack_p3 :
	                      (core0_imem_tid == 3'b100) ? core0_imem_lack_p4 :
			      'h0;

assign core0_imem_rdata  = 
	                      (core0_imem_tid == 3'b000) ? core0_imem_rdata_p0 :
	                      (core0_imem_tid == 3'b001) ? core0_imem_rdata_p1 :
	                      (core0_imem_tid == 3'b010) ? core0_imem_rdata_p2 :
	                      (core0_imem_tid == 3'b011) ? core0_imem_rdata_p3 :
	                      (core0_imem_tid == 3'b100) ? core0_imem_rdata_p4 :
			      'h0;

assign core0_imem_resp  = 
	                      (core0_imem_tid == 3'b000) ? core0_imem_resp_p0 :
	                      (core0_imem_tid == 3'b001) ? core0_imem_resp_p1 :
	                      (core0_imem_tid == 3'b010) ? core0_imem_resp_p2 :
	                      (core0_imem_tid == 3'b011) ? core0_imem_resp_p3 :
	                      (core0_imem_tid == 3'b100) ? core0_imem_resp_p4 :
			      'h0;

// CORE0 DMEM
assign core0_dmem_req_ack = 
	                      (core0_dmem_tid == 3'b000) ? core0_dmem_req_ack_p0 :
	                      (core0_dmem_tid == 3'b001) ? core0_dmem_req_ack_p1 :
	                      (core0_dmem_tid == 3'b010) ? core0_dmem_req_ack_p2 :
	                      (core0_dmem_tid == 3'b011) ? core0_dmem_req_ack_p3 :
	                      (core0_dmem_tid == 3'b100) ? core0_dmem_req_ack_p4 :
			      'h0;
assign core0_dmem_lack = 
	                      (core0_dmem_tid == 3'b000) ? core0_dmem_lack_p0 :
	                      (core0_dmem_tid == 3'b001) ? core0_dmem_lack_p1 :
	                      (core0_dmem_tid == 3'b010) ? core0_dmem_lack_p2 :
	                      (core0_dmem_tid == 3'b011) ? core0_dmem_lack_p3 :
	                      (core0_dmem_tid == 3'b100) ? core0_dmem_lack_p4 :
			      'h0;

// Added register to break the timing path
always_ff @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
      core0_dmem_rdata <= 'h0;
      core0_dmem_resp  <= 'h0;
    end else begin 
       core0_dmem_rdata  <= (core0_dmem_tid == 3'b000) ? core0_dmem_rdata_p0 :
	                    (core0_dmem_tid == 3'b001) ? core0_dmem_rdata_p1 :
	                    (core0_dmem_tid == 3'b010) ? core0_dmem_rdata_p2 :
	                    (core0_dmem_tid == 3'b011) ? core0_dmem_rdata_p3 :
	                    (core0_dmem_tid == 3'b100) ? core0_dmem_rdata_p4 :
			      'h0;

       core0_dmem_resp  <=  (core0_dmem_tid == 3'b000) ? core0_dmem_resp_p0 :
	                    (core0_dmem_tid == 3'b001) ? core0_dmem_resp_p1 :
	                    (core0_dmem_tid == 3'b010) ? core0_dmem_resp_p2 :
	                    (core0_dmem_tid == 3'b011) ? core0_dmem_resp_p3 :
	                    (core0_dmem_tid == 3'b100) ? core0_dmem_resp_p4 :
			      'h0;
   end
end


//-------------------------------------------------------------------------
// Burst is only support in icache & dmem and rest of the interface support only
// single burst, as cross-bar expect last burst access to exit the grant,
// we are generting LOK for dcache, tcm,timer,dmem interface
// ------------------------------------------------------------------------
               
wire [1:0] port0_resp_t   = port0_resp;


ycr_router  u_router_p0 (
    // Control signals
          .rst_n                      (rst_n                   ),
          .clk                        (clk                     ),
                                                                  
          .taget_id                   (3'b000                  ),

    // core0-imem interface
          .core0_imem_tid             (core0_imem_tid          ),
          .core0_imem_req_ack         (core0_imem_req_ack_p0   ),
          .core0_imem_lack            (core0_imem_lack_p0      ),
          .core0_imem_req             (core0_imem_req          ),
          .core0_imem_cmd             (core0_imem_cmd          ),
          .core0_imem_width           (core0_imem_width        ),
          .core0_imem_addr            (core0_imem_addr         ),
          .core0_imem_bl              (core0_imem_bl           ),
          .core0_imem_wdata           (core0_imem_wdata        ),
          .core0_imem_rdata           (core0_imem_rdata_p0     ),
          .core0_imem_resp            (core0_imem_resp_p0      ),

    // core0-dmem interface
          .core0_dmem_tid             (core0_dmem_tid          ),
          .core0_dmem_req_ack         (core0_dmem_req_ack_p0   ),
          .core0_dmem_lack            (core0_dmem_lack_p0      ),
          .core0_dmem_req             (core0_dmem_req          ),
          .core0_dmem_cmd             (core0_dmem_cmd          ),
          .core0_dmem_width           (core0_dmem_width        ),
          .core0_dmem_addr            (core0_dmem_addr         ),
          .core0_dmem_bl              (core0_dmem_bl           ),
          .core0_dmem_wdata           (core0_dmem_wdata        ),
          .core0_dmem_rdata           (core0_dmem_rdata_p0     ),
          .core0_dmem_resp            (core0_dmem_resp_p0      ),

    // core interface
          .core_req_ack               (port0_req_ack          ),
          .core_req                   (port0_req              ),
          .core_cmd                   (port0_cmd              ),
          .core_width                 (port0_width            ),
          .core_addr                  (port0_addr             ),
          .core_bl                    (port0_bl               ),
          .core_wdata                 (port0_wdata            ),
          .core_rdata                 (port0_rdata            ),
          .core_resp                  (port0_resp_t           )   

);

ycr_router  u_router_p1 (
    // Control signals
          .rst_n                      (rst_n                   ),
          .clk                        (clk                     ),
                                                                  
          .taget_id                   (3'b001                  ),

    // core0-imem interface
          .core0_imem_tid             (core0_imem_tid          ),
          .core0_imem_req_ack         (core0_imem_req_ack_p1   ),
          .core0_imem_lack            (core0_imem_lack_p1      ),
          .core0_imem_req             (core0_imem_req          ),
          .core0_imem_cmd             (core0_imem_cmd          ),
          .core0_imem_width           (core0_imem_width        ),
          .core0_imem_addr            (core0_imem_addr         ),
          .core0_imem_bl              (core0_imem_bl           ),
          .core0_imem_wdata           (core0_imem_wdata        ),
          .core0_imem_rdata           (core0_imem_rdata_p1     ),
          .core0_imem_resp            (core0_imem_resp_p1      ),

    // core0-dmem interface
          .core0_dmem_tid             (core0_dmem_tid          ),
          .core0_dmem_req_ack         (core0_dmem_req_ack_p1   ),
          .core0_dmem_lack            (core0_dmem_lack_p1      ),
          .core0_dmem_req             (core0_dmem_req          ),
          .core0_dmem_cmd             (core0_dmem_cmd          ),
          .core0_dmem_width           (core0_dmem_width        ),
          .core0_dmem_addr            (core0_dmem_addr         ),
          .core0_dmem_bl              (core0_dmem_bl           ),
          .core0_dmem_wdata           (core0_dmem_wdata        ),
          .core0_dmem_rdata           (core0_dmem_rdata_p1     ),
          .core0_dmem_resp            (core0_dmem_resp_p1      ),

    // core interface
          .core_req_ack               (port1_req_ack           ),
          .core_req                   (port1_req               ),
          .core_cmd                   (port1_cmd               ),
          .core_width                 (port1_width             ),
          .core_addr                  (port1_addr              ),
          .core_bl                    (port1_bl                ),
          .core_wdata                 (port1_wdata             ),
          .core_rdata                 (port1_rdata             ),
          .core_resp                  (port1_resp              )   

);


wire [1:0] port2_resp_t   = {2{port2_resp[0]}};
ycr_router  u_router_p2 (
    // Control signals
          .rst_n                      (rst_n                   ),
          .clk                        (clk                     ),
                                                                  
          .taget_id                   (3'b010                  ),

    // core0-imem interface
          .core0_imem_tid             (core0_imem_tid          ),
          .core0_imem_req_ack         (core0_imem_req_ack_p2   ),
          .core0_imem_lack            (core0_imem_lack_p2      ),
          .core0_imem_req             (core0_imem_req          ),
          .core0_imem_cmd             (core0_imem_cmd          ),
          .core0_imem_width           (core0_imem_width        ),
          .core0_imem_addr            (core0_imem_addr         ),
          .core0_imem_bl              (core0_imem_bl           ),
          .core0_imem_wdata           (core0_imem_wdata        ),
          .core0_imem_rdata           (core0_imem_rdata_p2     ),
          .core0_imem_resp            (core0_imem_resp_p2      ),

    // core0-dmem interface
          .core0_dmem_tid             (core0_dmem_tid          ),
          .core0_dmem_req_ack         (core0_dmem_req_ack_p2   ),
          .core0_dmem_lack            (core0_dmem_lack_p2      ),
          .core0_dmem_req             (core0_dmem_req          ),
          .core0_dmem_cmd             (core0_dmem_cmd          ),
          .core0_dmem_width           (core0_dmem_width        ),
          .core0_dmem_addr            (core0_dmem_addr         ),
          .core0_dmem_bl              (core0_dmem_bl           ),
          .core0_dmem_wdata           (core0_dmem_wdata        ),
          .core0_dmem_rdata           (core0_dmem_rdata_p2     ),
          .core0_dmem_resp            (core0_dmem_resp_p2      ),

    // core interface
          .core_req_ack               (port2_req_ack           ),
          .core_req                   (port2_req               ),
          .core_cmd                   (port2_cmd               ),
          .core_width                 (port2_width             ),
          .core_addr                  (port2_addr              ),
          .core_bl                    (port2_bl                ),
          .core_wdata                 (port2_wdata             ),
          .core_rdata                 (port2_rdata             ),
          .core_resp                  (port2_resp_t            )   

);

wire [1:0] port3_resp_t   = {2{port3_resp[0]}};
ycr_router  u_router_p3 (
    // Control signals
          .rst_n                      (rst_n                   ),
          .clk                        (clk                     ),
                                                                  
          .taget_id                   (3'b011                  ),

    // core0-imem interface
          .core0_imem_tid             (core0_imem_tid          ),
          .core0_imem_req_ack         (core0_imem_req_ack_p3   ),
          .core0_imem_lack            (core0_imem_lack_p3      ),
          .core0_imem_req             (core0_imem_req          ),
          .core0_imem_cmd             (core0_imem_cmd          ),
          .core0_imem_width           (core0_imem_width        ),
          .core0_imem_addr            (core0_imem_addr         ),
          .core0_imem_bl              (core0_imem_bl           ),
          .core0_imem_wdata           (core0_imem_wdata        ),
          .core0_imem_rdata           (core0_imem_rdata_p3     ),
          .core0_imem_resp            (core0_imem_resp_p3      ),

    // core0-dmem interface
          .core0_dmem_tid             (core0_dmem_tid          ),
          .core0_dmem_req_ack         (core0_dmem_req_ack_p3   ),
          .core0_dmem_lack            (core0_dmem_lack_p3      ),
          .core0_dmem_req             (core0_dmem_req          ),
          .core0_dmem_cmd             (core0_dmem_cmd          ),
          .core0_dmem_width           (core0_dmem_width        ),
          .core0_dmem_addr            (core0_dmem_addr         ),
          .core0_dmem_bl              (core0_dmem_bl           ),
          .core0_dmem_wdata           (core0_dmem_wdata        ),
          .core0_dmem_rdata           (core0_dmem_rdata_p3     ),
          .core0_dmem_resp            (core0_dmem_resp_p3      ),

    // core interface
          .core_req_ack               (port3_req_ack           ),
          .core_req                   (port3_req               ),
          .core_cmd                   (port3_cmd               ),
          .core_width                 (port3_width             ),
          .core_addr                  (port3_addr              ),
          .core_bl                    (port3_bl                ),
          .core_wdata                 (port3_wdata             ),
          .core_rdata                 (port3_rdata             ),
          .core_resp                  (port3_resp_t            )   

);

wire [1:0] port4_resp_t   = {2{port4_resp[0]}};
ycr_router  u_router_p4 (
    // Control signals
          .rst_n                      (rst_n                   ),
          .clk                        (clk                     ),
                                                                  
          .taget_id                   (3'b100                  ),

    // core0-imem interface
          .core0_imem_tid             (core0_imem_tid          ),
          .core0_imem_req_ack         (core0_imem_req_ack_p4   ),
          .core0_imem_lack            (core0_imem_lack_p4      ),
          .core0_imem_req             (core0_imem_req          ),
          .core0_imem_cmd             (core0_imem_cmd          ),
          .core0_imem_width           (core0_imem_width        ),
          .core0_imem_addr            (core0_imem_addr         ),
          .core0_imem_bl              (core0_imem_bl           ),
          .core0_imem_wdata           (core0_imem_wdata        ),
          .core0_imem_rdata           (core0_imem_rdata_p4     ),
          .core0_imem_resp            (core0_imem_resp_p4      ),

    // core0-dmem interface
          .core0_dmem_tid             (core0_dmem_tid          ),
          .core0_dmem_req_ack         (core0_dmem_req_ack_p4   ),
          .core0_dmem_lack            (core0_dmem_lack_p4      ),
          .core0_dmem_req             (core0_dmem_req          ),
          .core0_dmem_cmd             (core0_dmem_cmd          ),
          .core0_dmem_width           (core0_dmem_width        ),
          .core0_dmem_addr            (core0_dmem_addr         ),
          .core0_dmem_bl              (core0_dmem_bl           ),
          .core0_dmem_wdata           (core0_dmem_wdata        ),
          .core0_dmem_rdata           (core0_dmem_rdata_p4     ),
          .core0_dmem_resp            (core0_dmem_resp_p4      ),

    // core interface
          .core_req_ack               (port4_req_ack           ),
          .core_req                   (port4_req               ),
          .core_cmd                   (port4_cmd               ),
          .core_width                 (port4_width             ),
          .core_addr                  (port4_addr              ),
          .core_bl                    (port4_bl                ),
          .core_wdata                 (port4_wdata             ),
          .core_rdata                 (port4_rdata             ),
          .core_resp                  (port4_resp_t            )   

);

//---------------------------------------------
// Select the taget id based on address
//---------------------------------------------

function type_ycr_sel_e      func_taget_id;
input [`YCR_DMEM_AWIDTH-1:0] mem_addr;
begin
   func_taget_id    = YCR_SEL_PORT0;
   if (((mem_addr & YCR_ICACHE_ADDR_MASK) == YCR_ICACHE_ADDR_PATTERN) && (cfg_bypass_icache == 1'b0)) begin
       func_taget_id    = YCR_SEL_PORT1;
   end else if (((mem_addr & YCR_DCACHE_ADDR_MASK) == YCR_DCACHE_ADDR_PATTERN) && (cfg_bypass_dcache == 1'b0)) begin
       func_taget_id    = YCR_SEL_PORT2;
   end else if ((mem_addr & YCR_TCM_ADDR_MASK) == YCR_TCM_ADDR_PATTERN) begin
       func_taget_id    = YCR_SEL_PORT3;
   end else if ((mem_addr & YCR_LOCAL_ADDR_MASK) == YCR_LOCAL_ADDR_PATTERN) begin
       func_taget_id    = YCR_SEL_PORT4;
   end
end
endfunction


endmodule
