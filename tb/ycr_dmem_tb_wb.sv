//////////////////////////////////////////////////////////////////////////////
// SPDX-FileCopyrightText: 2021 , Dinesh Annayya                          
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0
// SPDX-FileContributor: Created by Dinesh Annayya <dinesha@opencores.org>
//
///////////////////////////////////////////////////////////////////
//                                                              
//  Wishbone Memory
////////////////////////////////////////////////////////////////////


module ycr_dmem_tb_wb #(
    parameter YCR_WB_WIDTH  = 32,
    parameter YCR_MEM_POWER_SIZE  = 25 // Memory sized increased for non TCM Mode
)
(
    // Control
    input   logic                                   rst_n,
    input   logic                                   clk,
    input   logic [YCR_WB_WIDTH-1:0]               mem_req_ack_stall_in,

    // Memory Interface
    input  logic                                    wbd_mem_stb_i         ,
    input  logic [31:0]                             wbd_mem_adr_i         ,
    input  logic                                    wbd_mem_we_i          ,
    input  logic [31:0]                             wbd_mem_dat_i         ,
    input  logic [3:0]                              wbd_mem_sel_i         ,
    input  logic [9:0]                              wbd_mem_bl_i          ,
    input  logic                                    wbd_mem_bry_i         ,
    output logic [31:0]                             wbd_mem_dat_o         ,
    output logic                                    wbd_mem_ack_o         ,
    output logic                                    wbd_mem_lack_o        ,
    output logic                                    wbd_mem_err_o         

);

//-------------------------------------------------------------------------------
// Local Types
//-------------------------------------------------------------------------------
typedef enum logic {
    YCR_STATE_IDLE = 1'b0,
    YCR_STATE_DATA = 1'b1,
    YCR_STATE_ERR  = 1'bx
} type_wb_state_e;

//-------------------------------------------------------------------------------
// Memory definition
//-------------------------------------------------------------------------------
logic [7:0]                             memory [0:2**YCR_MEM_POWER_SIZE-1];

`ifdef VERILATOR
logic [255:0]                           test_file;
`else // VERILATOR
string                                  test_file;
`endif // VERILATOR
bit                                     test_file_init;


assign wbd_mem_err_o = 0;

//-------------------------------------------------------------------------------
// Local functions
//-------------------------------------------------------------------------------
function logic [YCR_WB_WIDTH-1:0] ycr_read_mem(
    logic   [YCR_WB_WIDTH-1:0]    addr,
    logic   [3:0]                  r_be
);
    logic [YCR_WB_WIDTH-1:0]       tmp;
begin
    ycr_read_mem = 'x;

    for (int unsigned i=0; i<4; ++i) begin
        tmp[(8*(i+1)-1)-:8] = (r_be[i]) ?  memory[addr+i] : 'x;
    end
    //$display("MEMORY READ ADDRESS: %x Data: %x",addr,tmp);
    return tmp;
end
endfunction : ycr_read_mem

function void ycr_write_mem(
    logic   [YCR_WB_WIDTH-1:0]    addr,
    logic   [3:0]                  w_be,
    logic   [YCR_WB_WIDTH-1:0]    data
);
begin
    for (int unsigned i=0; i<4; ++i) begin
        if (w_be[i]) begin
             memory[addr+i] = data[(8*(i+1)-1)-:8];
        end
    end
end
endfunction : ycr_write_mem


//-------------------------------------------------------------------------------
// Local signal declaration
//-------------------------------------------------------------------------------


// MEM access
logic   [YCR_WB_WIDTH-1:0]    mem_req_ack_stall;
bit                            mem_req_ack_rnd;
logic                          mem_req_ack;
logic                          mem_req_ack_nc;
type_wb_state_e                mem_state;



//-------------------------------------------------------------------------------
// Data memory ready
//-------------------------------------------------------------------------------
always_ff @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
        mem_req_ack_stall = mem_req_ack_stall_in;
        mem_req_ack_rnd   = 1'b0;
    end else begin
        if (mem_req_ack_stall == 32'd0) begin
            mem_req_ack_rnd = $random;
        end else begin
            mem_req_ack_stall = {mem_req_ack_stall[0], mem_req_ack_stall[31:1]};
        end
    end
end

assign mem_req_ack = (mem_req_ack_stall == 32'd0) ?  mem_req_ack_rnd : mem_req_ack_stall[0];


//-------------------------------------------------------------------------------
// Address command latch
//-------------------------------------------------------------------------------
logic       wbd_mem_stb_l;
logic [9:0] mem_bl_cnt;
logic [YCR_MEM_POWER_SIZE-1:0] mem_ptr;

wire wbd_mem_stb_pedge = (wbd_mem_stb_l == 1'b0) && wbd_mem_stb_i;
always @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
	wbd_mem_stb_l   = '0;
        wbd_mem_ack_o   = 1'b0;
        wbd_mem_lack_o  = 1'b0;
        wbd_mem_dat_o   = 'x;
	mem_bl_cnt      = 10'h1;
	mem_ptr         = 0;
	// Memory init moved to test bench
	//if (test_file_init) $readmemh(test_file, memory);
    end else begin
	wbd_mem_stb_l   = wbd_mem_stb_i;
	if(wbd_mem_stb_pedge) begin
	    mem_bl_cnt    = 10'h1;
	    mem_ptr       =  {wbd_mem_adr_i[YCR_MEM_POWER_SIZE-1:2], 2'b00};
	end

        if (wbd_mem_stb_i && mem_req_ack && wbd_mem_bry_i && ~wbd_mem_we_i && !wbd_mem_lack_o) begin
            wbd_mem_ack_o   = #1 1'b1;
            wbd_mem_dat_o   = ycr_read_mem(mem_ptr, wbd_mem_sel_i );
	    if(wbd_mem_bl_i == mem_bl_cnt)
                wbd_mem_lack_o   = #1 1'b1;

	    mem_bl_cnt    = mem_bl_cnt+1;
	    mem_ptr       =  mem_ptr +4;
	end else if (wbd_mem_stb_i && mem_req_ack && wbd_mem_bry_i && wbd_mem_we_i && !wbd_mem_lack_o) begin
            wbd_mem_ack_o   = #1 1'b1;
	    if(wbd_mem_bl_i == mem_bl_cnt)
                wbd_mem_lack_o   = #1 1'b1;
            for (int unsigned i=0; i<4; ++i) begin
                if (wbd_mem_sel_i[i]) begin
                     memory[mem_ptr+i] = wbd_mem_dat_i[(8*(i+1)-1)-:8];
                end
            end
	    mem_bl_cnt    = mem_bl_cnt+1;
	    mem_ptr       =  mem_ptr +4;
         end else begin
            wbd_mem_ack_o    = #1 1'b0;
            wbd_mem_lack_o   = #1 1'b0;
         end
    end
end


endmodule : ycr_dmem_tb_wb
