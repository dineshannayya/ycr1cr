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
////  yifive AHB TOP                                                      ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     AHB TOP                                                          ////
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
`include "ycr_ahb.svh"
`ifdef YCR_IPIC_EN
`include "ycr_ipic.svh"
`endif // YCR_IPIC_EN

`ifdef YCR_TCM_EN
 `define YCR_IMEM_ROUTER_EN
`endif // YCR_TCM_EN

module ycr_top_ahb (
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
    output  logic [3:0]                             imem_hprot,
    output  logic [2:0]                             imem_hburst,
    output  logic [2:0]                             imem_hsize,
    output  logic [1:0]                             imem_htrans,
    output  logic                                   imem_hmastlock,
    output  logic [YCR_AHB_WIDTH-1:0]              imem_haddr,
    input   logic                                   imem_hready,
    input   logic [YCR_AHB_WIDTH-1:0]              imem_hrdata,
    input   logic                                   imem_hresp,

    // Data Memory Interface
    output  logic [3:0]                             dmem_hprot,
    output  logic [2:0]                             dmem_hburst,
    output  logic [2:0]                             dmem_hsize,
    output  logic [1:0]                             dmem_htrans,
    output  logic                                   dmem_hmastlock,
    output  logic [YCR_AHB_WIDTH-1:0]              dmem_haddr,
    output  logic                                   dmem_hwrite,
    output  logic [YCR_AHB_WIDTH-1:0]              dmem_hwdata,
    input   logic                                   dmem_hready,
    input   logic [YCR_AHB_WIDTH-1:0]              dmem_hrdata,
    input   logic                                   dmem_hresp
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

// Instruction memory interface from router to AHB bridge
logic                                               ahb_imem_req_ack;
logic                                               ahb_imem_req;
logic                                               ahb_imem_cmd;
logic [`YCR_IMEM_AWIDTH-1:0]                       ahb_imem_addr;
logic [`YCR_IMEM_DWIDTH-1:0]                       ahb_imem_rdata;
logic [1:0]                                         ahb_imem_resp;

// Data memory interface from router to AHB bridge
logic                                               ahb_dmem_req_ack;
logic                                               ahb_dmem_req;
logic                                               ahb_dmem_cmd;
logic [1:0]                                         ahb_dmem_width;
logic [`YCR_DMEM_AWIDTH-1:0]                       ahb_dmem_addr;
logic [`YCR_DMEM_DWIDTH-1:0]                       ahb_dmem_wdata;
logic [`YCR_DMEM_DWIDTH-1:0]                       ahb_dmem_rdata;
logic [1:0]                                         ahb_dmem_resp;

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

logic                                               timer_irq;
logic [63:0]                                        timer_val;


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
 `ifdef YCR_TCM_EN
    .YCR_ADDR_MASK     (YCR_TCM_ADDR_MASK),
    .YCR_ADDR_PATTERN  (YCR_TCM_ADDR_PATTERN)
 `endif // YCR_TCM_EN
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
    // Interface to AHB bridge
    .port0_req_ack  (ahb_imem_req_ack ),
    .port0_req      (ahb_imem_req     ),
    .port0_cmd      (ahb_imem_cmd     ),
    .port0_addr     (ahb_imem_addr    ),
    .port0_rdata    (ahb_imem_rdata   ),
    .port0_resp     (ahb_imem_resp    ),
 `ifdef YCR_TCM_EN
    // Interface to TCM
    .port1_req_ack  (tcm_imem_req_ack ),
    .port1_req      (tcm_imem_req     ),
    .port1_cmd      (tcm_imem_cmd     ),
    .port1_addr     (tcm_imem_addr    ),
    .port1_rdata    (tcm_imem_rdata   ),
    .port1_resp     (tcm_imem_resp    )
 `endif // YCR_TCM_EN
);

`else // YCR_IMEM_ROUTER_EN

assign ahb_imem_req         = core_imem_req;
assign ahb_imem_cmd         = core_imem_cmd;
assign ahb_imem_addr        = core_imem_addr;
assign core_imem_req_ack    = ahb_imem_req_ack;
assign core_imem_resp       = ahb_imem_resp;
assign core_imem_rdata      = ahb_imem_rdata;

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
    .port1_req_ack  (1'b0),
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
    // Interface to AHB bridge
    .port0_req_ack  (ahb_dmem_req_ack    ),
    .port0_req      (ahb_dmem_req        ),
    .port0_cmd      (ahb_dmem_cmd        ),
    .port0_width    (ahb_dmem_width      ),
    .port0_addr     (ahb_dmem_addr       ),
    .port0_wdata    (ahb_dmem_wdata      ),
    .port0_rdata    (ahb_dmem_rdata      ),
    .port0_resp     (ahb_dmem_resp       )
);


//-------------------------------------------------------------------------------
// Instruction memory AHB bridge
//-------------------------------------------------------------------------------
ycr_imem_ahb i_imem_ahb (
    .rst_n          (core_rst_n_local   ),
    .clk            (clk                ),
    // Interface to imem router
    .imem_req_ack   (ahb_imem_req_ack   ),
    .imem_req       (ahb_imem_req       ),
    .imem_addr      (ahb_imem_addr      ),
    .imem_rdata     (ahb_imem_rdata     ),
    .imem_resp      (ahb_imem_resp      ),
    // AHB interface
    .hprot          (imem_hprot         ),
    .hburst         (imem_hburst        ),
    .hsize          (imem_hsize         ),
    .htrans         (imem_htrans        ),
    .hmastlock      (imem_hmastlock     ),
    .haddr          (imem_haddr         ),
    .hready         (imem_hready        ),
    .hrdata         (imem_hrdata        ),
    .hresp          (imem_hresp         )
);


//-------------------------------------------------------------------------------
// Data memory AHB bridge
//-------------------------------------------------------------------------------
ycr_dmem_ahb i_dmem_ahb (
    .rst_n          (core_rst_n_local   ),
    .clk            (clk                ),
    // Interface to dmem router
    .dmem_req_ack   (ahb_dmem_req_ack   ),
    .dmem_req       (ahb_dmem_req       ),
    .dmem_cmd       (ahb_dmem_cmd       ),
    .dmem_width     (ahb_dmem_width     ),
    .dmem_addr      (ahb_dmem_addr      ),
    .dmem_wdata     (ahb_dmem_wdata     ),
    .dmem_rdata     (ahb_dmem_rdata     ),
    .dmem_resp      (ahb_dmem_resp      ),
    // AHB interface
    .hprot          (dmem_hprot         ),
    .hburst         (dmem_hburst        ),
    .hsize          (dmem_hsize         ),
    .htrans         (dmem_htrans        ),
    .hmastlock      (dmem_hmastlock     ),
    .haddr          (dmem_haddr         ),
    .hwrite         (dmem_hwrite        ),
    .hwdata         (dmem_hwdata        ),
    .hready         (dmem_hready        ),
    .hrdata         (dmem_hrdata        ),
    .hresp          (dmem_hresp         )
);

endmodule : ycr_top_ahb


