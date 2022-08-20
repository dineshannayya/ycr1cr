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
////  yifive core top                                                     ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     core top                                                         ////
////                                                                      ////
////  To Do:                                                              ////
////    nothing                                                           ////
////                                                                      ////
////  Author(s):                                                          ////
////     - syntacore, https://github.com/syntacore/scr1                   ////
////     - Dinesh Annayya, dinesha@opencores.org                          ////
////                                                                      ////
////  Revision :                                                          ////
////     v0:    Jan 2021- Initial version picked from                     ////
////             https://github.com/syntacore/scr1                        ////
////     v1:    June 7, 2021, Dinesh A                                    ////
////             opentool(iverilog/yosys) related cleanup                 ////
////                                                                      ////
//////////////////////////////////////////////////////////////////////////////

`include "ycr_arch_description.svh"
`include "ycr_arch_types.svh"
`include "ycr_memif.svh"

`ifdef YCR_DBG_EN
`include "ycr_tapc.svh"
`include "ycr_dm.svh"
`include "ycr_hdu.svh"
`endif // YCR_DBG_EN

`ifdef YCR_IPIC_EN
`include "ycr_ipic.svh"
`endif // YCR_IPIC_EN

module ycr_core_top (
`ifdef USE_POWER_PINS
    input logic                                     vccd1,    // User area 1 1.8V supply
    input logic                                     vssd1,    // User area 1 digital ground
`endif
    // Common
    input   logic                                   pwrup_rst_n,                // Power-Up reset
    input   logic                                   rst_n,                      // Regular reset
    input   logic                                   cpu_rst_n,                  // CPU reset
    input   logic                                   clk,                        // Core clock
    output  logic                                   clk_o,                      // Core clock
    output  logic                                   core_rst_n_o,               // Core reset
    output  logic                                   core_rdc_qlfy_o,            // Core RDC qualifier
    output  logic   [48:0]                          core_debug  ,
`ifdef YCR_DBG_EN
    output  logic                                   sys_rst_n_o,                // System reset
    output  logic                                   sys_rdc_qlfy_o,             // System RDC qualifier
`endif // YCR_DBG_EN

    input   logic [1:0]                             core_uid,        // Unique Core Id 
`ifdef YCR_DBG_EN
    input   logic [31:0]                            tapc_fuse_idcode_i,       // Fuse IDCODE value
`endif // YCR_DBG_EN

    // IRQ
`ifdef YCR_IPIC_EN
    input   logic [YCR_IRQ_LINES_NUM-1:0]          core_irq_lines_i,         // External interrupt request lines
`else
    input   logic                                   core_irq_ext_i,          // External interrupt request
`endif // YCR_IPIC_EN
    input   logic                                   core_irq_soft_i,         // Software generated interrupt request
    input   logic                                   core_irq_mtimer_i,       // Machine timer interrupt request

    // Memory-mapped external timer
    input   logic [63:0]                            core_mtimer_val_i,       // Machine timer value

`ifdef YCR_DBG_EN
    // Debug Interface
    input   logic                                   tapc_tck,                // Test Clock (TCK)
    input   logic                                   tapc_tms,                // Test Mode Select (TMS)
    input   logic                                   tapc_tdi,                // Test Data Input (TDI)
    output  logic                                   tapc_tdo,                // Test Data Output (TDO)
    output  logic                                   tapc_tdo_en,             // TDO Enable, signal for TDO buffer control
`endif // YCR_DBG_EN

    // Instruction Memory Interface
    input   logic                                   imem2core_req_ack_i,      // IMEM request acknowledge
    output  logic                                   core2imem_req_o,          // IMEM request
    output  logic                                   core2imem_cmd_o,          // IMEM command
    output  logic [`YCR_IMEM_AWIDTH-1:0]            core2imem_addr_o,         // IMEM address
    output  logic [`YCR_IMEM_BSIZE-1:0]             core2imem_bl_o,           // IMEM address
    input   logic [`YCR_IMEM_DWIDTH-1:0]            imem2core_rdata_i,        // IMEM read data
    input   logic [1:0]                             imem2core_resp_i,         // IMEM response

    // Data Memory Interface
    input   logic                                   dmem2core_req_ack_i,      // DMEM request acknowledge
    output  logic                                   core2dmem_req_o,          // DMEM request
    output  logic                                   core2dmem_cmd_o,          // DMEM command
    output  logic[1:0]                              core2dmem_width_o,        // DMEM data width
    output  logic [`YCR_DMEM_AWIDTH-1:0]            core2dmem_addr_o,         // DMEM address
    output  logic [`YCR_DMEM_DWIDTH-1:0]            core2dmem_wdata_o,        // DMEM write data
    input   logic [`YCR_DMEM_DWIDTH-1:0]            dmem2core_rdata_i,        // DMEM read data
    input   logic [1:0]                             dmem2core_resp_i          // DMEM response
);

//-------------------------------------------------------------------------------
// Local parameters
//-------------------------------------------------------------------------------
localparam int unsigned YCR_CORE_TOP_RST_SYNC_STAGES_NUM               = 2;

//-------------------------------------------------------------------------------
// Local signals declaration
//-------------------------------------------------------------------------------

// Reset Logic
`ifdef YCR_DBG_EN
logic                                           tapc_trst_n;             // Test Reset (TRSTn)
`else // YCR_DBG_EN
logic                                           core_rst_n_in_sync;
logic                                           core_rst_n_qlfy;
logic                                           core_rst_n_status;
`endif // YCR_DBG_EN
logic                                           core_rst_n;
logic                                           core_rst_n_status_sync;
logic                                           core_rst_status;
logic                                           core2hdu_rdc_qlfy;
logic                                           core2dm_rdc_qlfy;
logic                                           pwrup_rst_n_sync;
logic                                           rst_n_sync;
logic                                           cpu_rst_n_sync;

`ifdef YCR_DBG_EN
// TAPC-DM Interface
logic                                           tapc_dmi_ch_sel;
logic [YCR_DBG_DMI_CH_ID_WIDTH-1:0]            tapc_dmi_ch_id;
logic                                           tapc_dmi_ch_capture;
logic                                           tapc_dmi_ch_shift;
logic                                           tapc_dmi_ch_update;
logic                                           tapc_dmi_ch_tdi;
logic                                           tapc_dmi_ch_tdo;
//
logic                                           tapc_dmi_ch_sel_tapout;
logic [YCR_DBG_DMI_CH_ID_WIDTH-1:0]            tapc_dmi_ch_id_tapout;
logic                                           tapc_dmi_ch_capture_tapout;
logic                                           tapc_dmi_ch_shift_tapout;
logic                                           tapc_dmi_ch_update_tapout;
logic                                           tapc_dmi_ch_tdi_tapout;
logic                                           tapc_dmi_ch_tdo_tapin;
//
logic                                           dmi_req;
logic                                           dmi_wr;
logic [YCR_DBG_DMI_ADDR_WIDTH-1:0]             dmi_addr;
logic [YCR_DBG_DMI_DATA_WIDTH-1:0]             dmi_wdata;
logic                                           dmi_resp;
logic [YCR_DBG_DMI_DATA_WIDTH-1:0]             dmi_rdata;
// TAPC-SCU Interface
logic                                           tapc_scu_ch_sel;
logic                                           tapc_scu_ch_sel_tapout;
logic                                           tapc_scu_ch_tdo;
logic                                           tapc_ch_tdo;
// SCU nets
logic                                           sys_rst_n;
logic                                           sys_rst_status;
logic                                           hdu_rst_n;
logic                                           hdu2dm_rdc_qlfy;
logic                                           ndm_rst_n;
logic                                           dm_rst_n;
logic                                           hart_rst_n;
`endif // YCR_DBG_EN

`ifdef YCR_DBG_EN
// DM-Pipeline Interface
// HART Run Control i/f
logic                                           dm_active;
logic                                           dm_cmd_req;
type_ycr_hdu_dbgstates_e                       dm_cmd;
logic                                           dm_cmd_resp;
logic                                           dm_cmd_resp_qlfy;
logic                                           dm_cmd_rcode;
logic                                           dm_hart_event;
logic                                           dm_hart_event_qlfy;
type_ycr_hdu_hartstatus_s                      dm_hart_status;
type_ycr_hdu_hartstatus_s                      dm_hart_status_qlfy;
// Program Buffer - HART instruction execution i/f
logic [YCR_HDU_PBUF_ADDR_WIDTH-1:0]            dm_pbuf_addr;
logic [YCR_HDU_PBUF_ADDR_WIDTH-1:0]            dm_pbuf_addr_qlfy;
logic [YCR_HDU_CORE_INSTR_WIDTH-1:0]           dm_pbuf_instr;
// HART Abstract Data regs i/f
logic                                           dm_dreg_req;
logic                                           dm_dreg_req_qlfy;
logic                                           dm_dreg_wr;
logic [YCR_HDU_DATA_REG_WIDTH-1:0]             dm_dreg_wdata;
logic                                           dm_dreg_resp;
logic                                           dm_dreg_fail;
logic [YCR_HDU_DATA_REG_WIDTH-1:0]             dm_dreg_rdata;

logic [`YCR_XLEN-1 : 0]                        dm_pc_sample;
logic [`YCR_XLEN-1 : 0]                        dm_pc_sample_qlfy;
`endif // YCR_DBG_EN

`ifdef YCR_CLKCTRL_EN
// Global clock gating logic
logic                                           sleep_pipe;
logic                                           wake_pipe;
logic                                           clk_pipe;
logic                                           clk_pipe_en;
logic                                           clk_dbgc;
logic                                           clk_alw_on;
`endif // YCR_CLKCTRL_EN

//-------------------------------------------------------------------------------
// Local parameters
//-------------------------------------------------------------------------------
localparam int unsigned YCR_CLUSTER_TOP_RST_SYNC_STAGES_NUM            = 2;


// CORE HART ID
wire logic [`YCR_XLEN-1:0]        core_fuse_mhartid_i = {30'h0,core_uid}; // Fuse MHARTID value

// IMEM Retiming 
logic                                   imem2core_req_ack_int;      // IMEM request acknowledge
logic                                   core2imem_req_int;          // IMEM request
logic                                   core2imem_cmd_int;          // IMEM command
logic [`YCR_IMEM_AWIDTH-1:0]            core2imem_addr_int;         // IMEM address
logic [`YCR_IMEM_BSIZE-1:0]             core2imem_bl_int;           // IMEM address

// DMEM Retiming
logic                                   dmem2core_req_ack_int;      // DMEM request acknowledge
logic                                   core2dmem_req_int;          // DMEM request
logic                                   core2dmem_cmd_int;          // DMEM command
logic[1:0]                              core2dmem_width_int;        // DMEM data width
logic [`YCR_DMEM_AWIDTH-1:0]            core2dmem_addr_int;         // DMEM address
logic [`YCR_DMEM_DWIDTH-1:0]            core2dmem_wdata_int;        // DMEM write data

wire  test_mode = 1'b0;
wire  test_rst_n = 1'b0;
assign clk_o = clk;



//-------------------------------------------------------------------------------
// Reset Logic
//-------------------------------------------------------------------------------
`ifdef YCR_DBG_EN
ycr_scu    i_scu (
    // Global signals
    .pwrup_rst_n                (pwrup_rst_n        ),
    .rst_n                      (rst_n              ),
    .cpu_rst_n                  (cpu_rst_n          ),
    .test_mode                  (test_mode          ),
    .test_rst_n                 (test_rst_n         ),
    .clk                        (clk                ),

    // TAPC scan-chains
    .tapcsync2scu_ch_sel_i      (tapc_scu_ch_sel    ),
    .tapcsync2scu_ch_id_i       ('0                 ),
    .tapcsync2scu_ch_capture_i  (tapc_dmi_ch_capture),
    .tapcsync2scu_ch_shift_i    (tapc_dmi_ch_shift  ),
    .tapcsync2scu_ch_update_i   (tapc_dmi_ch_update ),
    .tapcsync2scu_ch_tdi_i      (tapc_dmi_ch_tdi    ),
    .scu2tapcsync_ch_tdo_o      (tapc_scu_ch_tdo    ),

    // Input sync resets:
    .ndm_rst_n_i                (ndm_rst_n          ),
    .hart_rst_n_i               (hart_rst_n         ),

    // Generated resets
    .sys_rst_n_o                (sys_rst_n          ),
    .core_rst_n_o               (core_rst_n         ),
    .dm_rst_n_o                 (dm_rst_n           ),
    .hdu_rst_n_o                (hdu_rst_n          ),

    // Resets statuses
    .sys_rst_status_o           (sys_rst_status     ),
    .core_rst_status_o          (core_rst_status    ),

    // Reset Domain Crossing (RDC) qualifiers
    .sys_rdc_qlfy_o             (sys_rdc_qlfy_o     ),
    .core_rdc_qlfy_o            (core_rdc_qlfy_o    ),
    .core2hdu_rdc_qlfy_o        (core2hdu_rdc_qlfy  ),
    .core2dm_rdc_qlfy_o         (core2dm_rdc_qlfy   ),
    .hdu2dm_rdc_qlfy_o          (hdu2dm_rdc_qlfy    )
);

assign sys_rst_n_o      = sys_rst_n;

// Reset inputs are assumed synchronous
assign pwrup_rst_n_sync = pwrup_rst_n;

`else // YCR_DBG_EN

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
    .clk            (clk        ),
    .test_rst_n     (test_rst_n      ),
    .test_mode      (test_mode       ),
    .rst_n_in       (rst_n           ),
    .rst_n_out      (rst_n_sync      )
);

// Regular Reset synchronizer
ycr_reset_sync_cell #(
    .STAGES_AMOUNT       (YCR_CLUSTER_TOP_RST_SYNC_STAGES_NUM)
) i_cpu_rstn_sync (
    .rst_n          (pwrup_rst_n     ),
    .clk            (clk        ),
    .test_rst_n     (test_rst_n      ),
    .test_mode      (test_mode       ),
    .rst_n_in       (cpu_rst_n       ),
    .rst_n_out      (cpu_rst_n_sync  )
);
assign core_rst_n_in_sync = rst_n_sync & cpu_rst_n_sync;

// Core Reset: core_rst_n
ycr_reset_qlfy_adapter_cell_sync i_core_rstn_qlfy_adapter_cell_sync (
    .rst_n              (pwrup_rst_n_sync  ),
    .clk                (clk               ),
    .test_rst_n         (test_rst_n        ),
    .test_mode          (test_mode         ),
    .reset_n_in_sync    (core_rst_n_in_sync),
    .reset_n_out_qlfy   (core_rst_n_qlfy   ),
    .reset_n_out        (core_rst_n        ),
    .reset_n_status     (core_rst_n_status )
);

ycr_data_sync_cell #(
    .STAGES_AMOUNT      (YCR_CORE_TOP_RST_SYNC_STAGES_NUM)
) i_core_rstn_status_sync (
    .rst_n               (pwrup_rst_n_sync      ),
    .clk                 (clk                   ),
    .data_in             (core_rst_n_status     ),
    .data_out            (core_rst_n_status_sync)
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

assign core_rst_status      = ~core_rst_n_status_sync;
assign core_rdc_qlfy_o      = core_rst_n_qlfy;

`endif // YCR_DBG_EN
assign core_rst_n_o         = core_rst_n;

//-------------------------------------------------------------------------------
// Retiming block to break the Timing Path
//-------------------------------------------------------------------------------
// Breaking Timing Path for core_imem
ycr_req_retiming #(.FIFO_WIDTH(`YCR_IMEM_AWIDTH+`YCR_IMEM_BSIZE+1))
                 u_core_imem_retim 
		 (

                   .clk                 (clk                       ),  // Core clock
                   .rst_n               (core_rst_n                ) ,
                   
                   .req_ack             (imem2core_req_ack_int     ), 
                   .req                 (core2imem_req_int         ), 
                   .wdata               ({core2imem_cmd_int,
		                          core2imem_addr_int,
					  core2imem_bl_int
		                         }), 

                   .req_ack_int         (imem2core_req_ack_i), 
                   .req_int             (core2imem_req_o    ), 
                   .rdata               ({core2imem_cmd_o,
		                          core2imem_addr_o,
					  core2imem_bl_o
		                         })  
		 );

// Breaking Timing Path for core_dmem
ycr_req_retiming #(.FIFO_WIDTH(`YCR_IMEM_AWIDTH+`YCR_DMEM_DWIDTH+2+1))
                 u_core_dmem_retim 
		 (

                   .clk                 (clk                       ),  // Core clock
                   .rst_n               (core_rst_n                ) ,
                   
                   .req_ack             (dmem2core_req_ack_int     ), 
                   .req                 (core2dmem_req_int         ), 
                   .wdata               ({core2dmem_cmd_int,
		                          core2dmem_width_int,
		                          core2dmem_addr_int,
					  core2dmem_wdata_int
		                         }), 

                   .req_ack_int         (dmem2core_req_ack_i), 
                   .req_int             (core2dmem_req_o    ), 
                   .rdata               ({core2dmem_cmd_o,
		                          core2dmem_width_o,
		                          core2dmem_addr_o,
					  core2dmem_wdata_o
		                         })  
		 );
//-------------------------------------------------------------------------------
// YCR pipeline
//-------------------------------------------------------------------------------
ycr_pipe_top i_pipe_top (
    // Control
    .pipe_rst_n                     (core_rst_n             ),
    .pipe_debug                     (core_debug             ),
`ifdef YCR_DBG_EN
    .pipe2hdu_rdc_qlfy_i            (core2hdu_rdc_qlfy      ),
    .dbg_rst_n                      (hdu_rst_n              ),
`endif // YCR_DBG_EN
`ifndef YCR_CLKCTRL_EN
    .clk                            (clk                    ),
`else // YCR_CLKCTRL_EN
    .clk                            (clk_pipe               ),
    .pipe2clkctl_sleep_req_o        (sleep_pipe             ),
    .pipe2clkctl_wake_req_o         (wake_pipe              ),
    .clkctl2pipe_clk_alw_on_i       (clk_alw_on             ),
    .clkctl2pipe_clk_dbgc_i         (clk_dbgc               ),
    .clkctl2pipe_clk_en_i           (clk_pipe_en            ),
`endif // YCR_CLKCTRL_EN

    // Instruction memory interface
    .pipe2imem_req_o                (core2imem_req_int      ),
    .pipe2imem_cmd_o                (core2imem_cmd_int      ),
    .pipe2imem_addr_o               (core2imem_addr_int     ),
    .pipe2imem_bl_o                 (core2imem_bl_int       ),
    .imem2pipe_req_ack_i            (imem2core_req_ack_int  ),
    .imem2pipe_rdata_i              (imem2core_rdata_i      ),
    .imem2pipe_resp_i               (imem2core_resp_i       ),

    // Data memory interface
    .pipe2dmem_req_o                (core2dmem_req_int      ),
    .pipe2dmem_cmd_o                (core2dmem_cmd_int      ),
    .pipe2dmem_width_o              (core2dmem_width_int    ),
    .pipe2dmem_addr_o               (core2dmem_addr_int     ),
    .pipe2dmem_wdata_o              (core2dmem_wdata_int    ),
    .dmem2pipe_req_ack_i            (dmem2core_req_ack_int  ),
    .dmem2pipe_rdata_i              (dmem2core_rdata_i      ),
    .dmem2pipe_resp_i               (dmem2core_resp_i       ),

`ifdef YCR_DBG_EN
    // Debug interface:
    .dbg_en                         (1'b1                   ),
    // Debug interface:
    // DM <-> Pipeline: HART Run Control i/f
    .dm2pipe_active_i               (dm_active              ),
    .dm2pipe_cmd_req_i              (dm_cmd_req             ),
    .dm2pipe_cmd_i                  (dm_cmd                 ),
    .pipe2dm_cmd_resp_o             (dm_cmd_resp            ),
    .pipe2dm_cmd_rcode_o            (dm_cmd_rcode           ),
    .pipe2dm_hart_event_o           (dm_hart_event          ),
    .pipe2dm_hart_status_o          (dm_hart_status         ),

    // DM <-> Pipeline: Program Buffer - HART instruction execution i/f
    .pipe2dm_pbuf_addr_o            (dm_pbuf_addr           ),
    .dm2pipe_pbuf_instr_i           (dm_pbuf_instr          ),

    // DM <-> Pipeline: HART Abstract Data regs i/f
    .pipe2dm_dreg_req_o             (dm_dreg_req            ),
    .pipe2dm_dreg_wr_o              (dm_dreg_wr             ),
    .pipe2dm_dreg_wdata_o           (dm_dreg_wdata          ),
    .dm2pipe_dreg_resp_i            (dm_dreg_resp           ),
    .dm2pipe_dreg_fail_i            (dm_dreg_fail           ),
    .dm2pipe_dreg_rdata_i           (dm_dreg_rdata          ),

    // DM <-> Pipeline: PC i/f
    .pipe2dm_pc_sample_o            (dm_pc_sample           ),
`endif // YCR_DBG_EN

    // IRQ
`ifdef YCR_IPIC_EN
    .soc2pipe_irq_lines_i           (core_irq_lines_i       ),
`else // YCR_IPIC_EN
    .soc2pipe_irq_ext_i             (core_irq_ext_i         ),
`endif // YCR_IPIC_EN
    .soc2pipe_irq_soft_i            (core_irq_soft_i        ),
    .soc2pipe_irq_mtimer_i          (core_irq_mtimer_i      ),

    // Memory-mapped external timer
    .soc2pipe_mtimer_val_i          (core_mtimer_val_i      ),

    // Fuse
    .soc2pipe_fuse_mhartid_i        (core_fuse_mhartid_i    )
);


`ifdef YCR_DBG_EN
//-------------------------------------------------------------------------------
// TAP Controller (TAPC)
//-------------------------------------------------------------------------------
ycr_tapc i_tapc (
    // JTAG signals
    .tapc_trst_n                    (tapc_trst_n               ),
    .tapc_tck                       (tapc_tck                  ),
    .tapc_tms                       (tapc_tms                  ),
    .tapc_tdi                       (tapc_tdi                  ),
    .tapc_tdo                       (tapc_tdo                  ),
    .tapc_tdo_en                    (tapc_tdo_en               ),

    // Fuses
    .soc2tapc_fuse_idcode_i         (tapc_fuse_idcode_i        ),

    // DMI/SCU scan-chains
    .tapc2tapcsync_scu_ch_sel_o     (tapc_scu_ch_sel_tapout    ),
    .tapc2tapcsync_dmi_ch_sel_o     (tapc_dmi_ch_sel_tapout    ),
    .tapc2tapcsync_ch_id_o          (tapc_dmi_ch_id_tapout     ),
    .tapc2tapcsync_ch_capture_o     (tapc_dmi_ch_capture_tapout),
    .tapc2tapcsync_ch_shift_o       (tapc_dmi_ch_shift_tapout  ),
    .tapc2tapcsync_ch_update_o      (tapc_dmi_ch_update_tapout ),
    .tapc2tapcsync_ch_tdi_o         (tapc_dmi_ch_tdi_tapout    ),
    .tapcsync2tapc_ch_tdo_i         (tapc_dmi_ch_tdo_tapin     )
);

ycr_tapc_synchronizer i_tapc_synchronizer (
    // System common signals
    .pwrup_rst_n                    (pwrup_rst_n_sync          ),
    .dm_rst_n                       (dm_rst_n                  ),
    .clk                            (clk                       ),

    // JTAG common signals
    .tapc_trst_n                    (tapc_trst_n               ),
    .tapc_tck                       (tapc_tck                  ),

    // DMI/SCU scan-chains
    .tapc2tapcsync_scu_ch_sel_i     (tapc_scu_ch_sel_tapout    ),
    .tapcsync2scu_ch_sel_o          (tapc_scu_ch_sel           ),
    .tapc2tapcsync_dmi_ch_sel_i     (tapc_dmi_ch_sel_tapout    ),
    .tapcsync2dmi_ch_sel_o          (tapc_dmi_ch_sel           ),

    .tapc2tapcsync_ch_id_i          (tapc_dmi_ch_id_tapout     ),
    .tapcsync2core_ch_id_o          (tapc_dmi_ch_id            ),
    .tapc2tapcsync_ch_capture_i     (tapc_dmi_ch_capture_tapout),
    .tapcsync2core_ch_capture_o     (tapc_dmi_ch_capture       ),
    .tapc2tapcsync_ch_shift_i       (tapc_dmi_ch_shift_tapout  ),
    .tapcsync2core_ch_shift_o       (tapc_dmi_ch_shift         ),
    .tapc2tapcsync_ch_update_i      (tapc_dmi_ch_update_tapout ),
    .tapcsync2core_ch_update_o      (tapc_dmi_ch_update        ),
    .tapc2tapcsync_ch_tdi_i         (tapc_dmi_ch_tdi_tapout    ),
    .tapcsync2core_ch_tdi_o         (tapc_dmi_ch_tdi           ),
    .tapc2tapcsync_ch_tdo_i         (tapc_dmi_ch_tdo_tapin     ),
    .tapcsync2core_ch_tdo_o         (tapc_ch_tdo               )
);
assign tapc_ch_tdo = (tapc_scu_ch_tdo & tapc_scu_ch_sel)
                   | (tapc_dmi_ch_tdo & tapc_dmi_ch_sel);

ycr_dmi i_dmi (
    .rst_n                      (dm_rst_n           ),
    .clk                        (clk                ),

    // TAP scan-chains
    .tapcsync2dmi_ch_sel_i      (tapc_dmi_ch_sel    ),
    .tapcsync2dmi_ch_id_i       (tapc_dmi_ch_id     ),
    .tapcsync2dmi_ch_capture_i  (tapc_dmi_ch_capture),
    .tapcsync2dmi_ch_shift_i    (tapc_dmi_ch_shift  ),
    .tapcsync2dmi_ch_update_i   (tapc_dmi_ch_update ),
    .tapcsync2dmi_ch_tdi_i      (tapc_dmi_ch_tdi    ),
    .dmi2tapcsync_ch_tdo_o      (tapc_dmi_ch_tdo    ),

    // DMI
    .dm2dmi_resp_i              (dmi_resp           ),
    .dm2dmi_rdata_i             (dmi_rdata          ),
    .dmi2dm_req_o               (dmi_req            ),
    .dmi2dm_wr_o                (dmi_wr             ),
    .dmi2dm_addr_o              (dmi_addr           ),
    .dmi2dm_wdata_o             (dmi_wdata          )
);

`endif // YCR_DBG_EN


`ifdef YCR_DBG_EN

//-------------------------------------------------------------------------------
// Debug Module (DM)
//-------------------------------------------------------------------------------
assign dm_cmd_resp_qlfy    = dm_cmd_resp   & {$bits(dm_cmd_resp){hdu2dm_rdc_qlfy}};
assign dm_hart_event_qlfy  = dm_hart_event & {$bits(dm_hart_event){hdu2dm_rdc_qlfy}};
assign dm_hart_status_qlfy.dbg_state = hdu2dm_rdc_qlfy ? dm_hart_status.dbg_state
                                                       : YCR_HDU_DBGSTATE_RESET;
assign dm_hart_status_qlfy.except    = dm_hart_status.except;
assign dm_hart_status_qlfy.ebreak    = dm_hart_status.ebreak;
assign dm_pbuf_addr_qlfy   = dm_pbuf_addr  & {$bits(dm_pbuf_addr){hdu2dm_rdc_qlfy}};
assign dm_dreg_req_qlfy    = dm_dreg_req   & {$bits(dm_dreg_req){hdu2dm_rdc_qlfy}};
assign dm_pc_sample_qlfy   = dm_pc_sample  & {$bits(dm_pc_sample){core2dm_rdc_qlfy}};

ycr_dm i_dm (
    // Common signals
    .rst_n                      (dm_rst_n               ),
    .clk                        (clk                    ),

    // DM internal interface
    .dmi2dm_req_i               (dmi_req                ),
    .dmi2dm_wr_i                (dmi_wr                 ),
    .dmi2dm_addr_i              (dmi_addr               ),
    .dmi2dm_wdata_i             (dmi_wdata              ),
    .dm2dmi_resp_o              (dmi_resp               ),
    .dm2dmi_rdata_o             (dmi_rdata              ),

    // DM <-> Pipeline: HART Run Control i/f
    .ndm_rst_n_o                (ndm_rst_n              ),
    .hart_rst_n_o               (hart_rst_n             ),
    .dm2pipe_active_o           (dm_active              ),
    .dm2pipe_cmd_req_o          (dm_cmd_req             ),
    .dm2pipe_cmd_o              (dm_cmd                 ),
    .pipe2dm_cmd_resp_i         (dm_cmd_resp_qlfy       ),
    .pipe2dm_cmd_rcode_i        (dm_cmd_rcode           ),
    .pipe2dm_hart_event_i       (dm_hart_event_qlfy     ),
    .pipe2dm_hart_status_i      (dm_hart_status_qlfy    ),

    .soc2dm_fuse_mhartid_i      (core_fuse_mhartid_i    ),
    .pipe2dm_pc_sample_i        (dm_pc_sample_qlfy      ),

    // DM <-> Pipeline: HART Abstract Command / Program Buffer i/f
    .pipe2dm_pbuf_addr_i        (dm_pbuf_addr_qlfy      ),
    .dm2pipe_pbuf_instr_o       (dm_pbuf_instr          ),

    // DM <-> Pipeline: HART Abstract Data regs i/f
    .pipe2dm_dreg_req_i         (dm_dreg_req_qlfy       ),
    .pipe2dm_dreg_wr_i          (dm_dreg_wr             ),
    .pipe2dm_dreg_wdata_i       (dm_dreg_wdata          ),
    .dm2pipe_dreg_resp_o        (dm_dreg_resp           ),
    .dm2pipe_dreg_fail_o        (dm_dreg_fail           ),
    .dm2pipe_dreg_rdata_o       (dm_dreg_rdata          )
);
`endif // YCR_DBG_EN


`ifdef YCR_CLKCTRL_EN
//-------------------------------------------------------------------------------
// Global clock gating logic
//-------------------------------------------------------------------------------
ycr_clk_ctrl i_clk_ctrl (
    .clk                            (clk        ),
    .rst_n                          (core_rst_n ),
    .test_mode                      (test_mode  ),
    .test_rst_n                     (test_rst_n ),

    // Sleep/wake interface
    .pipe2clkctl_sleep_req_i        (sleep_pipe ),
    .pipe2clkctl_wake_req_i         (wake_pipe  ),

    // Clocks
    .clkctl2pipe_clk_alw_on_o       (clk_alw_on ),
    .clkctl2pipe_clk_o              (clk_pipe   ),
    .clkctl2pipe_clk_en_o           (clk_pipe_en),
    .clkctl2pipe_clk_dbgc_o         (clk_dbgc   )
);
`endif // YCR_CLKCTRL_EN

endmodule : ycr_core_top
