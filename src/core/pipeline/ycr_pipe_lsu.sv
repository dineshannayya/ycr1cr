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
////  yifive Load/Store Unit (LSU)                                        ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     Load/Store Unit (LSU)                                            ////
////                                                                      ////
//// Functionality:                                                       ////
//// - Performs load and store operations in Data Memory                  ////
//// - Generates DMEM address misalign and access fault exceptions        ////
//// - Passes DMEM operations information to TDU and generates LSU        ////
////   breakpoint exception                                               ////
////                                                                      ////
//// Structure:                                                           ////
//// - FSM                                                                ////
//// - Exceptions logic                                                   ////
//// - LSU <-> EXU interface                                              ////
//// - LSU <-> DMEM interface                                             ////
//// - LSU <-> TDU interface                                              ////
///                                                                       ////
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
`ifdef YCR_TDU_EN
`include "ycr_tdu.svh"
`endif // YCR_TDU_EN

module ycr_pipe_lsu (
    // Common
    input   logic                               rst_n,                      // LSU reset
    input   logic                               clk,                        // LSU clock

    // LSU <-> EXU interface
    input   logic                               exu2lsu_req_i,              // Request to LSU
    input   type_ycr_lsu_cmd_sel_e             exu2lsu_cmd_i,              // LSU command
    input   logic [`YCR_XLEN-1:0]              exu2lsu_addr_i,             // Address of DMEM
    input   logic [`YCR_XLEN-1:0]              exu2lsu_sdata_i,            // Data for store
    output  logic                               lsu2exu_rdy_o,              // LSU received DMEM response
    output  logic [`YCR_XLEN-1:0]              lsu2exu_ldata_o,            // Load data
    output  logic                               lsu2exu_exc_o,              // Exception from LSU
    output  type_ycr_exc_code_e                lsu2exu_exc_code_o,         // Exception code

`ifdef YCR_TDU_EN
    // LSU <-> TDU interface
    output  type_ycr_brkm_lsu_mon_s            lsu2tdu_dmon_o,             // Data address stream monitoring
    input   logic                               tdu2lsu_ibrkpt_exc_req_i,   // Instruction BP exception request
    input   logic                               tdu2lsu_dbrkpt_exc_req_i,   // Data BP exception request
`endif // YCR_TDU_EN

    // LSU <-> DMEM interface
    output  logic                               lsu2dmem_req_o,             // Data memory request
    output  logic                               lsu2dmem_cmd_o,             // Data memory command (READ/WRITE)
    output  logic [1:0]                         lsu2dmem_width_o,           // Data memory data width
    output  logic [`YCR_DMEM_AWIDTH-1:0]       lsu2dmem_addr_o,            // Data memory address
    output  logic [`YCR_DMEM_DWIDTH-1:0]       lsu2dmem_wdata_o,           // Data memory write data
    input   logic                               dmem2lsu_req_ack_i,         // Data memory request acknowledge
    input   logic [`YCR_DMEM_DWIDTH-1:0]       dmem2lsu_rdata_i,           // Data memory read data
    input   logic [1:0]                         dmem2lsu_resp_i             // Data memory response
);

//------------------------------------------------------------------------------
// Local types declaration
//------------------------------------------------------------------------------

//typedef enum logic {
parameter  YCR_LSU_FSM_IDLE = 1'b0;
parameter  YCR_LSU_FSM_BUSY = 1'b1;
//} type_ycr_lsu_fsm_e;

//------------------------------------------------------------------------------
// Local signals declaration
//------------------------------------------------------------------------------

// LSU FSM signals
logic                       lsu_fsm_curr;       // LSU FSM current state
logic                       lsu_fsm_next;       // LSU FSM next state
logic                       lsu_fsm_idle;       // LSU FSM is in IDLE state

// LSU Command register signals
logic                       lsu_cmd_upd;        // LSU Command register update
type_ycr_lsu_cmd_sel_e     lsu_cmd_ff;         // LSU Command register value
logic                       lsu_cmd_ff_load;    // Registered LSU Command is load
logic                       lsu_cmd_ff_store;   // Registered LSU Command is store

// DMEM command and width flags
logic                       dmem_cmd_load;      // DMEM command is load
logic                       dmem_cmd_store;     // DMEM Command is store
logic                       dmem_wdth_word;     // DMEM data width is WORD
logic                       dmem_wdth_hword;    // DMEM data width is HALFWORD
logic                       dmem_wdth_byte;     // DMEM data width is BYTE

// DMEM response and request control signals
logic                       dmem_resp_ok;       // DMEM response is OK
logic                       dmem_resp_er;       // DMEM response is erroneous
logic                       dmem_resp_received; // DMEM response is received
logic                       dmem_req_vd;        // DMEM request is valid (req_ack received)

// Exceptions signals
logic                       lsu_exc_req;        // LSU exception request
logic                       dmem_addr_mslgn;    // DMEM address is misaligned
logic                       dmem_addr_mslgn_l;  // DMEM load address is misaligned
logic                       dmem_addr_mslgn_s;  // DMEM store address is misaligned
`ifdef YCR_TDU_EN
logic                       lsu_exc_hwbrk;      // LSU hardware breakpoint exception
`endif // YCR_TDU_EN

//------------------------------------------------------------------------------
// Control logic
//------------------------------------------------------------------------------

// DMEM response and request control signals
assign dmem_resp_ok       = (dmem2lsu_resp_i == YCR_MEM_RESP_RDY_OK);
assign dmem_resp_er       = (dmem2lsu_resp_i == YCR_MEM_RESP_RDY_ER);
assign dmem_resp_received = dmem_resp_ok | dmem_resp_er;
assign dmem_req_vd        = exu2lsu_req_i & dmem2lsu_req_ack_i & ~lsu_exc_req;

// LSU load and store command flags
assign dmem_cmd_load  = (exu2lsu_cmd_i == YCR_LSU_CMD_LB )
                      | (exu2lsu_cmd_i == YCR_LSU_CMD_LBU)
                      | (exu2lsu_cmd_i == YCR_LSU_CMD_LH )
                      | (exu2lsu_cmd_i == YCR_LSU_CMD_LHU)
                      | (exu2lsu_cmd_i == YCR_LSU_CMD_LW );
assign dmem_cmd_store = (exu2lsu_cmd_i == YCR_LSU_CMD_SB )
                      | (exu2lsu_cmd_i == YCR_LSU_CMD_SH )
                      | (exu2lsu_cmd_i == YCR_LSU_CMD_SW );

// LSU data width flags
assign dmem_wdth_word  = (exu2lsu_cmd_i == YCR_LSU_CMD_LW )
                       | (exu2lsu_cmd_i == YCR_LSU_CMD_SW );
assign dmem_wdth_hword = (exu2lsu_cmd_i == YCR_LSU_CMD_LH )
                       | (exu2lsu_cmd_i == YCR_LSU_CMD_LHU)
                       | (exu2lsu_cmd_i == YCR_LSU_CMD_SH );
assign dmem_wdth_byte  = (exu2lsu_cmd_i == YCR_LSU_CMD_LB )
                       | (exu2lsu_cmd_i == YCR_LSU_CMD_LBU)
                       | (exu2lsu_cmd_i == YCR_LSU_CMD_SB );

// LSU command register
assign lsu_cmd_upd = lsu_fsm_idle & dmem_req_vd;

always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        lsu_cmd_ff <= YCR_LSU_CMD_NONE;
    end else if (lsu_cmd_upd) begin
        lsu_cmd_ff <= exu2lsu_cmd_i;
    end
end

// LSU registered load and store command flags
assign lsu_cmd_ff_load  = (lsu_cmd_ff == YCR_LSU_CMD_LB )
                        | (lsu_cmd_ff == YCR_LSU_CMD_LBU)
                        | (lsu_cmd_ff == YCR_LSU_CMD_LH )
                        | (lsu_cmd_ff == YCR_LSU_CMD_LHU)
                        | (lsu_cmd_ff == YCR_LSU_CMD_LW );
assign lsu_cmd_ff_store = (lsu_cmd_ff == YCR_LSU_CMD_SB )
                        | (lsu_cmd_ff == YCR_LSU_CMD_SH )
                        | (lsu_cmd_ff == YCR_LSU_CMD_SW );

//------------------------------------------------------------------------------
// LSU FSM
//------------------------------------------------------------------------------
 //
 // LSU FSM is used to control the LSU <-> DMEM interface
 //
//

// Updating LSU FSM state
always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        lsu_fsm_curr <= YCR_LSU_FSM_IDLE;
    end else begin
        lsu_fsm_curr <= lsu_fsm_next;
    end
end

// LSU FSM next state logic
always_comb begin
    case (lsu_fsm_curr)
        YCR_LSU_FSM_IDLE: begin
            lsu_fsm_next = dmem_req_vd        ? YCR_LSU_FSM_BUSY
                                              : YCR_LSU_FSM_IDLE;
        end
        YCR_LSU_FSM_BUSY: begin
            lsu_fsm_next = dmem_resp_received ? YCR_LSU_FSM_IDLE
                                              : YCR_LSU_FSM_BUSY;
        end
    endcase
end

assign lsu_fsm_idle = (lsu_fsm_curr == YCR_LSU_FSM_IDLE);

//------------------------------------------------------------------------------
// Exceptions logic
//------------------------------------------------------------------------------
 //
 // The following types of exceptions are supported:
 // - Load address misalign
 // - Load access fault
 // - Store address misalign
 // - Store access fault
 // - LSU breakpoint exception
//

// DMEM addr misalign logic
assign dmem_addr_mslgn   = exu2lsu_req_i & ( (dmem_wdth_hword & exu2lsu_addr_i[0])
                                           | (dmem_wdth_word  & |exu2lsu_addr_i[1:0]));
assign dmem_addr_mslgn_l = dmem_addr_mslgn & dmem_cmd_load;
assign dmem_addr_mslgn_s = dmem_addr_mslgn & dmem_cmd_store;

// Exception code logic
always_comb begin
    case (1'b1)
        dmem_resp_er     : if(lsu_cmd_ff_load)
		               lsu2exu_exc_code_o = YCR_EXC_CODE_LD_ACCESS_FAULT;
                           else if(lsu_cmd_ff_store)
                               lsu2exu_exc_code_o =  YCR_EXC_CODE_ST_ACCESS_FAULT;
			   else
                               lsu2exu_exc_code_o =  YCR_EXC_CODE_INSTR_MISALIGN;
`ifdef YCR_TDU_EN
        lsu_exc_hwbrk    : lsu2exu_exc_code_o = YCR_EXC_CODE_BREAKPOINT;
`endif // YCR_TDU_EN
        dmem_addr_mslgn_l: lsu2exu_exc_code_o = YCR_EXC_CODE_LD_ADDR_MISALIGN;
        dmem_addr_mslgn_s: lsu2exu_exc_code_o = YCR_EXC_CODE_ST_ADDR_MISALIGN;
        default          : lsu2exu_exc_code_o = YCR_EXC_CODE_INSTR_MISALIGN;
    endcase // 1'b1
end

assign lsu_exc_req = dmem_addr_mslgn_l | dmem_addr_mslgn_s
`ifdef YCR_TDU_EN
                   | lsu_exc_hwbrk
`endif // YCR_TDU_EN
;

//------------------------------------------------------------------------------
// LSU <-> EXU interface
//------------------------------------------------------------------------------

assign lsu2exu_rdy_o = dmem_resp_received;
assign lsu2exu_exc_o = dmem_resp_er | lsu_exc_req;

// Sign- or zero-extending data received from DMEM
always_comb begin
    case (lsu_cmd_ff)
        YCR_LSU_CMD_LH : lsu2exu_ldata_o = {{16{dmem2lsu_rdata_i[15]}}, dmem2lsu_rdata_i[15:0]};
        YCR_LSU_CMD_LHU: lsu2exu_ldata_o = { 16'b0,                     dmem2lsu_rdata_i[15:0]};
        YCR_LSU_CMD_LB : lsu2exu_ldata_o = {{24{dmem2lsu_rdata_i[7]}},  dmem2lsu_rdata_i[7:0]};
        YCR_LSU_CMD_LBU: lsu2exu_ldata_o = { 24'b0,                     dmem2lsu_rdata_i[7:0]};
        default         : lsu2exu_ldata_o = dmem2lsu_rdata_i;
    endcase // lsu_cmd_ff
end

//------------------------------------------------------------------------------
// LSU <-> DMEM interface
//------------------------------------------------------------------------------

assign lsu2dmem_req_o   = exu2lsu_req_i & ~lsu_exc_req & lsu_fsm_idle;
assign lsu2dmem_addr_o  = exu2lsu_addr_i;
assign lsu2dmem_wdata_o = exu2lsu_sdata_i;
assign lsu2dmem_cmd_o   = dmem_cmd_store  ? YCR_MEM_CMD_WR : YCR_MEM_CMD_RD;
assign lsu2dmem_width_o = dmem_wdth_byte  ? YCR_MEM_WIDTH_BYTE
                        : dmem_wdth_hword ? YCR_MEM_WIDTH_HWORD
                                          : YCR_MEM_WIDTH_WORD;

`ifdef YCR_TDU_EN
//------------------------------------------------------------------------------
// LSU <-> TDU interface
//------------------------------------------------------------------------------

assign lsu2tdu_dmon_o.vd    = exu2lsu_req_i & lsu_fsm_idle & ~tdu2lsu_ibrkpt_exc_req_i;
assign lsu2tdu_dmon_o.addr  = exu2lsu_addr_i;
assign lsu2tdu_dmon_o.load  = dmem_cmd_load;
assign lsu2tdu_dmon_o.store = dmem_cmd_store;

assign lsu_exc_hwbrk = (exu2lsu_req_i & tdu2lsu_ibrkpt_exc_req_i)
                     | tdu2lsu_dbrkpt_exc_req_i;

`endif // YCR_TDU_EN

`ifdef YCR_TRGT_SIMULATION
//------------------------------------------------------------------------------
// Assertions
//------------------------------------------------------------------------------

// X checks

YCR_SVA_LSU_XCHECK_CTRL : assert property (
    @(negedge clk) disable iff (~rst_n)
    !$isunknown({exu2lsu_req_i, lsu_fsm_curr
`ifdef YCR_TDU_EN
        , tdu2lsu_ibrkpt_exc_req_i, tdu2lsu_dbrkpt_exc_req_i
`endif // YCR_TDU_EN
    })
    ) else $error("LSU Error: unknown control value");

YCR_SVA_LSU_XCHECK_CMD : assert property (
    @(negedge clk) disable iff (~rst_n)
    exu2lsu_req_i |-> !$isunknown({exu2lsu_cmd_i, exu2lsu_addr_i})
    ) else $error("LSU Error: undefined CMD or address");

YCR_SVA_LSU_XCHECK_SDATA : assert property (
    @(negedge clk) disable iff (~rst_n)
    (exu2lsu_req_i & (lsu2dmem_cmd_o == YCR_MEM_CMD_WR)) |-> !$isunknown({exu2lsu_sdata_i})
    ) else $error("LSU Error: undefined store data");

YCR_SVA_LSU_XCHECK_EXC : assert property (
    @(negedge clk) disable iff (~rst_n)
    lsu2exu_exc_o |-> !$isunknown(lsu2exu_exc_code_o)
    ) else $error("LSU Error: exception code undefined");

YCR_SVA_LSU_IMEM_CTRL : assert property (
    @(negedge clk) disable iff (~rst_n)
    lsu2dmem_req_o |-> !$isunknown({lsu2dmem_cmd_o, lsu2dmem_width_o, lsu2dmem_addr_o})
    ) else $error("LSU Error: undefined dmem control");

YCR_SVA_LSU_IMEM_ACK : assert property (
    @(negedge clk) disable iff (~rst_n)
    lsu2dmem_req_o |-> !$isunknown(dmem2lsu_req_ack_i)
    ) else $error("LSU Error: undefined dmem ack");

YCR_SVA_LSU_IMEM_WDATA : assert property (
    @(negedge clk) disable iff (~rst_n)
    lsu2dmem_req_o & (lsu2dmem_cmd_o == YCR_MEM_CMD_WR)
    |-> !$isunknown(lsu2dmem_wdata_o[8:0])
    ) else $error("LSU Error: undefined dmem wdata");

// Behavior checks

YCR_SVA_LSU_EXC_ONEHOT : assert property (
    @(negedge clk) disable iff (~rst_n)
    $onehot0({dmem_resp_er, dmem_addr_mslgn_l, dmem_addr_mslgn_s})
    ) else $error("LSU Error: more than one exception at a time");

YCR_SVA_LSU_UNEXPECTED_DMEM_RESP : assert property (
    @(negedge clk) disable iff (~rst_n)
    lsu_fsm_idle |-> ~dmem_resp_received
    ) else $error("LSU Error: not expecting memory response");

YCR_SVA_LSU_REQ_EXC : assert property (
    @(negedge clk) disable iff (~rst_n)
    lsu2exu_exc_o |-> exu2lsu_req_i
    ) else $error("LSU Error: impossible exception");

`ifdef YCR_TDU_EN

YCR_COV_LSU_MISALIGN_BRKPT : cover property (
    @(negedge clk) disable iff (~rst_n)
    (dmem_addr_mslgn_l | dmem_addr_mslgn_s) & lsu_exc_hwbrk
);
`endif // YCR_TDU_EN

`endif // YCR_TRGT_SIMULATION

endmodule : ycr_pipe_lsu
