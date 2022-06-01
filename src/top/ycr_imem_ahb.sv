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
////  yifive AHB interface for Program memory                             ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     AHB interface for Program memory                                 ////
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

`include "ycr_ahb.svh"
`include "ycr_memif.svh"

module ycr_imem_ahb (
    // Control Signals
    input   logic                           rst_n,
    input   logic                           clk,

    // Core Interface
    output  logic                           imem_req_ack,
    input   logic                           imem_req,
    input   logic   [YCR_AHB_WIDTH-1:0]    imem_addr,
    output  logic   [YCR_AHB_WIDTH-1:0]    imem_rdata,
    output  logic [1:0]                     imem_resp,

    // AHB Interface
    output  logic   [3:0]                   hprot,
    output  logic   [2:0]                   hburst,
    output  logic   [2:0]                   hsize,
    output  logic   [1:0]                   htrans,
    output  logic                           hmastlock,
    output  logic   [YCR_AHB_WIDTH-1:0]    haddr,
    input   logic                           hready,
    input   logic   [YCR_AHB_WIDTH-1:0]    hrdata,
    input   logic                           hresp

);

//-------------------------------------------------------------------------------
// Local parameters declaration
//-------------------------------------------------------------------------------
`ifndef YCR_IMEM_AHB_OUT_BP
localparam  YCR_FIFO_WIDTH = 2;
localparam  YCR_FIFO_CNT_WIDTH = $clog2(YCR_FIFO_WIDTH+1);
`endif // YCR_IMEM_AHB_OUT_BP

//-------------------------------------------------------------------------------
// Local types declaration
//-------------------------------------------------------------------------------
typedef enum logic {
    YCR_FSM_ADDR = 1'b0,
    YCR_FSM_DATA = 1'b1,
    YCR_FSM_ERR  = 1'bx
} type_ycr_fsm_e;

typedef struct packed {
    logic   [YCR_AHB_WIDTH-1:0]    haddr;
} type_ycr_req_fifo_s;

typedef struct packed {
    logic                           hresp;
    logic   [YCR_AHB_WIDTH-1:0]    hrdata;
} type_ycr_resp_fifo_s;

//-------------------------------------------------------------------------------
// Local signal declaration
//-------------------------------------------------------------------------------
type_ycr_fsm_e                             fsm;
logic                                       req_fifo_rd;
logic                                       req_fifo_wr;
logic                                       req_fifo_up;
`ifdef YCR_IMEM_AHB_OUT_BP
type_ycr_req_fifo_s                        req_fifo_r;
type_ycr_req_fifo_s [0:0]                  req_fifo;
`else // YCR_IMEM_AHB_OUT_BP
type_ycr_req_fifo_s [0:YCR_FIFO_WIDTH-1]  req_fifo;
type_ycr_req_fifo_s [0:YCR_FIFO_WIDTH-1]  req_fifo_new;
logic       [YCR_FIFO_CNT_WIDTH-1:0]       req_fifo_cnt;
logic       [YCR_FIFO_CNT_WIDTH-1:0]       req_fifo_cnt_new;
`endif // YCR_IMEM_AHB_OUT_BP
logic                                       req_fifo_empty;
logic                                       req_fifo_full;

type_ycr_resp_fifo_s                       resp_fifo;
logic                                       resp_fifo_hready;

//-------------------------------------------------------------------------------
// Interface to Core
//-------------------------------------------------------------------------------
assign imem_req_ack = ~req_fifo_full;
assign req_fifo_wr  = ~req_fifo_full & imem_req;

assign imem_rdata = resp_fifo.hrdata;

assign imem_resp = (resp_fifo_hready)
                    ? (resp_fifo.hresp == YCR_HRESP_OKAY)
                        ? YCR_MEM_RESP_RDY_OK
                        : YCR_MEM_RESP_RDY_ER
                    : YCR_MEM_RESP_NOTRDY;

//-------------------------------------------------------------------------------
// REQ_FIFO
//-------------------------------------------------------------------------------
`ifdef YCR_IMEM_AHB_OUT_BP
always_ff @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
        req_fifo_full <= 1'b0;
    end else begin
        if (~req_fifo_full) begin
            req_fifo_full <= imem_req & ~req_fifo_rd;
        end else begin
            req_fifo_full <= ~req_fifo_rd;
        end
    end
end
assign req_fifo_empty = ~(req_fifo_full | imem_req);

assign req_fifo_up    = ~req_fifo_rd & req_fifo_wr;
always_ff @(posedge clk) begin
    if (req_fifo_up) begin
        req_fifo_r.haddr <= imem_addr;
    end
end

assign req_fifo[0] = (req_fifo_full) ? req_fifo_r : imem_addr;

`else // YCR_IMEM_AHB_OUT_BP
always_comb begin
    req_fifo_up      = 1'b0;
    req_fifo_cnt_new = req_fifo_cnt;
    req_fifo_new     = req_fifo;
    case ({req_fifo_rd, req_fifo_wr})
        2'b00 : begin
            // nothing todo
        end
        2'b01: begin
            // FIFO write
            req_fifo_up = 1'b1;
            req_fifo_new[req_fifo_cnt].haddr  = imem_addr;
            req_fifo_cnt_new = req_fifo_cnt + 1'b1;
        end
        2'b10 : begin
            // FIFO read
            req_fifo_up     = 1'b1;
            req_fifo_new[0] = req_fifo_new[1];
            req_fifo_new[1].haddr  = 'x;
            req_fifo_cnt_new = req_fifo_cnt - 1'b1;
        end
        2'b11 : begin
            // Read and Write FIFO. It is possible only when fifo_cnt = 1
            req_fifo_up           = 1'b1;
            req_fifo_new[0].haddr = imem_addr;
        end
        default : begin
            req_fifo_up      = 'x;
            req_fifo_cnt_new = 'x;
            req_fifo_new     = 'x;
        end
    endcase
end

always_ff @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
        req_fifo_cnt <= '0;
    end else begin
        if (req_fifo_up) begin
            req_fifo_cnt <= req_fifo_cnt_new;
        end
    end
end
assign req_fifo_full  = (req_fifo_cnt == YCR_FIFO_WIDTH);
assign req_fifo_empty = ~(|req_fifo_cnt);

always_ff @(posedge clk) begin
    if (req_fifo_up) begin
        req_fifo <= req_fifo_new;
    end
end
`endif // YCR_IMEM_AHB_OUT_BP

//-------------------------------------------------------------------------------
// FSM
//-------------------------------------------------------------------------------
always_ff @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
        fsm <= YCR_FSM_ADDR;
    end else begin
        case (fsm)
            YCR_FSM_ADDR : begin
                if (hready) begin
                    fsm <= (req_fifo_empty) ? YCR_FSM_ADDR : YCR_FSM_DATA;
                end
            end
            YCR_FSM_DATA : begin
                if (hready) begin
                    if (hresp == YCR_HRESP_OKAY) begin
                        fsm <= (req_fifo_empty) ? YCR_FSM_ADDR : YCR_FSM_DATA;
                    end else begin
                        fsm <= YCR_FSM_ADDR;
                    end
                end
            end
            default : begin
                fsm <= YCR_FSM_ERR;
            end
        endcase
    end
end

always_comb begin
    req_fifo_rd = 1'b0;
    case (fsm)
        YCR_FSM_ADDR : begin
            if (hready) begin
                req_fifo_rd = ~req_fifo_empty;
            end
        end
        YCR_FSM_DATA : begin
            if (hready) begin
                req_fifo_rd = ~req_fifo_empty & (hresp == YCR_HRESP_OKAY);
            end
        end
        default : begin
            req_fifo_rd = 1'bx;
        end
    endcase
end

//-------------------------------------------------------------------------------
// FIFO response
//-------------------------------------------------------------------------------
`ifdef YCR_IMEM_AHB_IN_BP
assign resp_fifo_hready = (fsm == YCR_FSM_DATA) ? hready : 1'b0;
assign resp_fifo.hresp  = hresp;
assign resp_fifo.hrdata = hrdata;
`else // YCR_IMEM_AHB_IN_BP
always_ff @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
        resp_fifo_hready <= 1'b0;
    end else begin
        resp_fifo_hready <= (fsm == YCR_FSM_DATA) ? hready : 1'b0;
    end
end

always_ff @(posedge clk) begin
    if (hready & (fsm == YCR_FSM_DATA)) begin
        resp_fifo.hresp  <= hresp;
        resp_fifo.hrdata <= hrdata;
    end
end
`endif // YCR_IMEM_AHB_IN_BP

//-------------------------------------------------------------------------------
// Interface to AHB
//-------------------------------------------------------------------------------
assign hprot[YCR_HPROT_DATA]  = 1'b0;
assign hprot[YCR_HPROT_PRV]   = 1'b0;
assign hprot[YCR_HPROT_BUF]   = 1'b0;
assign hprot[YCR_HPROT_CACHE] = 1'b0;

assign hburst       = YCR_HBURST_SINGLE;
assign hsize        = YCR_HSIZE_32B;
assign hmastlock    = 1'b0;

always_comb begin
    htrans = YCR_HTRANS_IDLE;
    case (fsm)
        YCR_FSM_ADDR : begin
            if (~req_fifo_empty) begin
                htrans = YCR_HTRANS_NONSEQ;
            end
        end
        YCR_FSM_DATA : begin
            if (hready) begin
                if (hresp == YCR_HRESP_OKAY) begin
                    if (~req_fifo_empty) begin
                        htrans = YCR_HTRANS_NONSEQ;
                    end
                end
            end
        end
        default : begin
            htrans = YCR_HTRANS_ERR;
        end
    endcase
end

assign haddr  = req_fifo[0].haddr;

`ifdef YCR_TRGT_SIMULATION
//-------------------------------------------------------------------------------
// Assertion
//-------------------------------------------------------------------------------

// Check Core interface
YCR_SVA_IMEM_AHB_BRIDGE_REQ_XCHECK : assert property (
    @(negedge clk) disable iff (~rst_n)
    !$isunknown(imem_req)
    ) else $error("IMEM AHB bridge Error: imem_req has unknown values");

YCR_IMEM_AHB_BRIDGE_ADDR_XCHECK : assert property (
    @(negedge clk) disable iff (~rst_n)
    imem_req |-> !$isunknown(imem_addr)
    ) else $error("IMEM AHB bridge Error: imem_addr has unknown values");

YCR_IMEM_AHB_BRIDGE_ADDR_ALLIGN : assert property (
    @(negedge clk) disable iff (~rst_n)
    imem_req |-> (imem_addr[1:0] == '0)
    ) else $error("IMEM AHB bridge Error: imem_addr has unalign values");

// Check AHB interface
YCR_IMEM_AHB_BRIDGE_HREADY_XCHECK : assert property (
    @(negedge clk) disable iff (~rst_n)
    !$isunknown(hready)
    ) else $error("IMEM AHB bridge Error: hready has unknown values");

YCR_IMEM_AHB_BRIDGE_HRESP_XCHECK : assert property (
    @(negedge clk) disable iff (~rst_n)
    !$isunknown(hresp)
    ) else $error("IMEM AHB bridge Error: hresp has unknown values");

`endif // YCR_TRGT_SIMULATION

endmodule : ycr_imem_ahb
