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
////  yifive interface block                                              ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr.git                            ////
////                                                                      ////
////  Description:                                                        ////
////     Holds interface block and icache/dcache logic                    ////
////                                                                      ////
////  To Do:                                                              ////
////    nothing                                                           ////
////                                                                      ////
////  Author(s):                                                          ////
////      - Dinesh Annayya, dinesha@opencores.org                         ////
////                                                                      ////
////  Revision :                                                          ////
////     v0:    June 7, 2021, Dinesh A                                    ////
////             Initial version                                          ////
////                                                                      ////
//////////////////////////////////////////////////////////////////////////////

`include "ycr_arch_description.svh"
`include "ycr_memif.svh"
`include "ycr_wb.svh"
`ifdef YCR_IPIC_EN
`include "ycr_ipic.svh"
`endif // YCR_IPIC_EN

`ifdef YCR_TCM_EN
 `define YCR_IMEM_ROUTER_EN
`endif // YCR_TCM_EN

module ycr_intf (
`ifdef USE_POWER_PINS
    input logic                             vccd1                     , // User area 1 1.8V supply
    input logic                             vssd1                     , // User area 1 digital ground
`endif

    input  logic   [3:0]                    cfg_wcska                 ,
    input  logic                            wbd_clk_int               ,
    output logic                            wbd_clk_skew              ,


    // Control
    input   logic                           pwrup_rst_n               , // Power-Up Reset
    // From clock gen
    input   logic [3:0]                     cfg_ccska                 ,
    input   logic                           core_clk_int              ,
    output  logic                           core_clk_skew             ,
    input   logic                           core_clk                  , // Core clock
    input   logic                           cpu_intf_rst_n            , // CPU interface reset

    input   logic                           cfg_icache_pfet_dis       , // disable icache prefetch
    input   logic                           cfg_icache_ntag_pfet_dis  , // disable tag preftech
    input   logic                           cfg_bypass_icache         , // icache disabled

    input   logic                           cfg_dcache_pfet_dis       , // disable dcache prefetch
    input   logic                           cfg_dcache_force_flush    , // force dcache flush
    input   logic                           cfg_bypass_dcache         , // dcache disabled

    input   logic [1:0]                     cfg_sram_lphase           ,  // SRAM data lanuch phase selection

    // Instruction Memory Interface
    output   logic                          core_icache_req_ack       , // IMEM request acknowledge
    output   logic [`YCR_IMEM_DWIDTH-1:0]   core_icache_rdata         , // IMEM read data
    output   logic [1:0]                    core_icache_resp          , // IMEM response
    input    logic                          core_icache_req           , // IMEM request
    input    logic                          core_icache_cmd           , // IMEM command
    input    logic [`YCR_IMEM_AWIDTH-1:0]   core_icache_addr          , // IMEM address
    input    logic [`YCR_IMEM_BSIZE-1:0]    core_icache_bl            , // IMEM burst size
    input    logic [1:0]                    core_icache_width         , // IMEM Width

    // Data Memory Interface
    output   logic                          core_dcache_req_ack       , // DMEM request acknowledge
    output   logic [`YCR_DMEM_DWIDTH-1:0]   core_dcache_rdata         , // DMEM read data
    output   logic [1:0]                    core_dcache_resp          , // DMEM response
    input    logic                          core_dcache_req           , // DMEM request
    input    logic                          core_dcache_cmd           , // DMEM command
    input    logic[1:0]                     core_dcache_width         , // DMEM data width
    input    logic [`YCR_DMEM_AWIDTH-1:0]   core_dcache_addr          , // DMEM address
    input    logic [`YCR_DMEM_DWIDTH-1:0]   core_dcache_wdata         , // DMEM write data

    // Data memory interface from router to WB bridge
    output   logic                          core_dmem_req_ack         ,
    output   logic [`YCR_DMEM_DWIDTH-1:0]   core_dmem_rdata           ,
    output   logic [1:0]                    core_dmem_resp            ,
    input    logic                          core_dmem_req             ,
    input    logic                          core_dmem_cmd             ,
    input    logic [1:0]                    core_dmem_width           ,
    input    logic [`YCR_DMEM_AWIDTH-1:0]   core_dmem_addr            ,
    input    logic [`YCR_IMEM_BSIZE-1:0]    core_dmem_bl              ,
    input    logic [`YCR_DMEM_DWIDTH-1:0]   core_dmem_wdata           ,
    //--------------------------------------------
    // Wishbone  
    // ------------------------------------------

    input   logic                           wb_rst_n                  , // Wish bone reset
    input   logic                           wb_clk                    , // wish bone clock

    // Data Memory Interface
    output  logic                           wbd_dmem_stb_o            , // strobe/request
    output  logic                           wbd_dmem_cyc_o            , // strobe/request
    output  logic   [YCR_WB_WIDTH-1:0]      wbd_dmem_adr_o            , // address
    output  logic                           wbd_dmem_we_o             , // write
    output  logic   [YCR_WB_WIDTH-1:0]      wbd_dmem_dat_o            , // data output
    output  logic   [3:0]                   wbd_dmem_sel_o            , // byte enable
    output  logic   [YCR_WB_BL_DMEM-1:0]    wbd_dmem_bl_o             , // byte enable
    output  logic                           wbd_dmem_bry_o            , // burst ready
    input   logic   [YCR_WB_WIDTH-1:0]      wbd_dmem_dat_i            , // data input
    input   logic                           wbd_dmem_ack_i            , // acknowlegement
    input   logic                           wbd_dmem_lack_i           , // last ack
    input   logic                           wbd_dmem_err_i            , // error

   `ifdef YCR_ICACHE_EN
   // Wishbone ICACHE I/F
   output logic                             wb_icache_cyc_o           , // strobe/request
   output logic                             wb_icache_stb_o           , // strobe/request
   output logic   [YCR_WB_WIDTH-1:0]        wb_icache_adr_o           , // address
   output logic                             wb_icache_we_o            , // write
   output logic   [3:0]                     wb_icache_sel_o           , // byte enable
   output logic   [9:0]                     wb_icache_bl_o            , // Burst Length
   output logic                             wb_icache_bry_o           , // Burst Ready 

   input logic   [YCR_WB_WIDTH-1:0]         wb_icache_dat_i           , // data input
   input logic                              wb_icache_ack_i           , // acknowlegement
   input logic                              wb_icache_lack_i          , // last acknowlegement
   input logic                              wb_icache_err_i           , // error

   // CACHE SRAM Memory I/F
   output logic                             icache_mem_clk0           , // CLK
   output logic                             icache_mem_csb0           , // CS#
   output logic                             icache_mem_web0           , // WE#
   output logic   [8:0]                     icache_mem_addr0          , // Address
   output logic   [3:0]                     icache_mem_wmask0         , // WMASK#
   output logic   [31:0]                    icache_mem_din0           , // Write Data
   //input  logic   [31:0]                  icache_mem_dout0          , // Read Data
   
   // SRAM-0 PORT-1, IMEM I/F
   output logic                             icache_mem_clk1           , // CLK
   output logic                             icache_mem_csb1           , // CS#
   output logic  [8:0]                      icache_mem_addr1          , // Address
   input  logic  [31:0]                     icache_mem_dout1          , // Read Data
   `endif

   `ifdef YCR_DCACHE_EN
   // Wishbone ICACHE I/F
   output logic                             wb_dcache_cyc_o           , // strobe/request
   output logic                             wb_dcache_stb_o           , // strobe/request
   output logic   [YCR_WB_WIDTH-1:0]        wb_dcache_adr_o           , // address
   output logic                             wb_dcache_we_o            , // write
   output logic   [YCR_WB_WIDTH-1:0]        wb_dcache_dat_o           , // data output
   output logic   [3:0]                     wb_dcache_sel_o           , // byte enable
   output logic   [9:0]                     wb_dcache_bl_o            , // Burst Length
   output logic                             wb_dcache_bry_o           , // Burst Ready

   input logic   [YCR_WB_WIDTH-1:0]         wb_dcache_dat_i           , // data input
   input logic                              wb_dcache_ack_i           , // acknowlegement
   input logic                              wb_dcache_lack_i          , // last acknowlegement
   input logic                              wb_dcache_err_i           , // error

   // DCACHE PORT-0 SRAM Memory I/F
   output logic                             dcache_mem_clk0           , // CLK
   output logic                             dcache_mem_csb0           , // CS#
   output logic                             dcache_mem_web0           , // WE#
   output logic   [8:0]                     dcache_mem_addr0          , // Address
   output logic   [3:0]                     dcache_mem_wmask0         , // WMASK#
   output logic   [31:0]                    dcache_mem_din0           , // Write Data
   input  logic   [31:0]                    dcache_mem_dout0          , // Read Data
   
   // DCACHE SRAM-0 PORT-1, IMEM I/F
   output logic                             dcache_mem_clk1           , // CLK
   output logic                             dcache_mem_csb1           , // CS#
   output logic  [8:0]                      dcache_mem_addr1          , // Address
   input  logic  [31:0]                     dcache_mem_dout1           // Read Data

   `endif


);
//-------------------------------------------------------------------------------
// Local parameters
//-------------------------------------------------------------------------------
localparam int unsigned YCR_CLUSTER_TOP_RST_SYNC_STAGES_NUM            = 2;

//-------------------------------------------------------------------------------
// Local signal declaration
//-------------------------------------------------------------------------------

logic                                              cpu_intf_rst_n_sync;

`ifdef YCR_ICACHE_EN
   // Wishbone ICACHE I/F
   logic                                           wb_icache_cclk_stb_o; // strobe/request
   logic   [YCR_WB_WIDTH-1:0]                      wb_icache_cclk_adr_o; // address
   logic                                           wb_icache_cclk_we_o;  // write
   logic   [YCR_WB_WIDTH-1:0]                      wb_icache_cclk_dat_o; // data output
   logic   [3:0]                                   wb_icache_cclk_sel_o; // byte enable
   logic   [9:0]                                   wb_icache_cclk_bl_o;  // Burst Length

   logic   [YCR_WB_WIDTH-1:0]                      wb_icache_cclk_dat_i; // data input
   logic                                           wb_icache_cclk_ack_i; // acknowlegement
   logic                                           wb_icache_cclk_lack_i;// last acknowlegement
   logic                                           wb_icache_cclk_err_i; // error
`endif

`ifdef YCR_DCACHE_EN
   // Wishbone ICACHE I/F
   logic                                           wb_dcache_cclk_stb_o; // strobe/request
   logic   [YCR_WB_WIDTH-1:0]                      wb_dcache_cclk_adr_o; // address
   logic                                           wb_dcache_cclk_we_o;  // write
   logic   [YCR_WB_WIDTH-1:0]                      wb_dcache_cclk_dat_o; // data output
   logic   [3:0]                                   wb_dcache_cclk_sel_o; // byte enable
   logic   [9:0]                                   wb_dcache_cclk_bl_o;  // Burst Length

   logic   [YCR_WB_WIDTH-1:0]                      wb_dcache_cclk_dat_i; // data input
   logic                                           wb_dcache_cclk_ack_i; // acknowlegement
   logic                                           wb_dcache_cclk_lack_i;// last acknowlegement
   logic                                           wb_dcache_cclk_err_i; // error
`endif


//-----------------------------------------------------------------------------------
// Variable for sram mux for icache
// ---------------------------------------------------------------------------------
// CACHE SRAM Memory I/F
logic                             icache_mem_csb0_int       ; // CS#
logic                             icache_mem_web0_int       ; // WE#
logic   [8:0]                     icache_mem_addr0_int      ; // Address
logic   [3:0]                     icache_mem_wmask0_int     ; // WMASK#
logic   [31:0]                    icache_mem_din0_int       ; // Write Data
   
// SRAM-0 PORT-1, IMEM I/F
logic                             icache_mem_csb1_int       ; // CS#
logic  [8:0]                      icache_mem_addr1_int      ; // Address

//-----------------------------------------------------------------------------------
// Variable for sram mux for dcache
// ---------------------------------------------------------------------------------
// CACHE SRAM Memory I/F
logic                             dcache_mem_csb0_int       ; // CS#
logic                             dcache_mem_web0_int       ; // WE#
logic   [8:0]                     dcache_mem_addr0_int      ; // Address
logic   [3:0]                     dcache_mem_wmask0_int     ; // WMASK#
logic   [31:0]                    dcache_mem_din0_int       ; // Write Data
   
// SRAM-0 PORT-1, IMEM I/F
logic                             dcache_mem_csb1_int       ; // CS#
logic  [8:0]                      dcache_mem_addr1_int      ; // Address



assign wbd_dmem_cyc_o  = wbd_dmem_stb_o;

//--------------------------------------------
// RISCV clock skew control
//--------------------------------------------
clk_skew_adjust u_skew_core_clk
       (
`ifdef USE_POWER_PINS
     .vccd1                   (vccd1                   ),// User area 1 1.8V supply
     .vssd1                   (vssd1                   ),// User area 1 digital ground
`endif
	    .clk_in               (core_clk_int            ), 
	    .sel                  (cfg_ccska               ), 
	    .clk_out              (core_clk_skew           ) 
       );

//--------------------------------------------
// WB clock skew control
//--------------------------------------------
clk_skew_adjust u_skew_wb_clk
       (
`ifdef USE_POWER_PINS
     .vccd1                   (vccd1                   ),// User area 1 1.8V supply
     .vssd1                   (vssd1                   ),// User area 1 digital ground
`endif
	    .clk_in               (wbd_clk_int             ), 
	    .sel                  (cfg_wcska               ), 
	    .clk_out              (wbd_clk_skew            ) 
       );
//---------------------------------------------------------------------------------
// To avoid core level power hook up, we have brought this signal inside, to
// avoid any cell at digital core level
// --------------------------------------------------------------------------------
assign test_mode = 1'b0;
assign test_rst_n = 1'b0;


//-------------------------------------------------------------------------------
// Reset logic
//-------------------------------------------------------------------------------

// CPU Reset synchronizer
ycr_reset_sync_cell #(
    .STAGES_AMOUNT       (YCR_CLUSTER_TOP_RST_SYNC_STAGES_NUM)
) i_cpu_intf_rstn_reset_sync (
    .rst_n          (pwrup_rst_n          ),
    .clk            (core_clk             ),
    .test_rst_n     (test_rst_n           ),
    .test_mode      (test_mode            ),
    .rst_n_in       (cpu_intf_rst_n       ),
    .rst_n_out      (cpu_intf_rst_n_sync  )
);


`ifdef YCR_ICACHE_EN

// Icache top
icache_top  #(.MEM_BL(`YCR_IMEM_BSIZE) )u_icache (
	.mclk                         (core_clk),	   //Clock input 
	.rst_n                        (cpu_intf_rst_n_sync),  //Active Low Asynchronous Reset Signal Input

	.cfg_pfet_dis                 (cfg_icache_pfet_dis),// To disable Next Pre data Pre fetch, default = 0
	.cfg_ntag_pfet_dis            (cfg_icache_ntag_pfet_dis),// To disable next Tag refill, default = 0
	.cfg_bypass_icache            (cfg_bypass_icache), 

	// Wishbone CPU I/F
        .cpu_mem_req                 (core_icache_req),        // strobe/request
        .cpu_mem_addr                (core_icache_addr),       // address
        .cpu_mem_bl                  (core_icache_bl),       // address
	.cpu_mem_width               (core_icache_width),

        .cpu_mem_req_ack             (core_icache_req_ack),    // data input
        .cpu_mem_rdata               (core_icache_rdata),      // data input
        .cpu_mem_resp                (core_icache_resp),        // acknowlegement

	// Wishbone CPU I/F
        .wb_app_stb_o                 (wb_icache_cclk_stb_o  ), // strobe/request
        .wb_app_adr_o                 (wb_icache_cclk_adr_o  ), // address
        .wb_app_we_o                  (wb_icache_cclk_we_o   ), // write
        .wb_app_dat_o                 (wb_icache_cclk_dat_o  ), // data output
        .wb_app_sel_o                 (wb_icache_cclk_sel_o  ), // byte enable
        .wb_app_bl_o                  (wb_icache_cclk_bl_o   ), // Burst Length
                                                    
        .wb_app_dat_i                 (wb_icache_cclk_dat_i  ), // data input
        .wb_app_ack_i                 (wb_icache_cclk_ack_i  ), // acknowlegement
        .wb_app_lack_i                (wb_icache_cclk_lack_i ), // last acknowlegement
        .wb_app_err_i                 (wb_icache_cclk_err_i  ), // error

        // CACHE SRAM Memory I/F
        .cache_mem_clk0               (icache_mem_clk0        ), // CLK
        .cache_mem_csb0               (icache_mem_csb0_int    ), // CS#
        .cache_mem_web0               (icache_mem_web0_int    ), // WE#
        .cache_mem_addr0              (icache_mem_addr0_int   ), // Address
        .cache_mem_wmask0             (icache_mem_wmask0_int  ), // WMASK#
        .cache_mem_din0               (icache_mem_din0_int    ), // Write Data
        
        // SRAM-0 PORT-1, IMEM I/F
        .cache_mem_clk1               (icache_mem_clk1        ), // CLK
        .cache_mem_csb1               (icache_mem_csb1_int    ), // CS#
        .cache_mem_addr1              (icache_mem_addr1_int   ), // Address
        .cache_mem_dout1              (icache_mem_dout1       ) // Read Data

);

//----------------------------------------------------------------
// As there SRAM timing model is not correct. we have created
// additional position drive data in negedge
// ----------------------------------------------------------------
ycr_sram_mux  u_icache_smux (
   .rst_n                (cpu_intf_rst_n_sync    ),
   .cfg_mem_lphase       (cfg_sram_lphase[0]     ), // 0 - Posedge (Default), 1 - Negedge
   // SRAM Memory I/F, PORT-0
   .mem_clk0_i           (icache_mem_clk0        ), // CLK
   .mem_csb0_i           (icache_mem_csb0_int    ), // CS#
   .mem_web0_i           (icache_mem_web0_int    ), // WE#
   .mem_addr0_i          (icache_mem_addr0_int   ), // Address
   .mem_wmask0_i         (icache_mem_wmask0_int  ), // WMASK#
   .mem_din0_i           (icache_mem_din0_int    ), // Write Data
   
   // SRAM-0 PORT-1, 
   .mem_clk1_i           (icache_mem_clk1        ), // CLK
   .mem_csb1_i           (icache_mem_csb1_int    ), // CS#
   .mem_addr1_i          (icache_mem_addr1_int   ), // Address

   // SRAM Memory I/F, PORT-0
   .mem_csb0_o           (icache_mem_csb0        ), // CS#
   .mem_web0_o           (icache_mem_web0        ), // WE#
   .mem_addr0_o          (icache_mem_addr0       ), // Address
   .mem_wmask0_o         (icache_mem_wmask0      ), // WMASK#
   .mem_din0_o           (icache_mem_din0        ), // Write Data
   
   // SRAM-0 PORT-1, 
   .mem_csb1_o           (icache_mem_csb1        ), // CS#
   .mem_addr1_o          (icache_mem_addr1       )  // Address
);


// Async Wishbone clock domain translation
ycr_async_wbb u_async_icache(

    // Master Port
       .wbm_rst_n       (cpu_intf_rst_n_sync ),  // Regular Reset signal
       .wbm_clk_i       (core_clk ),  // System clock
       .wbm_cyc_i       (wb_icache_cclk_stb_o ),  // strobe/request
       .wbm_stb_i       (wb_icache_cclk_stb_o ),  // strobe/request
       .wbm_adr_i       (wb_icache_cclk_adr_o ),  // address
       .wbm_we_i        (wb_icache_cclk_we_o  ),  // write
       .wbm_dat_i       (wb_icache_cclk_dat_o ),  // data output
       .wbm_sel_i       (wb_icache_cclk_sel_o ),  // byte enable
       .wbm_bl_i        (wb_icache_cclk_bl_o  ),  // Burst Count
       .wbm_dat_o       (wb_icache_cclk_dat_i ),  // data input
       .wbm_ack_o       (wb_icache_cclk_ack_i ),  // acknowlegement
       .wbm_lack_o      (wb_icache_cclk_lack_i),  // Last Burst access
       .wbm_err_o       (wb_icache_cclk_err_i ),  // error

    // Slave Port
       .wbs_rst_n       (wb_rst_n             ),  // Regular Reset signal
       .wbs_clk_i       (wb_clk               ),  // System clock
       .wbs_cyc_o       (wb_icache_cyc_o      ),  // strobe/request
       .wbs_stb_o       (wb_icache_stb_o      ),  // strobe/request
       .wbs_adr_o       (wb_icache_adr_o      ),  // address
       .wbs_we_o        (wb_icache_we_o       ),  // write
       .wbs_dat_o       (                     ),  // data output- Unused
       .wbs_sel_o       (wb_icache_sel_o      ),  // byte enable
       .wbs_bl_o        (wb_icache_bl_o       ),  // Burst Count
       .wbs_bry_o       (wb_icache_bry_o      ),  // Burst Ready
       .wbs_dat_i       (wb_icache_dat_i      ),  // data input
       .wbs_ack_i       (wb_icache_ack_i      ),  // acknowlegement
       .wbs_lack_i      (wb_icache_lack_i     ),  // Last Ack
       .wbs_err_i       (wb_icache_err_i      )   // error

    );



`endif

`ifdef YCR_DCACHE_EN

// dcache top
dcache_top  u_dcache (
	.mclk                         (core_clk),	       //Clock input 
	.rst_n                        (cpu_intf_rst_n_sync),      //Active Low Asynchronous Reset Signal Input

	.cfg_pfet_dis                 (cfg_dcache_pfet_dis),   // To disable Next Pre data Pre fetch, default = 0
	.cfg_force_flush              (cfg_dcache_force_flush),// Force flush
	.cfg_bypass_dcache            (cfg_bypass_dcache), 

	// Wishbone CPU I/F
        .cpu_mem_req                 (core_dcache_req),        // strobe/request
        .cpu_mem_cmd                 (core_dcache_cmd),        // address
        .cpu_mem_addr                (core_dcache_addr),       // address
	.cpu_mem_width               (core_dcache_width),
        .cpu_mem_wdata               (core_dcache_wdata),      // data input

        .cpu_mem_req_ack             (core_dcache_req_ack),    // data input
        .cpu_mem_rdata               (core_dcache_rdata),      // data input
        .cpu_mem_resp                (core_dcache_resp),        // acknowlegement

	// Wishbone CPU I/F
        .wb_app_stb_o                 (wb_dcache_cclk_stb_o  ), // strobe/request
        .wb_app_adr_o                 (wb_dcache_cclk_adr_o  ), // address
        .wb_app_we_o                  (wb_dcache_cclk_we_o   ), // write
        .wb_app_dat_o                 (wb_dcache_cclk_dat_o  ), // data output
        .wb_app_sel_o                 (wb_dcache_cclk_sel_o  ), // byte enable
        .wb_app_bl_o                  (wb_dcache_cclk_bl_o   ), // Burst Length
                                                    
        .wb_app_dat_i                 (wb_dcache_cclk_dat_i  ), // data input
        .wb_app_ack_i                 (wb_dcache_cclk_ack_i  ), // acknowlegement
        .wb_app_lack_i                (wb_dcache_cclk_lack_i ), // last acknowlegement
        .wb_app_err_i                 (wb_dcache_cclk_err_i  ),  // error

        // CACHE SRAM Memory I/F
        .cache_mem_clk0               (dcache_mem_clk0       ), // CLK
        .cache_mem_csb0               (dcache_mem_csb0_int   ), // CS#
        .cache_mem_web0               (dcache_mem_web0_int   ), // WE#
        .cache_mem_addr0              (dcache_mem_addr0_int  ), // Address
        .cache_mem_wmask0             (dcache_mem_wmask0_int ), // WMASK#
        .cache_mem_din0               (dcache_mem_din0_int   ), // Write Data
        .cache_mem_dout0              (dcache_mem_dout0      ), // Read Data
        
        // SRAM-0 PORT-1, IMEM I/F
        .cache_mem_clk1               (dcache_mem_clk1       ), // CLK
        .cache_mem_csb1               (dcache_mem_csb1_int   ), // CS#
        .cache_mem_addr1              (dcache_mem_addr1_int  ), // Address
        .cache_mem_dout1              (dcache_mem_dout1      )  // Read Data

);

//----------------------------------------------------------------
// As there SRAM timing model is not correct. we have created
// additional position drive data in negedge
// ----------------------------------------------------------------
ycr_sram_mux  u_dcache_smux (
   .rst_n                (cpu_intf_rst_n_sync    ),
   .cfg_mem_lphase       (cfg_sram_lphase[1]     ), // 0 - Posedge (Default), 1 - Negedge
   // SRAM Memory I/F, PORT-0
   .mem_clk0_i           (dcache_mem_clk0        ), // CLK
   .mem_csb0_i           (dcache_mem_csb0_int    ), // CS#
   .mem_web0_i           (dcache_mem_web0_int    ), // WE#
   .mem_addr0_i          (dcache_mem_addr0_int   ), // Address
   .mem_wmask0_i         (dcache_mem_wmask0_int  ), // WMASK#
   .mem_din0_i           (dcache_mem_din0_int    ), // Write Data
   
   // SRAM-0 PORT-1, 
   .mem_clk1_i           (dcache_mem_clk1        ), // CLK
   .mem_csb1_i           (dcache_mem_csb1_int    ), // CS#
   .mem_addr1_i          (dcache_mem_addr1_int   ), // Address

   // SRAM Memory I/F, PORT-0
   .mem_csb0_o           (dcache_mem_csb0        ), // CS#
   .mem_web0_o           (dcache_mem_web0        ), // WE#
   .mem_addr0_o          (dcache_mem_addr0       ), // Address
   .mem_wmask0_o         (dcache_mem_wmask0      ), // WMASK#
   .mem_din0_o           (dcache_mem_din0        ), // Write Data
   
   // SRAM-0 PORT-1, 
   .mem_csb1_o           (dcache_mem_csb1        ), // CS#
   .mem_addr1_o          (dcache_mem_addr1       )  // Address
);

// Async Wishbone clock domain translation
ycr_async_wbb u_async_dcache(

    // Master Port
       .wbm_rst_n       (cpu_intf_rst_n_sync ),  // Regular Reset signal
       .wbm_clk_i       (core_clk ),  // System clock
       .wbm_cyc_i       (wb_dcache_cclk_stb_o ),  // strobe/request
       .wbm_stb_i       (wb_dcache_cclk_stb_o ),  // strobe/request
       .wbm_adr_i       (wb_dcache_cclk_adr_o ),  // address
       .wbm_we_i        (wb_dcache_cclk_we_o  ),  // write
       .wbm_dat_i       (wb_dcache_cclk_dat_o ),  // data output
       .wbm_sel_i       (wb_dcache_cclk_sel_o ),  // byte enable
       .wbm_bl_i        (wb_dcache_cclk_bl_o  ),  // Burst Count
       .wbm_dat_o       (wb_dcache_cclk_dat_i ),  // data input
       .wbm_ack_o       (wb_dcache_cclk_ack_i ),  // acknowlegement
       .wbm_lack_o      (wb_dcache_cclk_lack_i),  // Last Burst access
       .wbm_err_o       (wb_dcache_cclk_err_i ),  // error

    // Slave Port
       .wbs_rst_n       (wb_rst_n             ),  // Regular Reset signal
       .wbs_clk_i       (wb_clk               ),  // System clock
       .wbs_cyc_o       (wb_dcache_cyc_o      ),  // strobe/request
       .wbs_stb_o       (wb_dcache_stb_o      ),  // strobe/request
       .wbs_adr_o       (wb_dcache_adr_o      ),  // address
       .wbs_we_o        (wb_dcache_we_o       ),  // write
       .wbs_dat_o       (wb_dcache_dat_o      ),  // data output
       .wbs_sel_o       (wb_dcache_sel_o      ),  // byte enable
       .wbs_bl_o        (wb_dcache_bl_o       ),  // Burst Count
       .wbs_bry_o       (wb_dcache_bry_o      ),  // Burst Ready
       .wbs_dat_i       (wb_dcache_dat_i      ),  // data input
       .wbs_ack_i       (wb_dcache_ack_i      ),  // acknowlegement
       .wbs_lack_i      (wb_dcache_lack_i     ),  // Last Ack
       .wbs_err_i       (wb_dcache_err_i      )   // error

    );



`endif


//-------------------------------------------------------------------------------
// Data memory WB bridge
//-------------------------------------------------------------------------------
ycr_dmem_wb i_dmem_wb (
    .core_rst_n     (cpu_intf_rst_n_sync   ),
    .core_clk       (core_clk           ),
    // Interface to dmem router
    .dmem_req_ack   (core_dmem_req_ack   ),
    .dmem_req       (core_dmem_req       ),
    .dmem_cmd       (core_dmem_cmd       ),
    .dmem_width     (core_dmem_width     ),
    .dmem_addr      (core_dmem_addr      ),
    .dmem_bl        (core_dmem_bl        ),
    .dmem_wdata     (core_dmem_wdata     ),
    .dmem_rdata     (core_dmem_rdata     ),
    .dmem_resp      (core_dmem_resp      ),
    // WB interface
    .wb_rst_n       (wb_rst_n          ),
    .wb_clk         (wb_clk            ),
    .wbd_stb_o      (wbd_dmem_stb_o    ), 
    .wbd_adr_o      (wbd_dmem_adr_o    ), 
    .wbd_we_o       (wbd_dmem_we_o     ),  
    .wbd_dat_o      (wbd_dmem_dat_o    ), 
    .wbd_sel_o      (wbd_dmem_sel_o    ), 
    .wbd_bl_o       (wbd_dmem_bl_o     ), 
    .wbd_bry_o      (wbd_dmem_bry_o     ), 
    .wbd_dat_i      (wbd_dmem_dat_i    ), 
    .wbd_ack_i      (wbd_dmem_ack_i    ), 
    .wbd_lack_i     (wbd_dmem_lack_i    ), 
    .wbd_err_i      (wbd_dmem_err_i    )
);

endmodule : ycr_intf
