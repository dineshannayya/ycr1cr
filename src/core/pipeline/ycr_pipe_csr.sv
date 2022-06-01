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
////  yifive Control Status Registers (CSR)                               ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     Control Status Registers (CSR)                                   ////
////                                                                      ////
//// Functionality:                                                       ////
//// - Provides access to RISC-V CSR Machine registers                    ////
//// - Handles events (EXC, IRQ and MRET):                                ////
////   - Setups handling configuration                                    ////
////   - Displays events statuses and information                         ////
////   - Generates new PC                                                 ////
//// - Provides information about the number of executed instructions and ////
////   elapsed  cycles                                                    ////
//// - Provides interfaces for IPIC, HDU and TDU registers access         ////
////                                                                      ////
//// Structure:                                                           ////
//// - Events (EXC, IRQ, MRET) logic                                      ////
//// - CSR read/write interface                                           ////
//// - CSR registers:                                                     ////
////   - Machine Trap Setup registers                                     ////
////   - Machine Trap Handling registers                                  ////
////   - Machine Counters/Timers registers                                ////
////   - Non-standard CSRs (MCOUNTEN)                                     ////
//// - CSR <-> EXU i/f                                                    ////
//// - CSR <-> IPIC i/f                                                   ////
//// - CSR <-> HDU i/f                                                    ////
//// - CSR <-> TDU i/f                                                    ////
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
`include "ycr_csr.svh"
`include "ycr_arch_types.svh"
`include "ycr_riscv_isa_decoding.svh"
`ifdef YCR_IPIC_EN
`include "ycr_ipic.svh"
`endif // YCR_IPIC_EN
`ifdef YCR_DBG_EN
`include "ycr_hdu.svh"
`endif // YCR_DBG_EN
`ifdef YCR_TDU_EN
`include "ycr_tdu.svh"
`endif // YCR_TDU_EN

module ycr_pipe_csr (
    // Common
    input   logic                                       rst_n,                      // CSR reset
    input   logic                                       clk,                        // Gated CSR clock
`ifdef YCR_CLKCTRL_EN
    input   logic                                       clk_alw_on,                 // Not-gated CSR clock
`endif // YCR_CLKCTRL_EN

    // SOC signals
    // IRQ
    input   logic                                       soc2csr_irq_ext_i,          // External interrupt request
    input   logic                                       soc2csr_irq_soft_i,         // Software interrupt request
    input   logic                                       soc2csr_irq_mtimer_i,       // External timer interrupt request

    // Memory-mapped external timer
    input   logic [63:0]                                soc2csr_mtimer_val_i,       // External timer value

    // MHARTID fuse
    input   logic [`YCR_XLEN-1:0]                      soc2csr_fuse_mhartid_i,     // MHARTID fuse

    // CSR <-> EXU read/write interface
    input   logic                                       exu2csr_r_req_i,            // CSR read/write address
    input   logic [YCR_CSR_ADDR_WIDTH-1:0]             exu2csr_rw_addr_i,          // CSR read request
    output  logic [`YCR_XLEN-1:0]                      csr2exu_r_data_o,           // CSR read data
    input   logic                                       exu2csr_w_req_i,            // CSR write request
    input   type_ycr_csr_cmd_sel_e                     exu2csr_w_cmd_i,            // CSR write command
    input   logic [`YCR_XLEN-1:0]                      exu2csr_w_data_i,           // CSR write data
    output  logic                                       csr2exu_rw_exc_o,           // CSR read/write access exception

    // CSR <-> EXU event interface
    input   logic                                       exu2csr_take_irq_i,         // Take IRQ trap
    input   logic                                       exu2csr_take_exc_i,         // Take exception trap
    input   logic                                       exu2csr_mret_update_i,      // MRET update CSR
    input   logic                                       exu2csr_mret_instr_i,       // MRET instruction
    input   logic [YCR_EXC_CODE_WIDTH_E-1:0]          exu2csr_exc_code_i,         // Exception code (see ycr_arch_types.svh) - cp.7
    input   logic [`YCR_XLEN-1:0]                      exu2csr_trap_val_i,         // Trap value
    output  logic                                       csr2exu_irq_o,              // IRQ request
    output  logic                                       csr2exu_ip_ie_o,            // Some IRQ pending and locally enabled
    output  logic                                       csr2exu_mstatus_mie_up_o,   // MSTATUS or MIE update in the current cycle

`ifdef YCR_IPIC_EN
    // CSR <-> IPIC interface
    output  logic                                       csr2ipic_r_req_o,           // IPIC read request
    output  logic                                       csr2ipic_w_req_o,           // IPIC write request
    output  logic [2:0]                                 csr2ipic_addr_o,            // IPIC address
    output  logic [`YCR_XLEN-1:0]                      csr2ipic_wdata_o,           // IPIC write data
    input   logic [`YCR_XLEN-1:0]                      ipic2csr_rdata_i,           // IPIC read data
`endif // YCR_IPIC_EN

`ifdef YCR_DBG_EN
    // CSR <-> HDU interface
    output  logic                                       csr2hdu_req_o,              // Request to HDU
    output  type_ycr_csr_cmd_sel_e                     csr2hdu_cmd_o,              // HDU command
    output  logic [YCR_HDU_DEBUGCSR_ADDR_WIDTH-1:0]    csr2hdu_addr_o,             // HDU address
    output  logic [`YCR_XLEN-1:0]                      csr2hdu_wdata_o,            // HDU write data
    input   logic [`YCR_XLEN-1:0]                      hdu2csr_rdata_i,            // HDU read data
    input   type_ycr_csr_resp_e                        hdu2csr_resp_i,             // HDU response
    input   logic                                       hdu2csr_no_commit_i,        // Forbid instruction commitment
`endif // YCR_DBG_EN

`ifdef YCR_TDU_EN
    // CSR <-> TDU interface
    output  logic                                       csr2tdu_req_o,              // Request to TDU
    output  type_ycr_csr_cmd_sel_e                     csr2tdu_cmd_o,              // TDU command
    output  logic [YCR_CSR_ADDR_TDU_OFFS_W-1:0]        csr2tdu_addr_o,             // TDU address
    output  logic [`YCR_XLEN-1:0]                      csr2tdu_wdata_o,            // TDU write data
    input   logic [`YCR_XLEN-1:0]                      tdu2csr_rdata_i,            // TDU read data
    input   type_ycr_csr_resp_e                        tdu2csr_resp_i,             // TDU response
`endif // YCR_TDU_EN

    // CSR <-> EXU PC interface
`ifndef YCR_CSR_REDUCED_CNT
    input   logic                                       exu2csr_instret_no_exc_i,   // Instruction retired (without exception)
`endif // YCR_CSR_REDUCED_CNT
    input   logic [`YCR_XLEN-1:0]                      exu2csr_pc_curr_i,          // Current PC
    input   logic [`YCR_XLEN-1:0]                      exu2csr_pc_next_i,          // Next PC
    output  logic [`YCR_XLEN-1:0]                      csr2exu_new_pc_o            // Exception/IRQ/MRET new PC
);

//------------------------------------------------------------------------------
// Local parameters
//------------------------------------------------------------------------------

`ifdef YCR_RVC_EXT
    localparam PC_LSB = 1;
`else
    localparam PC_LSB = 2;
`endif

//------------------------------------------------------------------------------
// Local signals declaration
//------------------------------------------------------------------------------

// Machine Trap Setup registers
//------------------------------------------------------------------------------

// MSTATUS register
logic                                               csr_mstatus_upd;        // MSTATUS update enable
logic [`YCR_XLEN-1:0]                              csr_mstatus;            // Aggregated MSTATUS
logic                                               csr_mstatus_mie_ff;     // MSTATUS: Global interrupt enable
logic                                               csr_mstatus_mie_next;   // MSTATUS: Global interrupt enable next value
logic                                               csr_mstatus_mpie_ff;    // MSTATUS: Global interrupt enable prior to the trap
logic                                               csr_mstatus_mpie_next;  // MSTATUS: Global interrupt enable prior to the trap next value

// MIE register
logic                                               csr_mie_upd;            // MIE update enable
logic [`YCR_XLEN-1:0]                              csr_mie;                // Aggregated MIE
logic                                               csr_mie_mtie_ff;        // MIE: Machine timer interrupt enable
logic                                               csr_mie_meie_ff;        // MIE: Machine external interrupt enable
logic                                               csr_mie_msie_ff;        // MIE: Machine software interrupt enable

// MTVEC register
logic                                               csr_mtvec_upd;          // MTVEC update enable
logic [`YCR_XLEN-1:YCR_CSR_MTVEC_BASE_ZERO_BITS]  csr_mtvec_base;         // MTVEC: Base (upper 26 bits)
logic                                               csr_mtvec_mode;         // MTVEC: Mode (0-direct, 1-vectored) (wired)
`ifdef YCR_MTVEC_MODE_EN
logic                                               csr_mtvec_mode_ff;      // MTVEC: Mode (0-direct, 1-vectored) (registered)
logic                                               csr_mtvec_mode_vect;
`endif

// Machine Trap Handling registers
//------------------------------------------------------------------------------

// MSCRATCH register
logic                                               csr_mscratch_upd;       // MSCRATCH update enable
logic [`YCR_XLEN-1:0]                              csr_mscratch_ff;        // MSCRATCH

// MEPC register
logic                                               csr_mepc_upd;           // MEPC update enable
logic [`YCR_XLEN-1:PC_LSB]                         csr_mepc_ff;            // MEPC registered value
logic [`YCR_XLEN-1:PC_LSB]                         csr_mepc_next;          // MEPC next value
logic [`YCR_XLEN-1:0]                              csr_mepc;               // MEPC registered value extended to XLEN

// MCAUSE register
logic                                               csr_mcause_upd;         // MCAUSE update enable
logic                                               csr_mcause_i_ff;        // MCAUSE: Interrupt
logic                                               csr_mcause_i_next;      // MCAUSE: Interrupt next value
logic [YCR_EXC_CODE_WIDTH_E-1:0]                   csr_mcause_ec_ff;       // MCAUSE: Exception code - cp.7
logic [YCR_EXC_CODE_WIDTH_E-1:0]                   csr_mcause_ec_next;     // MCAUSE: Exception code next value - cp.7
logic [YCR_EXC_CODE_WIDTH_E-1:0]                   csr_mcause_ec_new;      // MCAUSE: Exception code new value (IRQs) - cp.7

// MTVAL register
logic                                               csr_mtval_upd;          // MTVAL update enable
logic [`YCR_XLEN-1:0]                              csr_mtval_ff;           // MTVAL registered value
logic [`YCR_XLEN-1:0]                              csr_mtval_next;         // MTVAL next value

// MIP register
logic [`YCR_XLEN-1:0]                              csr_mip;                // Aggregated MIP
logic                                               csr_mip_mtip;           // MIP: Machine timer interrupt pending
logic                                               csr_mip_meip;           // MIP: Machine external interrupt pending
logic                                               csr_mip_msip;           // MIP: Machine software interrupt pending

// Machine Counters/Timers registers
//------------------------------------------------------------------------------

`ifndef YCR_CSR_REDUCED_CNT
// MINSTRET register
logic [1:0]                                         csr_minstret_upd;
logic [YCR_CSR_COUNTERS_WIDTH-1:0]                 csr_minstret;
logic                                               csr_minstret_lo_inc;
logic                                               csr_minstret_lo_upd;
logic [7:0]                                         csr_minstret_lo_ff;
logic [7:0]                                         csr_minstret_lo_next;
logic                                               csr_minstret_hi_inc;
logic                                               csr_minstret_hi_upd;
logic [YCR_CSR_COUNTERS_WIDTH-1:8]                 csr_minstret_hi_ff;
logic [YCR_CSR_COUNTERS_WIDTH-1:8]                 csr_minstret_hi_next;
logic [YCR_CSR_COUNTERS_WIDTH-1:8]                 csr_minstret_hi_new;

// MCYCLE register
logic [1:0]                                         csr_mcycle_upd;
logic [YCR_CSR_COUNTERS_WIDTH-1:0]                 csr_mcycle;
logic                                               csr_mcycle_lo_inc;
logic                                               csr_mcycle_lo_upd;
logic [7:0]                                         csr_mcycle_lo_ff;
logic [7:0]                                         csr_mcycle_lo_next;
logic                                               csr_mcycle_hi_inc;
logic                                               csr_mcycle_hi_upd;
logic [YCR_CSR_COUNTERS_WIDTH-1:8]                 csr_mcycle_hi_ff;
logic [YCR_CSR_COUNTERS_WIDTH-1:8]                 csr_mcycle_hi_next;
logic [YCR_CSR_COUNTERS_WIDTH-1:8]                 csr_mcycle_hi_new;
`endif // ~YCR_CSR_REDUCED_CNT

// Non-standard CSRs
//------------------------------------------------------------------------------

// MCOUNTEN register
`ifdef YCR_MCOUNTEN_EN
logic                                               csr_mcounten_upd;       // MCOUNTEN update enable
logic [`YCR_XLEN-1:0]                              csr_mcounten;           // Aggregated MCOUNTEN
logic                                               csr_mcounten_cy_ff;     // Cycle count enable
logic                                               csr_mcounten_ir_ff;     // Instret count enable
`endif // YCR_MCOUNTEN_EN

// CSR read/write i/f
//------------------------------------------------------------------------------

logic [`YCR_XLEN-1:0]                              csr_r_data;
logic [`YCR_XLEN-1:0]                              csr_w_data;

// Events (exceptions, interrupts, mret) signals
//------------------------------------------------------------------------------

// Event flags
logic                                               e_exc;              // Successful exception trap
logic                                               e_irq;              // Successful IRQ trap
logic                                               e_mret;             // MRET instruction
logic                                               e_irq_nmret;        // IRQ trap without MRET instruction

// Interrupt pending & enable signals
logic                                               csr_eirq_pnd_en;    // External IRQ pending and locally enabled
logic                                               csr_sirq_pnd_en;    // Software IRQ pending and locally enabled
logic                                               csr_tirq_pnd_en;    // Timer IRQ pending and locally enabled

// Exception flags
logic                                               csr_w_exc;
logic                                               csr_r_exc;
logic                                               exu_req_no_exc;

// Requests to other modules
logic                                               csr_ipic_req;
`ifdef YCR_DBG_EN
logic                                               csr_hdu_req;
`endif // YCR_DBG_EN
`ifdef YCR_TDU_EN
logic                                               csr_brkm_req;
`endif // YCR_TDU_EN

//------------------------------------------------------------------------------
// Events (IRQ, EXC, MRET)
//------------------------------------------------------------------------------

// Events priority
assign e_exc    = exu2csr_take_exc_i
`ifdef YCR_DBG_EN
                & ~hdu2csr_no_commit_i
`endif // YCR_DBG_EN
                ;
assign e_irq    = exu2csr_take_irq_i & ~exu2csr_take_exc_i
`ifdef YCR_DBG_EN
                & ~hdu2csr_no_commit_i
`endif // YCR_DBG_EN
                ;
assign e_mret   = exu2csr_mret_update_i
`ifdef YCR_DBG_EN
                & ~hdu2csr_no_commit_i
`endif // YCR_DBG_EN
                ;
assign e_irq_nmret = e_irq & ~exu2csr_mret_instr_i;

// IRQ pending & enable signals
assign csr_eirq_pnd_en = csr_mip_meip & csr_mie_meie_ff;
assign csr_sirq_pnd_en = csr_mip_msip & csr_mie_msie_ff;
assign csr_tirq_pnd_en = csr_mip_mtip & csr_mie_mtie_ff;

// IRQ exception codes priority
always_comb begin
    case (1'b1)
        csr_eirq_pnd_en: csr_mcause_ec_new = YCR_EXC_CODE_IRQ_M_EXTERNAL; // cp.7
        csr_sirq_pnd_en: csr_mcause_ec_new = YCR_EXC_CODE_IRQ_M_SOFTWARE; // cp.7
        csr_tirq_pnd_en: csr_mcause_ec_new = YCR_EXC_CODE_IRQ_M_TIMER; // cp.7
        default        : csr_mcause_ec_new = YCR_EXC_CODE_IRQ_M_EXTERNAL; // cp.7
    endcase
end

assign exu_req_no_exc = ((exu2csr_r_req_i & ~csr_r_exc)
                      |  (exu2csr_w_req_i & ~csr_w_exc));

//------------------------------------------------------------------------------
// CSR read/write interface
//------------------------------------------------------------------------------

// CSR read logic
//------------------------------------------------------------------------------

always_comb begin
    csr_r_data     = '0;
    csr_r_exc      = 1'b0;
`ifdef YCR_DBG_EN
    csr_hdu_req    = 1'b0;
`endif // YCR_DBG_EN
`ifdef YCR_TDU_EN
    csr_brkm_req   = 1'b0;
`endif // YCR_TDU_EN
`ifdef YCR_IPIC_EN
    csr2ipic_r_req_o = 1'b0;
`endif // YCR_IPIC_EN

    casez (exu2csr_rw_addr_i)
        // Machine Information Registers (read-only)
        YCR_CSR_ADDR_MVENDORID : csr_r_data    = YCR_CSR_MVENDORID;
        YCR_CSR_ADDR_MARCHID   : csr_r_data    = YCR_CSR_MARCHID;
        YCR_CSR_ADDR_MIMPID    : csr_r_data    = YCR_CSR_MIMPID;
        YCR_CSR_ADDR_MHARTID   : csr_r_data    = soc2csr_fuse_mhartid_i;
        YCR_CSR_ADDR_NUMCORES  : csr_r_data    = YCR_CSR_NUMCORES;

        // Machine Trap Setup (read-write)
        YCR_CSR_ADDR_MSTATUS   : csr_r_data    = csr_mstatus;
        YCR_CSR_ADDR_MISA      : csr_r_data    = YCR_CSR_MISA;
        YCR_CSR_ADDR_MIE       : csr_r_data    = csr_mie;
        YCR_CSR_ADDR_MTVEC     : csr_r_data    = {csr_mtvec_base, 4'd0, 2'(csr_mtvec_mode)};

        // Machine Trap Handling (read-write)
        YCR_CSR_ADDR_MSCRATCH  : csr_r_data    = csr_mscratch_ff;
        YCR_CSR_ADDR_MEPC      : csr_r_data    = csr_mepc;
        YCR_CSR_ADDR_MCAUSE    : csr_r_data    = {csr_mcause_i_ff, (`YCR_XLEN-1)'(csr_mcause_ec_ff)};
        YCR_CSR_ADDR_MTVAL     : csr_r_data    = csr_mtval_ff;
        YCR_CSR_ADDR_MIP       : csr_r_data    = csr_mip;

        // User Counters/Timers (read-only)
        {YCR_CSR_ADDR_HPMCOUNTER_MASK, 5'b?????}   : begin
            case (exu2csr_rw_addr_i[4:0])
                5'd1        : csr_r_data    = soc2csr_mtimer_val_i[31:0];
`ifndef YCR_CSR_REDUCED_CNT
                5'd0        : csr_r_data    = csr_mcycle[31:0];
                5'd2        : csr_r_data    = csr_minstret[31:0];
`endif // YCR_CSR_REDUCED_CNT
                default     : begin
                    // return 0
                end
            endcase
        end

        {YCR_CSR_ADDR_HPMCOUNTERH_MASK, 5'b?????}  : begin
            case (exu2csr_rw_addr_i[4:0])
                5'd1        : csr_r_data    = soc2csr_mtimer_val_i[63:32];
`ifndef YCR_CSR_REDUCED_CNT
                5'd0        : csr_r_data    = csr_mcycle[63:32];
                5'd2        : csr_r_data    = csr_minstret[63:32];
`endif // YCR_CSR_REDUCED_CNT
                default     : begin
                    // return 0
                end
            endcase
        end

        // Machine Counters/Timers (read-write)
        {YCR_CSR_ADDR_MHPMCOUNTER_MASK, 5'b?????}  : begin
            case (exu2csr_rw_addr_i[4:0])
                5'd1        : csr_r_exc     = exu2csr_r_req_i;
`ifndef YCR_CSR_REDUCED_CNT
                5'd0        : csr_r_data    = csr_mcycle[31:0];
                5'd2        : csr_r_data    = csr_minstret[31:0];
`endif // YCR_CSR_REDUCED_CNT
                default     : begin
                    // return 0
                end
            endcase
        end

        {YCR_CSR_ADDR_MHPMCOUNTERH_MASK, 5'b?????} : begin
            case (exu2csr_rw_addr_i[4:0])
                5'd1        : csr_r_exc     = exu2csr_r_req_i;
`ifndef YCR_CSR_REDUCED_CNT
                5'd0        : csr_r_data    = csr_mcycle[63:32];
                5'd2        : csr_r_data    = csr_minstret[63:32];
`endif // YCR_CSR_REDUCED_CNT
                default     : begin
                    // return 0
                end
            endcase
        end

        {YCR_CSR_ADDR_MHPMEVENT_MASK, 5'b?????}    : begin
            case (exu2csr_rw_addr_i[4:0])
                5'd0,
                5'd1,
                5'd2        : csr_r_exc = exu2csr_r_req_i;
                default     : begin
                    // return 0
                end
            endcase
        end

`ifdef YCR_MCOUNTEN_EN
        YCR_CSR_ADDR_MCOUNTEN      : csr_r_data    = csr_mcounten;
`endif // YCR_MCOUNTEN_EN

`ifdef YCR_IPIC_EN
        // IPIC registers
        YCR_CSR_ADDR_IPIC_CISV,
        YCR_CSR_ADDR_IPIC_CICSR,
        YCR_CSR_ADDR_IPIC_IPR,
        YCR_CSR_ADDR_IPIC_ISVR,
        YCR_CSR_ADDR_IPIC_EOI,
        YCR_CSR_ADDR_IPIC_SOI,
        YCR_CSR_ADDR_IPIC_IDX,
        YCR_CSR_ADDR_IPIC_ICSR     : begin
            csr_r_data       = ipic2csr_rdata_i;
            csr2ipic_r_req_o = exu2csr_r_req_i;
        end
`endif // YCR_IPIC_EN

`ifdef YCR_DBG_EN
        // HDU registers
        YCR_HDU_DBGCSR_ADDR_DCSR,
        YCR_HDU_DBGCSR_ADDR_DPC,
        YCR_HDU_DBGCSR_ADDR_DSCRATCH0,
        YCR_HDU_DBGCSR_ADDR_DSCRATCH1 : begin
            csr_hdu_req = 1'b1;
            csr_r_data  = hdu2csr_rdata_i;
        end
`endif // YCR_DBG_EN

`ifdef YCR_TDU_EN
        // TDU registers
        YCR_CSR_ADDR_TDU_TSELECT,
        YCR_CSR_ADDR_TDU_TDATA1,
        YCR_CSR_ADDR_TDU_TDATA2,
        YCR_CSR_ADDR_TDU_TINFO: begin
            csr_brkm_req    = 1'b1;
            csr_r_data      = tdu2csr_rdata_i;
        end
`endif // YCR_TDU_EN

        default     : begin
            csr_r_exc   = exu2csr_r_req_i;
        end
    endcase // exu2csr_rw_addr_i
end

assign csr2exu_r_data_o = csr_r_data;

// CSR write logic
//------------------------------------------------------------------------------

always_comb begin
    case (exu2csr_w_cmd_i)
        YCR_CSR_CMD_WRITE  : csr_w_data =  exu2csr_w_data_i;
        YCR_CSR_CMD_SET    : csr_w_data =  exu2csr_w_data_i | csr_r_data;
        YCR_CSR_CMD_CLEAR  : csr_w_data = ~exu2csr_w_data_i & csr_r_data;
        default             : csr_w_data = '0;
    endcase
end

always_comb begin
    csr_mstatus_upd     = 1'b0;
    csr_mie_upd         = 1'b0;
    csr_mscratch_upd    = 1'b0;
    csr_mepc_upd        = 1'b0;
    csr_mcause_upd      = 1'b0;
    csr_mtval_upd       = 1'b0;
    csr_mtvec_upd       = 1'b0;

`ifndef YCR_CSR_REDUCED_CNT
    csr_mcycle_upd      = 2'b00;
    csr_minstret_upd    = 2'b00;
`endif // YCR_CSR_REDUCED_CNT

`ifdef YCR_MCOUNTEN_EN
    csr_mcounten_upd    = 1'b0;
`endif // YCR_MCOUNTEN_EN
    csr_w_exc           = 1'b0;
`ifdef YCR_IPIC_EN
    csr2ipic_w_req_o    = 1'b0;
`endif // YCR_IPIC_EN

    if (exu2csr_w_req_i) begin
        casez (exu2csr_rw_addr_i)
            // Machine Trap Setup (read-write)
            YCR_CSR_ADDR_MSTATUS   : csr_mstatus_upd   = 1'b1;
            YCR_CSR_ADDR_MISA      : begin end
            YCR_CSR_ADDR_MIE       : csr_mie_upd       = 1'b1;
            YCR_CSR_ADDR_MTVEC     : csr_mtvec_upd     = 1'b1;

            // Machine Trap Handling (read-write)
            YCR_CSR_ADDR_MSCRATCH  : csr_mscratch_upd  = 1'b1;
            YCR_CSR_ADDR_MEPC      : csr_mepc_upd      = 1'b1;
            YCR_CSR_ADDR_MCAUSE    : csr_mcause_upd    = 1'b1;
            YCR_CSR_ADDR_MTVAL     : csr_mtval_upd     = 1'b1;
            YCR_CSR_ADDR_MIP       : begin end

            // Machine Counters/Timers (read-write)
            {YCR_CSR_ADDR_MHPMCOUNTER_MASK, 5'b?????}  : begin
                case (exu2csr_rw_addr_i[4:0])
                    5'd1        : csr_w_exc           = 1'b1;
`ifndef YCR_CSR_REDUCED_CNT
                    5'd0        : csr_mcycle_upd[0]   = 1'b1;
                    5'd2        : csr_minstret_upd[0] = 1'b1;
`endif // YCR_CSR_REDUCED_CNT
                    default     : begin
                        // no exception
                    end
                endcase
            end

            {YCR_CSR_ADDR_MHPMCOUNTERH_MASK, 5'b?????} : begin
                case (exu2csr_rw_addr_i[4:0])
                    5'd1        : csr_w_exc           = 1'b1;
`ifndef YCR_CSR_REDUCED_CNT
                    5'd0        : csr_mcycle_upd[1]   = 1'b1;
                    5'd2        : csr_minstret_upd[1] = 1'b1;
`endif // YCR_CSR_REDUCED_CNT
                    default     : begin
                        // no exception
                    end
                endcase
            end

            {YCR_CSR_ADDR_MHPMEVENT_MASK, 5'b?????}    : begin
                case (exu2csr_rw_addr_i[4:0])
                    5'd0,
                    5'd1,
                    5'd2        : csr_w_exc = 1'b1;
                    default     : begin
                        // no exception
                    end
                endcase
            end

`ifdef YCR_MCOUNTEN_EN
            YCR_CSR_ADDR_MCOUNTEN      : csr_mcounten_upd = 1'b1;
`endif // YCR_MCOUNTEN_EN

`ifdef YCR_IPIC_EN
            // IPIC registers
            YCR_CSR_ADDR_IPIC_CICSR,
            YCR_CSR_ADDR_IPIC_IPR,
            YCR_CSR_ADDR_IPIC_EOI,
            YCR_CSR_ADDR_IPIC_SOI,
            YCR_CSR_ADDR_IPIC_IDX,
            YCR_CSR_ADDR_IPIC_ICSR     : begin
                csr2ipic_w_req_o  = 1'b1;
            end
            YCR_CSR_ADDR_IPIC_CISV,
            YCR_CSR_ADDR_IPIC_ISVR     : begin
                // no exception on write
            end
`endif // YCR_IPIC_EN

`ifdef YCR_DBG_EN
            YCR_HDU_DBGCSR_ADDR_DCSR,
            YCR_HDU_DBGCSR_ADDR_DPC,
            YCR_HDU_DBGCSR_ADDR_DSCRATCH0,
            YCR_HDU_DBGCSR_ADDR_DSCRATCH1 : begin
            end
`endif // YCR_DBG_EN

`ifdef YCR_TDU_EN
            // TDU registers
            YCR_CSR_ADDR_TDU_TSELECT,
            YCR_CSR_ADDR_TDU_TDATA1,
            YCR_CSR_ADDR_TDU_TDATA2,
            YCR_CSR_ADDR_TDU_TINFO: begin
            end
`endif // YCR_TDU_EN

            default : begin
                csr_w_exc   = 1'b1;
            end
        endcase
    end
end

//------------------------------------------------------------------------------
// Machine Trap Setup registers
//------------------------------------------------------------------------------
//
 // Registers:
 // - MSTATUS
 // - MIE
 // - MTVEC
//

// MSTATUS register
//------------------------------------------------------------------------------
// Consists of 2 bits - current and previous (before trap) global interrupt
// enable bits (MIE & MPIE)

always_ff @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
        csr_mstatus_mie_ff  <= YCR_CSR_MSTATUS_MIE_RST_VAL;
        csr_mstatus_mpie_ff <= YCR_CSR_MSTATUS_MPIE_RST_VAL;
    end else begin
        csr_mstatus_mie_ff  <= csr_mstatus_mie_next;
        csr_mstatus_mpie_ff <= csr_mstatus_mpie_next;
    end
end

always_comb begin
    case (1'b1)
        e_exc, e_irq  : begin
            csr_mstatus_mie_next  = 1'b0;
            csr_mstatus_mpie_next = csr_mstatus_mie_ff;
        end
        e_mret        : begin
            csr_mstatus_mie_next  = csr_mstatus_mpie_ff;
            csr_mstatus_mpie_next = 1'b1;
        end
        csr_mstatus_upd: begin
            csr_mstatus_mie_next  = csr_w_data[YCR_CSR_MSTATUS_MIE_OFFSET];
            csr_mstatus_mpie_next = csr_w_data[YCR_CSR_MSTATUS_MPIE_OFFSET];
        end
        default       : begin
            csr_mstatus_mie_next  = csr_mstatus_mie_ff;
            csr_mstatus_mpie_next = csr_mstatus_mpie_ff;
        end
    endcase
end

always_comb begin
    csr_mstatus                                                            = '0;
    csr_mstatus[YCR_CSR_MSTATUS_MIE_OFFSET]                               = csr_mstatus_mie_ff;
    csr_mstatus[YCR_CSR_MSTATUS_MPIE_OFFSET]                              = csr_mstatus_mpie_ff;
    csr_mstatus[YCR_CSR_MSTATUS_MPP_OFFSET+1:YCR_CSR_MSTATUS_MPP_OFFSET] = YCR_CSR_MSTATUS_MPP;
end

// MIE register
//------------------------------------------------------------------------------
// Contains interrupt enable bits (external, software, timer IRQs)

always_ff @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
        csr_mie_mtie_ff <= YCR_CSR_MIE_MTIE_RST_VAL;
        csr_mie_meie_ff <= YCR_CSR_MIE_MEIE_RST_VAL;
        csr_mie_msie_ff <= YCR_CSR_MIE_MSIE_RST_VAL;
    end else if (csr_mie_upd) begin
        csr_mie_mtie_ff <= csr_w_data[YCR_CSR_MIE_MTIE_OFFSET];
        csr_mie_meie_ff <= csr_w_data[YCR_CSR_MIE_MEIE_OFFSET];
        csr_mie_msie_ff <= csr_w_data[YCR_CSR_MIE_MSIE_OFFSET];
    end
end

always_comb begin
    csr_mie                           = '0;
    csr_mie[YCR_CSR_MIE_MSIE_OFFSET] = csr_mie_msie_ff;
    csr_mie[YCR_CSR_MIE_MTIE_OFFSET] = csr_mie_mtie_ff;
    csr_mie[YCR_CSR_MIE_MEIE_OFFSET] = csr_mie_meie_ff;
end

// MTVEC register
//------------------------------------------------------------------------------
// Holds trap vector configuation. Consists of base and mode parts

// MTVEC BASE part
//------------------------------------------------------------------------------
// Holds trap vector base address
generate
    // All bits of MTVEC base are Read-Only and hardwired to 0's
    if (YCR_MTVEC_BASE_WR_BITS == 0) begin : mtvec_base_ro

        assign csr_mtvec_base   = YCR_CSR_MTVEC_BASE_RST_VAL;

    // All bits of MTVEC base are RW
    end else if (YCR_MTVEC_BASE_WR_BITS == YCR_CSR_MTVEC_BASE_VAL_BITS) begin : mtvec_base_rw

        always_ff @(negedge rst_n, posedge clk) begin
            if (~rst_n) begin
                csr_mtvec_base  <= YCR_CSR_MTVEC_BASE_RST_VAL;
            end else if (csr_mtvec_upd) begin
                csr_mtvec_base  <= csr_w_data[`YCR_XLEN-1:YCR_CSR_MTVEC_BASE_ZERO_BITS];
            end
        end

    // Lower bits of MTVEC base are RO, higher - RW
    end else begin : mtvec_base_ro_rw

        logic [(`YCR_XLEN-1):(`YCR_XLEN-YCR_MTVEC_BASE_WR_BITS)]   csr_mtvec_base_reg;

        always_ff @(negedge rst_n, posedge clk) begin
            if (~rst_n) begin
                csr_mtvec_base_reg <= YCR_CSR_MTVEC_BASE_RST_VAL[(`YCR_XLEN-1)-:YCR_MTVEC_BASE_WR_BITS] ;
            end else if (csr_mtvec_upd) begin
                csr_mtvec_base_reg <= csr_w_data[(`YCR_XLEN-1)-:YCR_MTVEC_BASE_WR_BITS];
            end
        end

        assign csr_mtvec_base = {csr_mtvec_base_reg, YCR_CSR_MTVEC_BASE_RST_VAL[YCR_CSR_MTVEC_BASE_ZERO_BITS+:YCR_CSR_MTVEC_BASE_RO_BITS]};
    end
endgenerate

// MTVEC MODE part
//------------------------------------------------------------------------------
// Chooses between direct (all exceptions set PC to BASE) or vectored
// (asynchronous interrupts set PC to BASE+4xcause) interrupt modes

`ifdef YCR_MTVEC_MODE_EN
always_ff @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
        csr_mtvec_mode_ff <= YCR_CSR_MTVEC_MODE_DIRECT;
    end else if (csr_mtvec_upd) begin
        csr_mtvec_mode_ff <= csr_w_data[0];
    end
end

assign csr_mtvec_mode      = csr_mtvec_mode_ff;
assign csr_mtvec_mode_vect = (csr_mtvec_mode_ff == YCR_CSR_MTVEC_MODE_VECTORED);
`else // YCR_MTVEC_MODE_EN
assign csr_mtvec_mode = YCR_CSR_MTVEC_MODE_DIRECT;
`endif // YCR_MTVEC_MODE_EN

//------------------------------------------------------------------------------
// Machine Trap Handling registers
//------------------------------------------------------------------------------
//
 // Registers:
 // - MSCRATCH
 // - MEPC
 // - MCAUSE
 // - MTVAL
 // - MIP
//

// MSCRATCH register
//------------------------------------------------------------------------------
// Holds a pointer to a machine-mode hart-local context space

always_ff @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
        csr_mscratch_ff <= '0;
    end else if (csr_mscratch_upd) begin
        csr_mscratch_ff <= csr_w_data;
    end
end

// MEPC register
//------------------------------------------------------------------------------
// When a trap is taken into M-mode saves the virtual address of instruction that
// was interrupted or that encountered the exception

always_ff @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
        csr_mepc_ff <= '0;
    end else begin
        csr_mepc_ff <= csr_mepc_next;
    end
end

always_comb begin
    case (1'b1)
        e_exc       : csr_mepc_next = exu2csr_pc_curr_i[`YCR_XLEN-1:PC_LSB];
        e_irq_nmret : csr_mepc_next = exu2csr_pc_next_i[`YCR_XLEN-1:PC_LSB];
        csr_mepc_upd: csr_mepc_next = csr_w_data[`YCR_XLEN-1:PC_LSB];
        default     : csr_mepc_next = csr_mepc_ff;
    endcase
end

`ifdef YCR_RVC_EXT
    assign csr_mepc = {csr_mepc_ff, 1'b0};
`else
    assign csr_mepc = {csr_mepc_ff, 2'b00};
`endif

// MCAUSE register
//------------------------------------------------------------------------------
// When a trap is taken into M-mode saves a code indicating the event that caused
// the trap

always_ff @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
        csr_mcause_i_ff  <= 1'b0;
        csr_mcause_ec_ff <= YCR_EXC_CODE_RESET; // cp.7
    end else begin
        csr_mcause_i_ff  <= csr_mcause_i_next;
        csr_mcause_ec_ff <= csr_mcause_ec_next;
    end
end

always_comb begin
    case (1'b1)
        e_exc         : begin
            csr_mcause_i_next  = 1'b0;
            csr_mcause_ec_next = exu2csr_exc_code_i;
        end
        e_irq         : begin
            csr_mcause_i_next  = 1'b1;
            csr_mcause_ec_next = csr_mcause_ec_new;
        end
        csr_mcause_upd: begin
            csr_mcause_i_next  = csr_w_data[`YCR_XLEN-1];
            csr_mcause_ec_next = csr_w_data[YCR_EXC_CODE_WIDTH_E-1:0]; // cp.7
        end
        default       : begin
            csr_mcause_i_next  = csr_mcause_i_ff;
            csr_mcause_ec_next = csr_mcause_ec_ff;
        end
    endcase
end

// MTVAL register
//------------------------------------------------------------------------------
// When a trap is taken into M-mode is either set to zero or written with exception-
// specific information

always_ff @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
        csr_mtval_ff <= '0;
    end else begin
        csr_mtval_ff <= csr_mtval_next;
    end
end

always_comb begin
    case (1'b1)
        e_exc        : csr_mtval_next = exu2csr_trap_val_i;
        e_irq        : csr_mtval_next = '0;
        csr_mtval_upd: csr_mtval_next = csr_w_data;
        default      : csr_mtval_next = csr_mtval_ff;
    endcase
end

// MIP register
//------------------------------------------------------------------------------
// Contains information on pending interrupts (external, software, timer IRQs)

assign csr_mip_mtip = soc2csr_irq_mtimer_i;
assign csr_mip_meip = soc2csr_irq_ext_i;
assign csr_mip_msip = soc2csr_irq_soft_i;

always_comb begin
    csr_mip                           = '0;
    csr_mip[YCR_CSR_MIE_MSIE_OFFSET] = csr_mip_msip;
    csr_mip[YCR_CSR_MIE_MTIE_OFFSET] = csr_mip_mtip;
    csr_mip[YCR_CSR_MIE_MEIE_OFFSET] = csr_mip_meip;
end

//------------------------------------------------------------------------------
// Machine Counters/Timers registers
//------------------------------------------------------------------------------
//
 // Registers:
 // - MCYCLE
 // - MINSTRET
//

`ifndef YCR_CSR_REDUCED_CNT
// MCYCLE register
//------------------------------------------------------------------------------
// Holds the number of clock cycles since some arbitrary point of time in the
// past at which MCYCLE was zero

assign csr_mcycle_lo_inc = 1'b1
 `ifdef YCR_MCOUNTEN_EN
                         & csr_mcounten_cy_ff
 `endif // YCR_MCOUNTEN_EN
                         ;
assign csr_mcycle_hi_inc = csr_mcycle_lo_inc & (&csr_mcycle_lo_ff);

assign csr_mcycle_lo_upd = csr_mcycle_lo_inc | csr_mcycle_upd[0];
assign csr_mcycle_hi_upd = csr_mcycle_hi_inc | (|csr_mcycle_upd);

 `ifndef YCR_CLKCTRL_EN
always_ff @(negedge rst_n, posedge clk) begin
 `else // YCR_CLKCTRL_EN
always_ff @(negedge rst_n, posedge clk_alw_on) begin
 `endif // YCR_CLKCTRL_EN
    if (~rst_n) begin
        csr_mcycle_lo_ff <= '0;
        csr_mcycle_hi_ff <= '0;
    end else begin
        if (csr_mcycle_lo_upd) csr_mcycle_lo_ff <= csr_mcycle_lo_next;
        if (csr_mcycle_hi_upd) csr_mcycle_hi_ff <= csr_mcycle_hi_next;
    end
end

assign csr_mcycle_hi_new  = csr_mcycle_hi_ff + 1'b1;

assign csr_mcycle_lo_next = csr_mcycle_upd[0] ? csr_w_data[7:0]
                          : csr_mcycle_lo_inc ? csr_mcycle_lo_ff + 1'b1
                                              : csr_mcycle_lo_ff;
assign csr_mcycle_hi_next = csr_mcycle_upd[0] ? {csr_mcycle_hi_new[63:32], csr_w_data[31:8]}
                          : csr_mcycle_upd[1] ? {csr_w_data, csr_mcycle_hi_new[31:8]}
                          : csr_mcycle_hi_inc ? csr_mcycle_hi_new
                                              : csr_mcycle_hi_ff;

assign csr_mcycle = {csr_mcycle_hi_ff, csr_mcycle_lo_ff};

// MINSTRET register
//------------------------------------------------------------------------------
// Holds the number of instructions executed by the core from some arbitrary time
// in the past at which MINSTRET was equal to zero

assign csr_minstret_lo_inc = exu2csr_instret_no_exc_i
 `ifdef YCR_MCOUNTEN_EN
                           & csr_mcounten_ir_ff
 `endif // YCR_MCOUNTEN_EN
                           ;
assign csr_minstret_hi_inc = csr_minstret_lo_inc & (&csr_minstret_lo_ff);

assign csr_minstret_lo_upd = csr_minstret_lo_inc | csr_minstret_upd[0];
assign csr_minstret_hi_upd = csr_minstret_hi_inc | (|csr_minstret_upd);

always_ff @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
        csr_minstret_lo_ff <= '0;
        csr_minstret_hi_ff <= '0;
    end else begin
        if (csr_minstret_lo_upd) csr_minstret_lo_ff <= csr_minstret_lo_next;
        if (csr_minstret_hi_upd) csr_minstret_hi_ff <= csr_minstret_hi_next;
    end
end

assign csr_minstret_hi_new  = csr_minstret_hi_ff + 1'b1;

assign csr_minstret_lo_next = csr_minstret_upd[0] ? csr_w_data[7:0]
                            : csr_minstret_lo_inc ? csr_minstret_lo_ff + 1'b1
                                                  : csr_minstret_lo_ff;
assign csr_minstret_hi_next = csr_minstret_upd[0] ? {csr_minstret_hi_new[63:32], csr_w_data[31:8]}
                            : csr_minstret_upd[1] ? {csr_w_data, csr_minstret_hi_new[31:8]}
                            : csr_minstret_hi_inc ? csr_minstret_hi_new
                                                  : csr_minstret_hi_ff;

assign csr_minstret = {csr_minstret_hi_ff, csr_minstret_lo_ff};
`endif // YCR_CSR_REDUCED_CNT

//------------------------------------------------------------------------------
// Non-standard CSR
//------------------------------------------------------------------------------

`ifdef YCR_MCOUNTEN_EN
// MCOUNTEN register
//------------------------------------------------------------------------------
// Holds Counters enable bits (CY - MCYCLE counter; IR - MINSTRET counter)

always_ff @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
        csr_mcounten_cy_ff <= 1'b1;
        csr_mcounten_ir_ff <= 1'b1;
    end else if (csr_mcounten_upd) begin
        csr_mcounten_cy_ff <= csr_w_data[YCR_CSR_MCOUNTEN_CY_OFFSET];
        csr_mcounten_ir_ff <= csr_w_data[YCR_CSR_MCOUNTEN_IR_OFFSET];
    end
end

always_comb begin
    csr_mcounten    = '0;
    csr_mcounten[YCR_CSR_MCOUNTEN_CY_OFFSET]   = csr_mcounten_cy_ff;
    csr_mcounten[YCR_CSR_MCOUNTEN_IR_OFFSET]   = csr_mcounten_ir_ff;
end
`endif // YCR_MCOUNTEN_EN

//------------------------------------------------------------------------------
// CSR <-> EXU interface
//------------------------------------------------------------------------------

// CSR exception
assign csr2exu_rw_exc_o = csr_r_exc | csr_w_exc
`ifdef YCR_DBG_EN
                        | (csr2hdu_req_o & (hdu2csr_resp_i != YCR_CSR_RESP_OK))
`endif // YCR_DBG_EN
`ifdef YCR_TDU_EN
                        | (csr2tdu_req_o & (tdu2csr_resp_i != YCR_CSR_RESP_OK))
`endif // YCR_TDU_EN
                        ;
assign csr2exu_ip_ie_o  = csr_eirq_pnd_en | csr_sirq_pnd_en | csr_tirq_pnd_en;
assign csr2exu_irq_o    = csr2exu_ip_ie_o & csr_mstatus_mie_ff;

assign csr2exu_mstatus_mie_up_o = csr_mstatus_upd | csr_mie_upd | e_mret;

// New PC multiplexer
`ifndef YCR_MTVEC_MODE_EN
assign csr2exu_new_pc_o = (exu2csr_mret_instr_i & ~exu2csr_take_irq_i)
                        ? csr_mepc
                        : {csr_mtvec_base, YCR_CSR_MTVEC_BASE_ZERO_BITS'(0)};
`else // YCR_MTVEC_MODE_EN
always_comb begin
    if (exu2csr_mret_instr_i & ~exu2csr_take_irq_i) begin
        csr2exu_new_pc_o  = csr_mepc;
    end else begin
        if (csr_mtvec_mode_vect) begin
            case (1'b1)
                exu2csr_take_exc_i: csr2exu_new_pc_o = {csr_mtvec_base, YCR_CSR_MTVEC_BASE_ZERO_BITS'(0)};
                csr_eirq_pnd_en   : csr2exu_new_pc_o = {csr_mtvec_base, YCR_EXC_CODE_IRQ_M_EXTERNAL, 2'd0};
                csr_sirq_pnd_en   : csr2exu_new_pc_o = {csr_mtvec_base, YCR_EXC_CODE_IRQ_M_SOFTWARE, 2'd0};
                csr_tirq_pnd_en   : csr2exu_new_pc_o = {csr_mtvec_base, YCR_EXC_CODE_IRQ_M_TIMER, 2'd0};
                default           : csr2exu_new_pc_o = {csr_mtvec_base, YCR_CSR_MTVEC_BASE_ZERO_BITS'(0)};
            endcase
        end else begin // direct mode
            csr2exu_new_pc_o = {csr_mtvec_base, YCR_CSR_MTVEC_BASE_ZERO_BITS'(0)};
        end
    end
end
`endif // YCR_MTVEC_MODE_EN

`ifdef YCR_IPIC_EN
//------------------------------------------------------------------------------
// CSR <-> IPIC interface
//------------------------------------------------------------------------------

assign csr_ipic_req     = csr2ipic_r_req_o | csr2ipic_w_req_o;
assign csr2ipic_addr_o  = csr_ipic_req     ? exu2csr_rw_addr_i[2:0] : '0;
assign csr2ipic_wdata_o = csr2ipic_w_req_o ? exu2csr_w_data_i       : '0;
`endif // YCR_IPIC_EN

`ifdef YCR_DBG_EN
//------------------------------------------------------------------------------
// CSR <-> HDU interface
//------------------------------------------------------------------------------

assign csr2hdu_req_o   = csr_hdu_req & exu_req_no_exc;
assign csr2hdu_cmd_o   = exu2csr_w_cmd_i;
assign csr2hdu_addr_o  = exu2csr_rw_addr_i[YCR_HDU_DEBUGCSR_ADDR_WIDTH-1:0];
assign csr2hdu_wdata_o = exu2csr_w_data_i;
`endif // YCR_DBG_EN

`ifdef YCR_TDU_EN
//------------------------------------------------------------------------------
// CSR <-> TDU interface
//------------------------------------------------------------------------------

assign csr2tdu_req_o   = csr_brkm_req & exu_req_no_exc;
assign csr2tdu_cmd_o   = exu2csr_w_cmd_i;
assign csr2tdu_addr_o  = exu2csr_rw_addr_i[YCR_CSR_ADDR_TDU_OFFS_W-1:0];
assign csr2tdu_wdata_o = exu2csr_w_data_i;
`endif // YCR_TDU_EN

`ifdef YCR_TRGT_SIMULATION
//------------------------------------------------------------------------------
// Assertions
//------------------------------------------------------------------------------

// X checks

YCR_SVA_CSR_XCHECK_CTRL : assert property (
    @(negedge clk) disable iff (~rst_n)
    !$isunknown({exu2csr_r_req_i, exu2csr_w_req_i, exu2csr_take_irq_i, exu2csr_take_exc_i, exu2csr_mret_update_i
`ifndef YCR_CSR_REDUCED_CNT
    , exu2csr_instret_no_exc_i
`endif // YCR_CSR_REDUCED_CNT
    })
    ) else $error("CSR Error: unknown control values");

YCR_SVA_CSR_XCHECK_READ : assert property (
    @(negedge clk) disable iff (~rst_n)
    exu2csr_r_req_i |-> !$isunknown({exu2csr_rw_addr_i, csr2exu_r_data_o, csr2exu_rw_exc_o})
    ) else $error("CSR Error: unknown control values");

YCR_SVA_CSR_XCHECK_WRITE : assert property (
    @(negedge clk) disable iff (~rst_n)
    exu2csr_w_req_i |-> !$isunknown({exu2csr_rw_addr_i, exu2csr_w_cmd_i, exu2csr_w_data_i, csr2exu_rw_exc_o})
    ) else $error("CSR Error: unknown control values");

`ifdef YCR_IPIC_EN
YCR_SVA_CSR_XCHECK_READ_IPIC : assert property (
    @(negedge clk) disable iff (~rst_n)
    csr2ipic_r_req_o |-> !$isunknown({csr2ipic_addr_o, ipic2csr_rdata_i})
    ) else $error("CSR Error: unknown control values");

YCR_SVA_CSR_XCHECK_WRITE_IPIC : assert property (
    @(negedge clk) disable iff (~rst_n)
    csr2ipic_w_req_o |-> !$isunknown({csr2ipic_addr_o, csr2ipic_wdata_o})
    ) else $error("CSR Error: unknown control values");
`endif // YCR_IPIC_EN

// Behavior checks

`ifndef VERILATOR
YCR_SVA_CSR_MRET : assert property (
    @(negedge clk) disable iff (~rst_n)
    e_mret |=> ($stable(csr_mepc_ff) & $stable(csr_mtval_ff))
    ) else $error("CSR Error: MRET wrong behavior");

YCR_SVA_CSR_MRET_IRQ : assert property (
    @(negedge clk) disable iff (~rst_n)
    (exu2csr_mret_instr_i & e_irq)
    |=> ($stable(csr_mepc_ff) & (exu2csr_pc_curr_i != csr_mepc))
    ) else $error("CSR Error: MRET+IRQ wrong behavior");

YCR_SVA_CSR_EXC_IRQ : assert property (
    @(negedge clk) disable iff (~rst_n)
    (exu2csr_take_exc_i & exu2csr_take_irq_i
`ifdef YCR_DBG_EN
    & ~hdu2csr_no_commit_i
`endif
    ) |=>
    (~csr_mstatus_mie_ff & (~csr_mcause_i_ff)
    & (exu2csr_pc_curr_i=={csr_mtvec_base, YCR_CSR_MTVEC_BASE_ZERO_BITS'(0)}))
    ) else $error("CSR Error: wrong EXC+IRQ");
`endif // VERILATOR
YCR_SVA_CSR_EVENTS : assert property (
    @(negedge clk) disable iff (~rst_n)
    $onehot0({e_irq, e_exc, e_mret})
    ) else $error("CSR Error: more than one event at a time");

YCR_SVA_CSR_RW_EXC : assert property (
    @(negedge clk) disable iff (~rst_n)
    csr2exu_rw_exc_o |-> (exu2csr_w_req_i | exu2csr_r_req_i)
    ) else $error("CSR Error: impossible exception");

`ifndef VERILATOR
YCR_SVA_CSR_MSTATUS_MIE_UP : assert property (
    @(negedge clk) disable iff (~rst_n)
    csr2exu_mstatus_mie_up_o |=> ~csr2exu_mstatus_mie_up_o
    ) else $error("CSR Error: csr2exu_mstatus_mie_up_o can only be high for one mcycle");
`endif // VERILATOR

`ifndef YCR_CSR_REDUCED_CNT

`ifndef VERILATOR
YCR_SVA_CSR_CYCLE_INC : assert property (
    @(
`ifndef YCR_CLKCTRL_EN
negedge clk
`else // YCR_CLKCTRL_EN
negedge clk_alw_on
`endif // YCR_CLKCTRL_EN
    ) disable iff (~rst_n)
    (~|csr_mcycle_upd) |=>
`ifdef YCR_MCOUNTEN_EN
    ($past(csr_mcounten_cy_ff) ? (csr_mcycle == $past(csr_mcycle + 1'b1)) : $stable(csr_mcycle))
`else //YCR_MCOUNTEN_EN
    (csr_mcycle == $past(csr_mcycle + 1'b1))
`endif // YCR_MCOUNTEN_EN
    ) else $error("CSR Error: CYCLE increment wrong behavior");

YCR_SVA_CSR_INSTRET_INC : assert property (
    @(negedge clk) disable iff (~rst_n)
    (exu2csr_instret_no_exc_i & ~|csr_minstret_upd) |=>
`ifdef YCR_MCOUNTEN_EN
    ($past(csr_mcounten_ir_ff) ? (csr_minstret == $past(csr_minstret + 1'b1)) : $stable(csr_minstret))
`else //YCR_MCOUNTEN_EN
    (csr_minstret == $past(csr_minstret + 1'b1))
`endif // YCR_MCOUNTEN_EN
    ) else $error("CSR Error: INSTRET increment wrong behavior");
`endif
YCR_SVA_CSR_CYCLE_INSTRET_UP : assert property (
    @(negedge clk) disable iff (~rst_n)
    ~(&csr_minstret_upd | &csr_mcycle_upd)
    ) else $error("CSR Error: INSTRET/CYCLE up illegal value");

`endif // YCR_CSR_REDUCED_CNT

`endif // YCR_TRGT_SIMULATION

endmodule : ycr_pipe_csr
