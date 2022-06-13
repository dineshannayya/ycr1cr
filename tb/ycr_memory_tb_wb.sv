/// @file       <ycr_memory_tb_ahb.sv>
/// @brief      AHB memory testbench
///

`include "ycr_arch_description.svh"
`include "ycr_wb.svh"
`include "ycr_ipic.svh"

module ycr_memory_tb_wb #(
`ifdef YCR_TCM_EN
    parameter YCR_MEM_POWER_SIZE  = 16
`else
    parameter YCR_MEM_POWER_SIZE  = 23 // Memory sized increased for non TCM Mode
`endif
)
(
    // Control
    input   logic                                   rst_n,
    input   logic                                   clk,
`ifdef YCR_IPIC_EN
    output  logic  [YCR_IRQ_LINES_NUM-1:0]         irq_lines,
`else // YCR_IPIC_EN
    output  logic                                   ext_irq,
`endif // YCR_IPIC_EN
    output  logic                                   soft_irq,
    input   logic [YCR_WB_WIDTH-1:0]               imem_req_ack_stall_in,
    input   logic [YCR_WB_WIDTH-1:0]               dmem_req_ack_stall_in,

    // Instruction Memory Interface
    input  logic                                    wbd_imem_stb_i,
    input  logic [31:0]                             wbd_imem_adr_i         ,
    input  logic                                    wbd_imem_we_i          ,
    input  logic [31:0]                             wbd_imem_dat_i         ,
    input  logic [3:0]                              wbd_imem_sel_i         ,
    input  logic [9:0]                              wbd_imem_bl_i          ,
    input  logic                                    wbd_imem_bry_i         ,
    output logic [31:0]                             wbd_imem_dat_o         ,
    output logic                                    wbd_imem_ack_o         ,
    output logic                                    wbd_imem_lack_o        ,
    output logic                                    wbd_imem_err_o         ,

    // Memory Interface
    input  logic                                    wbd_dmem_stb_i         ,
    input  logic [31:0]                             wbd_dmem_adr_i         ,
    input  logic                                    wbd_dmem_we_i          ,
    input  logic [31:0]                             wbd_dmem_dat_i         ,
    input  logic [3:0]                              wbd_dmem_sel_i         ,
    input  logic [9:0]                              wbd_dmem_bl_i          ,
    output logic [31:0]                             wbd_dmem_dat_o         ,
    output logic                                    wbd_dmem_ack_o         ,
    output logic                                    wbd_dmem_lack_o        ,
    output logic                                    wbd_dmem_err_o         

);

//-------------------------------------------------------------------------------
// Local Types
//-------------------------------------------------------------------------------

//-------------------------------------------------------------------------------
// Memory definition
//-------------------------------------------------------------------------------
logic [7:0]                             memory [0:2**YCR_MEM_POWER_SIZE-1];
`ifdef YCR_IPIC_EN
logic [YCR_IRQ_LINES_NUM-1:0]          irq_lines_reg;
`else // YCR_IPIC_EN
logic                                   ext_irq_reg;
`endif // YCR_IPIC_EN
logic                                   soft_irq_reg;
logic [7:0]                             mirage [0:2**YCR_MEM_POWER_SIZE-1];
bit                                     mirage_en;
bit                                     mirage_rangeen;
bit [YCR_WB_WIDTH-1:0]                mirage_adrlo = '1;
bit [YCR_WB_WIDTH-1:0]                mirage_adrhi = '1;

`ifdef VERILATOR
logic [255:0]                           test_file;
`else // VERILATOR
string                                  test_file;
`endif // VERILATOR
bit                                     test_file_init;


assign wbd_imem_err_o = 0;
assign wbd_dmem_err_o = 0;

//-------------------------------------------------------------------------------
// Local functions
//-------------------------------------------------------------------------------
function logic [YCR_WB_WIDTH-1:0] ycr_read_mem(
    logic   [YCR_WB_WIDTH-1:0]    addr,
    logic   [3:0]                   r_be,
    logic   [3:0]                   w_hazard,
    logic   [YCR_WB_WIDTH-1:0]    w_data,
    bit                             mirage_en
);
    logic [YCR_WB_WIDTH-1:0]      tmp;
    logic [YCR_MEM_POWER_SIZE-1:0] addr_mirage;
begin
    ycr_read_mem = 'x;

    if(~mirage_en) begin
        for (int unsigned i=0; i<4; ++i) begin
            tmp[(8*(i+1)-1)-:8] = (r_be[i])
                                        ? (w_hazard[i])
                                            ? w_data[(8*(i+1)-1)-:8]
                                            : memory[addr+i]
                                        : 'x;
        end
    end
    else begin
        addr_mirage = addr;
        for (int i = 0; i < 4; ++i) begin
            tmp[ (i*8)+:8 ] = (r_be[i])
                                        ? (w_hazard[i])
                                            ? w_data[(i*8)+:8]
                                            : mirage[addr_mirage+i]
                                        : 'x;
        end
    end
    //$display("MEMORY READ ADDRESS: %x Data: %x",addr,tmp);
    return tmp;
end
endfunction : ycr_read_mem

function void ycr_write_mem(
    logic   [YCR_WB_WIDTH-1:0]    addr,
    logic   [3:0]                   w_be,
    logic   [YCR_WB_WIDTH-1:0]    data,
    bit                             mirage_en
);
    logic [YCR_MEM_POWER_SIZE-1:0] addr_mirage;
begin
    for (int unsigned i=0; i<4; ++i) begin
        if (w_be[i]) begin
            if(~mirage_en)
                memory[addr+i] <= data[(8*(i+1)-1)-:8];
            else begin
                addr_mirage = addr;
                mirage[addr_mirage+i] <= data[(8*(i+1)-1)-:8];
            end
        end
    end
end
endfunction : ycr_write_mem


//-------------------------------------------------------------------------------
// Local signal declaration
//-------------------------------------------------------------------------------
// IMEM access
logic   [YCR_WB_WIDTH-1:0]    imem_ahb_addr;
logic   [YCR_WB_WIDTH-1:0]    imem_req_ack_stall;
bit                           imem_req_ack_rnd;
logic                         imem_req_ack_i;
logic                         imem_req_ack_nc;
logic   [YCR_WB_WIDTH-1:0]    imem_hrdata_l;
logic   [3:0]                 imem_wr_hazard;

// DMEM access
logic   [YCR_WB_WIDTH-1:0]    dmem_req_ack_stall;
bit                           dmem_req_ack_rnd;
logic                         dmem_req_ack;
logic                         dmem_req_ack_nc;
logic   [YCR_WB_WIDTH-1:0]    dmem_ahb_addr;
logic   [2:0]                 dmem_ahb_size;
logic   [3:0]                 dmem_ahb_be;
logic   [YCR_WB_WIDTH-1:0]    dmem_hrdata_l;
logic   [3:0]                 dmem_wr_hazard;

//-------------------------------------------------------------------------------
// Instruction memory ready
//-------------------------------------------------------------------------------
always_ff @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
        imem_req_ack_stall <= imem_req_ack_stall_in;
        imem_req_ack_rnd   <= 1'b0;
    end else begin
        if (imem_req_ack_stall == '0) begin
            imem_req_ack_rnd <= $random;
        end else begin
            imem_req_ack_stall <= {imem_req_ack_stall[0], imem_req_ack_stall[31:1]};
        end
    end
end

assign imem_req_ack_i = (imem_req_ack_stall == 32'd0) ?  imem_req_ack_rnd : imem_req_ack_stall[0];


//-------------------------------------------------------------------------------
// Address data generation
//-------------------------------------------------------------------------------
assign imem_wr_hazard = '0;
logic       wbd_imem_stb_l;
logic [9:0] imem_bl_cnt;
logic [31:0] imem_ptr;

wire wbd_imem_stb_pedge = (wbd_imem_stb_l == 1'b0) && wbd_imem_stb_i;
always @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
	wbd_imem_stb_l   = '0;
        wbd_imem_lack_o  = 1'b0;
	imem_bl_cnt      = 10'h1;
	imem_ptr         = 0;
        wbd_imem_dat_o   = 'x;
	wbd_imem_ack_o   = 1'b0;
    end else begin
	wbd_imem_stb_l   = wbd_imem_stb_i;
	if(wbd_imem_stb_pedge) begin
	    imem_bl_cnt    = 10'h1;
	    imem_ptr       =  {wbd_imem_adr_i[YCR_WB_WIDTH-1:2], 2'b00};
	end
        if (wbd_imem_stb_i && wbd_imem_we_i == 1'b0 && imem_req_ack_i && wbd_imem_bry_i && !wbd_imem_lack_o) begin // IMEM has only Read access
             if(mirage_rangeen & wbd_imem_adr_i>=mirage_adrlo & wbd_imem_adr_i<mirage_adrhi)
                 wbd_imem_dat_o = ycr_read_mem(imem_ptr, wbd_imem_sel_i, imem_wr_hazard, wbd_dmem_dat_i, 1'b1);
             else
                 wbd_imem_dat_o = ycr_read_mem(imem_ptr, wbd_imem_sel_i, imem_wr_hazard, wbd_dmem_dat_i, 1'b0);
	    wbd_imem_ack_o = #1 1'b1;

	    if(wbd_imem_bl_i == imem_bl_cnt)
                wbd_imem_lack_o   = #1 1'b1;

	    imem_bl_cnt    = imem_bl_cnt+1;
	    imem_ptr       = imem_ptr +4;
        end else begin
                wbd_imem_dat_o  = #1 'x;
	        wbd_imem_ack_o  = #1 1'b0;
                wbd_imem_lack_o = #1 1'b0;
        end
    end
end


//-------------------------------------------------------------------------------
// Data memory ready
//-------------------------------------------------------------------------------
always_ff @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
        dmem_req_ack_stall <= dmem_req_ack_stall_in;
        dmem_req_ack_rnd   <= 1'b0;
    end else begin
        if (dmem_req_ack_stall == 32'd0) begin
            dmem_req_ack_rnd <= $random;
        end else begin
            dmem_req_ack_stall <= {dmem_req_ack_stall[0], dmem_req_ack_stall[31:1]};
        end
    end
end

assign dmem_req_ack = (dmem_req_ack_stall == 32'd0) ?  dmem_req_ack_rnd : dmem_req_ack_stall[0];

//-------------------------------------------------------------------------------
// Address command latch
//-------------------------------------------------------------------------------
logic       wbd_dmem_stb_l;
logic [9:0] dmem_bl_cnt;
logic [31:0]dmem_ptr;

assign dmem_wr_hazard = '0;
wire wbd_dmem_stb_pedge = (wbd_dmem_stb_l == 1'b0) && wbd_dmem_stb_i;

// DMEM Write and Read
always @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
	wbd_dmem_stb_l   = '0;
        wbd_dmem_ack_o   = 1'b0;
        wbd_dmem_lack_o  = 1'b0;
        wbd_dmem_dat_o   = 'x;
	dmem_bl_cnt      = 10'h1;
	dmem_ptr         = 0;
        soft_irq_reg   = '0;
`ifdef YCR_IPIC_EN
        irq_lines_reg  = '0;
`else // YCR_IPIC_EN
        ext_irq_reg    = '0;
`endif // YCR_IPIC_EN
     // Memory init moved to test bench
     // if (test_file_init) $readmemh(test_file, memory);
    end else begin
	wbd_dmem_stb_l   = wbd_dmem_stb_i;
	if(wbd_dmem_stb_pedge) begin
	    dmem_bl_cnt    = 10'h1;
	    dmem_ptr       =  {wbd_dmem_adr_i[YCR_WB_WIDTH-1:2], 2'b00};
	end
        if (wbd_dmem_stb_i && dmem_req_ack && ~wbd_dmem_we_i && !wbd_dmem_lack_o) begin
            case (wbd_dmem_adr_i)
                  // Reading Soft IRQ value
               YCR_SIM_SOFT_IRQ_ADDR : begin
                  wbd_dmem_dat_o    = '0;
                  wbd_dmem_dat_o[0] = soft_irq_reg;
               end
`ifdef YCR_IPIC_EN
                  // Reading IRQ Lines values
               YCR_SIM_EXT_IRQ_ADDR : begin
                  wbd_dmem_dat_o = '0;
                  wbd_dmem_dat_o[YCR_IRQ_LINES_NUM-1:0] <= irq_lines_reg;
               end
`else // YCR_IPIC_EN
                 // Reading External IRQ value
              YCR_SIM_EXT_IRQ_ADDR : begin
                 wbd_dmem_dat_o    = '0;
                 wbd_dmem_dat_o[0] = ext_irq_reg;
              end
`endif // YCR_IPIC_EN
             // Regular read operation
             default : begin
                if(mirage_rangeen & wbd_dmem_adr_i>=mirage_adrlo & wbd_dmem_adr_i<mirage_adrhi)
                   wbd_dmem_dat_o = ycr_read_mem(dmem_ptr, wbd_dmem_sel_i, dmem_wr_hazard, wbd_dmem_dat_i, 1'b1);
                else
                   wbd_dmem_dat_o = ycr_read_mem(dmem_ptr, wbd_dmem_sel_i, dmem_wr_hazard, wbd_dmem_dat_i, 1'b0);
             end
            endcase
	end
        if (wbd_dmem_stb_i && dmem_req_ack && wbd_dmem_we_i && !wbd_dmem_lack_o) begin
            case (wbd_dmem_adr_i)
                // Printing character in the simulation console
                YCR_SIM_PRINT_ADDR : begin
                    $write("%c", wbd_dmem_dat_i[7:0]);
                end
                // Writing Soft IRQ value
                YCR_SIM_SOFT_IRQ_ADDR : begin
                    soft_irq_reg = wbd_dmem_dat_i[0];
                end
`ifdef YCR_IPIC_EN
                // Writing IRQ Lines values
                YCR_SIM_EXT_IRQ_ADDR : begin
                    irq_lines_reg = wbd_dmem_dat_i[YCR_IRQ_LINES_NUM-1:0];
                end
`else // YCR_IPIC_EN
                // Writing External IRQ value
                YCR_SIM_EXT_IRQ_ADDR : begin
                    ext_irq_reg = wbd_dmem_dat_i[0];
                end
`endif // YCR_IPIC_EN
                // Regular write operation
                default : begin
                    if(mirage_rangeen & dmem_ptr >=mirage_adrlo & dmem_ptr<mirage_adrhi)
                        ycr_write_mem(dmem_ptr, wbd_dmem_sel_i, wbd_dmem_dat_i, 1'b1);
                    else
                        ycr_write_mem(dmem_ptr, wbd_dmem_sel_i, wbd_dmem_dat_i, 1'b0);
                end
            endcase
        end
        if (wbd_dmem_stb_i && dmem_req_ack && !wbd_dmem_lack_o) begin
	    wbd_dmem_ack_o = #1 1'b1;
	    if(wbd_dmem_bl_i == dmem_bl_cnt)
                wbd_dmem_lack_o   = #1 1'b1;

	    dmem_bl_cnt    = dmem_bl_cnt+1;
	    dmem_ptr       = dmem_ptr +4;
        end else begin
                wbd_dmem_dat_o  = #1 'x;
	        wbd_dmem_ack_o  = #1 1'b0;
                wbd_dmem_lack_o = #1 1'b0;
        end
    end
end



`ifdef YCR_IPIC_EN
assign irq_lines = irq_lines_reg;
`else // YCR_IPIC_EN
assign ext_irq = ext_irq_reg;
`endif // YCR_IPIC_EN
assign soft_irq = soft_irq_reg;

endmodule : ycr_memory_tb_wb
