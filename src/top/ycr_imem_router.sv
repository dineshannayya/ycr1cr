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
////  yifive Instruction memory router                                    ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     Instruction memory router                                        ////
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
////            https://github.com/syntacore/scr1                         ////
////     v1:    June 7, 2021, Dinesh A                                    ////
////             opentool(iverilog/yosys) related cleanup                 ////
////                                                                      ////
//////////////////////////////////////////////////////////////////////////////

`include "ycr_memif.svh"
`include "ycr_arch_description.svh"

module ycr_imem_router
#(
    parameter YCR_PORT1_ADDR_MASK      = `YCR_IMEM_AWIDTH'hFFFF0000,
    parameter YCR_PORT1_ADDR_PATTERN   = `YCR_IMEM_AWIDTH'h00010000,
    parameter YCR_PORT2_ADDR_MASK      = `YCR_IMEM_AWIDTH'hFFFF0000,
    parameter YCR_PORT2_ADDR_PATTERN   = `YCR_IMEM_AWIDTH'h00020000,
    parameter YCR_PORT3_ADDR_MASK      = `YCR_IMEM_AWIDTH'hFFFF0000,
    parameter YCR_PORT3_ADDR_PATTERN   = `YCR_IMEM_AWIDTH'h00020000

)
(
    // Control signals
    input   logic                           rst_n,
    input   logic                           clk,

    // Core interface
    output  logic                           imem_req_ack,
    input   logic                           imem_req,
    input   logic                           imem_cmd,
    input   logic [`YCR_IMEM_AWIDTH-1:0]   imem_addr,
    input   logic [`YCR_IMEM_BSIZE -1:0]   imem_bl,
    output  logic [`YCR_IMEM_DWIDTH-1:0]   imem_rdata,
    output  logic [1:0]                     imem_resp,

    // PORT0 interface
    input   logic                           port0_req_ack,
    output  logic                           port0_req,
    output  logic                           port0_cmd,
    output  logic [`YCR_IMEM_AWIDTH-1:0]   port0_addr,
    output  logic [`YCR_IMEM_BSIZE-1:0]    port0_bl,
    input   logic [`YCR_IMEM_DWIDTH-1:0]   port0_rdata,
    input   logic [1:0]                     port0_resp,

    // PORT1 interface
    input   logic                           port1_req_ack,
    output  logic                           port1_req,
    output  logic                           port1_cmd,
    output  logic [`YCR_IMEM_AWIDTH-1:0]   port1_addr,
    output  logic [`YCR_IMEM_BSIZE-1:0]    port1_bl,
    input   logic [`YCR_IMEM_DWIDTH-1:0]   port1_rdata,
    input   logic [1:0]                     port1_resp,

    // PORT2 interface
    input   logic                           port2_req_ack,
    output  logic                           port2_req,
    output  logic                           port2_cmd,
    output  logic [`YCR_IMEM_AWIDTH-1:0]   port2_addr,
    input   logic [`YCR_IMEM_DWIDTH-1:0]   port2_rdata,
    input   logic [1:0]                     port2_resp,

    // PORT3 interface
    input   logic                           port3_req_ack,
    output  logic                           port3_req,
    output  logic                           port3_cmd,
    output  logic [`YCR_IMEM_AWIDTH-1:0]   port3_addr,
    input   logic [`YCR_IMEM_DWIDTH-1:0]   port3_rdata,
    input   logic [1:0]                     port3_resp
);

//-------------------------------------------------------------------------------
// Local types declaration
//-------------------------------------------------------------------------------
typedef enum logic {
    YCR_FSM_ADDR,
    YCR_FSM_DATA
} type_ycr_fsm_e;

typedef enum logic [1:0] {
    YCR_SEL_PORT0,
    YCR_SEL_PORT1,
    YCR_SEL_PORT2,
    YCR_SEL_PORT3
} type_ycr_sel_e;

//-------------------------------------------------------------------------------
// Local signal declaration
//-------------------------------------------------------------------------------
type_ycr_fsm_e                 fsm;
type_ycr_sel_e                 port_sel;
type_ycr_sel_e                 port_sel_r;
logic [`YCR_IMEM_DWIDTH-1:0]   sel_rdata;
logic [1:0]                     sel_resp;
logic                           sel_req_ack;

//-------------------------------------------------------------------------------
// FSM
//-------------------------------------------------------------------------------
always_comb begin
    port_sel    = YCR_SEL_PORT0;
    if ((imem_addr & YCR_PORT1_ADDR_MASK) == YCR_PORT1_ADDR_PATTERN) begin
        port_sel    = YCR_SEL_PORT1;
    end else if ((imem_addr & YCR_PORT2_ADDR_MASK) == YCR_PORT2_ADDR_PATTERN) begin
        port_sel    = YCR_SEL_PORT2;
    end else if ((imem_addr & YCR_PORT3_ADDR_MASK) == YCR_PORT3_ADDR_PATTERN) begin
        port_sel    = YCR_SEL_PORT3;
    end 
end

always_ff @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
        fsm        <= YCR_FSM_ADDR;
        port_sel_r <= YCR_SEL_PORT0;
    end else begin
        case (fsm)
            YCR_FSM_ADDR : begin
                if (imem_req & sel_req_ack) begin
                    fsm <= YCR_FSM_DATA;
                    port_sel_r <= port_sel;
                end
            end
            YCR_FSM_DATA : begin
                case (sel_resp)
                    YCR_MEM_RESP_RDY_OK : begin
                        if (imem_req & sel_req_ack) begin
                            fsm <= YCR_FSM_DATA;
                            port_sel_r <= port_sel;
                        end else begin
                            fsm <= YCR_FSM_ADDR;
                        end
                    end
                    YCR_MEM_RESP_RDY_ER : begin
                        fsm <= YCR_FSM_ADDR;
                    end
                    default : begin
                    end
                endcase
            end
            default : begin
            end
        endcase
    end
end

always_comb begin
    if ((fsm == YCR_FSM_ADDR) | ((fsm == YCR_FSM_DATA) & (sel_resp == YCR_MEM_RESP_RDY_OK))) begin
        case (port_sel)
            YCR_SEL_PORT0  : sel_req_ack   = port0_req_ack;
            YCR_SEL_PORT1  : sel_req_ack   = port1_req_ack;
            YCR_SEL_PORT2  : sel_req_ack   = port2_req_ack;
            YCR_SEL_PORT3  : sel_req_ack   = port3_req_ack;
            default         : sel_req_ack   = 1'b0;
        endcase
    end else begin
        sel_req_ack = 1'b0;
    end
end

always_comb begin
    case (port_sel_r)
        YCR_SEL_PORT0  : begin
            sel_rdata   = port0_rdata;
            sel_resp    = port0_resp;
        end
        YCR_SEL_PORT1  : begin
            sel_rdata   = port1_rdata;
            sel_resp    = port1_resp;
        end
        YCR_SEL_PORT2  : begin
            sel_rdata   = port2_rdata;
            sel_resp    = port2_resp;
	end
        YCR_SEL_PORT3  : begin
            sel_rdata   = port3_rdata;
            sel_resp    = port3_resp;
	end
        default         : begin
            sel_rdata   = '0;
            sel_resp    = YCR_MEM_RESP_RDY_ER;
        end
    endcase
end

//-------------------------------------------------------------------------------
// Interface to core
//-------------------------------------------------------------------------------
assign imem_req_ack = sel_req_ack;
assign imem_rdata   = sel_rdata;
assign imem_resp    = sel_resp;

//-------------------------------------------------------------------------------
// Interface to PORT0
//-------------------------------------------------------------------------------
always_comb begin
    port0_req = 1'b0;
    case (fsm)
        YCR_FSM_ADDR : begin
            port0_req = imem_req & (port_sel == YCR_SEL_PORT0);
        end
        YCR_FSM_DATA : begin
            if (sel_resp == YCR_MEM_RESP_RDY_OK) begin
                port0_req = imem_req & (port_sel == YCR_SEL_PORT0);
            end
        end
        default : begin
        end
    endcase
end

`ifdef YCR_XPROP_EN
assign port0_cmd   = (port_sel == YCR_SEL_PORT0) ? imem_cmd  : YCR_MEM_CMD_ERROR;
assign port0_addr  = (port_sel == YCR_SEL_PORT0) ? imem_addr : 'x;
assign port0_bl    = (port_sel == YCR_SEL_PORT0) ? imem_bl : 'x;
`else // YCR_XPROP_EN
assign port0_cmd   = imem_cmd ;
assign port0_addr  = imem_addr;
assign port0_bl    = imem_bl;
`endif // YCR_XPROP_EN

//-------------------------------------------------------------------------------
// Interface to PORT1
//-------------------------------------------------------------------------------
always_comb begin
    port1_req = 1'b0;
    case (fsm)
        YCR_FSM_ADDR : begin
            port1_req = imem_req & (port_sel == YCR_SEL_PORT1);
        end
        YCR_FSM_DATA : begin
            if (sel_resp == YCR_MEM_RESP_RDY_OK) begin
                port1_req = imem_req & (port_sel == YCR_SEL_PORT1);
            end
        end
        default : begin
        end
    endcase
end

`ifdef YCR_XPROP_EN
assign port1_cmd   = (port_sel == YCR_SEL_PORT1) ? imem_cmd  : YCR_MEM_CMD_ERROR;
assign port1_addr  = (port_sel == YCR_SEL_PORT1) ? imem_addr : 'x;
assign port1_bl    = (port_sel == YCR_SEL_PORT1) ? imem_bl   : 'x;
`else // YCR_XPROP_EN
assign port1_cmd   = imem_cmd ;
assign port1_addr  = imem_addr;
assign port1_bl    = imem_bl;
`endif // YCR_XPROP_EN

//-------------------------------------------------------------------------------
// Interface to PORT2
//-------------------------------------------------------------------------------
always_comb begin
    port2_req = 1'b0;
    case (fsm)
        YCR_FSM_ADDR : begin
            port2_req = imem_req & (port_sel == YCR_SEL_PORT2);
        end
        YCR_FSM_DATA : begin
            if (sel_resp == YCR_MEM_RESP_RDY_OK) begin
                port2_req = imem_req & (port_sel == YCR_SEL_PORT2);
            end
        end
        default : begin
        end
    endcase
end

`ifdef YCR_XPROP_EN
assign port2_cmd   = (port_sel == YCR_SEL_PORT2) ? imem_cmd  : YCR_MEM_CMD_ERROR;
assign port2_addr  = (port_sel == YCR_SEL_PORT2) ? imem_addr : 'x;
`else // YCR_XPROP_EN
assign port2_cmd   = imem_cmd ;
assign port2_addr  = imem_addr;
`endif // YCR_XPROP_EN

//-------------------------------------------------------------------------------
// Interface to PORT3
//-------------------------------------------------------------------------------
always_comb begin
    port3_req = 1'b0;
    case (fsm)
        YCR_FSM_ADDR : begin
            port3_req = imem_req & (port_sel == YCR_SEL_PORT3);
        end
        YCR_FSM_DATA : begin
            if (sel_resp == YCR_MEM_RESP_RDY_OK) begin
                port3_req = imem_req & (port_sel == YCR_SEL_PORT3);
            end
        end
        default : begin
        end
    endcase
end

`ifdef YCR_XPROP_EN
assign port3_cmd   = (port_sel == YCR_SEL_PORT3) ? imem_cmd  : YCR_MEM_CMD_ERROR;
assign port3_addr  = (port_sel == YCR_SEL_PORT3) ? imem_addr : 'x;
`else // YCR_XPROP_EN
assign port3_cmd   = imem_cmd ;
assign port3_addr  = imem_addr;
`endif // YCR_XPROP_EN

`ifdef YCR_TRGT_SIMULATION
//-------------------------------------------------------------------------------
// Assertion
//-------------------------------------------------------------------------------

YCR_SVA_IMEM_RT_XCHECK : assert property (
    @(negedge clk) disable iff (~rst_n)
    imem_req |-> !$isunknown({port_sel, imem_cmd})
    ) else $error("IMEM router Error: unknown values");

`endif // YCR_TRGT_SIMULATION

endmodule : ycr_imem_router
