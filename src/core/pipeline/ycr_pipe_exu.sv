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
////  yifive Execution Unit (EXU)                                         ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     Execution Unit (EXU)                                             ////
////                                                                      ////
//// Functionality:                                                       ////
//// - Performs instructions execution:                                   ////
////   - Prevents instructions from execution if the HART is in WFI or    ////
//       Debug Halted state                                               ////
////   - Fetches operands for IALU                                        ////
////   - Calculates operation results via IALU                            ////
////   - Stores IALU results in MPRF                                      ////
////   - Performs LOAD/STORE operations via LSU                           ////
//// - Handles exceptions:                                                ////
////   - Generates exception request                                      ////
////   - Encodes exception code                                           ////
////   - Calculates exception trap value                                  ////
//// - Controls WFI instruction execution                                 ////
//// - Calculates PC value:                                               ////
////   - Initializes PC on reset                                          ////
////   - Stores the current PC value                                      ////
////   - Calculates a New PC value and generates a New PC request to IFU  ////
////                                                                      ////
//// Structure:                                                           ////
//// - Instruction queue                                                  ////
//// - Integer Arithmetic Logic Unit (IALU)                               ////
//// - Exceptions logic                                                   ////
//// - WFI logic                                                          ////
//// - Program Counter logic                                              ////
//// - Load-Store Unit (LSU)                                              ////
//// - EXU status logic                                                   ////
//// - EXU <-> MPRF i/f                                                   ////
//// - EXU <-> CSR i/f                                                    ////
//// - EXU <-> TDU i/f                                                    ////
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
`include "ycr_arch_types.svh"
`include "ycr_memif.svh"
`include "ycr_riscv_isa_decoding.svh"
`include "ycr_csr.svh"

`ifdef YCR_DBG_EN
 `include "ycr_hdu.svh"
`endif // YCR_DBG_EN

`ifdef YCR_TDU_EN
 `include "ycr_tdu.svh"
`endif // YCR_TDU_EN

module ycr_pipe_exu (
    // Common
    input   logic                               rst_n,                      // EXU reset
    input   logic                               clk,                        // Gated EXU clock
`ifdef YCR_CLKCTRL_EN
    input   logic                               clk_alw_on,                 // Not-gated EXU clock
    input   logic                               clk_pipe_en,                // EXU clock enabled flag
`endif // YCR_CLKCTRL_EN

    // EXU <-> IDU interface
    input   logic                               idu2exu_req_i,              // Request form IDU to EXU
    output  logic                               exu2idu_rdy_o,              // EXU ready for new data from IDU
    input   type_ycr_exu_cmd_s                 idu2exu_cmd_i,              // EXU command
    input   logic                               idu2exu_use_rs1_i,          // Clock gating on rs1_addr field
    input   logic                               idu2exu_use_rs2_i,          // Clock gating on rs2_addr field
`ifndef YCR_NO_EXE_STAGE
    input   logic                               idu2exu_use_rd_i,           // Clock gating on rd_addr field
    input   logic                               idu2exu_use_imm_i,          // Clock gating on imm field
`endif // YCR_NO_EXE_STAGE

    // EXU <-> MPRF interface
    output  logic [`YCR_MPRF_AWIDTH-1:0]       exu2mprf_rs1_addr_o,        // MPRF rs1 read address
    input   logic [`YCR_XLEN-1:0]              mprf2exu_rs1_data_i,        // MPRF rs1 read data
    output  logic [`YCR_MPRF_AWIDTH-1:0]       exu2mprf_rs2_addr_o,        // MPRF rs2 read address
    input   logic [`YCR_XLEN-1:0]              mprf2exu_rs2_data_i,        // MPRF rs2 read data
    output  logic                               exu2mprf_w_req_o,           // MPRF write request
    output  logic [`YCR_MPRF_AWIDTH-1:0]       exu2mprf_rd_addr_o,         // MPRF rd write address
    output  logic [`YCR_XLEN-1:0]              exu2mprf_rd_data_o,         // MPRF rd write data

    // EXU <-> CSR read/write interface
    output  logic [YCR_CSR_ADDR_WIDTH-1:0]     exu2csr_rw_addr_o,          // CSR read/write address
    output  logic                               exu2csr_r_req_o,            // CSR read request
    input   logic [`YCR_XLEN-1:0]              csr2exu_r_data_i,           // CSR read data
    output  logic                               exu2csr_w_req_o,            // CSR write request
    output  type_ycr_csr_cmd_sel_e             exu2csr_w_cmd_o,            // CSR write command
    output  logic [`YCR_XLEN-1:0]              exu2csr_w_data_o,           // CSR write data
    input   logic                               csr2exu_rw_exc_i,           // CSR read/write access exception

    // EXU <-> CSR events interface
    output  logic                               exu2csr_take_irq_o,         // Take IRQ trap
    output  logic                               exu2csr_take_exc_o,         // Take exception trap
    output  logic                               exu2csr_mret_update_o,      // MRET update CSR
    output  logic                               exu2csr_mret_instr_o,       // MRET instruction
    output  logic [YCR_EXC_CODE_WIDTH_E-1:0]   exu2csr_exc_code_o,         // Exception code (see ycr_arch_types.svh) - cp.7
    output  logic [`YCR_XLEN-1:0]              exu2csr_trap_val_o,         // Trap value
    input   logic [`YCR_XLEN-1:0]              csr2exu_new_pc_i,           // Exception/IRQ/MRET new PC
    input   logic                               csr2exu_irq_i,              // IRQ request
    input   logic                               csr2exu_ip_ie_i,            // Some IRQ pending and locally enabled
    input   logic                               csr2exu_mstatus_mie_up_i,   // MSTATUS or MIE update in the current cycle

    // EXU <-> DMEM interface
    output  logic                               exu2dmem_req_o,             // Data memory request
    output  logic                               exu2dmem_cmd_o,             // Data memory command - cp.7
    output  logic [1:0]                         exu2dmem_width_o,           // Data memory width
    output  logic [`YCR_DMEM_AWIDTH-1:0]       exu2dmem_addr_o,            // Data memory address
    output  logic [`YCR_DMEM_DWIDTH-1:0]       exu2dmem_wdata_o,           // Data memory write data
    input   logic                               dmem2exu_req_ack_i,         // Data memory request acknowledge
    input   logic [`YCR_DMEM_DWIDTH-1:0]       dmem2exu_rdata_i,           // Data memory read data
    input   logic [1:0]                         dmem2exu_resp_i,            // Data memory response - cp.7

    // EXU control
    output  logic                               exu2pipe_exc_req_o,         // Exception on last instruction
    output  logic                               exu2pipe_brkpt_o,           // Software Breakpoint (EBREAK)
    output  logic                               exu2pipe_init_pc_o,         // Reset exit
    output  logic                               exu2pipe_wfi_run2halt_o,    // Transition to WFI halted state
    output  logic                               exu2pipe_instret_o,         // Instruction retired (with or without exception)
    output  logic                               exu2csr_instret_no_exc_o,   // Instruction retired (without exception)
    output  logic                               exu2pipe_exu_busy_o,        // EXU busy

`ifdef YCR_DBG_EN
    // EXU <-> HDU interface
    input   logic                               hdu2exu_no_commit_i,        // Forbid instruction commitment
    input   logic                               hdu2exu_irq_dsbl_i,         // Disable IRQ
    input   logic                               hdu2exu_pc_advmt_dsbl_i,    // Forbid PC advancement
    input   logic                               hdu2exu_dmode_sstep_en_i,   // Enable single-step
    input   logic                               hdu2exu_pbuf_fetch_i,       // Take instructions from Program Buffer
    input   logic                               hdu2exu_dbg_halted_i,       // Debug halted state
    input   logic                               hdu2exu_dbg_run2halt_i,     // Transition to debug halted state
    input   logic                               hdu2exu_dbg_halt2run_i,     // Transition to run state
    input   logic                               hdu2exu_dbg_run_start_i,    // First cycle of run state
    input   logic [`YCR_XLEN-1:0]              hdu2exu_dbg_new_pc_i,       // New PC as starting point for HART Resume
`endif // YCR_DBG_EN

`ifdef YCR_TDU_EN
    // EXU <-> TDU interface
    output type_ycr_brkm_instr_mon_s           exu2tdu_imon_o,             // Instruction monitor
    input  logic [YCR_TDU_ALLTRIG_NUM-1:0]     tdu2exu_ibrkpt_match_i,     // Instruction breakpoint(s) match
    input  logic                                tdu2exu_ibrkpt_exc_req_i,   // Instruction breakpoint exception
    output type_ycr_brkm_lsu_mon_s             lsu2tdu_dmon_o,             // Data monitor
    input  logic                                tdu2lsu_ibrkpt_exc_req_i,   // Instruction breakpoint exception
    input  logic [YCR_TDU_MTRIG_NUM-1:0]       tdu2lsu_dbrkpt_match_i,     // Data breakpoint(s) match
    input  logic                                tdu2lsu_dbrkpt_exc_req_i,   // Data breakpoint exception
    output logic [YCR_TDU_ALLTRIG_NUM-1:0]     exu2tdu_ibrkpt_ret_o,       // Instruction with breakpoint flag retire
    output logic                                exu2hdu_ibrkpt_hw_o,        // Hardware breakpoint on current instruction
`endif // YCR_TDU_EN

    // PC interface
`ifdef YCR_CLKCTRL_EN
    output  logic                               exu2pipe_wfi_halted_o,      // WFI halted state
`endif // YCR_CLKCTRL_EN
    output  logic [`YCR_XLEN-1:0]              exu2pipe_pc_curr_o,         // Current PC
    output  logic [`YCR_XLEN-1:0]              exu2csr_pc_next_o,          // Next PC
    output  logic                               exu2ifu_pc_new_req_o,       // New PC request
    output  logic [`YCR_XLEN-1:0]              exu2ifu_pc_new_o            // New PC data
);

//------------------------------------------------------------------------------
// Local parameters declaration
//------------------------------------------------------------------------------

localparam YCR_JUMP_MASK = `YCR_XLEN'hFFFF_FFFE;

//------------------------------------------------------------------------------
// Local types declaration
//------------------------------------------------------------------------------

//typedef enum logic {
parameter     YCR_CSR_INIT = 1'b0;
parameter     YCR_CSR_RDY  = 1'b1;
//} ycr_csr_access_e;

//------------------------------------------------------------------------------
// Local signals declaration
//------------------------------------------------------------------------------

// Instruction queue signals
//------------------------------------------------------------------------------
logic                               exu_queue_vd;
type_ycr_exu_cmd_s                 exu_queue;
logic                               exu_queue_barrier;

`ifdef YCR_DBG_EN
logic                               dbg_run_start_npbuf;
`endif // YCR_DBG_EN
logic                               exu_queue_en;
logic [`YCR_XLEN-1:0]              exu_illegal_instr;

`ifndef YCR_NO_EXE_STAGE
logic                               idu2exu_use_rs1_ff;
logic                               idu2exu_use_rs2_ff;

// EXU queue valid flag register signals
logic                               exu_queue_vd_upd;
logic                               exu_queue_vd_ff;
logic                               exu_queue_vd_next;
`endif // YCR_NO_EXE_STAGE

// IALU signals
//------------------------------------------------------------------------------
`ifdef YCR_RVM_EXT
logic                               ialu_rdy;
logic                               ialu_vd;
`endif // YCR_RVM_EXT
logic [`YCR_XLEN-1:0]              ialu_main_op1;
logic [`YCR_XLEN-1:0]              ialu_main_op2;
logic [`YCR_XLEN-1:0]              ialu_main_res;
logic [`YCR_XLEN-1:0]              ialu_addr_op1;
logic [`YCR_XLEN-1:0]              ialu_addr_op2;
logic [`YCR_XLEN-1:0]              ialu_addr_res;
logic                               ialu_cmp;

// Exceptions signals
//------------------------------------------------------------------------------
logic                               exu_exc_req;
`ifdef YCR_DBG_EN
logic                               exu_exc_req_ff;
logic                               exu_exc_req_next;
`endif // YCR_DBG_EN
logic [YCR_EXC_CODE_WIDTH_E-1:0]   exc_code; // cp.7
logic [`YCR_XLEN-1:0]              exc_trap_val;
logic                               instr_fault_rvi_hi;

// WFI signals
//------------------------------------------------------------------------------
// WFI control signals
logic                               wfi_halt_cond;
logic                               wfi_run_req;
logic                               wfi_halt_req;

// WFI Run Start register
logic                               wfi_run_start_ff;
logic                               wfi_run_start_next;

// WFI halted register
logic                               wfi_halted_upd;
logic                               wfi_halted_ff;
logic                               wfi_halted_next;

// PC signals
//------------------------------------------------------------------------------
logic [3:0]                         init_pc_v;
logic                               init_pc;
logic [`YCR_XLEN-1:0]              inc_pc;

logic                               branch_taken;
logic                               jb_taken;
logic [`YCR_XLEN-1:0]              jb_new_pc;
`ifndef YCR_RVC_EXT
logic                               jb_misalign;
`endif

// Current PC register
logic                               pc_curr_upd;
logic [`YCR_XLEN-1:0]              pc_curr_ff;
logic [`YCR_XLEN-1:0]              pc_curr_next;

// LSU signals
//------------------------------------------------------------------------------
logic                               lsu_req;
logic                               lsu_rdy;
logic [`YCR_XLEN-1:0]              lsu_l_data;
logic                               lsu_exc_req;
logic [YCR_EXC_CODE_WIDTH_E-1:0]   lsu_exc_code; // cp.7

// EXU status signals
//------------------------------------------------------------------------------
logic                               exu_rdy;

// MPRF signals
//------------------------------------------------------------------------------
logic                               mprf_rs1_req;
logic                               mprf_rs2_req;

logic   [`YCR_MPRF_AWIDTH-1:0]     mprf_rs1_addr;
logic   [`YCR_MPRF_AWIDTH-1:0]     mprf_rs2_addr;

// CSR signals
//------------------------------------------------------------------------------
// CSR access register
logic                               csr_access_ff;
logic                               csr_access_next;
logic                               csr_access_init;

//------------------------------------------------------------------------------
// Instruction execution queue
//------------------------------------------------------------------------------
//
 // Instruction execution queue consists of the following functional units:
 // - EXU queue control logic
 // - EXU queue valid flag register
 // - EXU queue register
 // - EXU queue status logic
//

`ifdef YCR_DBG_EN
assign dbg_run_start_npbuf = hdu2exu_dbg_run_start_i & ~hdu2exu_pbuf_fetch_i;
`endif // YCR_DBG_EN

`ifndef YCR_NO_EXE_STAGE

// EXU queue control logic
//------------------------------------------------------------------------------

assign exu_queue_barrier = wfi_halted_ff | wfi_halt_req | wfi_run_start_ff
`ifdef YCR_DBG_EN
                         | hdu2exu_dbg_halted_i  | hdu2exu_dbg_run2halt_i
                         | dbg_run_start_npbuf
`endif // YCR_DBG_EN
;

assign exu_queue_en = exu2idu_rdy_o & idu2exu_req_i;

// EXU queue valid flag register
//------------------------------------------------------------------------------

assign exu_queue_vd_upd = exu_queue_barrier | exu_rdy;

always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        exu_queue_vd_ff <= 1'b0;
    end else if (exu_queue_vd_upd) begin
        exu_queue_vd_ff <= exu_queue_vd_next;
    end
end

assign exu_queue_vd_next = ~exu_queue_barrier & idu2exu_req_i & ~exu2ifu_pc_new_req_o;
assign exu_queue_vd      = exu_queue_vd_ff;

// EXU queue register
//------------------------------------------------------------------------------

always_ff @(posedge clk) begin
    if (exu_queue_en) begin
        exu_queue.instr_rvc      <= idu2exu_cmd_i.instr_rvc;
        exu_queue.ialu_op        <= idu2exu_cmd_i.ialu_op;
        exu_queue.ialu_cmd       <= idu2exu_cmd_i.ialu_cmd;
        exu_queue.sum2_op        <= idu2exu_cmd_i.sum2_op;
        exu_queue.lsu_cmd        <= idu2exu_cmd_i.lsu_cmd;
        exu_queue.csr_op         <= idu2exu_cmd_i.csr_op;
        exu_queue.csr_cmd        <= idu2exu_cmd_i.csr_cmd;
        exu_queue.rd_wb_sel      <= idu2exu_cmd_i.rd_wb_sel;
        exu_queue.jump_req       <= idu2exu_cmd_i.jump_req;
        exu_queue.branch_req     <= idu2exu_cmd_i.branch_req;
        exu_queue.mret_req       <= idu2exu_cmd_i.mret_req;
        exu_queue.fencei_req     <= idu2exu_cmd_i.fencei_req;
        exu_queue.wfi_req        <= idu2exu_cmd_i.wfi_req;
        exu_queue.exc_req        <= idu2exu_cmd_i.exc_req;
        exu_queue.exc_code       <= idu2exu_cmd_i.exc_code;
        idu2exu_use_rs1_ff       <= idu2exu_use_rs1_i;
        idu2exu_use_rs2_ff       <= idu2exu_use_rs2_i;
        if (idu2exu_use_rs1_i) begin
            exu_queue.rs1_addr   <= idu2exu_cmd_i.rs1_addr;
        end
        if (idu2exu_use_rs2_i) begin
            exu_queue.rs2_addr   <= idu2exu_cmd_i.rs2_addr;
        end
        if (idu2exu_use_rd_i)  begin
            exu_queue.rd_addr    <= idu2exu_cmd_i.rd_addr;
        end
        if (idu2exu_use_imm_i) begin
            exu_queue.imm        <= idu2exu_cmd_i.imm;
        end
    end
end

`else // ~YCR_NO_EXE_STAGE

assign exu_queue_barrier = wfi_halted_ff | wfi_run_start_ff
`ifdef YCR_DBG_EN
                         | hdu2exu_dbg_halted_i  | dbg_run_start_npbuf
`endif // YCR_DBG_EN
;
assign exu_queue_vd  = idu2exu_req_i & ~exu_queue_barrier;
assign exu_queue     = idu2exu_cmd_i;

`endif // ~YCR_NO_EXE_STAGE

//------------------------------------------------------------------------------
// Integer Arithmetic Logic Unit (IALU)
//------------------------------------------------------------------------------
 //
 // Functionality:
 // - Performs addition/subtraction and arithmetic and branch comparisons
 // - Performs logical operations (AND(I), OR(I), XOR(I))
 // - Performs address calculation for branch, jump, DMEM load and store and AUIPC
 //   instructions
 // - Performs shift operations
 // - Performs MUL/DIV operations
 //
//------------------------------------------------------------------------------

// IALU main operands fetch
//------------------------------------------------------------------------------

`ifdef YCR_RVM_EXT
assign ialu_vd  = exu_queue_vd & (exu_queue.ialu_cmd != YCR_IALU_CMD_NONE)
`ifdef YCR_TDU_EN
                & ~tdu2exu_ibrkpt_exc_req_i
`endif // YCR_TDU_EN
                ;
`endif // YCR_RVM_EXT

always_comb begin
`ifdef YCR_RVM_EXT
    if (~ialu_vd) begin
        ialu_main_op1 = '0;
        ialu_main_op2 = '0;
    end else begin
`endif // YCR_RVM_EXT
        if (exu_queue.ialu_op == YCR_IALU_OP_REG_REG) begin
            ialu_main_op1 = mprf2exu_rs1_data_i;
            ialu_main_op2 = mprf2exu_rs2_data_i;
        end else begin
            ialu_main_op1 = mprf2exu_rs1_data_i;
            ialu_main_op2 = exu_queue.imm;
        end
`ifdef YCR_RVM_EXT
    end
`endif // YCR_RVM_EXT
end

// IALU address operands fetch
//------------------------------------------------------------------------------

always_comb begin
    if (exu_queue.sum2_op == YCR_SUM2_OP_REG_IMM) begin
        ialu_addr_op1 = mprf2exu_rs1_data_i;
        ialu_addr_op2 = exu_queue.imm;
    end else begin
        ialu_addr_op1 = pc_curr_ff;
        ialu_addr_op2 = exu_queue.imm;
    end
end

// IALU module instantiation
//------------------------------------------------------------------------------

ycr_pipe_ialu i_ialu(
`ifdef YCR_RVM_EXT
    // Common
    .clk                        (clk               ),
    .rst_n                      (rst_n             ),
    .exu2ialu_rvm_cmd_vd_i      (ialu_vd           ),
    .ialu2exu_rvm_res_rdy_o     (ialu_rdy          ),
`endif // YCR_RVM_EXT

    // IALU
    .exu2ialu_main_op1_i        (ialu_main_op1     ),
    .exu2ialu_main_op2_i        (ialu_main_op2     ),
    .exu2ialu_cmd_i             (exu_queue.ialu_cmd),
    .ialu2exu_main_res_o        (ialu_main_res     ),
    .ialu2exu_cmp_res_o         (ialu_cmp          ),

    // Address adder signals
    .exu2ialu_addr_op1_i        (ialu_addr_op1     ),
    .exu2ialu_addr_op2_i        (ialu_addr_op2     ),
    .ialu2exu_addr_res_o        (ialu_addr_res     )
);

//------------------------------------------------------------------------------
// Exceptions logic
//------------------------------------------------------------------------------
//
 // Exceptions logic consists of the following functional units:
 // - Exception request logic
 // - Exception code encoder
 // - Exception trap value multiplexer
 //
//

`ifndef YCR_RVC_EXT
assign jb_misalign  = exu_queue_vd  & jb_taken & |jb_new_pc[1:0];
`endif // ~YCR_RVC_EXT

// Exception request
assign exu_exc_req  = exu_queue_vd & (exu_queue.exc_req | lsu_exc_req
                                                        | csr2exu_rw_exc_i
`ifndef YCR_RVC_EXT
                                                        | jb_misalign
`endif // ~YCR_RVC_EXT
`ifdef YCR_TDU_EN
                                                        | exu2hdu_ibrkpt_hw_o
`endif // YCR_TDU_EN
                                                        );

// EXU exception request register
//------------------------------------------------------------------------------

`ifdef YCR_DBG_EN

always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        exu_exc_req_ff <= 1'b0;
    end else begin
        exu_exc_req_ff <= exu_exc_req_next;
    end
end

assign exu_exc_req_next = hdu2exu_dbg_halt2run_i ? 1'b0 : exu_exc_req;
`endif // YCR_DBG_EN

// Exception code encoder
//------------------------------------------------------------------------------

always_comb begin
    case (1'b1)
`ifdef YCR_TDU_EN
        exu2hdu_ibrkpt_hw_o: exc_code = YCR_EXC_CODE_BREAKPOINT;
`endif // YCR_TDU_EN
        exu_queue.exc_req  : exc_code = exu_queue.exc_code;
        lsu_exc_req        : exc_code = lsu_exc_code;
        csr2exu_rw_exc_i   : exc_code = YCR_EXC_CODE_ILLEGAL_INSTR;
`ifndef YCR_RVC_EXT
        jb_misalign        : exc_code = YCR_EXC_CODE_INSTR_MISALIGN;
`endif // ~YCR_RVC_EXT
        default            : exc_code = YCR_EXC_CODE_ECALL_M;
    endcase // 1'b1
end

// Exception trap value multiplexer
//------------------------------------------------------------------------------

assign instr_fault_rvi_hi = exu_queue.instr_rvc;
assign exu_illegal_instr = {exu2csr_rw_addr_o,          // CSR address
                            5'(exu_queue.rs1_addr),     // rs1 / zimm
                            exu_queue.imm[14:12],       // funct3
                            5'(exu_queue.rd_addr),      // rd
                            YCR_OPCODE_SYSTEM,
                            YCR_INSTR_RVI
                           };

// If Instruction Access Fault occurred on high part of RVI instruction trap
// value is set to point on the high part of the instruction (inc_pc=pc+2)
always_comb begin
    case (exc_code)
`ifndef YCR_RVC_EXT
        YCR_EXC_CODE_INSTR_MISALIGN    : exc_trap_val = jb_new_pc;
`endif // YCR_RVC_EXT
        YCR_EXC_CODE_INSTR_ACCESS_FAULT: exc_trap_val = instr_fault_rvi_hi
                                                       ? inc_pc
                                                       : pc_curr_ff;
`ifdef YCR_MTVAL_ILLEGAL_INSTR_EN
        YCR_EXC_CODE_ILLEGAL_INSTR     : exc_trap_val = exu_queue.exc_req
                                                       ? exu_queue.imm
                                                       : exu_illegal_instr;
`else // YCR_MTVAL_ILLEGAL_INSTR_EN
        YCR_EXC_CODE_ILLEGAL_INSTR     : exc_trap_val = '0;
`endif // YCR_MTVAL_ILLEGAL_INSTR_EN
`ifdef YCR_TDU_EN
        YCR_EXC_CODE_BREAKPOINT: begin
            case (1'b1)
                tdu2exu_ibrkpt_exc_req_i: exc_trap_val = pc_curr_ff;
                tdu2lsu_dbrkpt_exc_req_i: exc_trap_val = ialu_addr_res;
                default                 : exc_trap_val = '0;
            endcase
        end
`endif // YCR_TDU_EN
        YCR_EXC_CODE_LD_ADDR_MISALIGN,
        YCR_EXC_CODE_LD_ACCESS_FAULT,
        YCR_EXC_CODE_ST_ADDR_MISALIGN,
        YCR_EXC_CODE_ST_ACCESS_FAULT   : exc_trap_val = ialu_addr_res;
        default                         : exc_trap_val = '0;
    endcase // exc_code
end

//------------------------------------------------------------------------------
// WFI logic
//------------------------------------------------------------------------------
//
 // Wait for interrupt (WFI) logic consists of the following functional units:
 // - WFI control logic
 // - WFI Run Start register
 // - WFI Halted flag register
 // - WFI status signals
//

// WFI control logic
//------------------------------------------------------------------------------

assign wfi_halt_cond = ~csr2exu_ip_ie_i
                     & ((exu_queue_vd & exu_queue.wfi_req) | wfi_run_start_ff)
`ifdef YCR_DBG_EN
                     & ~hdu2exu_no_commit_i & ~hdu2exu_dmode_sstep_en_i & ~hdu2exu_dbg_run2halt_i
`endif // YCR_DBG_EN
                     ;
assign wfi_halt_req  = ~wfi_halted_ff & wfi_halt_cond;

// HART will exit WFI halted state if the event that causes the HART to resume
// execution occurs even if it doesn't cause an interrupt to be taken
assign wfi_run_req   = wfi_halted_ff  & (csr2exu_ip_ie_i
`ifdef YCR_DBG_EN
                                      | hdu2exu_dbg_halt2run_i
`endif // YCR_DBG_EN
                                      );

// WFI Run Start register
//------------------------------------------------------------------------------

`ifndef YCR_CLKCTRL_EN
always_ff @(negedge rst_n, posedge clk) begin
`else // YCR_CLKCTRL_EN
always_ff @(negedge rst_n, posedge clk_alw_on) begin
`endif // YCR_CLKCTRL_EN
    if (~rst_n) begin
        wfi_run_start_ff <= 1'b0;
    end else begin
        wfi_run_start_ff <= wfi_run_start_next;
    end
end

assign wfi_run_start_next = wfi_halted_ff & csr2exu_ip_ie_i & ~exu2csr_take_irq_o;

// WFI halted flag register
//------------------------------------------------------------------------------

assign wfi_halted_upd = wfi_halt_req | wfi_run_req;

`ifndef YCR_CLKCTRL_EN
always_ff @(negedge rst_n, posedge clk) begin
`else // YCR_CLKCTRL_EN
always_ff @(negedge rst_n, posedge clk_alw_on) begin
`endif // YCR_CLKCTRL_EN
    if (~rst_n) begin
        wfi_halted_ff <= 1'b0;
    end else if (wfi_halted_upd) begin
        wfi_halted_ff <= wfi_halted_next;
    end
end

assign wfi_halted_next = wfi_halt_req | ~wfi_run_req;

// WFI status signals
//------------------------------------------------------------------------------

assign exu2pipe_wfi_run2halt_o = wfi_halt_req;
`ifdef YCR_CLKCTRL_EN
assign exu2pipe_wfi_halted_o   = wfi_halted_ff;
`endif // YCR_CLKCTRL_EN

//------------------------------------------------------------------------------
// Program Counter logic
//------------------------------------------------------------------------------
//
 // PC logic consists of the following functional units:
 // - PC initialization logic
 // - Current PC register
 // - New PC multiplexer

// PC initialization logic
//------------------------------------------------------------------------------
// Generates a New PC request to set PC to reset value

always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        init_pc_v <= '0;
    end else begin
        if (~&init_pc_v) begin
            init_pc_v <= {init_pc_v[2:0], 1'b1};
        end
    end
end

assign init_pc = ~init_pc_v[3] & init_pc_v[2];

// Current PC register
//------------------------------------------------------------------------------

assign pc_curr_upd = ((exu2pipe_instret_o | exu2csr_take_irq_o
`ifdef YCR_DBG_EN
                   | dbg_run_start_npbuf) & ( ~hdu2exu_pc_advmt_dsbl_i
                                            & ~hdu2exu_no_commit_i
`endif // YCR_DBG_EN
                   ));

always_ff @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
        pc_curr_ff <= YCR_RST_VECTOR;
    end else if (pc_curr_upd) begin
        pc_curr_ff <= pc_curr_next;
    end
end

`ifdef YCR_RVC_EXT
wire instr_rvc = exu_queue.instr_rvc;
assign inc_pc = pc_curr_ff + (exu_queue.instr_rvc ? `YCR_XLEN'd2 : `YCR_XLEN'd4);
`else // ~YCR_RVC_EXT
assign inc_pc = pc_curr_ff + `YCR_XLEN'd4;
`endif // ~YCR_RVC_EXT

assign pc_curr_next = exu2ifu_pc_new_req_o        ? exu2ifu_pc_new_o
                    : (inc_pc[6] ^ pc_curr_ff[6]) ? inc_pc
                                                  : {pc_curr_ff[`YCR_XLEN-1:6], inc_pc[5:0]};

// New PC multiplexer
//------------------------------------------------------------------------------
wire fencei_req = exu_queue.fencei_req;

always_comb begin
    case (1'b1)
        init_pc             : exu2ifu_pc_new_o = YCR_RST_VECTOR;
        exu2csr_take_exc_o,
        exu2csr_take_irq_o,
        exu2csr_mret_instr_o: exu2ifu_pc_new_o = csr2exu_new_pc_i;
`ifdef YCR_DBG_EN
        dbg_run_start_npbuf : exu2ifu_pc_new_o = hdu2exu_dbg_new_pc_i;
`endif // YCR_DBG_EN
        wfi_run_start_ff    : exu2ifu_pc_new_o = pc_curr_ff;
        fencei_req:           exu2ifu_pc_new_o = inc_pc;
        default             : exu2ifu_pc_new_o = ialu_addr_res & YCR_JUMP_MASK;
    endcase
end

assign exu2ifu_pc_new_req_o = init_pc                                        // reset
                            | exu2csr_take_irq_o
                            | exu2csr_take_exc_o
                            | (exu2csr_mret_instr_o & ~csr2exu_mstatus_mie_up_i)
                            | (exu_queue_vd & fencei_req)
                            | (wfi_run_start_ff
`ifdef YCR_CLKCTRL_EN
                            & clk_pipe_en
`endif // YCR_CLKCTRL_EN
                            )
`ifdef YCR_DBG_EN
                            | dbg_run_start_npbuf
`endif // YCR_DBG_EN
                            | (exu_queue_vd & jb_taken);

// Jump/branch signals
assign branch_taken = exu_queue.branch_req & ialu_cmp & ialu_rdy;
assign jb_taken     = exu_queue.jump_req | branch_taken;
assign jb_new_pc    = ialu_addr_res & YCR_JUMP_MASK;

// PC to be loaded on MRET from interrupt trap
assign exu2csr_pc_next_o  = ~exu_queue_vd ? pc_curr_ff
                          : jb_taken      ? jb_new_pc
                                          : inc_pc;
assign exu2pipe_pc_curr_o = pc_curr_ff;

//------------------------------------------------------------------------------
// Load/Store Unit (LSU)
//------------------------------------------------------------------------------
 //
 // Functionality:
 // - Performs load and store operations in Data Memory
 // - Generates DMEM address misalign and access fault exceptions
 // - Passes DMEM operations information to TDU and generates LSU breakpoint exception
 //
//------------------------------------------------------------------------------

assign lsu_req  = ((exu_queue.lsu_cmd != YCR_LSU_CMD_NONE) & exu_queue_vd);

ycr_pipe_lsu i_lsu(
    .rst_n                      (rst_n                   ),
    .clk                        (clk                     ),

    // EXU <-> LSU interface
    .exu2lsu_req_i              (lsu_req                 ),       // Request to LSU
    .exu2lsu_cmd_i              (exu_queue.lsu_cmd       ),       // LSU command
    .exu2lsu_addr_i             (ialu_addr_res           ),       // DMEM address
    .exu2lsu_sdata_i            (mprf2exu_rs2_data_i     ),       // Data for store to DMEM
    .lsu2exu_rdy_o              (lsu_rdy                 ),       // LSU ready
    .lsu2exu_ldata_o            (lsu_l_data              ),       // Loaded data form DMEM
    .lsu2exu_exc_o              (lsu_exc_req             ),       // LSU exception
    .lsu2exu_exc_code_o         (lsu_exc_code            ),       // LSU exception code

`ifdef YCR_TDU_EN
    // TDU <-> LSU interface
    .lsu2tdu_dmon_o             (lsu2tdu_dmon_o          ),
    .tdu2lsu_ibrkpt_exc_req_i   (tdu2lsu_ibrkpt_exc_req_i),
    .tdu2lsu_dbrkpt_exc_req_i   (tdu2lsu_dbrkpt_exc_req_i),
`endif // YCR_TDU_EN

    // Data memory interface
    .lsu2dmem_req_o             (exu2dmem_req_o          ),       // DMEM request
    .lsu2dmem_cmd_o             (exu2dmem_cmd_o          ),       // DMEM command
    .lsu2dmem_width_o           (exu2dmem_width_o        ),       // DMEM width
    .lsu2dmem_addr_o            (exu2dmem_addr_o         ),       // DMEM address
    .lsu2dmem_wdata_o           (exu2dmem_wdata_o        ),       // DMEM write data
    .dmem2lsu_req_ack_i         (dmem2exu_req_ack_i      ),       // DMEM request acknowledge
    .dmem2lsu_rdata_i           (dmem2exu_rdata_i        ),       // DMEM read data
    .dmem2lsu_resp_i            (dmem2exu_resp_i         )        // DMEM response
);

//------------------------------------------------------------------------------
// EXU status logic
//------------------------------------------------------------------------------

// EXU ready flag
always_comb begin
    case (1'b1)
        lsu_req                 : exu_rdy = lsu_rdy | lsu_exc_req;
`ifdef YCR_RVM_EXT
        ialu_vd                 : exu_rdy = ialu_rdy;
`endif // YCR_RVM_EXT
        csr2exu_mstatus_mie_up_i: exu_rdy = 1'b0;
        default                 : exu_rdy = 1'b1;
    endcase
end

assign exu2pipe_init_pc_o       = init_pc;
assign exu2idu_rdy_o            = exu_rdy & ~exu_queue_barrier;
assign exu2pipe_exu_busy_o      = exu_queue_vd & ~exu_rdy;
assign exu2pipe_instret_o       = exu_queue_vd & exu_rdy;
assign exu2csr_instret_no_exc_o = exu2pipe_instret_o & ~exu_exc_req;

// Exceptions
`ifdef YCR_DBG_EN
assign exu2pipe_exc_req_o  = exu_queue_vd ? exu_exc_req : exu_exc_req_ff;
`else // YCR_DBG_EN
assign exu2pipe_exc_req_o  = exu_exc_req;
`endif // YCR_DBG_EN

// Breakpoints
assign exu2pipe_brkpt_o    = exu_queue_vd & (exu_queue.exc_code == YCR_EXC_CODE_BREAKPOINT);
`ifdef YCR_TDU_EN
assign exu2hdu_ibrkpt_hw_o = tdu2exu_ibrkpt_exc_req_i | tdu2lsu_dbrkpt_exc_req_i;
`endif // YCR_TDU_EN

//------------------------------------------------------------------------------
// EXU <-> MPRF interface
//------------------------------------------------------------------------------

// Operands fetching stage
//------------------------------------------------------------------------------

`ifdef  YCR_NO_EXE_STAGE
assign mprf_rs1_req = exu_queue_vd & idu2exu_use_rs1_i;
assign mprf_rs2_req = exu_queue_vd & idu2exu_use_rs2_i;
`else // YCR_NO_EXE_STAGE
 `ifdef  YCR_MPRF_RAM
     assign mprf_rs1_req = exu_queue_en
                         ? (exu_queue_vd_next & idu2exu_use_rs1_i)
                         : (exu_queue_vd      & idu2exu_use_rs1_ff);
     assign mprf_rs2_req = exu_queue_en
                         ? (exu_queue_vd_next & idu2exu_use_rs2_i)
                         : (exu_queue_vd      & idu2exu_use_rs2_ff);
 `else // YCR_MPRF_RAM
    `ifdef  YCRC1_MPRF_STAGE // ADD FF Stage at MRPF
        assign mprf_rs1_req = exu_queue_en
                            ? (exu_queue_vd_next & idu2exu_use_rs1_i)
                            : (exu_queue_vd      & idu2exu_use_rs1_ff);
        assign mprf_rs2_req = exu_queue_en
                            ? (exu_queue_vd_next & idu2exu_use_rs2_i)
                            : (exu_queue_vd      & idu2exu_use_rs2_ff);

     `else
          assign mprf_rs1_req = exu_queue_vd & idu2exu_use_rs1_ff;
          assign mprf_rs2_req = exu_queue_vd & idu2exu_use_rs2_ff;
     `endif // YCR_MPRF_RAM
  `endif
`endif // YCR_NO_EXE_STAGE

// If exu_queue isn't enabled we need previous addresses and usage flags because
// RAM blocks read operation is SYNCHRONOUS
`ifdef YCR_MPRF_RAM
     assign mprf_rs1_addr = exu_queue_en ? idu2exu_cmd_i.rs1_addr : exu_queue.rs1_addr;
     assign mprf_rs2_addr = exu_queue_en ? idu2exu_cmd_i.rs2_addr : exu_queue.rs2_addr;
`else // YCR_MPRF_RAM
    `ifdef YCRC1_MPRF_STAGE
        assign mprf_rs1_addr = exu_queue_en ? idu2exu_cmd_i.rs1_addr : exu_queue.rs1_addr;
        assign mprf_rs2_addr = exu_queue_en ? idu2exu_cmd_i.rs2_addr : exu_queue.rs2_addr;
    `else
        assign mprf_rs1_addr = exu_queue.rs1_addr;
        assign mprf_rs2_addr = exu_queue.rs2_addr;
     `endif
`endif // YCR_MPRF_RAM

assign exu2mprf_rs1_addr_o = mprf_rs1_req ? `YCR_MPRF_AWIDTH'(mprf_rs1_addr) : '0;
assign exu2mprf_rs2_addr_o = mprf_rs2_req ? `YCR_MPRF_AWIDTH'(mprf_rs2_addr) : '0;

// Write back stage
//------------------------------------------------------------------------------

assign exu2mprf_w_req_o   = (exu_queue.rd_wb_sel != YCR_RD_WB_NONE) & exu_queue_vd & ~exu_exc_req
`ifdef YCR_DBG_EN
                          & ~hdu2exu_no_commit_i
`endif // YCR_DBG_EN
                          & ((exu_queue.rd_wb_sel == YCR_RD_WB_CSR) ? csr_access_init : exu_rdy);

assign exu2mprf_rd_addr_o = `YCR_MPRF_AWIDTH'(exu_queue.rd_addr);

// MRPF RD data multiplexer
always_comb begin
    case (exu_queue.rd_wb_sel)
        YCR_RD_WB_SUM2  : exu2mprf_rd_data_o = ialu_addr_res;
        YCR_RD_WB_IMM   : exu2mprf_rd_data_o = exu_queue.imm;
        YCR_RD_WB_INC_PC: exu2mprf_rd_data_o = inc_pc;
        YCR_RD_WB_LSU   : exu2mprf_rd_data_o = lsu_l_data;
        YCR_RD_WB_CSR   : exu2mprf_rd_data_o = csr2exu_r_data_i;
        default          : exu2mprf_rd_data_o = ialu_main_res;
    endcase
end

//------------------------------------------------------------------------------
// EXU <-> CSR interface
//------------------------------------------------------------------------------
//
 // EXU <-> CSR interface consists of the following functional units:
 // - CSR write/read interface
 // - CSR access FSM
 // - CSR events interface:
 //   - Exceptions signals
 //   - Interrupts signals
 //   - MRET signals
//

// CSRs write/read interface
//------------------------------------------------------------------------------

// CSR write/read request signals calculation
always_comb begin
    if (~exu_queue_vd
`ifdef YCR_TDU_EN
       | tdu2exu_ibrkpt_exc_req_i
`endif // YCR_TDU_EN
    ) begin
        exu2csr_r_req_o = 1'b0;
        exu2csr_w_req_o = 1'b0;
    end else begin
        case (exu_queue.csr_cmd)
            YCR_CSR_CMD_WRITE  : begin
                exu2csr_r_req_o = |exu_queue.rd_addr;
                exu2csr_w_req_o = csr_access_init;
            end
            YCR_CSR_CMD_SET,
            YCR_CSR_CMD_CLEAR  : begin
                exu2csr_r_req_o = 1'b1;
                exu2csr_w_req_o = |exu_queue.rs1_addr & csr_access_init;
            end
            default : begin
                exu2csr_r_req_o = 1'b0;
                exu2csr_w_req_o = 1'b0;
            end
        endcase
    end
end

assign exu2csr_w_cmd_o   = exu_queue.csr_cmd;
assign exu2csr_rw_addr_o = exu_queue.imm[YCR_CSR_ADDR_WIDTH-1:0];
assign exu2csr_w_data_o  = (exu_queue.csr_op == YCR_CSR_OP_REG)
                         ? mprf2exu_rs1_data_i
                         : {'0, exu_queue.rs1_addr}; // zimm


// CSR access FSM
//------------------------------------------------------------------------------

always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        csr_access_ff <= YCR_CSR_INIT;
    end else begin
        csr_access_ff <= csr_access_next;
    end
end

assign csr_access_next = (csr_access_init & csr2exu_mstatus_mie_up_i)
                       ? YCR_CSR_RDY
                       : YCR_CSR_INIT;

assign csr_access_init = (csr_access_ff == YCR_CSR_INIT);

// CSR events interface
//------------------------------------------------------------------------------

// Exceptions signals
assign exu2csr_take_exc_o = exu_exc_req
`ifdef YCR_DBG_EN
                          & ~hdu2exu_dbg_halted_i
`endif // YCR_DBG_EN
                          ;
assign exu2csr_exc_code_o = exc_code;
assign exu2csr_trap_val_o = exc_trap_val;

// Interrupts signals
assign exu2csr_take_irq_o = csr2exu_irq_i & ~exu2pipe_exu_busy_o
`ifdef YCR_DBG_EN
                          & ~hdu2exu_irq_dsbl_i
                          & ~hdu2exu_dbg_halted_i
`endif // YCR_DBG_EN
`ifdef YCR_CLKCTRL_EN
                          & clk_pipe_en
`endif // YCR_CLKCTRL_EN
                          ;

// MRET signals
// MRET instruction flag
assign exu2csr_mret_instr_o  = exu_queue_vd & exu_queue.mret_req
`ifdef YCR_TDU_EN
                             & ~tdu2exu_ibrkpt_exc_req_i
`endif // YCR_TDU_EN
`ifdef YCR_DBG_EN
                             & ~hdu2exu_dbg_halted_i
`endif // YCR_DBG_EN
                             ;
assign exu2csr_mret_update_o = exu2csr_mret_instr_o & csr_access_init;

`ifdef YCR_TDU_EN
//------------------------------------------------------------------------------
// EXU <-> TDU interface
//------------------------------------------------------------------------------

// Instruction monitor
assign exu2tdu_imon_o.vd    = exu_queue_vd;
assign exu2tdu_imon_o.req   = exu2pipe_instret_o;
assign exu2tdu_imon_o.addr  = pc_curr_ff;

always_comb begin
    exu2tdu_ibrkpt_ret_o = '0;
    if (exu_queue_vd) begin
        exu2tdu_ibrkpt_ret_o = tdu2exu_ibrkpt_match_i;
        if (lsu_req) begin
            exu2tdu_ibrkpt_ret_o[YCR_TDU_MTRIG_NUM-1:0] |= tdu2lsu_dbrkpt_match_i;
        end
    end
end
`endif // YCR_TDU_EN


`ifdef YCR_TRGT_SIMULATION
//------------------------------------------------------------------------------
// Tracelog signals
//------------------------------------------------------------------------------

logic [`YCR_XLEN-1:0]      update_pc;
logic                       update_pc_en;

assign update_pc_en = (init_pc | exu2pipe_instret_o | exu2csr_take_irq_o)
`ifdef YCR_DBG_EN
                    & ~hdu2exu_pc_advmt_dsbl_i & ~hdu2exu_no_commit_i
`endif // YCR_DBG_EN
                    ;
assign update_pc    = exu2ifu_pc_new_req_o ? exu2ifu_pc_new_o : inc_pc;


//------------------------------------------------------------------------------
// Assertion
//------------------------------------------------------------------------------

// X checks

YCR_SVA_EXU_XCHECK_CTRL : assert property (
    @(negedge clk) disable iff (~rst_n)
    !$isunknown({idu2exu_req_i, csr2exu_irq_i, csr2exu_ip_ie_i, lsu_req, lsu_rdy, exu_exc_req})
    ) else $error("EXU Error: unknown control values");

YCR_SVA_EXU_XCHECK_QUEUE : assert property (
    @(negedge clk) disable iff (~rst_n)
    idu2exu_req_i |-> !$isunknown(idu2exu_cmd_i)
    ) else $error("EXU Error: unknown values in queue");

YCR_SVA_EXU_XCHECK_CSR_RDATA : assert property (
    @(negedge clk) disable iff (~rst_n)
    exu2csr_r_req_o |-> !$isunknown({csr2exu_r_data_i, csr2exu_rw_exc_i})
    ) else $error("EXU Error: unknown values from CSR");

// Behavior checks

YCR_SVA_EXU_ONEHOT : assert property (
    @(negedge clk) disable iff (~rst_n)
    $onehot0({exu_queue.jump_req, exu_queue.branch_req, lsu_req})
    ) else $error("EXU Error: illegal combination of control signals");

YCR_SVA_EXU_ONEHOT_EXC : assert property (
    @(negedge clk) disable iff (~rst_n)
    exu_queue_vd |->
    $onehot0({exu_queue.exc_req, lsu_exc_req, csr2exu_rw_exc_i
`ifndef YCR_RVC_EXT
    , jb_misalign
`endif
    })
    ) else $error("EXU Error: exceptions $onehot0 failed");

`endif // YCR_TRGT_SIMULATION

endmodule : ycr_pipe_exu
