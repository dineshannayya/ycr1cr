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
////  yifive Memory-mapped Timer                                          ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     Memory-mapped Timer                                              ////
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
////     v2:    18 July 2021 - Dinesh A                                   ////
////          A.To break the timing path, input and output path are       ////
////             registered                                               ////
////          B.Spilt the 64 bit adder into two 32 bit adder with         ////
////            taking care ofoverflow                                    ////
////                                                                      ////
//////////////////////////////////////////////////////////////////////////////


`include "ycr_arch_description.svh"
`include "ycr_memif.svh"

module ycr_timer (
    // Common
    input   logic                                   rst_n,
    input   logic                                   clk,
    input   logic                                   rtc_clk,

    // Memory interface
    input   logic                                   dmem_req,
    input   logic                                   dmem_cmd,
    input   logic [1:0]                             dmem_width,
    input   logic [`YCR_DMEM_AWIDTH-1:0]           dmem_addr,
    input   logic [`YCR_DMEM_DWIDTH-1:0]           dmem_wdata,
    output  logic                                   dmem_req_ack,
    output  logic [`YCR_DMEM_DWIDTH-1:0]           dmem_rdata,
    output  logic [1:0]                             dmem_resp,

    // Timer interface
    output  logic [63:0]                            timer_val,
    output  logic                                   timer_irq,

    output  logic [31:0]                            riscv_glbl_cfg
);

//-------------------------------------------------------------------------------
// Local parameters declaration
//-------------------------------------------------------------------------------
localparam int unsigned YCR_TIMER_ADDR_WIDTH                               = 5;
localparam logic [YCR_TIMER_ADDR_WIDTH-1:0] YCR_TIMER_CONTROL             = 5'h0;
localparam logic [YCR_TIMER_ADDR_WIDTH-1:0] YCR_TIMER_DIVIDER             = 5'h4;
localparam logic [YCR_TIMER_ADDR_WIDTH-1:0] YCR_TIMER_MTIMELO             = 5'h8;
localparam logic [YCR_TIMER_ADDR_WIDTH-1:0] YCR_TIMER_MTIMEHI             = 5'hC;
localparam logic [YCR_TIMER_ADDR_WIDTH-1:0] YCR_TIMER_MTIMECMPLO          = 5'h10;
localparam logic [YCR_TIMER_ADDR_WIDTH-1:0] YCR_TIMER_MTIMECMPHI          = 5'h14;
localparam logic [YCR_TIMER_ADDR_WIDTH-1:0] YCR_GLBL_CONTROL              = 5'h18;

localparam int unsigned YCR_TIMER_CONTROL_EN_OFFSET                        = 0;
localparam int unsigned YCR_TIMER_CONTROL_CLKSRC_OFFSET                    = 1;
localparam int unsigned YCR_TIMER_DIVIDER_WIDTH                            = 10;

//-------------------------------------------------------------------------------
// Local signals declaration
//-------------------------------------------------------------------------------
logic [63:0]                                        mtime_reg;
logic                                               mtime_32b_ovr; // Indicate 32b Ovr flow
logic [63:0]                                        mtime_new;
logic [63:0]                                        mtimecmp_reg;
logic [63:0]                                        mtimecmp_new;
logic                                               timer_en;
logic                                               timer_clksrc_rtc;
logic [YCR_TIMER_DIVIDER_WIDTH-1:0]                timer_div;

logic                                               control_up;
logic                                               divider_up;
logic                                               mtimelo_up;
logic                                               mtimehi_up;
logic                                               mtimecmplo_up;
logic                                               mtimecmphi_up;
logic                                               glbl_cfg_up;

logic                                               dmem_req_valid;

logic [3:0]                                         rtc_sync;
logic                                               rtc_ext_pulse;
logic [YCR_TIMER_DIVIDER_WIDTH-1:0]                timeclk_cnt;
logic                                               timeclk_cnt_en;
logic                                               time_posedge;
logic                                               time_cmp_flag;

//-------------------------------------------------------------------------------
// Registers
//-------------------------------------------------------------------------------

// CONTROL
always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        timer_en            <= 1'b1;
        timer_clksrc_rtc    <= 1'b0;
    end else begin
        if (control_up) begin
            timer_en            <= dmem_wdata[YCR_TIMER_CONTROL_EN_OFFSET];
            timer_clksrc_rtc    <= dmem_wdata[YCR_TIMER_CONTROL_CLKSRC_OFFSET];
        end
    end
end

// DIVIDER
always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        timer_div   <= '0;
    end else begin
        if (divider_up) begin
            timer_div   <= dmem_wdata[YCR_TIMER_DIVIDER_WIDTH-1:0];
        end
    end
end

// MTIME
assign time_posedge = (timeclk_cnt_en & (timeclk_cnt == 0));

always_comb begin
    mtime_new   = mtime_reg;
    if (time_posedge) begin
        mtime_new[31:0]    = mtime_reg[31:0] + 1'b1;
        mtime_new[63:32]   = mtime_32b_ovr ? (mtime_new[63:32] + 1'b1) : mtime_new[63:32];
    end else if (mtimelo_up) begin
        mtime_new[31:0]     = dmem_wdata;
    end else if (mtimehi_up) begin
        mtime_new[63:32]    = dmem_wdata;
    end
end

always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        mtime_reg   <= '0;
	mtime_32b_ovr <= '0;
    end else begin
        if (time_posedge | mtimelo_up | mtimehi_up) begin
            mtime_reg   <= mtime_new;
	    mtime_32b_ovr <= &mtime_new; // Indicate 32B Overflow in next increment by check all one
        end
    end
end

// MTIMECMP
always_comb begin
    mtimecmp_new    = mtimecmp_reg;
    if (mtimecmplo_up) begin
        mtimecmp_new[31:0]  = dmem_wdata;
    end
    if (mtimecmphi_up) begin
        mtimecmp_new[63:32] = dmem_wdata;
    end
end

always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        mtimecmp_reg    <= '0;
    end else begin
        if (mtimecmplo_up | mtimecmphi_up) begin
            mtimecmp_reg    <= mtimecmp_new;
        end
    end
end

always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        riscv_glbl_cfg    <= '0;
    end else begin
        if (glbl_cfg_up) begin
            riscv_glbl_cfg    <= dmem_wdata;
        end
    end
end

//-------------------------------------------------------------------------------
// Interrupt pending
//-------------------------------------------------------------------------------
assign time_cmp_flag = (mtime_reg >= ((mtimecmplo_up | mtimecmphi_up) ? mtimecmp_new : mtimecmp_reg));

always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        timer_irq   <= 1'b0;
    end else begin
        if (~timer_irq) begin
            timer_irq   <= time_cmp_flag;
        end else begin // 1'b1
            if (mtimecmplo_up | mtimecmphi_up) begin
                timer_irq   <= time_cmp_flag;
            end
        end
    end
end

//-------------------------------------------------------------------------------
// Timer divider
//-------------------------------------------------------------------------------
assign timeclk_cnt_en   = (~timer_clksrc_rtc ? 1'b1 : rtc_ext_pulse) & timer_en;

always_ff @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
        timeclk_cnt <= '0;
    end else begin
        case (1'b1)
            divider_up      : timeclk_cnt   <= dmem_wdata[YCR_TIMER_DIVIDER_WIDTH-1:0];
            time_posedge    : timeclk_cnt   <= timer_div;
            timeclk_cnt_en  : timeclk_cnt   <= timeclk_cnt - 1'b1;
            default         : begin end
        endcase
    end
end

//-------------------------------------------------------------------------------
// RTC synchronization
//-------------------------------------------------------------------------------
assign rtc_ext_pulse    = rtc_sync[3] ^ rtc_sync[2];

always_ff @(negedge rst_n, posedge rtc_clk) begin
    if (~rst_n) begin
        rtc_sync[0] <= 1'b0;
    end else begin
        if (timer_clksrc_rtc) begin
            rtc_sync[0] <= ~rtc_sync[0];
        end
    end
end

always_ff @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
        rtc_sync[3:1]   <= '0;
    end else begin
        if (timer_clksrc_rtc) begin
            rtc_sync[3:1]   <= rtc_sync[2:0];
        end
    end
end

//-------------------------------------------------------------------------------
// Memory interface
//-------------------------------------------------------------------------------
logic                           dmem_cmd_ff;
logic [YCR_TIMER_ADDR_WIDTH-1:0]   dmem_addr_ff;
always_ff @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
       dmem_req_valid <= '0;
       dmem_req_ack  <= '0;
       dmem_cmd_ff  <= '0;
       dmem_addr_ff <= '0;
    end else begin
       dmem_req_valid <=  (dmem_req) && (dmem_req_ack == 0) &&  (dmem_width == YCR_MEM_WIDTH_WORD) & (~|dmem_addr[1:0]) &
                          (dmem_addr[YCR_TIMER_ADDR_WIDTH-1:2] <= YCR_TIMER_MTIMECMPHI[YCR_TIMER_ADDR_WIDTH-1:2]);
       dmem_req_ack   <= dmem_req & (dmem_req_ack ==0);
       dmem_cmd_ff    <= dmem_cmd;
       dmem_addr_ff   <= dmem_addr[YCR_TIMER_ADDR_WIDTH-1:0];
    end
end

always_ff @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
        dmem_resp   <= YCR_MEM_RESP_NOTRDY;
        dmem_rdata  <= '0;
    end else begin
        if (dmem_req_valid) begin
                dmem_resp   <= YCR_MEM_RESP_RDY_OK;
                if (dmem_cmd_ff == YCR_MEM_CMD_RD) begin
                    case (dmem_addr_ff)
                        YCR_TIMER_CONTROL      : dmem_rdata    <= `YCR_DMEM_DWIDTH'({timer_clksrc_rtc, timer_en});
                        YCR_TIMER_DIVIDER      : dmem_rdata    <= `YCR_DMEM_DWIDTH'(timer_div);
                        YCR_TIMER_MTIMELO      : dmem_rdata    <= mtime_reg[31:0];
                        YCR_TIMER_MTIMEHI      : dmem_rdata    <= mtime_reg[63:32];
                        YCR_TIMER_MTIMECMPLO   : dmem_rdata    <= mtimecmp_reg[31:0];
                        YCR_TIMER_MTIMECMPHI   : dmem_rdata    <= mtimecmp_reg[63:32];
                        YCR_GLBL_CONTROL       : dmem_rdata    <= riscv_glbl_cfg;
                        default                 : begin end
                    endcase
                end
        end else begin
            dmem_resp   <= YCR_MEM_RESP_NOTRDY;
            dmem_rdata  <= '0;
        end
    end
end

always_comb begin
    control_up      = 1'b0;
    divider_up      = 1'b0;
    mtimelo_up      = 1'b0;
    mtimehi_up      = 1'b0;
    mtimecmplo_up   = 1'b0;
    mtimecmphi_up   = 1'b0;
    glbl_cfg_up     = 1'b0;
    if (dmem_req_valid & (dmem_cmd_ff == YCR_MEM_CMD_WR)) begin
        case (dmem_addr_ff)
            YCR_TIMER_CONTROL      : control_up    = 1'b1;
            YCR_TIMER_DIVIDER      : divider_up    = 1'b1;
            YCR_TIMER_MTIMELO      : mtimelo_up    = 1'b1;
            YCR_TIMER_MTIMEHI      : mtimehi_up    = 1'b1;
            YCR_TIMER_MTIMECMPLO   : mtimecmplo_up = 1'b1;
            YCR_TIMER_MTIMECMPHI   : mtimecmphi_up = 1'b1;
	    YCR_GLBL_CONTROL       : glbl_cfg_up   = 1'b1;
            default                 : begin end
        endcase
    end
end

//-------------------------------------------------------------------------------
// Timer interface
//-------------------------------------------------------------------------------
assign timer_val    = mtime_reg;

endmodule : ycr_timer
