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
////  https://github.com/dineshannayya/ycr1.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     Holds interface block and timer & reset sync logic               ////
////     Instruction memory router                                        ////
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

`include "ycr1_arch_description.svh"
`include "ycr1_memif.svh"
`include "ycr1_wb.svh"
`ifdef YCR1_IPIC_EN
`include "ycr1_ipic.svh"
`endif // YCR1_IPIC_EN

`ifdef YCR1_TCM_EN
 `define YCR1_IMEM_ROUTER_EN
`endif // YCR1_TCM_EN

module ycr1_intf (
    // Control
    input   logic                           pwrup_rst_n,            // Power-Up Reset
    input   logic                           rst_n,                  // Regular Reset signal
    input   logic                           cpu_rst_n,              // CPU Reset (Core Reset)
    input   logic                           core_clk,               // Core clock
    input   logic                           rtc_clk,                // Real-time clock
    output  logic [63:0]                    riscv_debug,

`ifdef YCR1_DBG_EN
    // -- JTAG I/F
    input   logic                           trst_n,
`endif // YCR1_DBG_EN

`ifndef YCR1_TCM_MEM
    // DFFRAM I/F

   output  logic                             tcm_dffram_clk0    , // CLK
   output  logic                             tcm_dffram_cs0     , // Chip Select
   output  logic    [7:0]                    tcm_dffram_addr0   , // Address
   output  logic    [3:0]                    tcm_dffram_wmask0  , // Write Mask
   output  logic    [31:0]                   tcm_dffram_din0    , // Write Data
   input   logic    [31:0]                   tcm_dffram_dout0   , // Read Data
   
   output  logic                             tcm_dffram_clk1    , // CLK
   output  logic                             tcm_dffram_cs1     , // Chip Select
   output  logic    [7:0]                    tcm_dffram_addr1   , // Address
   output  logic    [3:0]                    tcm_dffram_wmask1  , // Write Mask
   output  logic    [31:0]                   tcm_dffram_din1    , // Write Data
   input   logic    [31:0]                   tcm_dffram_dout1   , // Read Data
`endif

    input   logic                           wb_rst_n,       // Wish bone reset
    input   logic                           wb_clk,         // wish bone clock
    // Instruction Memory Interface
    //output  logic                           wbd_imem_stb_o, // strobe/request
    //output  logic   [YCR1_WB_WIDTH-1:0]     wbd_imem_adr_o, // address
    //output  logic                           wbd_imem_we_o,  // write
    //output  logic   [YCR1_WB_WIDTH-1:0]     wbd_imem_dat_o, // data output
    //output  logic   [3:0]                   wbd_imem_sel_o, // byte enable
    //input   logic   [YCR1_WB_WIDTH-1:0]     wbd_imem_dat_i, // data input
    //input   logic                           wbd_imem_ack_i, // acknowlegement
    //input   logic                           wbd_imem_err_i,  // error

    // Data Memory Interface
    output  logic                           wbd_dmem_stb_o, // strobe/request
    output  logic   [YCR1_WB_WIDTH-1:0]     wbd_dmem_adr_o, // address
    output  logic                           wbd_dmem_we_o,  // write
    output  logic   [YCR1_WB_WIDTH-1:0]     wbd_dmem_dat_o, // data output
    output  logic   [3:0]                   wbd_dmem_sel_o, // byte enable
    input   logic   [YCR1_WB_WIDTH-1:0]     wbd_dmem_dat_i, // data input
    input   logic                           wbd_dmem_ack_i, // acknowlegement
    input   logic                           wbd_dmem_err_i, // error

   `ifdef YCR1_ICACHE_EN
   // Wishbone ICACHE I/F
   output logic                             wb_icache_cyc_o, // strobe/request
   output logic                             wb_icache_stb_o, // strobe/request
   output logic   [YCR1_WB_WIDTH-1:0]       wb_icache_adr_o, // address
   output logic                             wb_icache_we_o,  // write
   output logic   [3:0]                     wb_icache_sel_o, // byte enable
   output logic   [9:0]                     wb_icache_bl_o,  // Burst Length
   output logic                             wb_icache_bry_o, // Burst Ready 

   input logic   [YCR1_WB_WIDTH-1:0]        wb_icache_dat_i, // data input
   input logic                              wb_icache_ack_i, // acknowlegement
   input logic                              wb_icache_lack_i,// last acknowlegement
   input logic                              wb_icache_err_i,  // error

    // DFFRAM I/F

   output  logic                             icache_dffram_clk0    , // CLK
   output  logic                             icache_dffram_cs0     , // Chip Select
   output  logic    [7:0]                    icache_dffram_addr0   , // Address
   output  logic    [3:0]                    icache_dffram_wmask0  , // Write Mask
   output  logic    [31:0]                   icache_dffram_din0    , // Write Data
   input   logic    [31:0]                   icache_dffram_dout0   , // Read Data
   
   output  logic                             icache_dffram_clk1    , // CLK
   output  logic                             icache_dffram_cs1     , // Chip Select
   output  logic    [7:0]                    icache_dffram_addr1   , // Address
   output  logic    [3:0]                    icache_dffram_wmask1  , // Write Mask
   output  logic    [31:0]                   icache_dffram_din1    , // Write Data
   input   logic    [31:0]                   icache_dffram_dout1   , // Read Data
   `endif

   `ifdef YCR1_DCACHE_EN
   // Wishbone ICACHE I/F
   output logic                             wb_dcache_cyc_o, // strobe/request
   output logic                             wb_dcache_stb_o, // strobe/request
   output logic   [YCR1_WB_WIDTH-1:0]       wb_dcache_adr_o, // address
   output logic                             wb_dcache_we_o,  // write
   output logic   [YCR1_WB_WIDTH-1:0]       wb_dcache_dat_o, // data output
   output logic   [3:0]                     wb_dcache_sel_o, // byte enable
   output logic   [9:0]                     wb_dcache_bl_o,  // Burst Length
   output logic                             wb_dcache_bry_o, // Burst Ready

   input logic   [YCR1_WB_WIDTH-1:0]        wb_dcache_dat_i, // data input
   input logic                              wb_dcache_ack_i, // acknowlegement
   input logic                              wb_dcache_lack_i,// last acknowlegement
   input logic                              wb_dcache_err_i,  // error

    // DFFRAM I/F

   output  logic                             dcache_dffram_clk0    , // CLK
   output  logic                             dcache_dffram_cs0     , // Chip Select
   output  logic    [7:0]                    dcache_dffram_addr0   , // Address
   output  logic    [3:0]                    dcache_dffram_wmask0  , // Write Mask
   output  logic    [31:0]                   dcache_dffram_din0    , // Write Data
   input   logic    [31:0]                   dcache_dffram_dout0   , // Read Data
   
   output  logic                             dcache_dffram_clk1    , // CLK
   output  logic                             dcache_dffram_cs1     , // Chip Select
   output  logic    [7:0]                    dcache_dffram_addr1   , // Address
   output  logic    [3:0]                    dcache_dffram_wmask1  , // Write Mask
   output  logic    [31:0]                   dcache_dffram_din1    , // Write Data
   input   logic    [31:0]                   dcache_dffram_dout1   , // Read Data

   `endif

    // Common
    output   logic                          pwrup_rst_n_sync,                // Power-Up reset
    output   logic                          rst_n_sync,                      // Regular reset
    output   logic                          cpu_rst_n_sync,                  // CPU reset
    output   logic                          test_mode,                  // DFT Test Mode
    output   logic                          test_rst_n,                 // DFT Test Reset
    input    logic                          core_rst_n_local,               // Core reset
    input    logic   [48:0]                 core_debug  ,
`ifdef YCR1_DBG_EN
    // Debug Interface
    output   logic                          tapc_trst_n,                // Test Reset (TRSTn)
`endif
    // Memory-mapped external timer
    output   logic [63:0]                   timer_val,          // Machine timer value
    output   logic                          timer_irq,
    // Instruction Memory Interface
    output   logic                          core_imem_req_ack,        // IMEM request acknowledge
    input    logic                          core_imem_req,            // IMEM request
    input    logic                          core_imem_cmd,            // IMEM command
    input    logic [`YCR1_IMEM_AWIDTH-1:0]  core_imem_addr,           // IMEM address
    input    logic [`YCR1_IMEM_BSIZE-1:0]   core_imem_bl,           // IMEM burst size
    output   logic [`YCR1_IMEM_DWIDTH-1:0]  core_imem_rdata,          // IMEM read data
    output   logic [1:0]                    core_imem_resp,           // IMEM response

    // Data Memory Interface
    output   logic                          core_dmem_req_ack,        // DMEM request acknowledge
    input    logic                          core_dmem_req,            // DMEM request
    input    logic                          core_dmem_cmd,            // DMEM command
    input    logic[1:0]                     core_dmem_width,          // DMEM data width
    input    logic [`YCR1_DMEM_AWIDTH-1:0]  core_dmem_addr,           // DMEM address
    input    logic [`YCR1_DMEM_DWIDTH-1:0]  core_dmem_wdata,          // DMEM write data
    output   logic [`YCR1_DMEM_DWIDTH-1:0]  core_dmem_rdata,          // DMEM read data
    output   logic [1:0]                    core_dmem_resp            // DMEM response

);
//-------------------------------------------------------------------------------
// Local parameters
//-------------------------------------------------------------------------------
localparam int unsigned YCR1_CLUSTER_TOP_RST_SYNC_STAGES_NUM            = 2;

//-------------------------------------------------------------------------------
// Local signal declaration
//-------------------------------------------------------------------------------

// Instruction memory interface from router to WB bridge
logic                                               wb_imem_req_ack;
logic                                               wb_imem_req;
logic                                               wb_imem_cmd;
logic [`YCR1_IMEM_AWIDTH-1:0]                       wb_imem_addr;
logic [`YCR1_IMEM_BSIZE-1:0]                        wb_imem_bl;
logic [`YCR1_IMEM_DWIDTH-1:0]                       wb_imem_rdata;
logic [1:0]                                         wb_imem_resp;

// Data memory interface from router to WB bridge
logic                                               wb_dmem_req_ack;
logic                                               wb_dmem_req;
logic                                               wb_dmem_cmd;
logic [1:0]                                         wb_dmem_width;
logic [`YCR1_DMEM_AWIDTH-1:0]                       wb_dmem_addr;
logic [`YCR1_DMEM_DWIDTH-1:0]                       wb_dmem_wdata;
logic [`YCR1_DMEM_DWIDTH-1:0]                       wb_dmem_rdata;
logic [1:0]                                         wb_dmem_resp;

`ifdef YCR1_TCM_EN
// Instruction memory interface from router to TCM
logic                                               tcm_imem_req_ack;
logic                                               tcm_imem_req;
logic                                               tcm_imem_cmd;
logic [`YCR1_IMEM_AWIDTH-1:0]                       tcm_imem_addr;
logic [`YCR1_IMEM_DWIDTH-1:0]                       tcm_imem_rdata;
logic [1:0]                                         tcm_imem_resp;

// Data memory interface from router to TCM
logic                                               tcm_dmem_req_ack;
logic                                               tcm_dmem_req;
logic                                               tcm_dmem_cmd;
logic [1:0]                                         tcm_dmem_width;
logic [`YCR1_DMEM_AWIDTH-1:0]                       tcm_dmem_addr;
logic [`YCR1_DMEM_DWIDTH-1:0]                       tcm_dmem_wdata;
logic [`YCR1_DMEM_DWIDTH-1:0]                       tcm_dmem_rdata;
logic [1:0]                                         tcm_dmem_resp;
`endif // YCR1_TCM_EN

// Data memory interface from router to memory-mapped timer
logic                                               timer_dmem_req_ack;
logic                                               timer_dmem_req;
logic                                               timer_dmem_cmd;
logic [1:0]                                         timer_dmem_width;
logic [`YCR1_DMEM_AWIDTH-1:0]                       timer_dmem_addr;
logic [`YCR1_DMEM_DWIDTH-1:0]                       timer_dmem_wdata;
logic [`YCR1_DMEM_DWIDTH-1:0]                       timer_dmem_rdata;
logic [1:0]                                         timer_dmem_resp;

`ifdef YCR1_ICACHE_EN
// Instruction memory interface from router to icache
logic                                               icache_imem_req_ack;
logic                                               icache_imem_req;
logic                                               icache_imem_cmd;
logic [`YCR1_IMEM_AWIDTH-1:0]                       icache_imem_addr;
logic [`YCR1_IMEM_BSIZE-1:0]                        icache_imem_bl;
logic [`YCR1_IMEM_DWIDTH-1:0]                       icache_imem_rdata;
logic [1:0]                                         icache_imem_resp;

// Data memory interface from router to icache
logic                                               icache_dmem_req_ack;
logic                                               icache_dmem_req;
logic                                               icache_dmem_cmd;
logic [1:0]                                         icache_dmem_width;
logic [`YCR1_DMEM_AWIDTH-1:0]                       icache_dmem_addr;
logic [`YCR1_DMEM_DWIDTH-1:0]                       icache_dmem_wdata;
logic [`YCR1_DMEM_DWIDTH-1:0]                       icache_dmem_rdata;
logic [1:0]                                         icache_dmem_resp;

// instruction/Data memory interface towards icache
logic                                               icache_req_ack;
logic                                               icache_req;
logic                                               icache_cmd;
logic [1:0]                                         icache_width;
logic [`YCR1_IMEM_AWIDTH-1:0]                       icache_addr;
logic [`YCR1_IMEM_BSIZE-1:0]                        icache_bl;
logic [`YCR1_IMEM_DWIDTH-1:0]                       icache_wdata;
logic [`YCR1_IMEM_DWIDTH-1:0]                       icache_rdata;
logic [1:0]                                         icache_resp;

`endif // YCR1_ICACHE_EN

`ifdef YCR1_DCACHE_EN
// Instruction memory interface from router to dcache
logic                                               dcache_imem_req_ack;
logic                                               dcache_imem_req;
logic                                               dcache_imem_cmd;
logic [`YCR1_IMEM_AWIDTH-1:0]                       dcache_imem_addr;
logic [`YCR1_IMEM_DWIDTH-1:0]                       dcache_imem_rdata;
logic [1:0]                                         dcache_imem_resp;

// Data memory interface from router to icache
logic                                               dcache_dmem_req_ack;
logic                                               dcache_dmem_req;
logic                                               dcache_dmem_cmd;
logic [1:0]                                         dcache_dmem_width;
logic [`YCR1_DMEM_AWIDTH-1:0]                       dcache_dmem_addr;
logic [`YCR1_DMEM_DWIDTH-1:0]                       dcache_dmem_wdata;
logic [`YCR1_DMEM_DWIDTH-1:0]                       dcache_dmem_rdata;
logic [1:0]                                         dcache_dmem_resp;

// instruction/Data memory interface towards icache
logic                                               dcache_req_ack;
logic                                               dcache_req;
logic                                               dcache_cmd;
logic [1:0]                                         dcache_width;
logic [`YCR1_DMEM_AWIDTH-1:0]                       dcache_addr;
logic [`YCR1_DMEM_DWIDTH-1:0]                       dcache_wdata;
logic [`YCR1_DMEM_DWIDTH-1:0]                       dcache_rdata;
logic [1:0]                                         dcache_resp;

`endif // YCR1_ICACHE_EN

`ifdef YCR1_ICACHE_EN
   // Wishbone ICACHE I/F
   logic                             wb_icache_cclk_stb_o; // strobe/request
   logic   [YCR1_WB_WIDTH-1:0]       wb_icache_cclk_adr_o; // address
   logic                             wb_icache_cclk_we_o;  // write
   logic   [YCR1_WB_WIDTH-1:0]       wb_icache_cclk_dat_o; // data output
   logic   [3:0]                     wb_icache_cclk_sel_o; // byte enable
   logic   [9:0]                     wb_icache_cclk_bl_o;  // Burst Length

   logic   [YCR1_WB_WIDTH-1:0]       wb_icache_cclk_dat_i; // data input
   logic                             wb_icache_cclk_ack_i; // acknowlegement
   logic                             wb_icache_cclk_lack_i;// last acknowlegement
   logic                             wb_icache_cclk_err_i; // error
`endif

`ifdef YCR1_DCACHE_EN
   // Wishbone ICACHE I/F
   logic                             wb_dcache_cclk_stb_o; // strobe/request
   logic   [YCR1_WB_WIDTH-1:0]       wb_dcache_cclk_adr_o; // address
   logic                             wb_dcache_cclk_we_o;  // write
   logic   [YCR1_WB_WIDTH-1:0]       wb_dcache_cclk_dat_o; // data output
   logic   [3:0]                     wb_dcache_cclk_sel_o; // byte enable
   logic   [9:0]                     wb_dcache_cclk_bl_o;  // Burst Length

   logic   [YCR1_WB_WIDTH-1:0]       wb_dcache_cclk_dat_i; // data input
   logic                             wb_dcache_cclk_ack_i; // acknowlegement
   logic                             wb_dcache_cclk_lack_i;// last acknowlegement
   logic                             wb_dcache_cclk_err_i; // error
`endif
`ifndef YCR1_TCM_MEM
    // SRAM-1 PORT-0
    logic                           sram1_clk0;
    logic                           sram1_csb0;
    logic                           sram1_web0;
    logic   [8:0]                   sram1_addr0;
    logic   [3:0]                   sram1_wmask0;
    logic   [31:0]                  sram1_din0;
    logic   [31:0]                  sram1_dout0;

    // SRAM-1 PORT-1
    logic                           sram1_clk1;
    logic                           sram1_csb1;
    logic  [8:0]                    sram1_addr1;
    logic  [31:0]                   sram1_dout1;
`endif

logic [31:0]                        riscv_glbl_cfg;   
//---------------------------------------------------------------------------------
// To avoid core level power hook up, we have brought this signal inside, to
// avoid any cell at digital core level
// --------------------------------------------------------------------------------
assign test_mode = 1'b0;
assign test_rst_n = 1'b0;

assign riscv_debug = {core_imem_req_ack,core_imem_req,core_imem_cmd,core_imem_resp[1:0],
	              core_dmem_req_ack,core_dmem_req,core_dmem_cmd,core_dmem_resp[1:0],
		      wb_imem_req,wb_dmem_req,wb_imem_cmd,wb_imem_resp[1:0], core_debug };


wire cfg_icache_pfet_dis      = riscv_glbl_cfg[0];
wire cfg_icache_ntag_pfet_dis = riscv_glbl_cfg[1];

wire cfg_dcache_pfet_dis      = riscv_glbl_cfg[2];
wire cfg_dcache_force_flush   = riscv_glbl_cfg[3];
//-------------------------------------------------------------------------------
// Reset logic
//-------------------------------------------------------------------------------
// Power-Up Reset synchronizer
ycr1_reset_sync_cell #(
    .STAGES_AMOUNT       (YCR1_CLUSTER_TOP_RST_SYNC_STAGES_NUM)
) i_pwrup_rstn_reset_sync (
    .rst_n          (pwrup_rst_n     ),
    .clk            (core_clk        ),
    .test_rst_n     (test_rst_n      ),
    .test_mode      (test_mode       ),
    .rst_n_in       (1'b1            ),
    .rst_n_out      (pwrup_rst_n_sync)
);

// Regular Reset synchronizer
ycr1_reset_sync_cell #(
    .STAGES_AMOUNT       (YCR1_CLUSTER_TOP_RST_SYNC_STAGES_NUM)
) i_rstn_reset_sync (
    .rst_n          (pwrup_rst_n     ),
    .clk            (core_clk        ),
    .test_rst_n     (test_rst_n      ),
    .test_mode      (test_mode       ),
    .rst_n_in       (rst_n           ),
    .rst_n_out      (rst_n_sync      )
);

// CPU Reset synchronizer
ycr1_reset_sync_cell #(
    .STAGES_AMOUNT       (YCR1_CLUSTER_TOP_RST_SYNC_STAGES_NUM)
) i_cpu_rstn_reset_sync (
    .rst_n          (pwrup_rst_n     ),
    .clk            (core_clk        ),
    .test_rst_n     (test_rst_n      ),
    .test_mode      (test_mode       ),
    .rst_n_in       (cpu_rst_n       ),
    .rst_n_out      (cpu_rst_n_sync  )
);

`ifdef YCR1_DBG_EN
// TAPC Reset
ycr1_reset_and2_cell i_tapc_rstn_and2_cell (
    .rst_n_in       ({trst_n, pwrup_rst_n}),
    .test_rst_n     (test_rst_n      ),
    .test_mode      (test_mode       ),
    .rst_n_out      (tapc_trst_n     )
);
`endif // YCR1_DBG_EN

`ifdef YCR1_TCM_EN
//-------------------------------------------------------------------------------
// TCM instance
//-------------------------------------------------------------------------------
ycr1_tcm_router #(
    .YCR1_TCM_SIZE  (`YCR1_DMEM_AWIDTH'(~YCR1_TCM_ADDR_MASK + 1'b1))
) i_tcm (
    .clk            (core_clk        ),
    .rst_n          (core_rst_n_local),

`ifndef YCR1_TCM_MEM
	// DFFRAM I/F
        .tcm_dffram_clk0            (tcm_dffram_clk0    ), // CLK
        .tcm_dffram_cs0             (tcm_dffram_cs0     ), // Chip Select
        .tcm_dffram_addr0           (tcm_dffram_addr0   ), // Address
        .tcm_dffram_wmask0          (tcm_dffram_wmask0  ), // Write Mask
        .tcm_dffram_din0            (tcm_dffram_din0    ), // Write Data
        .tcm_dffram_dout0           (tcm_dffram_dout0   ), // Read Data
                                                    
        .tcm_dffram_clk1            (tcm_dffram_clk1    ), // CLK
        .tcm_dffram_cs1             (tcm_dffram_cs1     ), // Chip Select
        .tcm_dffram_addr1           (tcm_dffram_addr1   ), // Address
        .tcm_dffram_wmask1          (tcm_dffram_wmask1  ), // Write Mask
        .tcm_dffram_din1            (tcm_dffram_din1    ), // Write Data
        .tcm_dffram_dout1           (tcm_dffram_dout1   ), // Read Data

`endif


    // Instruction interface to TCM
    .imem_req_ack   (tcm_imem_req_ack),
    .imem_req       (tcm_imem_req    ),
    .imem_addr      (tcm_imem_addr   ),
    .imem_rdata     (tcm_imem_rdata  ),
    .imem_resp      (tcm_imem_resp   ),

    // Data interface to TCM
    .dmem_req_ack   (tcm_dmem_req_ack),
    .dmem_req       (tcm_dmem_req    ),
    .dmem_cmd       (tcm_dmem_cmd    ),
    .dmem_width     (tcm_dmem_width  ),
    .dmem_addr      (tcm_dmem_addr   ),
    .dmem_wdata     (tcm_dmem_wdata  ),
    .dmem_rdata     (tcm_dmem_rdata  ),
    .dmem_resp      (tcm_dmem_resp   )
);
`endif // YCR1_TCM_EN


//-------------------------------------------------------------------------------
// Memory-mapped timer instance
//-------------------------------------------------------------------------------
ycr1_timer i_timer (
    // Common
    .rst_n          (core_rst_n_local  ),
    .clk            (core_clk          ),
    .rtc_clk        (rtc_clk           ),

    // Memory interface
    .dmem_req       (timer_dmem_req    ),
    .dmem_cmd       (timer_dmem_cmd    ),
    .dmem_width     (timer_dmem_width  ),
    .dmem_addr      (timer_dmem_addr   ),
    .dmem_wdata     (timer_dmem_wdata  ),
    .dmem_req_ack   (timer_dmem_req_ack),
    .dmem_rdata     (timer_dmem_rdata  ),
    .dmem_resp      (timer_dmem_resp   ),

    // Timer interface
    .timer_val      (timer_val         ),
    .timer_irq      (timer_irq         ),

    .riscv_glbl_cfg (riscv_glbl_cfg    )
);


`ifdef YCR1_IMEM_ROUTER_EN
//-------------------------------------------------------------------------------
// Instruction memory router
//-------------------------------------------------------------------------------
ycr1_imem_router #(
 `ifdef YCR1_ICACHE_EN
    .YCR1_PORT1_ADDR_MASK     (YCR1_ICACHE_ADDR_MASK),
    .YCR1_PORT1_ADDR_PATTERN  (YCR1_ICACHE_ADDR_PATTERN),
`else // YCR1_ICACHE_EN
    .YCR1_PORT1_ADDR_MASK       (32'h00000000),
    .YCR1_PORT1_ADDR_PATTERN    (32'hFFFFFFFF),
`endif // YCR1_ICAHCE_EN
 
`ifdef YCR1_DCACHE_EN
    .YCR1_PORT2_ADDR_MASK     (YCR1_DCACHE_ADDR_MASK),
    .YCR1_PORT2_ADDR_PATTERN  (YCR1_DCACHE_ADDR_PATTERN),
`else // YCR1_DCACHE_EN
    .YCR1_PORT2_ADDR_MASK       (32'h00000000),
    .YCR1_PORT2_ADDR_PATTERN    (32'hFFFFFFFF),
`endif // YCR1_DCAHCE_EN

 `ifdef YCR1_TCM_EN
    .YCR1_PORT3_ADDR_MASK     (YCR1_TCM_ADDR_MASK),
    .YCR1_PORT3_ADDR_PATTERN  (YCR1_TCM_ADDR_PATTERN)
`else // YCR1_TCM_EN
    .YCR1_PORT3_ADDR_MASK       (32'h00000000),
    .YCR1_PORT3_ADDR_PATTERN    (32'hFFFFFFFF)
`endif // YCR1_TCM_EN
) i_imem_router (
    .rst_n          (core_rst_n_local    ),
    .clk            (core_clk            ),
    // Interface to core
    .imem_req_ack   (core_imem_req_ack   ),
    .imem_req       (core_imem_req       ),
    .imem_cmd       (core_imem_cmd       ),
    .imem_addr      (core_imem_addr      ),
    .imem_bl        (core_imem_bl        ),
    .imem_rdata     (core_imem_rdata     ),
    .imem_resp      (core_imem_resp      ),

    // Interface to WB bridge
    .port0_req_ack  (wb_imem_req_ack     ),
    .port0_req      (wb_imem_req         ),
    .port0_cmd      (wb_imem_cmd         ),
    .port0_addr     (wb_imem_addr        ),
    .port0_bl       (wb_imem_bl          ),
    .port0_rdata    (wb_imem_rdata       ),
    .port0_resp     (wb_imem_resp        ),

 `ifdef YCR1_ICACHE_EN
    // Interface to icache
    .port1_req_ack  (icache_imem_req_ack ),
    .port1_req      (icache_imem_req     ),
    .port1_cmd      (icache_imem_cmd     ),
    .port1_addr     (icache_imem_addr    ),
    .port1_bl       (icache_imem_bl      ),
    .port1_rdata    (icache_imem_rdata   ),
    .port1_resp     (icache_imem_resp    ),
`else // YCR1_ICACHE_EN
    .port1_req_ack  (1'b0),
    .port1_req      (                    ),
    .port1_cmd      (                    ),
    .port1_addr     (                    ),
    .port1_bl       (                    ),
    .port1_rdata    (32'h0               ),
    .port1_resp     (YCR1_MEM_RESP_RDY_ER),
`endif // YCR1_ICACHE_EN
 
`ifdef YCR1_DCACHE_EN
    // Interface to dcache
    .port2_req_ack  (dcache_imem_req_ack ),
    .port2_req      (dcache_imem_req     ),
    .port2_cmd      (dcache_imem_cmd     ),
    .port2_addr     (dcache_imem_addr    ),
    .port2_rdata    (dcache_imem_rdata   ),
    .port2_resp     (dcache_imem_resp    ),
`else // YCR1_ICACHE_EN
    .port2_req_ack  (1'b0),
    .port2_req      (                    ),
    .port2_cmd      (                    ),
    .port2_addr     (                    ),
    .port2_rdata    (32'h0               ),
    .port2_resp     (YCR1_MEM_RESP_RDY_ER),
`endif // YCR1_ICACHE_EN

 `ifdef YCR1_TCM_EN
    // Interface to TCM
    .port3_req_ack  (tcm_imem_req_ack ),
    .port3_req      (tcm_imem_req     ),
    .port3_cmd      (tcm_imem_cmd     ),
    .port3_addr     (tcm_imem_addr    ),
    .port3_rdata    (tcm_imem_rdata   ),
    .port3_resp     (tcm_imem_resp    )
`else // YCR1_TCM_EN
    .port3_req_ack  (1'b0),
    .port3_req      (                    ),
    .port3_cmd      (                    ),
    .port3_addr     (                    ),
    .port3_rdata    (32'h0               ),
    .port3_resp     (YCR1_MEM_RESP_RDY_ER)
`endif // YCR1_TCM_EN
);

`else // YCR1_IMEM_ROUTER_EN

assign wb_imem_req          = core_imem_req;
assign wb_imem_cmd          = core_imem_cmd;
assign wb_imem_addr         = core_imem_addr;
assign wb_imem_bl           = core_imem_bl;
assign core_imem_req_ack    = wb_imem_req_ack;
assign core_imem_resp       = wb_imem_resp;
assign core_imem_rdata      = wb_imem_rdata;

`endif // YCR1_IMEM_ROUTER_EN

//-------------------------------------------------------------------------------
// Data memory router
//-------------------------------------------------------------------------------
ycr1_dmem_router #(

`ifdef YCR1_ICACHE_EN
    .YCR1_PORT1_ADDR_MASK       (YCR1_ICACHE_ADDR_MASK),
    .YCR1_PORT1_ADDR_PATTERN    (YCR1_ICACHE_ADDR_PATTERN),
`else // YCR1_ICACHE_EN
    .YCR1_PORT1_ADDR_MASK       (32'h00000000),
    .YCR1_PORT1_ADDR_PATTERN    (32'hFFFFFFFF),
`endif // YCR1_ICACHE_EN

`ifdef YCR1_DCACHE_EN
    .YCR1_PORT2_ADDR_MASK       (YCR1_DCACHE_ADDR_MASK),
    .YCR1_PORT2_ADDR_PATTERN    (YCR1_DCACHE_ADDR_PATTERN),
`else // YCR1_DCACHE_EN
    .YCR1_PORT2_ADDR_MASK       (32'h00000000),
    .YCR1_PORT2_ADDR_PATTERN    (32'hFFFFFFFF),
`endif // YCR1_DCACHE_EN

`ifdef YCR1_TCM_EN
    .YCR1_PORT3_ADDR_MASK       (YCR1_TCM_ADDR_MASK),
    .YCR1_PORT3_ADDR_PATTERN    (YCR1_TCM_ADDR_PATTERN),
`else // YCR1_TCM_EN
    .YCR1_PORT3_ADDR_MASK       (32'h00000000),
    .YCR1_PORT3_ADDR_PATTERN    (32'hFFFFFFFF),
`endif // YCR1_TCM_EN

    .YCR1_PORT4_ADDR_MASK       (YCR1_TIMER_ADDR_MASK),
    .YCR1_PORT4_ADDR_PATTERN    (YCR1_TIMER_ADDR_PATTERN)

) i_dmem_router (
    .rst_n          (core_rst_n_local    ),
    .clk            (core_clk            ),
    // Interface to core
    .dmem_req_ack   (core_dmem_req_ack   ),
    .dmem_req       (core_dmem_req       ),
    .dmem_cmd       (core_dmem_cmd       ),
    .dmem_width     (core_dmem_width     ),
    .dmem_addr      (core_dmem_addr      ),
    .dmem_wdata     (core_dmem_wdata     ),
    .dmem_rdata     (core_dmem_rdata     ),
    .dmem_resp      (core_dmem_resp      ),

`ifdef YCR1_ICACHE_EN
    // Interface to TCM
    .port1_req_ack  (icache_dmem_req_ack    ),
    .port1_req      (icache_dmem_req        ),
    .port1_cmd      (icache_dmem_cmd        ),
    .port1_width    (icache_dmem_width      ),
    .port1_addr     (icache_dmem_addr       ),
    .port1_wdata    (icache_dmem_wdata      ),
    .port1_rdata    (icache_dmem_rdata      ),
    .port1_resp     (icache_dmem_resp       ),
`else // YCR1_ICACHE_EN
    .port1_req_ack  (1'b0),
    .port1_req      (                    ),
    .port1_cmd      (                    ),
    .port1_width    (                    ),
    .port1_addr     (                    ),
    .port1_wdata    (                    ),
    .port1_rdata    (32'h0               ),
    .port1_resp     (YCR1_MEM_RESP_RDY_ER),
`endif // YCR1_ICACHE_EN

`ifdef YCR1_DCACHE_EN
    // Interface to TCM
    .port2_req_ack  (dcache_dmem_req_ack    ),
    .port2_req      (dcache_dmem_req        ),
    .port2_cmd      (dcache_dmem_cmd        ),
    .port2_width    (dcache_dmem_width      ),
    .port2_addr     (dcache_dmem_addr       ),
    .port2_wdata    (dcache_dmem_wdata      ),
    .port2_rdata    (dcache_dmem_rdata      ),
    .port2_resp     (dcache_dmem_resp       ),
`else // YCR1_ICACHE_EN
    .port2_req_ack  (1'b0),
    .port2_req      (                    ),
    .port2_cmd      (                    ),
    .port2_width    (                    ),
    .port2_addr     (                    ),
    .port2_wdata    (                    ),
    .port2_rdata    (32'h0               ),
    .port2_resp     (YCR1_MEM_RESP_RDY_ER),
`endif // YCR1_ICACHE_EN

`ifdef YCR1_TCM_EN
    // Interface to TCM
    .port3_req_ack  (tcm_dmem_req_ack    ),
    .port3_req      (tcm_dmem_req        ),
    .port3_cmd      (tcm_dmem_cmd        ),
    .port3_width    (tcm_dmem_width      ),
    .port3_addr     (tcm_dmem_addr       ),
    .port3_wdata    (tcm_dmem_wdata      ),
    .port3_rdata    (tcm_dmem_rdata      ),
    .port3_resp     (tcm_dmem_resp       ),
`else // YCR1_TCM_EN
    .port3_req_ack  (1'b0),
    .port3_req      (                    ),
    .port3_cmd      (                    ),
    .port3_width    (                    ),
    .port3_addr     (                    ),
    .port3_wdata    (                    ),
    .port3_rdata    (32'h0               ),
    .port3_resp     (YCR1_MEM_RESP_RDY_ER),
`endif // YCR1_TCM_EN

    // Interface to memory-mapped timer
    .port4_req_ack  (timer_dmem_req_ack  ),
    .port4_req      (timer_dmem_req      ),
    .port4_cmd      (timer_dmem_cmd      ),
    .port4_width    (timer_dmem_width    ),
    .port4_addr     (timer_dmem_addr     ),
    .port4_wdata    (timer_dmem_wdata    ),
    .port4_rdata    (timer_dmem_rdata    ),
    .port4_resp     (timer_dmem_resp     ),

    // Interface to WB bridge
    .port0_req_ack  (wb_dmem_req_ack    ),
    .port0_req      (wb_dmem_req        ),
    .port0_cmd      (wb_dmem_cmd        ),
    .port0_width    (wb_dmem_width      ),
    .port0_addr     (wb_dmem_addr       ),
    .port0_wdata    (wb_dmem_wdata      ),
    .port0_rdata    (wb_dmem_rdata      ),
    .port0_resp     (wb_dmem_resp       )
);


`ifdef YCR1_ICACHE_EN

// icache request selection betweem imem and dmem
ycr1_icache_router u_icache_router(
    // Control signals
    .rst_n           (core_rst_n_local   ),
    .clk             (core_clk           ),

    // imem interface
    .imem_req_ack    (icache_imem_req_ack),
    .imem_req        (icache_imem_req    ),
    .imem_cmd        (icache_imem_cmd    ),
    .imem_addr       (icache_imem_addr   ),
    .imem_bl         (icache_imem_bl     ),
    .imem_width      (YCR1_MEM_WIDTH_WORD),
    .imem_rdata      (icache_imem_rdata  ),
    .imem_resp       (icache_imem_resp   ),

    // dmem interface
    .dmem_req_ack    (icache_dmem_req_ack),
    .dmem_req        (icache_dmem_req    ),
    .dmem_cmd        (icache_dmem_cmd    ),
    .dmem_width      (icache_dmem_width  ),
    .dmem_addr       (icache_dmem_addr   ),
    .dmem_rdata      (icache_dmem_rdata  ),
    .dmem_resp       (icache_dmem_resp   ),

    // icache interface  
    .icache_req_ack  (icache_req_ack    ),
    .icache_req      (icache_req        ),
    .icache_cmd      (icache_cmd        ),
    .icache_width    (icache_width      ),
    .icache_addr     (icache_addr       ),
    .icache_bl       (icache_bl         ),
    .icache_rdata    (icache_rdata      ),
    .icache_resp     (icache_resp       )

);


// Icache top
icache_top  #(.MEM_BL(`YCR1_IMEM_BSIZE) )u_icache (
	.mclk                         (core_clk),	   //Clock input 
	.rst_n                        (core_rst_n_local),  //Active Low Asynchronous Reset Signal Input

	.cfg_pfet_dis                 (cfg_icache_pfet_dis),// To disable Next Pre data Pre fetch, default = 0
	.cfg_ntag_pfet_dis            (cfg_icache_ntag_pfet_dis),// To disable next Tag refill, default = 0

	// Wishbone CPU I/F
        .cpu_mem_req                 (icache_req),        // strobe/request
        .cpu_mem_addr                (icache_addr),       // address
        .cpu_mem_bl                  (icache_bl),       // address
	.cpu_mem_width               (icache_width),

        .cpu_mem_req_ack             (icache_req_ack),    // data input
        .cpu_mem_rdata               (icache_rdata),      // data input
        .cpu_mem_resp                (icache_resp),        // acknowlegement

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

	// DFFRAM I/F
        .cache_dffram_clk0            (icache_dffram_clk0    ), // CLK
        .cache_dffram_cs0             (icache_dffram_cs0     ), // Chip Select
        .cache_dffram_addr0           (icache_dffram_addr0   ), // Address
        .cache_dffram_wmask0          (icache_dffram_wmask0  ), // Write Mask
        .cache_dffram_din0            (icache_dffram_din0    ), // Write Data
        .cache_dffram_dout0           (icache_dffram_dout0   ), // Read Data
                                                    
        .cache_dffram_clk1            (icache_dffram_clk1    ), // CLK
        .cache_dffram_cs1             (icache_dffram_cs1     ), // Chip Select
        .cache_dffram_addr1           (icache_dffram_addr1   ), // Address
        .cache_dffram_wmask1          (icache_dffram_wmask1  ), // Write Mask
        .cache_dffram_din1            (icache_dffram_din1    ), // Write Data
        .cache_dffram_dout1           (icache_dffram_dout1   ) // Read Data


);

// Async Wishbone clock domain translation
ycr1_async_wbb u_async_icache(

    // Master Port
       .wbm_rst_n       (core_rst_n_local ),  // Regular Reset signal
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

`ifdef YCR1_DCACHE_EN

// dcache request selection betweem imem and dmem
ycr1_dcache_router u_dcache_router(
    // Control signals
    .rst_n           (core_rst_n_local   ),
    .clk             (core_clk           ),

    // imem interface
    .imem_req_ack    (dcache_imem_req_ack),
    .imem_req        (dcache_imem_req    ),
    .imem_cmd        (dcache_imem_cmd    ),
    .imem_addr       (dcache_imem_addr   ),
    .imem_width      (YCR1_MEM_WIDTH_WORD),
    .imem_wdata      ('h0                ),
    .imem_rdata      (dcache_imem_rdata  ),
    .imem_resp       (dcache_imem_resp   ),

    // dmem interface
    .dmem_req_ack    (dcache_dmem_req_ack),
    .dmem_req        (dcache_dmem_req    ),
    .dmem_cmd        (dcache_dmem_cmd    ),
    .dmem_width      (dcache_dmem_width  ),
    .dmem_addr       (dcache_dmem_addr   ),
    .dmem_wdata      (dcache_dmem_wdata  ),
    .dmem_rdata      (dcache_dmem_rdata  ),
    .dmem_resp       (dcache_dmem_resp   ),

    // icache interface  
    .dcache_req_ack  (dcache_req_ack    ),
    .dcache_req      (dcache_req        ),
    .dcache_cmd      (dcache_cmd        ),
    .dcache_width    (dcache_width      ),
    .dcache_addr     (dcache_addr       ),
    .dcache_wdata    (dcache_wdata      ),
    .dcache_rdata    (dcache_rdata      ),
    .dcache_resp     (dcache_resp       )


);


// dcache top
dcache_top  u_dcache (
	.mclk                         (core_clk),	       //Clock input 
	.rst_n                        (core_rst_n_local),      //Active Low Asynchronous Reset Signal Input

	.cfg_pfet_dis                 (cfg_dcache_pfet_dis),   // To disable Next Pre data Pre fetch, default = 0
	.cfg_force_flush              (cfg_dcache_force_flush),// Force flush

	// Wishbone CPU I/F
        .cpu_mem_req                 (dcache_req),        // strobe/request
        .cpu_mem_cmd                 (dcache_cmd),        // address
        .cpu_mem_addr                (dcache_addr),       // address
	.cpu_mem_width               (dcache_width),
        .cpu_mem_wdata               (dcache_wdata),      // data input

        .cpu_mem_req_ack             (dcache_req_ack),    // data input
        .cpu_mem_rdata               (dcache_rdata),      // data input
        .cpu_mem_resp                (dcache_resp),        // acknowlegement

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

	// DFFRAM I/F
        .cache_dffram_clk0            (dcache_dffram_clk0    ), // CLK
        .cache_dffram_cs0             (dcache_dffram_cs0     ), // Chip Select
        .cache_dffram_addr0           (dcache_dffram_addr0   ), // Address
        .cache_dffram_wmask0          (dcache_dffram_wmask0  ), // Write Mask
        .cache_dffram_din0            (dcache_dffram_din0    ), // Write Data
        .cache_dffram_dout0           (dcache_dffram_dout0   ), // Read Data
                                                    
        .cache_dffram_clk1            (dcache_dffram_clk1    ), // CLK
        .cache_dffram_cs1             (dcache_dffram_cs1     ), // Chip Select
        .cache_dffram_addr1           (dcache_dffram_addr1   ), // Address
        .cache_dffram_wmask1          (dcache_dffram_wmask1  ), // Write Mask
        .cache_dffram_din1            (dcache_dffram_din1    ), // Write Data
        .cache_dffram_dout1           (dcache_dffram_dout1   ) // Read Data

);

// Async Wishbone clock domain translation
ycr1_async_wbb u_async_dcache(

    // Master Port
       .wbm_rst_n       (core_rst_n_local ),  // Regular Reset signal
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
// Instruction memory WB bridge
//-------------------------------------------------------------------------------
ycr1_imem_wb i_imem_wb (
    .core_rst_n     (core_rst_n_local   ),
    .core_clk       (core_clk           ),
    // Interface to imem router
    .imem_req_ack   (wb_imem_req_ack   ),
    .imem_req       (wb_imem_req       ),
    .imem_addr      (wb_imem_addr      ),
    .imem_rdata     (wb_imem_rdata     ),
    .imem_resp      (wb_imem_resp      ),
    // WB interface
    .wb_rst_n       (wb_rst_n          ),
    .wb_clk         (wb_clk            ),
    .wbd_stb_o      (                  ), 
    .wbd_adr_o      (                  ), 
    .wbd_we_o       (                  ),  
    .wbd_dat_o      (                  ), 
    .wbd_sel_o      (                  ), 
    .wbd_dat_i      ('h0               ), 
    .wbd_ack_i      ('b0               ), 
    .wbd_err_i      ('b0               )
);


//-------------------------------------------------------------------------------
// Data memory WB bridge
//-------------------------------------------------------------------------------
ycr1_dmem_wb i_dmem_wb (
    .core_rst_n     (core_rst_n_local   ),
    .core_clk       (core_clk           ),
    // Interface to dmem router
    .dmem_req_ack   (wb_dmem_req_ack   ),
    .dmem_req       (wb_dmem_req       ),
    .dmem_cmd       (wb_dmem_cmd       ),
    .dmem_width     (wb_dmem_width     ),
    .dmem_addr      (wb_dmem_addr      ),
    .dmem_wdata     (wb_dmem_wdata     ),
    .dmem_rdata     (wb_dmem_rdata     ),
    .dmem_resp      (wb_dmem_resp      ),
    // WB interface
    .wb_rst_n       (wb_rst_n          ),
    .wb_clk         (wb_clk            ),
    .wbd_stb_o      (wbd_dmem_stb_o    ), 
    .wbd_adr_o      (wbd_dmem_adr_o    ), 
    .wbd_we_o       (wbd_dmem_we_o     ),  
    .wbd_dat_o      (wbd_dmem_dat_o    ), 
    .wbd_sel_o      (wbd_dmem_sel_o    ), 
    .wbd_dat_i      (wbd_dmem_dat_i    ), 
    .wbd_ack_i      (wbd_dmem_ack_i    ), 
    .wbd_err_i      (wbd_dmem_err_i    )
);

`ifndef SCR1_TCM_MEM

  /**
  sky130_sram_2kbyte_1rw1r_32x512_8 u_tsram1_2kb(
`ifdef USE_POWER_PINS
    .vccd1 (vccd1),// User area 1 1.8V supply
    .vssd1 (vssd1),// User area 1 digital ground
`endif
// Port 0: RW
    .clk0     (sram1_clk0),
    .csb0     (sram1_csb0),
    .web0     (sram1_web0),
    .wmask0   (sram1_wmask0),
    .addr0    (sram1_addr0),
    .din0     (sram1_din0),
    .dout0    (sram1_dout0),
// Port 1: R
    .clk1     (sram1_clk1),
    .csb1     (sram1_csb1),
    .addr1    (sram1_addr1),
    .dout1    (sram1_dout1)
  );
  ***/
  assign sram1_dout1 = 'h0;
  assign sram1_dout0 = 'h0;
`endif

endmodule : ycr1_intf
