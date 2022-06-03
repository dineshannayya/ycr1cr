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
////  yifive Wishbone interface for Data memory                           ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     integrated wishbone i/f to data  memory                          ////
////                                                                      ////
////  To Do:                                                              ////
////    nothing                                                           ////
////                                                                      ////
////  Author(s):                                                          ////
////      - Dinesh Annayya, dinesha@opencores.org                         ////
////                                                                      ////
////  Revision :                                                          ////
////     v0:    June 7, 2021, Dinesh A                                    ////
////             wishbone integration                                     ////
////     v1:    June 9, 2021, Dinesh A                                    ////
////              On power up, wishbone outputs are unkown as it          ////
////              driven from fifo output. To avoid unknown               ////
////              propgation, we are driving 'h0 when fifo empty          ////
////     v2:    June 18, 2021, Dinesh A                                   ////
////            core and wishbone is made async and async fifo            ////
////            added to take care of domain cross-over                   ////
////                                                                      ////
//////////////////////////////////////////////////////////////////////////////

`include "ycr_wb.svh"
`include "ycr_memif.svh"

module ycr_dmem_wb (
    // Control Signals
    input   logic                           core_rst_n, // core reset
    input   logic                           core_clk,   // Core clock

    // Core Interface
    output  logic                           dmem_req_ack,
    input   logic                           dmem_req,
    input   logic                           dmem_cmd,
    input   logic [1:0]                     dmem_width,
    input   logic   [YCR_WB_WIDTH-1:0]     dmem_addr,
    input   logic   [YCR_WB_WIDTH-1:0]     dmem_wdata,
    output  logic   [YCR_WB_WIDTH-1:0]     dmem_rdata,
    output  logic [1:0]                     dmem_resp,

    // WB Interface
    input   logic                           wb_rst_n,   // wishbone reset
    input   logic                           wb_clk,     // wishbone clock
    output  logic                           wbd_stb_o, // strobe/request
    output  logic   [YCR_WB_WIDTH-1:0]     wbd_adr_o, // address
    output  logic                           wbd_we_o,  // write
    output  logic   [YCR_WB_WIDTH-1:0]     wbd_dat_o, // data output
    output  logic   [3:0]                   wbd_sel_o, // byte enable
    input   logic   [YCR_WB_WIDTH-1:0]     wbd_dat_i, // data input
    input   logic                           wbd_ack_i, // acknowlegement
    input   logic                           wbd_err_i  // error

);

//-------------------------------------------------------------------------------
// Local Parameters
//-------------------------------------------------------------------------------

//-------------------------------------------------------------------------------
// Local type declaration
//-------------------------------------------------------------------------------

typedef struct packed {
    logic [3:0]                     hbel;
    logic                           hwrite;
    logic   [2:0]                   hwidth;
    logic   [YCR_WB_WIDTH-1:0]     haddr;
    logic   [YCR_WB_WIDTH-1:0]     hwdata;
} type_ycr_req_fifo_s;


typedef struct packed {
    logic                           hresp;
    logic   [2:0]                   hwidth;
    logic   [1:0]                   haddr;
    logic   [YCR_WB_WIDTH-1:0]    hrdata;
} type_ycr_resp_fifo_s;

//-------------------------------------------------------------------------------
// Local functions
//-------------------------------------------------------------------------------
function automatic logic   [2:0] ycr_conv_mem2wb_width (
    input   logic [1:0]              dmem_width
);
    logic   [2:0]   tmp;
begin
    case (dmem_width)
        YCR_MEM_WIDTH_BYTE : begin
            tmp = YCR_DSIZE_8B;
        end
        YCR_MEM_WIDTH_HWORD : begin
            tmp = YCR_DSIZE_16B;
        end
        YCR_MEM_WIDTH_WORD : begin
            tmp = YCR_DSIZE_32B;
        end
        default : begin
            tmp = YCR_DSIZE_32B;
        end
    endcase
    ycr_conv_mem2wb_width =  tmp; // cp.11
end
endfunction

function automatic logic[YCR_WB_WIDTH-1:0] ycr_conv_mem2wb_wdata (
    input   logic   [1:0]                   dmem_addr,
    input   logic [1:0]                     dmem_width,
    input   logic   [YCR_WB_WIDTH-1:0]    dmem_wdata
);
    logic   [YCR_WB_WIDTH-1:0]  tmp;
begin
    tmp = 'x;
    case (dmem_width)
        YCR_MEM_WIDTH_BYTE : begin
            case (dmem_addr)
                2'b00 : begin
                    tmp[7:0]   = dmem_wdata[7:0];
                end
                2'b01 : begin
                    tmp[15:8]  = dmem_wdata[7:0];
                end
                2'b10 : begin
                    tmp[23:16] = dmem_wdata[7:0];
                end
                2'b11 : begin
                    tmp[31:24] = dmem_wdata[7:0];
                end
                default : begin
                end
            endcase
        end
        YCR_MEM_WIDTH_HWORD : begin
            case (dmem_addr[1])
                1'b0 : begin
                    tmp[15:0]  = dmem_wdata[15:0];
                end
                1'b1 : begin
                    tmp[31:16] = dmem_wdata[15:0];
                end
                default : begin
                end
            endcase
        end
        YCR_MEM_WIDTH_WORD : begin
            tmp = dmem_wdata;
        end
        default : begin
        end
    endcase
    ycr_conv_mem2wb_wdata = tmp;
end
endfunction

function automatic logic[YCR_WB_WIDTH-1:0] ycr_conv_wb2mem_rdata (
    input   logic [1:0]                 hwidth,
    input   logic [1:0]                 haddr,
    input   logic [YCR_WB_WIDTH-1:0]  hrdata
);
    logic   [YCR_WB_WIDTH-1:0]  tmp;
begin
    tmp = 'x;
    case (hwidth)
        YCR_DSIZE_8B : begin
            case (haddr)
                2'b00 : tmp[7:0] = hrdata[7:0];
                2'b01 : tmp[7:0] = hrdata[15:8];
                2'b10 : tmp[7:0] = hrdata[23:16];
                2'b11 : tmp[7:0] = hrdata[31:24];
                default : begin
                end
            endcase
        end
        YCR_DSIZE_16B : begin
            case (haddr[1])
                1'b0 : tmp[15:0] = hrdata[15:0];
                1'b1 : tmp[15:0] = hrdata[31:16];
                default : begin
                end
            endcase
        end
        YCR_DSIZE_32B : begin
            tmp = hrdata;
        end
        default : begin
        end
    endcase
    ycr_conv_wb2mem_rdata = tmp;
end
endfunction

//-------------------------------------------------------------------------------
// Local signal declaration
//-------------------------------------------------------------------------------
logic                                       req_fifo_rd;
logic                                       req_fifo_wr;
logic                                       req_fifo_empty;
logic                                       req_fifo_full;
logic                                       req_fifo_afull;


logic                                       resp_fifo_rd;
logic                                       resp_fifo_empty;
logic                                       resp_fifo_full;


//-------------------------------------------------------------------------------
// REQ_FIFO (CORE to WB)
//-------------------------------------------------------------------------------
wire	                 hwrite_in = (dmem_cmd == YCR_MEM_CMD_WR);
wire [2:0]               hwidth_in = ycr_conv_mem2wb_width(dmem_width);
wire [YCR_WB_WIDTH-1:0] haddr_in  = dmem_addr;
wire [YCR_WB_WIDTH-1:0] hwdata_in = ycr_conv_mem2wb_wdata(dmem_addr[1:0], dmem_width, dmem_wdata);

reg  [3:0]              hbel_in; // byte select
always_comb begin
	hbel_in = 0;
    case (hwidth_in)
        YCR_DSIZE_8B : begin
            hbel_in = 4'b0001 << haddr_in[1:0];
        end
        YCR_DSIZE_16B : begin
            hbel_in = 4'b0011 << haddr_in[1:0];
        end
        YCR_DSIZE_32B : begin
            hbel_in = 4'b1111;
        end
    endcase
end


//-------------------------------------------------------------------------------
// REQ_FIFO (WB to CORE)
//-------------------------------------------------------------------------------
type_ycr_req_fifo_s    req_fifo_din;
type_ycr_req_fifo_s    req_fifo_dout;


// Back-Back write is not supported
always_ff @(negedge core_rst_n, posedge core_clk) begin
    if (~core_rst_n) begin
      dmem_req_ack  <= '0;
    end else begin
      dmem_req_ack  <= dmem_req & !req_fifo_full & !dmem_req_ack;
    end
end

assign req_fifo_wr         = dmem_req_ack;

//pack data in
assign req_fifo_din.hbel   =  hbel_in;
assign req_fifo_din.hwrite =  hwrite_in;
assign req_fifo_din.hwidth =  hwidth_in;
assign req_fifo_din.haddr  =  haddr_in;
assign req_fifo_din.hwdata =  hwdata_in;


 async_fifo #(
      .W(YCR_WB_WIDTH+YCR_WB_WIDTH+3+1+4), // Data Width
      .DP(4),            // FIFO DEPTH
      .WR_FAST(1),       // We need FF'ed Full
      .RD_FAST(1)        // We need FF'ed Empty
     )   u_req_fifo(
     // Writc Clock
	.wr_clk      (core_clk       ),
        .wr_reset_n  (core_rst_n     ),
        .wr_en       (req_fifo_wr    ),
        .wr_data     (req_fifo_din   ),
        .full        (req_fifo_full  ),
        .afull       (req_fifo_afull ),

    // RD Clock
        .rd_clk     (wb_clk          ),
        .rd_reset_n (wb_rst_n        ),
        .rd_en      (req_fifo_rd     ),
        .empty      (req_fifo_empty  ),                
        .aempty     (                ),                
        .rd_data    (req_fifo_dout   )
      );


always_comb begin
    req_fifo_rd = 1'b0;
    if (wbd_ack_i) begin
         req_fifo_rd = ~req_fifo_empty;
    end
end


assign wbd_stb_o    = ~req_fifo_empty;

// To avoid unknown progating the design, driven zero when fifo is empty
assign wbd_adr_o    = (req_fifo_empty) ? 'h0 : req_fifo_dout.haddr;
assign wbd_we_o     = (req_fifo_empty) ? 'h0 : req_fifo_dout.hwrite;
assign wbd_dat_o    = (req_fifo_empty) ? 'h0 : req_fifo_dout.hwdata;
assign wbd_sel_o    = (req_fifo_empty) ? 'h0 : req_fifo_dout.hbel;


//-------------------------------------------------------------------------------
// Response path - Used by Read path logic
//-------------------------------------------------------------------------------
type_ycr_resp_fifo_s                       resp_fifo_din;
type_ycr_resp_fifo_s                       resp_fifo_dout;


assign  resp_fifo_din.hresp  = (wbd_err_i) ? 1'b0 : 1'b1;
assign  resp_fifo_din.hwidth = req_fifo_dout.hwidth;
assign  resp_fifo_din.haddr  = req_fifo_dout.haddr[1:0];
assign  resp_fifo_din.hrdata = (wbd_we_o) ? 'h0: wbd_dat_i;

 async_fifo #(
      .W(YCR_WB_WIDTH+2+3+1), // Data Width
      .DP(4),            // FIFO DEPTH
      .WR_FAST(1),       // We need FF'ed Full
      .RD_FAST(1)        // We need FF'ed Empty
     )   u_res_fifo(
     // Writc Clock
	.wr_clk      (wb_clk                 ),
        .wr_reset_n  (wb_rst_n               ),
        .wr_en       (wbd_ack_i              ),
        .wr_data     (resp_fifo_din          ),
        .full        (                       ), // Assmed FIFO will never be full as it's Response a Single Request
        .afull       (                       ),                 

    // RD Clock
        .rd_clk     (core_clk                ),
        .rd_reset_n (core_rst_n              ),
        .rd_en      (resp_fifo_rd            ),
        .empty      (resp_fifo_empty         ),                
        .aempty     (                        ),                
        .rd_data    (resp_fifo_dout          )
      );

assign resp_fifo_rd = !resp_fifo_empty;
  
// Added FF to improve timing
always_ff @(posedge core_clk, negedge core_rst_n) begin
   if(core_rst_n == 0) begin
      dmem_rdata <= '0;
      dmem_resp <= '0;
   end else begin
      dmem_rdata <= (resp_fifo_rd) ? ycr_conv_wb2mem_rdata(resp_fifo_dout.hwidth, resp_fifo_dout.haddr, resp_fifo_dout.hrdata) : 'h0;
      dmem_resp  <= (resp_fifo_rd)
                          ? (resp_fifo_dout.hresp == 1'b1)
                              ? YCR_MEM_RESP_RDY_OK
                              : YCR_MEM_RESP_RDY_ER
                          : YCR_MEM_RESP_NOTRDY ;
   end
end




endmodule : ycr_dmem_wb
