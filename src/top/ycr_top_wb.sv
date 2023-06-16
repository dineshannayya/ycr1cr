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
////  https://github.com/dineshannayya/ycr1cr.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     integrated 1 Risc core with instruction/data memory & wb         ////
////                                                                      ////
////  To Do:                                                              ////
////    nothing                                                           ////
////                                                                      ////
////  Authors:                                                            ////
////     - syntacore, https://github.com/syntacore/scr1                   ////
////     - Dinesh Annayya, dinesha@opencores.org                          ////
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
////     1.6:   Mar 14, 2022, Dinesh A                                    ////
////            fuse_mhartid is internally tied                           ////
////     1.8:   Mar 28, 2022, Dinesh A                                    ////
////            Pipe line imem request generation is removed in           ////
////            ycr_pipe_ifu.sv and when ever there there is clash between////
////            current request and new change of addres request, new     ////
////            address will be holded and updated only at the end of     ////
////            pending transaction                                       ////
////     1.9:   Mar 29, 2022, Dinesh A                                    ////
////            To break the timing path, once cycle gap assumed between  ////
////            core request to slave ack, following files are modified   ////
////     	    src/cache/src/core/dcache_top.sv                          ////
////     	    src/cache/src/core/icache_top.sv                          ////
////     	    src/core/pipeline/ycr_pipe_ifu.sv                         ////
////     	    src/top/ycr_dmem_router.sv                                ////
////     	    src/top/ycr_dmem_wb.sv                                    ////
////     	    src/top/ycr_tcm.sv                                        ////
////            Synth and sta script are clean-up                         ////
////     2.0:  April 1, 2022, Dinesh A                                    ////
////           As sky130 SRAM timining library are not accurate, added    ////
////           Write interface lanuch phase selection                     ////  
////     2.1:  May 23, 2022, Dinesh A                                     ////
////           To improve the timing, request re-timing are added at      ////
////           iconnect block, In MPW-6 shows Riscv core meeting timing   ////
////           for 100Mhz                                                 ////
////     2.2:  June 3, 2022, Dinesh A                                     ////
////           Replaced DFFRAM with SRAM Memory                           ////
////     2.3:  June 12, 2022, Dinesh A                                    ////
////           icache and dcache bypass config added                      ////
////     2.4:  Aug 20, 2022, Dinesh A                                     ////
////           Increase total external interrupt from 16 to 32            ////
////     2.5:  Nov 7, 2022, Dinesh A                                      ////
////           Added Interface to integrate AES core                      ////
////           Added Interface to integrate FPU core                      ////
////     2.6:  Mar 4, 2023, Dinesh A                                      ////
////           Tap access is enabled                                      ////
////     2.7:  Mar 10, 2023, Dinesh A                                     ////
////            all cpu clock is branch are routed through iconnect       ////
////     2.8:  May 1, 2023, Dinesh A                                      ////
////           cpu clock gating feature added                             ////
////     2.9:  June 1, 2023, Dinesh A                                     ////
////            Bug fix in Tap reset connectivity                         ////
////                                                                      ////
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

module ycr_top_wb (

`ifdef USE_POWER_PINS
         input logic                          vccd1,    // User area 1 1.8V supply
         input logic                          vssd1,    // User area 1 digital ground
`endif
    // WB Clock Skew Control
    input  logic   [3:0]                      cfg_wcska_riscv_intf,
    input  logic                              wbd_clk_int,
    output logic                              wbd_clk_skew ,

    // RISCV Clock Skew Control
    input  logic   [3:0]                      cfg_ccska_riscv_intf,
    input  logic   [3:0]                      cfg_ccska_riscv_icon,
    input  logic   [3:0]                      cfg_ccska_riscv_core0,
    input  logic                              core_clk_int,

    // Control
    input   logic                             pwrup_rst_n,            // Power-Up Reset
    input   logic                             rst_n,                  // Regular Reset signal
    input   logic                             cpu_core_rst_n,         // CPReset (Core Reset )
    input   logic                             cpu_intf_rst_n,         // CPU interface reset
    input   logic [3:0]                       cfg_sram_lphase,
    input   logic [2:0]                       cfg_cache_ctrl,
    input   logic                             cfg_bypass_icache,  // 1 => Bypass icache
    input   logic                             cfg_bypass_dcache,  // 1 => Bypass dcache
    // input   logic                          test_mode,              // Test mode - unused
    // input   logic                          test_rst_n,             // Test mode's reset - unused
    input   logic                             rtc_clk,                // Real-time clock
    output  logic [63:0]                      riscv_debug,
`ifdef YCR_DBG_EN
    output  logic                             sys_rst_n_o,            // External System Reset output
                                                                      //   (for the processor cluster's components or
                                                                      //    external SOC (could be useful in small
                                                                      //    YCR-core-centric SOCs))
    output  logic                             sys_rdc_qlfy_o,         // System-to-External SOC Reset Domain Crossing Qualifier
`endif // YCR_DBG_EN


    // IRQ
`ifdef YCR_IPIC_EN
    input   logic [YCR_IRQ_LINES_NUM-1:0]irq_lines,              // IRQ lines to IPIC
`else // YCR_IPIC_EN
    input   logic                        ext_irq,                // External IRQ input
`endif // YCR_IPIC_EN
    input   logic                        soft_irq,               // Software IRQ input

`ifdef YCR_DBG_EN
    // -- JTAG I/F
    input   logic                        trst_n,
    input   logic                        tck,
    input   logic                        tms,
    input   logic                        tdi,
    output  logic                        tdo,
    output  logic                        tdo_en,
`endif // YCR_DBG_EN

`ifndef YCR_TCM_MEM
    // SRAM-0 PORT-0
    output  logic                        sram0_clk0,
    output  logic                        sram0_csb0,
    output  logic                        sram0_web0,
    output  logic   [8:0]                sram0_addr0,
    output  logic   [3:0]                sram0_wmask0,
    output  logic   [31:0]               sram0_din0,
    input   logic   [31:0]               sram0_dout0,

    // SRAM-0 PORT-1
    output  logic                        sram0_clk1,
    output  logic                        sram0_csb1,
    output  logic  [8:0]                 sram0_addr1,
    input   logic  [31:0]                sram0_dout1,

`endif


    input   logic                        wb_rst_n,       // Wish bone reset
    input   logic                        wb_clk,         // wish bone clock

   `ifdef YCR_ICACHE_EN
   // Wishbone ICACHE I/F

   output logic                          wb_icache_stb_o, // strobe/request
   output logic   [YCR_WB_WIDTH-1:0]     wb_icache_adr_o, // address
   output logic                          wb_icache_we_o,  // write
   output logic   [3:0]                  wb_icache_sel_o, // byte enable
   output logic   [9:0]                  wb_icache_bl_o,  // Burst Length
   output logic                          wb_icache_bry_o, // Burst Ready 

   input logic   [YCR_WB_WIDTH-1:0]      wb_icache_dat_i, // data input
   input logic                           wb_icache_ack_i, // acknowlegement
   input logic                           wb_icache_lack_i,// last acknowlegement
   input logic                           wb_icache_err_i,  // error

   // ICACHE PORT-0 SRAM Memory I/F
   output logic                          icache_mem_clk0, // CLK
   output logic                          icache_mem_csb0, // CS#
   output logic                          icache_mem_web0, // WE#
   output logic   [8:0]                  icache_mem_addr0, // Address
   output logic   [3:0]                  icache_mem_wmask0, // WMASK#
   output logic   [31:0]                 icache_mem_din0, // Write Data
   //input  logic   [31:0]               icache_mem_dout0, // Read Data
   
   // ICACHE PORT-1 SRAM Memory I/F
   output logic                          icache_mem_clk1, // CLK
   output logic                          icache_mem_csb1, // CS#
   output logic  [8:0]                   icache_mem_addr1, // Address
   input  logic  [31:0]                  icache_mem_dout1, // Read Data
   `endif

   `ifdef YCR_DCACHE_EN
   // Wishbone DCACHE I/F
   output logic                          wb_dcache_stb_o, // strobe/request
   output logic   [YCR_WB_WIDTH-1:0]     wb_dcache_adr_o, // address
   output logic                          wb_dcache_we_o,  // write
   output logic   [YCR_WB_WIDTH-1:0]     wb_dcache_dat_o, // data output
   output logic   [3:0]                  wb_dcache_sel_o, // byte enable
   output logic   [9:0]                  wb_dcache_bl_o,  // Burst Length
   output logic                          wb_dcache_bry_o, // Burst Ready

   input logic   [YCR_WB_WIDTH-1:0]      wb_dcache_dat_i, // data input
   input logic                           wb_dcache_ack_i, // acknowlegement
   input logic                           wb_dcache_lack_i,// last acknowlegement
   input logic                           wb_dcache_err_i,  // error

   // DCACHE PORT-0 SRAM I/F
   output logic                          dcache_mem_clk0           , // CLK
   output logic                          dcache_mem_csb0           , // CS#
   output logic                          dcache_mem_web0           , // WE#
   output logic   [8:0]                  dcache_mem_addr0          , // Address
   output logic   [3:0]                  dcache_mem_wmask0         , // WMASK#
   output logic   [31:0]                 dcache_mem_din0           , // Write Data
   input  logic   [31:0]                 dcache_mem_dout0          , // Read Data
   
   // DCACHE PORT-1 SRAM I/F
   output logic                          dcache_mem_clk1           , // CLK
   output logic                          dcache_mem_csb1           , // CS#
   output logic  [8:0]                   dcache_mem_addr1          , // Address
   input  logic  [31:0]                  dcache_mem_dout1          , // Read Data
   `endif


    // WB Data Memory Interface
    output  logic                        wbd_dmem_stb_o, // strobe/request
    output  logic   [YCR_WB_WIDTH-1:0]   wbd_dmem_adr_o, // address
    output  logic                        wbd_dmem_we_o,  // write
    output  logic   [YCR_WB_WIDTH-1:0]   wbd_dmem_dat_o, // data output
    output  logic   [3:0]                wbd_dmem_sel_o, // byte enable
    output  logic   [YCR_WB_BL_DMEM-1:0] wbd_dmem_bl_o, // byte enable
    output  logic                        wbd_dmem_bry_o, // bursty ready
    input   logic   [YCR_WB_WIDTH-1:0]   wbd_dmem_dat_i, // data input
    input   logic                        wbd_dmem_ack_i, // acknowlegement
    input   logic                        wbd_dmem_lack_i, // acknowlegement
    input   logic                        wbd_dmem_err_i,  // error

    // AES DMEM I/F
    output   logic                       cpu_clk_aes               , 
    input    logic                       aes_dmem_req_ack          ,
    output   logic                       aes_dmem_req              ,
    output   logic                       aes_dmem_cmd              ,
    output   logic [1:0]                 aes_dmem_width            ,
    output   logic [6:0]                 aes_dmem_addr             ,
    output   logic [`YCR_DMEM_DWIDTH-1:0]aes_dmem_wdata            ,
    input    logic [`YCR_DMEM_DWIDTH-1:0]aes_dmem_rdata            ,
    input    logic [1:0]                 aes_dmem_resp             ,
    input    logic                       aes_idle                  ,

    // FPU DMEM I/F
    output   logic                       cpu_clk_fpu               ,
    input    logic                       fpu_dmem_req_ack          ,
    output   logic                       fpu_dmem_req              ,
    output   logic                       fpu_dmem_cmd              ,
    output   logic [1:0]                 fpu_dmem_width            ,
    output   logic [4:0]                 fpu_dmem_addr             ,
    output   logic [`YCR_DMEM_DWIDTH-1:0]fpu_dmem_wdata            ,
    input    logic [`YCR_DMEM_DWIDTH-1:0]fpu_dmem_rdata            ,
    input    logic [1:0]                 fpu_dmem_resp             ,
    input    logic                       fpu_idle                   
);

//-------------------------------------------------------------------------------
// Local parameters
//-------------------------------------------------------------------------------
localparam int unsigned YCR_CLUSTER_TOP_RST_SYNC_STAGES_NUM            = 2;

//-------------------------------------------------------------------------------
// Local signal declaration
//-------------------------------------------------------------------------------
// Reset logic
logic                                               pwrup_rst_n_sync;
logic                                               cpu_rst_n_sync;
logic [`YCR_NUMCORES-1:0]                           cpu_core_rst_n_sync;        // CPU Reset (Core Reset)

//----------------------------------------------------------------
// CORE-0 Specific Signals
// ---------------------------------------------------------------
logic                                              core0_clk;
logic                                              core0_sleep;
logic [48:0]                                       core0_debug;
logic [1:0]                                        core0_uid;
logic                                              core0_timer_irq;
logic [63:0]                                       core0_timer_val;
logic [YCR_IRQ_LINES_NUM-1:0]                      core0_irq_lines;  // IRQ lines to IPIC
logic                                              core0_soft_irq;  // IRQ lines to IPIC

// Instruction memory interface from core to router
logic                                              core0_imem_req_ack;
logic                                              core0_imem_req;
logic                                              core0_imem_cmd;
logic [`YCR_IMEM_AWIDTH-1:0]                       core0_imem_addr;
logic [`YCR_IMEM_BSIZE-1:0]                        core0_imem_bl;
logic [`YCR_IMEM_DWIDTH-1:0]                       core0_imem_rdata;
logic [1:0]                                        core0_imem_resp;

// Data memory interface from core to router
logic                                              core0_dmem_req_ack;
logic                                              core0_dmem_req;
logic                                              core0_dmem_cmd;
logic [1:0]                                        core0_dmem_width;
logic [`YCR_DMEM_AWIDTH-1:0]                       core0_dmem_addr;
logic [`YCR_DMEM_DWIDTH-1:0]                       core0_dmem_wdata;
logic [`YCR_DMEM_DWIDTH-1:0]                       core0_dmem_rdata;
logic [1:0]                                        core0_dmem_resp;

//----------------------------------------------------
// Data memory interface from router to WB bridge
// --------------------------------------------------
logic                                              core_dmem_req_ack;
logic                                              core_dmem_req;
logic                                              core_dmem_cmd;
logic [1:0]                                        core_dmem_width;
logic [`YCR_DMEM_AWIDTH-1:0]                       core_dmem_addr;
logic [`YCR_IMEM_BSIZE-1:0]                        core_dmem_bl;
logic [`YCR_DMEM_DWIDTH-1:0]                       core_dmem_wdata;
logic [`YCR_DMEM_DWIDTH-1:0]                       core_dmem_rdata;
logic [1:0]                                        core_dmem_resp;

//----------------------------------------------------
// icache interface from router to WB bridge
// --------------------------------------------------
logic                                              core_icache_req_ack;
logic                                              core_icache_req;
logic                                              core_icache_cmd;
logic [1:0]                                        core_icache_width;
logic [`YCR_DMEM_AWIDTH-1:0]                       core_icache_addr;
logic [2:0]                                        core_icache_bl;
logic [`YCR_DMEM_DWIDTH-1:0]                       core_icache_rdata;
logic [1:0]                                        core_icache_resp;

//----------------------------------------------------
// dcache interface from router to WB bridge
// --------------------------------------------------
logic                                              core_dcache_req_ack;
logic                                              core_dcache_req;
logic                                              core_dcache_cmd;
logic [1:0]                                        core_dcache_width;
logic [`YCR_DMEM_AWIDTH-1:0]                       core_dcache_addr;
logic [`YCR_DMEM_DWIDTH-1:0]                       core_dcache_wdata;
logic [`YCR_DMEM_DWIDTH-1:0]                       core_dcache_rdata;
logic [1:0]                                        core_dcache_resp;

logic [3:0]                                        core_clk_out;

logic                                              cfg_dcache_force_flush;

logic                                              core_clk_intf_skew;
logic                                              core_clk_icon_skew;
logic                                              core_clk_core0_skew;

//------------------------------------------------------------------------------
// Tap will be daisy chained Tap Input => <core0> => Tap Out
//------------------------------------------------------------------------------

//-------------------------------------------------------------------------------
// YCR Intf instance
//-------------------------------------------------------------------------------
ycr_iconnect u_connect (
`ifdef USE_POWER_PINS
          .VPWR                         (vccd1                        ), // User area 1 1.8V supply
          .VGND                         (vssd1                        ), // User area 1 digital ground
`endif
          .cfg_bypass_icache            (cfg_bypass_icache            ), // 1 -> Bypass icache
          .cfg_bypass_dcache            (cfg_bypass_dcache            ), // 1 -> Bypass dcache

          // Core clock skew control
          .cfg_ccska                    (cfg_ccska_riscv_icon         ),
          .core_clk_int                 (core_clk_int                 ),
          .core_clk_skew                (core_clk_icon_skew           ),
          .core_clk                     (core_clk_icon_skew           ), // Core clock

          .rtc_clk                      (rtc_clk                      ), // Core clock
	  .pwrup_rst_n                  (pwrup_rst_n                  ),
          .cpu_intf_rst_n               (cpu_intf_rst_n               ), // CPU reset

	  .riscv_debug                  (riscv_debug                  ),
          .cfg_sram_lphase              (cfg_sram_lphase[3:2]         ),

          // Interrupt buffering      
          .core_irq_lines_i             (irq_lines                    ),
          .core_irq_soft_i              (soft_irq                     ),

    // CORE-0
          .core0_clk                    (core0_clk                    ),
          .core0_sleep                  (core0_sleep                  ),
          .core0_debug                  (core0_debug                  ),
          .core0_uid                    (core0_uid                    ),
          .core0_timer_val              (core0_timer_val              ), // Machine timer value
          .core0_timer_irq              (core0_timer_irq              ), // Machine timer value
          .core0_irq_lines              (core0_irq_lines              ),
          .core0_irq_soft               (core0_soft_irq               ),

    // Instruction Memory Interface
          .core0_imem_req_ack           (core0_imem_req_ack           ), // IMEM request acknowledge
          .core0_imem_req               (core0_imem_req               ), // IMEM request
          .core0_imem_cmd               (core0_imem_cmd               ), // IMEM command
          .core0_imem_addr              (core0_imem_addr              ), // IMEM address
          .core0_imem_bl                (core0_imem_bl                ), // IMEM address
          .core0_imem_rdata             (core0_imem_rdata             ), // IMEM read data
          .core0_imem_resp              (core0_imem_resp              ), // IMEM response

    // Data Memory Interface
          .core0_dmem_req_ack           (core0_dmem_req_ack           ), // DMEM request acknowledge
          .core0_dmem_req               (core0_dmem_req               ), // DMEM request
          .core0_dmem_cmd               (core0_dmem_cmd               ), // DMEM command
          .core0_dmem_width             (core0_dmem_width             ), // DMEM data width
          .core0_dmem_addr              (core0_dmem_addr              ), // DMEM address
          .core0_dmem_wdata             (core0_dmem_wdata             ), // DMEM write data
          .core0_dmem_rdata             (core0_dmem_rdata             ), // DMEM read data
          .core0_dmem_resp              (core0_dmem_resp              ), // DMEM response

    //------------------------------------------------------------------
    // Toward ycr_intf
    // -----------------------------------------------------------------
          .cpu_clk_intf                 (cpu_clk_intf                 ),
          .cfg_dcache_force_flush       (cfg_dcache_force_flush       ),

    // Interface to dmem router
          .core_dmem_req_ack            (core_dmem_req_ack            ),
          .core_dmem_req                (core_dmem_req                ),
          .core_dmem_cmd                (core_dmem_cmd                ),
          .core_dmem_width              (core_dmem_width              ),
          .core_dmem_addr               (core_dmem_addr               ),
          .core_dmem_bl                 (core_dmem_bl                 ),
          .core_dmem_wdata              (core_dmem_wdata              ),
          .core_dmem_rdata              (core_dmem_rdata              ),
          .core_dmem_resp               (core_dmem_resp               ),

        `ifdef YCR_ICACHE_EN
            // Interface to TCM
          .core_icache_req_ack           (core_icache_req_ack           ),
          .core_icache_req               (core_icache_req               ),
          .core_icache_cmd               (core_icache_cmd               ),
          .core_icache_width             (core_icache_width             ),
          .core_icache_addr              (core_icache_addr              ),
          .core_icache_bl                (core_icache_bl                ),
          .core_icache_rdata             (core_icache_rdata             ),
          .core_icache_resp              (core_icache_resp              ),
        `endif // YCR_ICACHE_EN
        
        `ifdef YCR_DCACHE_EN
            // Interface to TCM
          .core_dcache_req_ack           (core_dcache_req_ack           ),
          .core_dcache_req               (core_dcache_req               ),
          .core_dcache_cmd               (core_dcache_cmd               ),
          .core_dcache_width             (core_dcache_width             ),
          .core_dcache_addr              (core_dcache_addr              ),
          .core_dcache_wdata             (core_dcache_wdata             ),
          .core_dcache_rdata             (core_dcache_rdata             ),
          .core_dcache_resp              (core_dcache_resp              ),
        `endif // YCR_ICACHE_EN
`ifndef YCR_TCM_MEM
    // SRAM-0 PORT-0
          .sram0_clk0                   (sram0_clk0                     ),
          .sram0_csb0                   (sram0_csb0                     ),
          .sram0_web0                   (sram0_web0                     ),
          .sram0_addr0                  (sram0_addr0                    ),
          .sram0_wmask0                 (sram0_wmask0                   ),
          .sram0_din0                   (sram0_din0                     ),
          .sram0_dout0                  (sram0_dout0                    ),
    
    // SRAM-0 PORT-1
          .sram0_clk1                   (sram0_clk1                     ),
          .sram0_csb1                   (sram0_csb1                     ),
          .sram0_addr1                  (sram0_addr1                    ),
          .sram0_dout1                  (sram0_dout1                    ),
 
`endif
          .cpu_clk_aes                  (cpu_clk_aes                    ),
          .aes_dmem_req_ack             (aes_dmem_req_ack               ),
          .aes_dmem_req                 (aes_dmem_req                   ),
          .aes_dmem_cmd                 (aes_dmem_cmd                   ),
          .aes_dmem_width               (aes_dmem_width                 ),
          .aes_dmem_addr                (aes_dmem_addr                  ),
          .aes_dmem_wdata               (aes_dmem_wdata                 ),
          .aes_dmem_rdata               (aes_dmem_rdata                 ),
          .aes_dmem_resp                (aes_dmem_resp                  ),
          .aes_idle                     (aes_idle                       ),

          .cpu_clk_fpu                  (cpu_clk_fpu                    ),
          .fpu_dmem_req_ack             (fpu_dmem_req_ack               ),
          .fpu_dmem_req                 (fpu_dmem_req                   ),
          .fpu_dmem_cmd                 (fpu_dmem_cmd                   ),
          .fpu_dmem_width               (fpu_dmem_width                 ),
          .fpu_dmem_addr                (fpu_dmem_addr                  ),
          .fpu_dmem_wdata               (fpu_dmem_wdata                 ),
          .fpu_dmem_rdata               (fpu_dmem_rdata                 ),
          .fpu_dmem_resp                (fpu_dmem_resp                  ),
          .fpu_idle                     (fpu_idle                       )
);

//----------------------------------------------------------------------
//  Interface
//  -------------------------------------------------------------------

ycr_intf u_intf(
`ifdef USE_POWER_PINS
    .vccd1                     (vccd1), // User area 1 1.8V supply
    .vssd1                     (vssd1), // User area 1 digital ground
`endif

     // Core clock skew control
    .cfg_ccska                (cfg_ccska_riscv_intf      ),
    .core_clk_int             (cpu_clk_intf              ),
    .core_clk_skew            (core_clk_intf_skew        ),
    .core_clk                 (core_clk_intf_skew        ), // Core clock


     // WB  clock skew control
    .cfg_wcska                (cfg_wcska_riscv_intf      ),
    .wbd_clk_int              (wbd_clk_int               ),
    .wbd_clk_skew             (wbd_clk_skew              ),


    // Control
    .pwrup_rst_n               (pwrup_rst_n               ), // Power-Up Reset
    .cpu_intf_rst_n            (cpu_intf_rst_n            ), // CPU interface reset

    .cfg_icache_pfet_dis       (cfg_cache_ctrl[0]         ),
    .cfg_icache_ntag_pfet_dis  (cfg_cache_ctrl[1]         ),
    .cfg_dcache_pfet_dis       (cfg_cache_ctrl[2]         ),
    .cfg_dcache_force_flush    (cfg_dcache_force_flush    ),
    .cfg_sram_lphase           (cfg_sram_lphase[1:0]      ),
    .cfg_bypass_icache         (cfg_bypass_icache         ), // 1 -> Bypass icache
    .cfg_bypass_dcache         (cfg_bypass_dcache         ), // 1 -> Bypass dcache

    // Instruction Memory Interface
    .core_icache_req_ack       (core_icache_req_ack       ), // IMEM request acknowledge
    .core_icache_req           (core_icache_req           ), // IMEM request
    .core_icache_cmd           (core_icache_cmd           ), // IMEM command
    .core_icache_width         (core_icache_width         ),
    .core_icache_addr          (core_icache_addr          ), // IMEM address
    .core_icache_bl            (core_icache_bl            ), // IMEM burst size
    .core_icache_rdata         (core_icache_rdata         ), // IMEM read data
    .core_icache_resp          (core_icache_resp          ), // IMEM response

    // Data Memory Interface
    .core_dcache_req_ack       (core_dcache_req_ack       ), // DMEM request acknowledge
    .core_dcache_req           (core_dcache_req           ), // DMEM request
    .core_dcache_cmd           (core_dcache_cmd           ), // DMEM command
    .core_dcache_width         (core_dcache_width         ), // DMEM data width
    .core_dcache_addr          (core_dcache_addr          ), // DMEM address
    .core_dcache_wdata         (core_dcache_wdata         ), // DMEM write data
    .core_dcache_rdata         (core_dcache_rdata         ), // DMEM read data
    .core_dcache_resp          (core_dcache_resp          ), // DMEM response

    // Data memory interface from router to WB bridge
    .core_dmem_req_ack         (core_dmem_req_ack         ),
    .core_dmem_req             (core_dmem_req             ),
    .core_dmem_cmd             (core_dmem_cmd             ),
    .core_dmem_width           (core_dmem_width           ),
    .core_dmem_addr            (core_dmem_addr            ),
    .core_dmem_bl              (core_dmem_bl              ),
    .core_dmem_wdata           (core_dmem_wdata           ),
    .core_dmem_rdata           (core_dmem_rdata           ),
    .core_dmem_resp            (core_dmem_resp            ),
    //--------------------------------------------
    // Wishbone  
    // ------------------------------------------

    .wb_rst_n                  (wb_rst_n                  ), // Wish bone reset
    .wb_clk                    (wb_clk                    ), // wish bone clock

    // Data Memory Interface
    .wbd_dmem_stb_o            (wbd_dmem_stb_o            ), // strobe/request
    .wbd_dmem_adr_o            (wbd_dmem_adr_o            ), // address
    .wbd_dmem_we_o             (wbd_dmem_we_o             ), // write
    .wbd_dmem_dat_o            (wbd_dmem_dat_o            ), // data output
    .wbd_dmem_sel_o            (wbd_dmem_sel_o            ), // byte enable
    .wbd_dmem_bl_o             (wbd_dmem_bl_o             ), // byte enable
    .wbd_dmem_bry_o            (wbd_dmem_bry_o            ), // burst ready
    .wbd_dmem_dat_i            (wbd_dmem_dat_i            ), // data input
    .wbd_dmem_ack_i            (wbd_dmem_ack_i            ), // acknowlegement
    .wbd_dmem_lack_i           (wbd_dmem_lack_i           ), // acknowlegement
    .wbd_dmem_err_i            (wbd_dmem_err_i            ), // error

   `ifdef YCR_ICACHE_EN
   // Wishbone ICACHE I/F
   .wb_icache_cyc_o           (                           ), // strobe/request
   .wb_icache_stb_o           (wb_icache_stb_o            ), // strobe/request
   .wb_icache_adr_o           (wb_icache_adr_o            ), // address
   .wb_icache_we_o            (wb_icache_we_o             ), // write
   .wb_icache_sel_o           (wb_icache_sel_o            ), // byte enable
   .wb_icache_bl_o            (wb_icache_bl_o             ), // Burst Length
   .wb_icache_bry_o           (wb_icache_bry_o            ), // Burst Ready 
                                                        
   .wb_icache_dat_i           (wb_icache_dat_i            ), // data input
   .wb_icache_ack_i           (wb_icache_ack_i            ), // acknowlegement
   .wb_icache_lack_i          (wb_icache_lack_i           ), // last acknowlegement
   .wb_icache_err_i           (wb_icache_err_i            ), // error

   // CACHE SRAM Memory I/F
   .icache_mem_clk0           (icache_mem_clk0            ), // CLK
   .icache_mem_csb0           (icache_mem_csb0            ), // CS#
   .icache_mem_web0           (icache_mem_web0            ), // WE#
   .icache_mem_addr0          (icache_mem_addr0           ), // Address
   .icache_mem_wmask0         (icache_mem_wmask0          ), // WMASK#
   .icache_mem_din0           (icache_mem_din0            ), // Write Data
// .icache_mem_dout0          (icache_mem_dout0           ), // Read Data
   
   // SRAM-0 PORT-1, IMEM I/F
   .icache_mem_clk1           (icache_mem_clk1            ), // CLK
   .icache_mem_csb1           (icache_mem_csb1            ), // CS#
   .icache_mem_addr1          (icache_mem_addr1           ), // Address
   .icache_mem_dout1          (icache_mem_dout1           ), // Read Data
   `endif

   `ifdef YCR_DCACHE_EN
   // Wishbone ICACHE I/F
   .wb_dcache_cyc_o           (                           ), // strobe/request
   .wb_dcache_stb_o           (wb_dcache_stb_o            ), // strobe/request
   .wb_dcache_adr_o           (wb_dcache_adr_o            ), // address
   .wb_dcache_we_o            (wb_dcache_we_o             ), // write
   .wb_dcache_dat_o           (wb_dcache_dat_o            ), // data output
   .wb_dcache_sel_o           (wb_dcache_sel_o            ), // byte enable
   .wb_dcache_bl_o            (wb_dcache_bl_o             ), // Burst Length
   .wb_dcache_bry_o           (wb_dcache_bry_o            ), // Burst Ready

   .wb_dcache_dat_i           (wb_dcache_dat_i            ), // data input
   .wb_dcache_ack_i           (wb_dcache_ack_i            ), // acknowlegement
   .wb_dcache_lack_i          (wb_dcache_lack_i           ), // last acknowlegement
   .wb_dcache_err_i           (wb_dcache_err_i            ), // error

   // CACHE SRAM Memory I/F
   .dcache_mem_clk0           (dcache_mem_clk0            ), // CLK
   .dcache_mem_csb0           (dcache_mem_csb0            ), // CS#
   .dcache_mem_web0           (dcache_mem_web0            ), // WE#
   .dcache_mem_addr0          (dcache_mem_addr0           ), // Address
   .dcache_mem_wmask0         (dcache_mem_wmask0          ), // WMASK#
   .dcache_mem_din0           (dcache_mem_din0            ), // Write Data
   .dcache_mem_dout0          (dcache_mem_dout0           ), // Read Data
   
   // SRAM-0 PORT-1, IMEM I/F
   .dcache_mem_clk1           (dcache_mem_clk1            ), // CLK
   .dcache_mem_csb1           (dcache_mem_csb1            ), // CS#
   .dcache_mem_addr1          (dcache_mem_addr1           ), // Address
   .dcache_mem_dout1          (dcache_mem_dout1           )  // Read Data

   `endif
);

//-------------------------------------------------------------------------------
// YCR core_0 instance
//-------------------------------------------------------------------------------
ycr_core_top i_core_top_0 (
`ifdef USE_POWER_PINS
          .vccd1                        (vccd1), // User area 1 1.8V supply
          .vssd1                        (vssd1), // User area 1 digital ground
`endif
    // Common
          .pwrup_rst_n                  (pwrup_rst_n                  ),
          .rst_n                        (rst_n                        ),
          .cpu_rst_n                    (cpu_core_rst_n               ),
          // Core clock skew control
          .cfg_ccska                    (cfg_ccska_riscv_core0        ),
          .core_clk_int                 (core0_clk                    ),
          .core_clk_skew                (core_clk_core0_skew          ),
          .clk                          (core_clk_core0_skew          ),


          .clk_o                        (core_clk_out[0]              ),
          .core_rst_n_o                 (                             ),
          .core_rdc_qlfy_o              (                             ),
`ifdef YCR_DBG_EN
          .sys_rst_n_o                  (sys_rst_n_o                  ),
          .sys_rdc_qlfy_o               (sys_rdc_qlfy_o               ),
`endif // YCR_DBG_EN

          .core_sleep                    (core0_sleep                  ),

    // IRQ
`ifdef YCR_IPIC_EN
          .core_irq_lines_i             (core0_irq_lines              ),
`else // YCR_IPIC_EN
          .core_irq_ext_i               (ext_irq                      ),
`endif // YCR_IPIC_EN
          .core_irq_soft_i              (core0_soft_irq               ),
`ifdef YCR_DBG_EN
    // Debug interface
          .trst_n                       (trst_n                       ),
          .tapc_tck                     (tck                          ),
          .tapc_tms                     (tms                          ),
          .tapc_tdi                     (tdi                          ),
          .tapc_tdo                     (tdo                          ),
          .tapc_tdo_en                  (tdo_en                       ),
`endif // YCR_DBG_EN

   //---- inter-connect
          .core_irq_mtimer_i            (core0_timer_irq              ),
          .core_mtimer_val_i            (core0_timer_val              ),
          .core_uid                     (core0_uid                    ),
          .core_debug                   (core0_debug                  ),
    // Instruction memory interface
          .imem2core_req_ack_i          (core0_imem_req_ack           ),
          .core2imem_req_o              (core0_imem_req               ),
          .core2imem_cmd_o              (core0_imem_cmd               ),
          .core2imem_addr_o             (core0_imem_addr              ),
          .core2imem_bl_o               (core0_imem_bl                ),
          .imem2core_rdata_i            (core0_imem_rdata             ),
          .imem2core_resp_i             (core0_imem_resp              ),

    // Data memory interface
          .dmem2core_req_ack_i          (core0_dmem_req_ack           ),
          .core2dmem_req_o              (core0_dmem_req               ),
          .core2dmem_cmd_o              (core0_dmem_cmd               ),
          .core2dmem_width_o            (core0_dmem_width             ),
          .core2dmem_addr_o             (core0_dmem_addr              ),
          .core2dmem_wdata_o            (core0_dmem_wdata             ),
          .dmem2core_rdata_i            (core0_dmem_rdata             ),
          .dmem2core_resp_i             (core0_dmem_resp              )
);







endmodule : ycr_top_wb


