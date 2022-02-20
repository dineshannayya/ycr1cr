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
////  yifive Single core RISCV Top                                        ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr1.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     integrated wishbone i/f to instruction/data memory               ////
////                                                                      ////
////  To Do:                                                              ////
////    nothing                                                           ////
////                                                                      ////
////  Author(s):                                                          ////
////      - Dinesh Annayya, dinesha@opencores.org                         ////
////                                                                      ////
////  CPU Memory Map:                                                     ////
////            0x0000_0000 to 0x07FF_FFFF (128MB) - ICACHE               ////
////            0x0800_0000 to 0x0BFF_FFFF (64MB)  - DCACHE               ////
////            0x0C48_0000 to 0x0C48_FFFF (64K)   - TCM SRAM             ////
////            0x0C49_0000 to 0x0C49_000F (16)    - TIMER                ////
////                                                                      ////
////  Revision :                                                          ////
////     0.0:    June 7, 2021, Dinesh A                                   ////
////             wishbone integration                                     ////
////     0.1:    June 17, 2021, Dinesh A                                  ////
////             core and wishbone clock domain are seperated             ////
////             Async fifo added in imem and dmem path                   ////
////     0.2:    July 7, 2021, Dinesh A                                   ////
////            64bit debug signal added                                  ////
////     0.3:    Aug 23, 2021, Dinesh A                                   ////
////            timer_irq connective bug fix                              ////
////     1.0:   Jan 20, 2022, Dinesh A                                    ////
////            128MB icache integrated in address range 0x0000_0000 to   ////
////            0x07FF_FFFF                                               ////
////     1.1:   Jan 22, 2022, Dinesh A                                    ////
////            64MB dcache added in the address range 0x0800_0000 to     ////
////            0x0BFF_FFFF                                               ////
////     1.2:   Jan 30, 2022, Dinesh A                                    ////
////            global register newly added in timer register to control  ////
////            icache/dcache operation                                   ////
////     1.3:   Feb 14, 2022, Dinesh A                                    ////
////            Burst Access support added to imem prefetch logic         ////
////            Burst Prefetech support only towards imem address range   ////
////            0x0000_0000 to 0x07FFF_FFFF                               ////
////     1.4:   Feb 16, 2022, Dinesh A                                    ////
////            As SRAM from Sky130A is not qualified, we have changed    ////
////            cache and tcm interface to DFFRAM                         ////
////     1.5:   Feb 20, 2022, Dinesh A                                    ////
////            Total Risc core parameter added                           ////
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

module ycr1_top_wb (

`ifdef USE_POWER_PINS
         input logic            vccd1,    // User area 1 1.8V supply
         input logic            vssd1,    // User area 1 digital ground
`endif
    input  logic   [3:0]                 cfg_cska_riscv,
    input  logic                         wbd_clk_int,
    output logic                         wbd_clk_riscv,

    // Control
    input   logic                                   pwrup_rst_n,            // Power-Up Reset
    input   logic                                   rst_n,                  // Regular Reset signal
    input   logic                                   cpu_rst_n,              // CPU Reset (Core Reset)
    // input   logic                                test_mode,              // Test mode - unused
    // input   logic                                test_rst_n,             // Test mode's reset - unused
    input   logic                                   core_clk,               // Core clock
    input   logic                                   core_clk_mclk,        // Core clock for memory - without CTS
    input   logic                                   rtc_clk,                // Real-time clock
    output  logic [63:0]                            riscv_debug,
`ifdef YCR1_DBG_EN
    output  logic                                   sys_rst_n_o,            // External System Reset output
                                                                            //   (for the processor cluster's components or
                                                                            //    external SOC (could be useful in small
                                                                            //    YCR-core-centric SOCs))
    output  logic                                   sys_rdc_qlfy_o,         // System-to-External SOC Reset Domain Crossing Qualifier
`endif // YCR1_DBG_EN

    // Fuses
    input   logic [`YCR1_XLEN-1:0]                  fuse_mhartid,           // Hart ID
`ifdef YCR1_DBG_EN
    input   logic [31:0]                            fuse_idcode,            // TAPC IDCODE
`endif // YCR1_DBG_EN

    // IRQ
`ifdef YCR1_IPIC_EN
    input   logic [YCR1_IRQ_LINES_NUM-1:0]          irq_lines,              // IRQ lines to IPIC
`else // YCR1_IPIC_EN
    input   logic                                   ext_irq,                // External IRQ input
`endif // YCR1_IPIC_EN
    input   logic                                   soft_irq,               // Software IRQ input

`ifdef YCR1_DBG_EN
    // -- JTAG I/F
    input   logic                                   trst_n,
    input   logic                                   tck,
    input   logic                                   tms,
    input   logic                                   tdi,
    output  logic                                   tdo,
    output  logic                                   tdo_en,
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

   `ifdef YCR1_ICACHE_EN
   // Wishbone ICACHE I/F
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
   
   output logic                             icache_dffram_clk1    , // CLK
   output logic                             icache_dffram_cs1     , // Chip Select
   output logic    [7:0]                    icache_dffram_addr1   , // Address
   output logic    [3:0]                    icache_dffram_wmask1  , // Write Mask
   output logic    [31:0]                   icache_dffram_din1    , // Write Data
   input  logic    [31:0]                   icache_dffram_dout1   , // Read Data

   `endif

   `ifdef YCR1_DCACHE_EN
   // Wishbone ICACHE I/F
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
    input   logic                           wbd_dmem_err_i  // error
);

//-------------------------------------------------------------------------------
// Local parameters
//-------------------------------------------------------------------------------
localparam int unsigned YCR1_CLUSTER_TOP_RST_SYNC_STAGES_NUM            = 2;

//-------------------------------------------------------------------------------
// Local signal declaration
//-------------------------------------------------------------------------------
// Reset logic
logic                                               test_mode;              // Test mode - unused
logic                                               test_rst_n;             // Test mode's reset - unused
logic                                               pwrup_rst_n_sync;
logic                                               rst_n_sync;
logic                                               cpu_rst_n_sync;
logic                                               core_rst_n_local;
`ifdef YCR1_DBG_EN
logic                                               tapc_trst_n;
`endif // YCR1_DBG_EN

// Instruction memory interface from core to router
logic                                               core_imem_req_ack;
logic                                               core_imem_req;
logic                                               core_imem_cmd;
logic [`YCR1_IMEM_AWIDTH-1:0]                       core_imem_addr;
logic [`YCR1_IMEM_BSIZE-1:0]                        core_imem_bl;
logic [`YCR1_IMEM_DWIDTH-1:0]                       core_imem_rdata;
logic [1:0]                                         core_imem_resp;

// Data memory interface from core to router
logic                                               core_dmem_req_ack;
logic                                               core_dmem_req;
logic                                               core_dmem_cmd;
logic [1:0]                                         core_dmem_width;
logic [`YCR1_DMEM_AWIDTH-1:0]                       core_dmem_addr;
logic [`YCR1_DMEM_DWIDTH-1:0]                       core_dmem_wdata;
logic [`YCR1_DMEM_DWIDTH-1:0]                       core_dmem_rdata;
logic [1:0]                                         core_dmem_resp;

// Instruction memory interface from router to WB bridge
logic                                               wb_imem_req_ack;
logic                                               wb_imem_req;
logic                                               wb_imem_cmd;
logic [`YCR1_IMEM_AWIDTH-1:0]                       wb_imem_addr;
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

logic                                               timer_irq;
logic [63:0]                                        timer_val;
logic [48:0]                                        core_debug;


// As DFFRAM has hugh insertion delay, we have additional clock without CTS 
// to manage the input hold violation
ctech_clk_buf u_tcm_mem0_clk (.A(core_clk_mclk ) , .X(tcm_dffram_clk0 ));
ctech_clk_buf u_tcm_mem1_clk (.A(core_clk_mclk ) , .X(tcm_dffram_clk1 ));

ctech_clk_buf u_icache_mem0_clk (.A(core_clk_mclk ) , .X(icache_dffram_clk0 ));
ctech_clk_buf u_icache_mem1_clk (.A(core_clk_mclk ) , .X(icache_dffram_clk1 ));

ctech_clk_buf u_dcache_mem0_clk (.A(core_clk_mclk ) , .X(dcache_dffram_clk0 ));
ctech_clk_buf u_dcache_mem1_clk (.A(core_clk_mclk ) , .X(dcache_dffram_clk1 ));

// riscv clock skew control
clk_skew_adjust u_skew_riscv
       (
`ifdef USE_POWER_PINS
               .vccd1      (vccd1                      ),// User area 1 1.8V supply
               .vssd1      (vssd1                      ),// User area 1 digital ground
`endif
	       .clk_in     (wbd_clk_int                ), 
	       .sel        (cfg_cska_riscv             ), 
	       .clk_out    (wbd_clk_riscv              ) 
       );
//-------------------------------------------------------------------------------
// YCR1 Intf instance
//-------------------------------------------------------------------------------
ycr1_intf u_intf (
    // Control
    .pwrup_rst_n                        (pwrup_rst_n),        // Power-Up Reset
    .rst_n                              (rst_n),              // Regular Reset signal
    .cpu_rst_n                          (cpu_rst_n),          // CPU Reset (Core Reset)
    .core_clk                           (core_clk),           // Core clock
    .rtc_clk                            (rtc_clk),            // Real-time clock
    .riscv_debug                        (riscv_debug),

`ifdef YCR1_DBG_EN
    // -- JTAG I/F
    .trst_n                             (trst_n),
`endif // YCR1_DBG_EN

`ifndef YCR1_TCM_MEM
	// DFFRAM I/F
        .tcm_dffram_clk0            (                   ), // CLK
        .tcm_dffram_cs0             (tcm_dffram_cs0     ), // Chip Select
        .tcm_dffram_addr0           (tcm_dffram_addr0   ), // Address
        .tcm_dffram_wmask0          (tcm_dffram_wmask0  ), // Write Mask
        .tcm_dffram_din0            (tcm_dffram_din0    ), // Write Data
        .tcm_dffram_dout0           (tcm_dffram_dout0   ), // Read Data
                                                    
        .tcm_dffram_clk1            (                   ), // CLK
        .tcm_dffram_cs1             (tcm_dffram_cs1     ), // Chip Select
        .tcm_dffram_addr1           (tcm_dffram_addr1   ), // Address
        .tcm_dffram_wmask1          (tcm_dffram_wmask1  ), // Write Mask
        .tcm_dffram_din1            (tcm_dffram_din1    ), // Write Data
        .tcm_dffram_dout1           (tcm_dffram_dout1   ), // Read Data
 
`endif

    .wb_rst_n                           (wb_rst_n),           // Wish bone reset
    .wb_clk                             (wb_clk),             // wish bone clock

    // Instruction Memory Interface
    //.wbd_imem_stb_o                     (),         // strobe/request
    //.wbd_imem_adr_o                     (),         // address
    //.wbd_imem_we_o                      (),         // write
    //.wbd_imem_dat_o                     (),         // data output
    //.wbd_imem_sel_o                     (),         // byte enable
    //.wbd_imem_dat_i                     ('h0),      // data input
    //.wbd_imem_ack_i                     (1'b0),     // acknowlegement
    //.wbd_imem_err_i                     (1'b0),     // error

    // Data Memory Interface
    .wbd_dmem_stb_o                     (wbd_dmem_stb_o),     // strobe/request
    .wbd_dmem_adr_o                     (wbd_dmem_adr_o),     // address
    .wbd_dmem_we_o                      (wbd_dmem_we_o),      // write
    .wbd_dmem_dat_o                     (wbd_dmem_dat_o),     // data output
    .wbd_dmem_sel_o                     (wbd_dmem_sel_o),     // byte enable
    .wbd_dmem_dat_i                     (wbd_dmem_dat_i),     // data input
    .wbd_dmem_ack_i                     (wbd_dmem_ack_i),     // acknowlegement
    .wbd_dmem_err_i                     (wbd_dmem_err_i),     // error

   `ifdef YCR1_ICACHE_EN
   // Wishbone ICACHE I/F
    .wb_icache_cyc_o                    (                 ), // strobe/request
    .wb_icache_stb_o                    (wb_icache_stb_o  ), // strobe/request
    .wb_icache_adr_o                    (wb_icache_adr_o  ), // address
    .wb_icache_we_o                     (wb_icache_we_o   ), // write
    .wb_icache_sel_o                    (wb_icache_sel_o  ), // byte enable
    .wb_icache_bl_o                     (wb_icache_bl_o   ), // Burst Length
    .wb_icache_bry_o                    (wb_icache_bry_o  ), // Burst Ready
                                                          
    .wb_icache_dat_i                    (wb_icache_dat_i  ), // data input
    .wb_icache_ack_i                    (wb_icache_ack_i  ), // acknowlegement
    .wb_icache_lack_i                   (wb_icache_lack_i ),// last acknowlegement
    .wb_icache_err_i                    (wb_icache_err_i  ),  // error

     // DFFRAM I/F
    .icache_dffram_clk0                 (                      ), // CLK
    .icache_dffram_cs0                  (icache_dffram_cs0     ), // Chip Select
    .icache_dffram_addr0                (icache_dffram_addr0   ), // Address
    .icache_dffram_wmask0               (icache_dffram_wmask0  ), // Write Mask
    .icache_dffram_din0                 (icache_dffram_din0    ), // Write Data
    .icache_dffram_dout0                (icache_dffram_dout0   ), // Read Data
                                                         
    .icache_dffram_clk1                 (                      ), // CLK
    .icache_dffram_cs1                  (icache_dffram_cs1     ), // Chip Select
    .icache_dffram_addr1                (icache_dffram_addr1   ), // Address
    .icache_dffram_wmask1               (icache_dffram_wmask1  ), // Write Mask
    .icache_dffram_din1                 (icache_dffram_din1    ), // Write Data
    .icache_dffram_dout1                (icache_dffram_dout1   ), // Read Data

   `endif


   `ifdef YCR1_DCACHE_EN
   // Wishbone DCACHE I/F
    .wb_dcache_cyc_o                    (                 ), // strobe/request
    .wb_dcache_stb_o                    (wb_dcache_stb_o  ), // strobe/request
    .wb_dcache_adr_o                    (wb_dcache_adr_o  ), // address
    .wb_dcache_we_o                     (wb_dcache_we_o   ), // write
    .wb_dcache_dat_o                    (wb_dcache_dat_o  ), // data output
    .wb_dcache_sel_o                    (wb_dcache_sel_o  ), // byte enable
    .wb_dcache_bl_o                     (wb_dcache_bl_o   ),  // Burst Length
    .wb_dcache_bry_o                    (wb_dcache_bry_o  ),  // Burst Ready
                                                          
    .wb_dcache_dat_i                    (wb_dcache_dat_i  ), // data input
    .wb_dcache_ack_i                    (wb_dcache_ack_i  ), // acknowlegement
    .wb_dcache_lack_i                   (wb_dcache_lack_i ),// last acknowlegement
    .wb_dcache_err_i                    (wb_dcache_err_i  ),  // error

     // DFFRAM I/F
    .dcache_dffram_clk0                 (                      ), // CLK
    .dcache_dffram_cs0                  (dcache_dffram_cs0     ), // Chip Select
    .dcache_dffram_addr0                (dcache_dffram_addr0   ), // Address
    .dcache_dffram_wmask0               (dcache_dffram_wmask0  ), // Write Mask
    .dcache_dffram_din0                 (dcache_dffram_din0    ), // Write Data
    .dcache_dffram_dout0                (dcache_dffram_dout0   ), // Read Data
                                                         
    .dcache_dffram_clk1                 (                      ), // CLK
    .dcache_dffram_cs1                  (dcache_dffram_cs1     ), // Chip Select
    .dcache_dffram_addr1                (dcache_dffram_addr1   ), // Address
    .dcache_dffram_wmask1               (dcache_dffram_wmask1  ), // Write Mask
    .dcache_dffram_din1                 (dcache_dffram_din1    ), // Write Data
    .dcache_dffram_dout1                (dcache_dffram_dout1   ), // Read Data

   `endif
    // Common
    .pwrup_rst_n_sync                   (pwrup_rst_n_sync),   // Power-Up reset
    .rst_n_sync                         (rst_n_sync),         // Regular reset
    .cpu_rst_n_sync                     (cpu_rst_n_sync),     // CPU reset
    .test_mode                          (test_mode),          // DFT Test Mode
    .test_rst_n                         (test_rst_n),         // DFT Test Reset
    .core_rst_n_local                   (core_rst_n_local),   // Core reset
    .core_debug                         (core_debug  ),
`ifdef YCR1_DBG_EN
    // Debug Interface
    .tapc_trst_n                        (tapc_trst_n),        // Test Reset (TRSTn)
`endif
    // Memory-mapped external timer
    .timer_val                          (timer_val),          // Machine timer value
    .timer_irq                          (timer_irq),          // Machine timer value
    // Instruction Memory Interface
    .core_imem_req_ack                  (core_imem_req_ack),  // IMEM request acknowledge
    .core_imem_req                      (core_imem_req),      // IMEM request
    .core_imem_cmd                      (core_imem_cmd),      // IMEM command
    .core_imem_addr                     (core_imem_addr),     // IMEM address
    .core_imem_bl                       (core_imem_bl),     // IMEM address
    .core_imem_rdata                    (core_imem_rdata),    // IMEM read data
    .core_imem_resp                     (core_imem_resp),     // IMEM response

    // Data Memory Interface
    .core_dmem_req_ack                  (core_dmem_req_ack),  // DMEM request acknowledge
    .core_dmem_req                      (core_dmem_req),      // DMEM request
    .core_dmem_cmd                      (core_dmem_cmd),      // DMEM command
    .core_dmem_width                    (core_dmem_width),    // DMEM data width
    .core_dmem_addr                     (core_dmem_addr),     // DMEM address
    .core_dmem_wdata                    (core_dmem_wdata),    // DMEM write data
    .core_dmem_rdata                    (core_dmem_rdata),    // DMEM read data
    .core_dmem_resp                     (core_dmem_resp)      // DMEM response

);


//-------------------------------------------------------------------------------
// YCR1 core instance
//-------------------------------------------------------------------------------
ycr1_core_top i_core_top (
    // Common
    .pwrup_rst_n                (pwrup_rst_n_sync ),
    .rst_n                      (rst_n_sync       ),
    .cpu_rst_n                  (cpu_rst_n_sync   ),
    .test_mode                  (test_mode        ),
    .test_rst_n                 (test_rst_n       ),
    .clk                        (core_clk         ),
    .core_rst_n_o               (core_rst_n_local ),
    .core_rdc_qlfy_o            (                 ),
    .core_debug                 (core_debug       ),
`ifdef YCR1_DBG_EN
    .sys_rst_n_o                (sys_rst_n_o      ),
    .sys_rdc_qlfy_o             (sys_rdc_qlfy_o   ),
`endif // YCR1_DBG_EN

    // Fuses
    .core_fuse_mhartid_i        (fuse_mhartid     ),
`ifdef YCR1_DBG_EN
    .tapc_fuse_idcode_i         (fuse_idcode      ),
`endif // YCR1_DBG_EN

    // IRQ
`ifdef YCR1_IPIC_EN
    .core_irq_lines_i           (irq_lines        ),
`else // YCR1_IPIC_EN
    .core_irq_ext_i             (ext_irq          ),
`endif // YCR1_IPIC_EN
    .core_irq_soft_i            (soft_irq         ),
    .core_irq_mtimer_i          (timer_irq        ),

    // Memory-mapped external timer
    .core_mtimer_val_i          (timer_val        ),

`ifdef YCR1_DBG_EN
    // Debug interface
    .tapc_trst_n                (tapc_trst_n      ),
    .tapc_tck                   (tck              ),
    .tapc_tms                   (tms              ),
    .tapc_tdi                   (tdi              ),
    .tapc_tdo                   (tdo              ),
    .tapc_tdo_en                (tdo_en           ),
`endif // YCR1_DBG_EN

    // Instruction memory interface
    .imem2core_req_ack_i        (core_imem_req_ack),
    .core2imem_req_o            (core_imem_req    ),
    .core2imem_cmd_o            (core_imem_cmd    ),
    .core2imem_addr_o           (core_imem_addr   ),
    .core2imem_bl_o             (core_imem_bl     ),
    .imem2core_rdata_i          (core_imem_rdata  ),
    .imem2core_resp_i           (core_imem_resp   ),

    // Data memory interface
    .dmem2core_req_ack_i        (core_dmem_req_ack),
    .core2dmem_req_o            (core_dmem_req    ),
    .core2dmem_cmd_o            (core_dmem_cmd    ),
    .core2dmem_width_o          (core_dmem_width  ),
    .core2dmem_addr_o           (core_dmem_addr   ),
    .core2dmem_wdata_o          (core_dmem_wdata  ),
    .dmem2core_rdata_i          (core_dmem_rdata  ),
    .dmem2core_resp_i           (core_dmem_resp   )
);



endmodule : ycr1_top_wb


