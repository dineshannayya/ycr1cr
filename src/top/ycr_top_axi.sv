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
////  yifive AXI TOP                                                      ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     AXI TOP                                                          ////
////                                                                      ////
////  To Do:                                                              ////
////    nothing                                                           ////
////                                                                      ////
////  Author(s):                                                          ////
////      - Dinesh Annayya, dinesha@opencores.org                         ////
////                                                                      ////
////  Revision :                                                          ////
////     v0:    Jan 2021- Initial version picked from syntacore/scr1      ////
////     v1:    June 7, 2021, Dinesh A                                    ////
////             opentool(iverilog/yosys) related cleanup                 ////
////                                                                      ////
//////////////////////////////////////////////////////////////////////////////

`include "ycr_arch_description.svh"
`include "ycr_memif.svh"
`ifdef YCR_IPIC_EN
`include "ycr_ipic.svh"
`endif // YCR_IPIC_EN

`ifdef YCR_TCM_EN
 `define YCR_IMEM_ROUTER_EN
`endif // YCR_TCM_EN

module ycr_top_axi (
    // Control
    input   logic                                   pwrup_rst_n,            // Power-Up Reset
    input   logic                                   rst_n,                  // Regular Reset signal
    input   logic                                   cpu_rst_n,              // CPU Reset (Core Reset)
    input   logic                                   test_mode,              // Test mode
    input   logic                                   test_rst_n,             // Test mode's reset
    input   logic                                   clk,                    // System clock
    input   logic                                   rtc_clk,                // Real-time clock
`ifdef YCR_DBG_EN
    output  logic                                   sys_rst_n_o,            // External System Reset output
                                                                            //   (for the processor cluster's components or
                                                                            //    external SOC (could be useful in small
                                                                            //    YCR-core-centric SOCs))
    output  logic                                   sys_rdc_qlfy_o,         // System-to-External SOC Reset Domain Crossing Qualifier
`endif // YCR_DBG_EN

    // Fuses
    input   logic [`YCR_XLEN-1:0]                  fuse_mhartid,           // Hart ID
`ifdef YCR_DBG_EN
    input   logic [31:0]                            fuse_idcode,            // TAPC IDCODE
`endif // YCR_DBG_EN

    // IRQ
`ifdef YCR_IPIC_EN
    input   logic [YCR_IRQ_LINES_NUM-1:0]          irq_lines,              // IRQ lines to IPIC
`else // YCR_IPIC_EN
    input   logic                                   ext_irq,                // External IRQ input
`endif // YCR_IPIC_EN
    input   logic                                   soft_irq,               // Software IRQ input

`ifdef YCR_DBG_EN
    // -- JTAG I/F
    input   logic                                   trst_n,
    input   logic                                   tck,
    input   logic                                   tms,
    input   logic                                   tdi,
    output  logic                                   tdo,
    output  logic                                   tdo_en,
`endif // YCR_DBG_EN

    // Instruction Memory Interface
    output  logic [3:0]                             io_axi_imem_awid,
    output  logic [31:0]                            io_axi_imem_awaddr,
    output  logic [7:0]                             io_axi_imem_awlen,
    output  logic [2:0]                             io_axi_imem_awsize,
    output  logic [1:0]                             io_axi_imem_awburst,
    output  logic                                   io_axi_imem_awlock,
    output  logic [3:0]                             io_axi_imem_awcache,
    output  logic [2:0]                             io_axi_imem_awprot,
    output  logic [3:0]                             io_axi_imem_awregion,
    output  logic [3:0]                             io_axi_imem_awuser,
    output  logic [3:0]                             io_axi_imem_awqos,
    output  logic                                   io_axi_imem_awvalid,
    input   logic                                   io_axi_imem_awready,
    output  logic [31:0]                            io_axi_imem_wdata,
    output  logic [3:0]                             io_axi_imem_wstrb,
    output  logic                                   io_axi_imem_wlast,
    output  logic [3:0]                             io_axi_imem_wuser,
    output  logic                                   io_axi_imem_wvalid,
    input   logic                                   io_axi_imem_wready,
    input   logic [3:0]                             io_axi_imem_bid,
    input   logic [1:0]                             io_axi_imem_bresp,
    input   logic                                   io_axi_imem_bvalid,
    input   logic [3:0]                             io_axi_imem_buser,
    output  logic                                   io_axi_imem_bready,
    output  logic [3:0]                             io_axi_imem_arid,
    output  logic [31:0]                            io_axi_imem_araddr,
    output  logic [7:0]                             io_axi_imem_arlen,
    output  logic [2:0]                             io_axi_imem_arsize,
    output  logic [1:0]                             io_axi_imem_arburst,
    output  logic                                   io_axi_imem_arlock,
    output  logic [3:0]                             io_axi_imem_arcache,
    output  logic [2:0]                             io_axi_imem_arprot,
    output  logic [3:0]                             io_axi_imem_arregion,
    output  logic [3:0]                             io_axi_imem_aruser,
    output  logic [3:0]                             io_axi_imem_arqos,
    output  logic                                   io_axi_imem_arvalid,
    input   logic                                   io_axi_imem_arready,
    input   logic [3:0]                             io_axi_imem_rid,
    input   logic [31:0]                            io_axi_imem_rdata,
    input   logic [1:0]                             io_axi_imem_rresp,
    input   logic                                   io_axi_imem_rlast,
    input   logic [3:0]                             io_axi_imem_ruser,
    input   logic                                   io_axi_imem_rvalid,
    output  logic                                   io_axi_imem_rready,

    // Data Memory Interface
    output  logic [3:0]                             io_axi_dmem_awid,
    output  logic [31:0]                            io_axi_dmem_awaddr,
    output  logic [7:0]                             io_axi_dmem_awlen,
    output  logic [2:0]                             io_axi_dmem_awsize,
    output  logic [1:0]                             io_axi_dmem_awburst,
    output  logic                                   io_axi_dmem_awlock,
    output  logic [3:0]                             io_axi_dmem_awcache,
    output  logic [2:0]                             io_axi_dmem_awprot,
    output  logic [3:0]                             io_axi_dmem_awregion,
    output  logic [3:0]                             io_axi_dmem_awuser,
    output  logic [3:0]                             io_axi_dmem_awqos,
    output  logic                                   io_axi_dmem_awvalid,
    input   logic                                   io_axi_dmem_awready,
    output  logic [31:0]                            io_axi_dmem_wdata,
    output  logic [3:0]                             io_axi_dmem_wstrb,
    output  logic                                   io_axi_dmem_wlast,
    output  logic [3:0]                             io_axi_dmem_wuser,
    output  logic                                   io_axi_dmem_wvalid,
    input   logic                                   io_axi_dmem_wready,
    input   logic [3:0]                             io_axi_dmem_bid,
    input   logic [1:0]                             io_axi_dmem_bresp,
    input   logic                                   io_axi_dmem_bvalid,
    input   logic [3:0]                             io_axi_dmem_buser,
    output  logic                                   io_axi_dmem_bready,
    output  logic [3:0]                             io_axi_dmem_arid,
    output  logic [31:0]                            io_axi_dmem_araddr,
    output  logic [7:0]                             io_axi_dmem_arlen,
    output  logic [2:0]                             io_axi_dmem_arsize,
    output  logic [1:0]                             io_axi_dmem_arburst,
    output  logic                                   io_axi_dmem_arlock,
    output  logic [3:0]                             io_axi_dmem_arcache,
    output  logic [2:0]                             io_axi_dmem_arprot,
    output  logic [3:0]                             io_axi_dmem_arregion,
    output  logic [3:0]                             io_axi_dmem_aruser,
    output  logic [3:0]                             io_axi_dmem_arqos,
    output  logic                                   io_axi_dmem_arvalid,
    input   logic                                   io_axi_dmem_arready,
    input   logic [3:0]                             io_axi_dmem_rid,
    input   logic [31:0]                            io_axi_dmem_rdata,
    input   logic [1:0]                             io_axi_dmem_rresp,
    input   logic                                   io_axi_dmem_rlast,
    input   logic [3:0]                             io_axi_dmem_ruser,
    input   logic                                   io_axi_dmem_rvalid,
    output  logic                                   io_axi_dmem_rready
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
logic                                               rst_n_sync;
logic                                               cpu_rst_n_sync;
logic                                               core_rst_n_local;
logic                                               axi_rst_n;
`ifdef YCR_DBG_EN
logic                                               tapc_trst_n;
`endif // YCR_DBG_EN

// Instruction memory interface from core to router
logic                                               core_imem_req_ack;
logic                                               core_imem_req;
logic                                               core_imem_cmd;
logic [`YCR_IMEM_AWIDTH-1:0]                       core_imem_addr;
logic [`YCR_IMEM_DWIDTH-1:0]                       core_imem_rdata;
logic [1:0]                                         core_imem_resp;

// Data memory interface from core to router
logic                                               core_dmem_req_ack;
logic                                               core_dmem_req;
logic                                               core_dmem_cmd;
logic [1:0]                                         core_dmem_width;
logic [`YCR_DMEM_AWIDTH-1:0]                       core_dmem_addr;
logic [`YCR_DMEM_DWIDTH-1:0]                       core_dmem_wdata;
logic [`YCR_DMEM_DWIDTH-1:0]                       core_dmem_rdata;
logic [1:0]                                         core_dmem_resp;

// Instruction memory interface from router to AXI bridge
logic                                               axi_imem_req_ack;
logic                                               axi_imem_req;
logic                                               axi_imem_cmd;
logic [`YCR_IMEM_AWIDTH-1:0]                       axi_imem_addr;
logic [`YCR_IMEM_DWIDTH-1:0]                       axi_imem_rdata;
logic [1:0]                                         axi_imem_resp;

// Data memory interface from router to AXI bridge
logic                                               axi_dmem_req_ack;
logic                                               axi_dmem_req;
logic                                               axi_dmem_cmd;
logic [1:0]                                         axi_dmem_width;
logic [`YCR_DMEM_AWIDTH-1:0]                       axi_dmem_addr;
logic [`YCR_DMEM_DWIDTH-1:0]                       axi_dmem_wdata;
logic [`YCR_DMEM_DWIDTH-1:0]                       axi_dmem_rdata;
logic [1:0]                                         axi_dmem_resp;

`ifdef YCR_TCM_EN
// Instruction memory interface from router to TCM
logic                                               tcm_imem_req_ack;
logic                                               tcm_imem_req;
logic                                               tcm_imem_cmd;
logic [`YCR_IMEM_AWIDTH-1:0]                       tcm_imem_addr;
logic [`YCR_IMEM_DWIDTH-1:0]                       tcm_imem_rdata;
logic [1:0]                                         tcm_imem_resp;

// Data memory interface from router to TCM
logic                                               tcm_dmem_req_ack;
logic                                               tcm_dmem_req;
logic                                               tcm_dmem_cmd;
logic [1:0]                                         tcm_dmem_width;
logic [`YCR_DMEM_AWIDTH-1:0]                       tcm_dmem_addr;
logic [`YCR_DMEM_DWIDTH-1:0]                       tcm_dmem_wdata;
logic [`YCR_DMEM_DWIDTH-1:0]                       tcm_dmem_rdata;
logic [1:0]                                         tcm_dmem_resp;
`endif // YCR_TCM_EN

// Data memory interface from router to memory-mapped timer
logic                                               timer_dmem_req_ack;
logic                                               timer_dmem_req;
logic                                               timer_dmem_cmd;
logic [1:0]                                         timer_dmem_width;
logic [`YCR_DMEM_AWIDTH-1:0]                       timer_dmem_addr;
logic [`YCR_DMEM_DWIDTH-1:0]                       timer_dmem_wdata;
logic [`YCR_DMEM_DWIDTH-1:0]                       timer_dmem_rdata;
logic [1:0]                                         timer_dmem_resp;

// Misc
logic                                               timer_irq;
logic [63:0]                                        timer_val;
logic                                               axi_reinit;
logic                                               axi_imem_idle;
logic                                               axi_dmem_idle;

//-------------------------------------------------------------------------------
// Reset logic
//-------------------------------------------------------------------------------
// Power-Up Reset synchronizer
ycr_reset_sync_cell #(
    .STAGES_AMOUNT       (YCR_CLUSTER_TOP_RST_SYNC_STAGES_NUM)
) i_pwrup_rstn_reset_sync (
    .rst_n          (pwrup_rst_n     ),
    .clk            (clk             ),
    .test_rst_n     (test_rst_n      ),
    .test_mode      (test_mode       ),
    .rst_n_in       (1'b1            ),
    .rst_n_out      (pwrup_rst_n_sync)
);

// Regular Reset synchronizer
ycr_reset_sync_cell #(
    .STAGES_AMOUNT       (YCR_CLUSTER_TOP_RST_SYNC_STAGES_NUM)
) i_rstn_reset_sync (
    .rst_n          (pwrup_rst_n     ),
    .clk            (clk             ),
    .test_rst_n     (test_rst_n      ),
    .test_mode      (test_mode       ),
    .rst_n_in       (rst_n           ),
    .rst_n_out      (rst_n_sync      )
);

// CPU Reset synchronizer
ycr_reset_sync_cell #(
    .STAGES_AMOUNT       (YCR_CLUSTER_TOP_RST_SYNC_STAGES_NUM)
) i_cpu_rstn_reset_sync (
    .rst_n          (pwrup_rst_n     ),
    .clk            (clk             ),
    .test_rst_n     (test_rst_n      ),
    .test_mode      (test_mode       ),
    .rst_n_in       (cpu_rst_n       ),
    .rst_n_out      (cpu_rst_n_sync  )
);

`ifdef YCR_DBG_EN
// TAPC Reset
ycr_reset_and2_cell i_tapc_rstn_and2_cell (
    .rst_n_in       ({trst_n, pwrup_rst_n}),
    .test_rst_n     (test_rst_n      ),
    .test_mode      (test_mode       ),
    .rst_n_out      (tapc_trst_n     )
);
`endif // YCR_DBG_EN

`ifdef YCR_DBG_EN
assign axi_rst_n = sys_rst_n_o;
`else // YCR_DBG_EN
assign axi_rst_n = rst_n_sync;
`endif // YCR_DBG_EN

//-------------------------------------------------------------------------------
// YCR core instance
//-------------------------------------------------------------------------------
ycr_core_top i_core_top (
    // Common
    .pwrup_rst_n                (pwrup_rst_n_sync ),
    .rst_n                      (rst_n_sync       ),
    .cpu_rst_n                  (cpu_rst_n_sync   ),
    .test_mode                  (test_mode        ),
    .test_rst_n                 (test_rst_n       ),
    .clk                        (clk              ),
    .core_rst_n_o               (core_rst_n_local ),
    .core_rdc_qlfy_o            (                 ),
`ifdef YCR_DBG_EN
    .sys_rst_n_o                (sys_rst_n_o      ),
    .sys_rdc_qlfy_o             (sys_rdc_qlfy_o   ),
`endif // YCR_DBG_EN

    // Fuses
    .core_fuse_mhartid_i        (fuse_mhartid     ),
`ifdef YCR_DBG_EN
    .tapc_fuse_idcode_i         (fuse_idcode      ),
`endif // YCR_DBG_EN

    // IRQ
`ifdef YCR_IPIC_EN
    .core_irq_lines_i           (irq_lines        ),
`else // YCR_IPIC_EN
    .core_irq_ext_i             (ext_irq          ),
`endif // YCR_IPIC_EN
    .core_irq_soft_i            (soft_irq         ),
    .core_irq_mtimer_i          (timer_irq        ),

    // Memory-mapped external timer
    .core_mtimer_val_i          (timer_val        ),

`ifdef YCR_DBG_EN
    // Debug interface
    .tapc_trst_n                (tapc_trst_n      ),
    .tapc_tck                   (tck              ),
    .tapc_tms                   (tms              ),
    .tapc_tdi                   (tdi              ),
    .tapc_tdo                   (tdo              ),
    .tapc_tdo_en                (tdo_en           ),
`endif // YCR_DBG_EN

    // Instruction memory interface
    .imem2core_req_ack_i        (core_imem_req_ack),
    .core2imem_req_o            (core_imem_req    ),
    .core2imem_cmd_o            (core_imem_cmd    ),
    .core2imem_addr_o           (core_imem_addr   ),
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


`ifdef YCR_TCM_EN
//-------------------------------------------------------------------------------
// TCM instance
//-------------------------------------------------------------------------------
ycr_tcm #(
    .YCR_TCM_SIZE  (`YCR_DMEM_AWIDTH'(~YCR_TCM_ADDR_MASK + 1'b1))
) i_tcm (
    .clk            (clk             ),
    .rst_n          (core_rst_n_local),

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
`endif // YCR_TCM_EN


//-------------------------------------------------------------------------------
// Memory-mapped timer instance
//-------------------------------------------------------------------------------
ycr_timer i_timer (
    // Common
    .rst_n          (core_rst_n_local  ),
    .clk            (clk               ),
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
    .timer_irq      (timer_irq         )
);


`ifdef YCR_IMEM_ROUTER_EN
//-------------------------------------------------------------------------------
// Instruction memory router
//-------------------------------------------------------------------------------
ycr_imem_router #(
    .YCR_ADDR_MASK     (YCR_TCM_ADDR_MASK),
    .YCR_ADDR_PATTERN  (YCR_TCM_ADDR_PATTERN)
) i_imem_router (
    .rst_n          (core_rst_n_local ),
    .clk            (clk              ),

    // Interface to core
    .imem_req_ack   (core_imem_req_ack),
    .imem_req       (core_imem_req    ),
    .imem_cmd       (core_imem_cmd    ),
    .imem_addr      (core_imem_addr   ),
    .imem_rdata     (core_imem_rdata  ),
    .imem_resp      (core_imem_resp   ),

    // Interface to AXI bridge
    .port0_req_ack  (axi_imem_req_ack ),
    .port0_req      (axi_imem_req     ),
    .port0_cmd      (axi_imem_cmd     ),
    .port0_addr     (axi_imem_addr    ),
    .port0_rdata    (axi_imem_rdata   ),
    .port0_resp     (axi_imem_resp    ),

    // Interface to TCM
    .port1_req_ack  (tcm_imem_req_ack ),
    .port1_req      (tcm_imem_req     ),
    .port1_cmd      (tcm_imem_cmd     ),
    .port1_addr     (tcm_imem_addr    ),
    .port1_rdata    (tcm_imem_rdata   ),
    .port1_resp     (tcm_imem_resp    )
);

`else // YCR_IMEM_ROUTER_EN

assign axi_imem_req         = core_imem_req;
assign axi_imem_cmd         = core_imem_cmd;
assign axi_imem_addr        = core_imem_addr;
assign core_imem_req_ack    = axi_imem_req_ack;
assign core_imem_resp       = axi_imem_resp;
assign core_imem_rdata      = axi_imem_rdata;

`endif // YCR_IMEM_ROUTER_EN


//-------------------------------------------------------------------------------
// Data memory router
//-------------------------------------------------------------------------------
ycr_dmem_router #(

`ifdef YCR_TCM_EN
    .YCR_PORT1_ADDR_MASK       (YCR_TCM_ADDR_MASK),
    .YCR_PORT1_ADDR_PATTERN    (YCR_TCM_ADDR_PATTERN),
`else // YCR_TCM_EN
    .YCR_PORT1_ADDR_MASK       (32'h00000000),
    .YCR_PORT1_ADDR_PATTERN    (32'hFFFFFFFF),
`endif // YCR_TCM_EN

    .YCR_PORT2_ADDR_MASK       (YCR_TIMER_ADDR_MASK),
    .YCR_PORT2_ADDR_PATTERN    (YCR_TIMER_ADDR_PATTERN)

) i_dmem_router (
    .rst_n          (core_rst_n_local    ),
    .clk            (clk                 ),

    // Interface to core
    .dmem_req_ack   (core_dmem_req_ack   ),
    .dmem_req       (core_dmem_req       ),
    .dmem_cmd       (core_dmem_cmd       ),
    .dmem_width     (core_dmem_width     ),
    .dmem_addr      (core_dmem_addr      ),
    .dmem_wdata     (core_dmem_wdata     ),
    .dmem_rdata     (core_dmem_rdata     ),
    .dmem_resp      (core_dmem_resp      ),

`ifdef YCR_TCM_EN
    // Interface to TCM
    .port1_req_ack  (tcm_dmem_req_ack    ),
    .port1_req      (tcm_dmem_req        ),
    .port1_cmd      (tcm_dmem_cmd        ),
    .port1_width    (tcm_dmem_width      ),
    .port1_addr     (tcm_dmem_addr       ),
    .port1_wdata    (tcm_dmem_wdata      ),
    .port1_rdata    (tcm_dmem_rdata      ),
    .port1_resp     (tcm_dmem_resp       ),
`else // YCR_TCM_EN
    .port1_req_ack  (1'b0                ),
    .port1_req      (                    ),
    .port1_cmd      (                    ),
    .port1_width    (                    ),
    .port1_addr     (                    ),
    .port1_wdata    (                    ),
    .port1_rdata    ('0                  ),
    .port1_resp     (YCR_MEM_RESP_RDY_ER),
`endif // YCR_TCM_EN

    // Interface to memory-mapped timer
    .port2_req_ack  (timer_dmem_req_ack  ),
    .port2_req      (timer_dmem_req      ),
    .port2_cmd      (timer_dmem_cmd      ),
    .port2_width    (timer_dmem_width    ),
    .port2_addr     (timer_dmem_addr     ),
    .port2_wdata    (timer_dmem_wdata    ),
    .port2_rdata    (timer_dmem_rdata    ),
    .port2_resp     (timer_dmem_resp     ),

    // Interface to AXI bridge
    .port0_req_ack  (axi_dmem_req_ack    ),
    .port0_req      (axi_dmem_req        ),
    .port0_cmd      (axi_dmem_cmd        ),
    .port0_width    (axi_dmem_width      ),
    .port0_addr     (axi_dmem_addr       ),
    .port0_wdata    (axi_dmem_wdata      ),
    .port0_rdata    (axi_dmem_rdata      ),
    .port0_resp     (axi_dmem_resp       )
);


//-------------------------------------------------------------------------------
// Instruction memory AXI bridge
//-------------------------------------------------------------------------------
ycr_mem_axi #(
`ifdef YCR_IMEM_AXI_REQ_BP
    .YCR_AXI_REQ_BP    (1),
`else // YCR_IMEM_AXI_REQ_BP
    .YCR_AXI_REQ_BP    (0),
`endif // YCR_IMEM_AXI_REQ_BP
`ifdef YCR_IMEM_AXI_RESP_BP
    .YCR_AXI_RESP_BP   (1)
`else // YCR_IMEM_AXI_RESP_BP
    .YCR_AXI_RESP_BP   (0)
`endif // YCR_IMEM_AXI_RESP_BP
) i_imem_axi (
    .clk            (clk                    ),
    .rst_n          (axi_rst_n              ),
    .axi_reinit     (axi_reinit             ),

    // Interface to core
    .core_idle      (axi_imem_idle          ),
    .core_req_ack   (axi_imem_req_ack       ),
    .core_req       (axi_imem_req           ),
    .core_cmd       (axi_imem_cmd           ),
    .core_width     (YCR_MEM_WIDTH_WORD    ),
    .core_addr      (axi_imem_addr          ),
    .core_wdata     ('0                     ),
    .core_rdata     (axi_imem_rdata         ),
    .core_resp      (axi_imem_resp          ),

    // AXI I/O
    .awid           (io_axi_imem_awid       ),
    .awaddr         (io_axi_imem_awaddr     ),
    .awlen          (io_axi_imem_awlen      ),
    .awsize         (io_axi_imem_awsize     ),
    .awburst        (io_axi_imem_awburst    ),
    .awlock         (io_axi_imem_awlock     ),
    .awcache        (io_axi_imem_awcache    ),
    .awprot         (io_axi_imem_awprot     ),
    .awregion       (io_axi_imem_awregion   ),
    .awuser         (io_axi_imem_awuser     ),
    .awqos          (io_axi_imem_awqos      ),
    .awvalid        (io_axi_imem_awvalid    ),
    .awready        (io_axi_imem_awready    ),
    .wdata          (io_axi_imem_wdata      ),
    .wstrb          (io_axi_imem_wstrb      ),
    .wlast          (io_axi_imem_wlast      ),
    .wuser          (io_axi_imem_wuser      ),
    .wvalid         (io_axi_imem_wvalid     ),
    .wready         (io_axi_imem_wready     ),
    .bid            (io_axi_imem_bid        ),
    .bresp          (io_axi_imem_bresp      ),
    .bvalid         (io_axi_imem_bvalid     ),
    .buser          (io_axi_imem_buser      ),
    .bready         (io_axi_imem_bready     ),
    .arid           (io_axi_imem_arid       ),
    .araddr         (io_axi_imem_araddr     ),
    .arlen          (io_axi_imem_arlen      ),
    .arsize         (io_axi_imem_arsize     ),
    .arburst        (io_axi_imem_arburst    ),
    .arlock         (io_axi_imem_arlock     ),
    .arcache        (io_axi_imem_arcache    ),
    .arprot         (io_axi_imem_arprot     ),
    .arregion       (io_axi_imem_arregion   ),
    .aruser         (io_axi_imem_aruser     ),
    .arqos          (io_axi_imem_arqos      ),
    .arvalid        (io_axi_imem_arvalid    ),
    .arready        (io_axi_imem_arready    ),
    .rid            (io_axi_imem_rid        ),
    .rdata          (io_axi_imem_rdata      ),
    .rresp          (io_axi_imem_rresp      ),
    .rlast          (io_axi_imem_rlast      ),
    .ruser          (io_axi_imem_ruser      ),
    .rvalid         (io_axi_imem_rvalid     ),
    .rready         (io_axi_imem_rready     )
);


//-------------------------------------------------------------------------------
// Data memory AXI bridge
//-------------------------------------------------------------------------------
ycr_mem_axi #(
`ifdef YCR_DMEM_AXI_REQ_BP
    .YCR_AXI_REQ_BP    (1),
`else // YCR_DMEM_AXI_REQ_BP
    .YCR_AXI_REQ_BP    (0),
`endif // YCR_DMEM_AXI_REQ_BP
`ifdef YCR_DMEM_AXI_RESP_BP
    .YCR_AXI_RESP_BP   (1)
`else // YCR_DMEM_AXI_RESP_BP
    .YCR_AXI_RESP_BP   (0)
`endif // YCR_DMEM_AXI_RESP_BP
) i_dmem_axi (
    .clk            (clk                    ),
    .rst_n          (axi_rst_n              ),
    .axi_reinit     (axi_reinit             ),

    // Interface to core
    .core_idle      (axi_dmem_idle          ),
    .core_req_ack   (axi_dmem_req_ack       ),
    .core_req       (axi_dmem_req           ),
    .core_cmd       (axi_dmem_cmd           ),
    .core_width     (axi_dmem_width         ),
    .core_addr      (axi_dmem_addr          ),
    .core_wdata     (axi_dmem_wdata         ),
    .core_rdata     (axi_dmem_rdata         ),
    .core_resp      (axi_dmem_resp          ),

    // AXI I/O
    .awid           (io_axi_dmem_awid       ),
    .awaddr         (io_axi_dmem_awaddr     ),
    .awlen          (io_axi_dmem_awlen      ),
    .awsize         (io_axi_dmem_awsize     ),
    .awburst        (io_axi_dmem_awburst    ),
    .awlock         (io_axi_dmem_awlock     ),
    .awcache        (io_axi_dmem_awcache    ),
    .awprot         (io_axi_dmem_awprot     ),
    .awregion       (io_axi_dmem_awregion   ),
    .awuser         (io_axi_dmem_awuser     ),
    .awqos          (io_axi_dmem_awqos      ),
    .awvalid        (io_axi_dmem_awvalid    ),
    .awready        (io_axi_dmem_awready    ),
    .wdata          (io_axi_dmem_wdata      ),
    .wstrb          (io_axi_dmem_wstrb      ),
    .wlast          (io_axi_dmem_wlast      ),
    .wuser          (io_axi_dmem_wuser      ),
    .wvalid         (io_axi_dmem_wvalid     ),
    .wready         (io_axi_dmem_wready     ),
    .bid            (io_axi_dmem_bid        ),
    .bresp          (io_axi_dmem_bresp      ),
    .bvalid         (io_axi_dmem_bvalid     ),
    .buser          (io_axi_dmem_buser      ),
    .bready         (io_axi_dmem_bready     ),
    .arid           (io_axi_dmem_arid       ),
    .araddr         (io_axi_dmem_araddr     ),
    .arlen          (io_axi_dmem_arlen      ),
    .arsize         (io_axi_dmem_arsize     ),
    .arburst        (io_axi_dmem_arburst    ),
    .arlock         (io_axi_dmem_arlock     ),
    .arcache        (io_axi_dmem_arcache    ),
    .arprot         (io_axi_dmem_arprot     ),
    .arregion       (io_axi_dmem_arregion   ),
    .aruser         (io_axi_dmem_aruser     ),
    .arqos          (io_axi_dmem_arqos      ),
    .arvalid        (io_axi_dmem_arvalid    ),
    .arready        (io_axi_dmem_arready    ),
    .rid            (io_axi_dmem_rid        ),
    .rdata          (io_axi_dmem_rdata      ),
    .rresp          (io_axi_dmem_rresp      ),
    .rlast          (io_axi_dmem_rlast      ),
    .ruser          (io_axi_dmem_ruser      ),
    .rvalid         (io_axi_dmem_rvalid     ),
    .rready         (io_axi_dmem_rready     )
);

//-------------------------------------------------------------------------------
// AXI reinit logic
//-------------------------------------------------------------------------------
always_ff @(negedge core_rst_n_local, posedge clk) begin
    if (~core_rst_n_local)                      axi_reinit <= 1'b1;
    else if (axi_imem_idle & axi_dmem_idle)     axi_reinit <= 1'b0;
end

endmodule : ycr_top_axi
