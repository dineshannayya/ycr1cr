/// @file       <ycr_memory_tb_ahb.sv>
/// @brief      AHB memory testbench
///

`include "ycr_arch_description.svh"
`include "ycr_ahb.svh"
`include "ycr_ipic.svh"

module ycr_memory_tb_ahb #(
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
    input   integer                                 imem_req_ack_stall_in,
    input   integer                                 dmem_req_ack_stall_in,

    // Instruction Memory Interface
    // input   logic   [3:0]                           imem_hprot,
    // input   logic   [2:0]                           imem_hburst,
    input   logic   [2:0]                           imem_hsize,
    input   logic   [1:0]                           imem_htrans,
    input   logic   [YCR_AHB_WIDTH-1:0]            imem_haddr,
    output  logic                                   imem_hready,
    output  logic   [YCR_AHB_WIDTH-1:0]            imem_hrdata,
    output  logic                                   imem_hresp,

    // Memory Interface
    // input   logic   [3:0]                           dmem_hprot,
    // input   logic   [2:0]                           dmem_hburst,
    input   logic   [2:0]                           dmem_hsize,
    input   logic   [1:0]                           dmem_htrans,
    input   logic   [YCR_AHB_WIDTH-1:0]            dmem_haddr,
    input   logic                                   dmem_hwrite,
    input   logic   [YCR_AHB_WIDTH-1:0]            dmem_hwdata,
    output  logic                                   dmem_hready,
    output  logic   [YCR_AHB_WIDTH-1:0]            dmem_hrdata,
    output  logic                                   dmem_hresp
);

//-------------------------------------------------------------------------------
// Local Types
//-------------------------------------------------------------------------------
typedef enum logic {
    YCR_AHB_STATE_IDLE = 1'b0,
    YCR_AHB_STATE_DATA = 1'b1,
    YCR_AHB_STATE_ERR  = 1'bx
} type_ycr_ahb_state_e;

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
bit [YCR_AHB_WIDTH-1:0]                mirage_adrlo = '1;
bit [YCR_AHB_WIDTH-1:0]                mirage_adrhi = '1;

`ifdef VERILATOR
logic [255:0]                           test_file;
`else // VERILATOR
string                                  test_file;
`endif // VERILATOR
bit                                     test_file_init;

//-------------------------------------------------------------------------------
// Local functions
//-------------------------------------------------------------------------------
function logic [YCR_AHB_WIDTH-1:0] ycr_read_mem(
    logic   [YCR_AHB_WIDTH-1:0]    addr,
    logic   [3:0]                   r_be,
    logic   [3:0]                   w_hazard,
    logic   [YCR_AHB_WIDTH-1:0]    w_data,
    bit                             mirage_en
);
    logic [YCR_AHB_WIDTH-1:0]      tmp;
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
    return tmp;
end
endfunction : ycr_read_mem

function void ycr_write_mem(
    logic   [YCR_AHB_WIDTH-1:0]    addr,
    logic   [3:0]                   w_be,
    logic   [YCR_AHB_WIDTH-1:0]    data,
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

function logic [3:0] ycr_be_form(
    input   logic [1:0]     offset,
    input   logic [1:0]     hsize
);
    logic [3:0]     tmp;
begin
    case (hsize)
        YCR_HSIZE_8B : begin
            tmp = 4'b0001 << offset;
        end
        YCR_HSIZE_16B : begin
            tmp = 4'b0011 << offset;
        end
        YCR_HSIZE_32B : begin
            tmp = 4'b1111;
        end
    endcase
    return tmp;
end
endfunction : ycr_be_form

//-------------------------------------------------------------------------------
// Local signal declaration
//-------------------------------------------------------------------------------
// IMEM access
type_ycr_ahb_state_e           imem_ahb_state;
logic   [YCR_AHB_WIDTH-1:0]    imem_ahb_addr;
logic   [YCR_AHB_WIDTH-1:0]    imem_req_ack_stall;
bit                             imem_req_ack_rnd;
logic                           imem_req_ack;
logic                           imem_req_ack_nc;
logic   [3:0]                   imem_be;
logic   [YCR_AHB_WIDTH-1:0]    imem_hrdata_l;
logic   [3:0]                   imem_wr_hazard;

// DMEM access
logic   [YCR_AHB_WIDTH-1:0]    dmem_req_ack_stall;
bit                             dmem_req_ack_rnd;
logic                           dmem_req_ack;
logic                           dmem_req_ack_nc;
logic   [3:0]                   dmem_be;
type_ycr_ahb_state_e           dmem_ahb_state;
logic   [YCR_AHB_WIDTH-1:0]    dmem_ahb_addr;
logic                           dmem_ahb_wr;
logic   [2:0]                   dmem_ahb_size;
logic   [3:0]                   dmem_ahb_be;
logic   [YCR_AHB_WIDTH-1:0]    dmem_hrdata_l;
logic   [3:0]                   dmem_wr_hazard;

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

assign imem_req_ack = (imem_req_ack_stall == 32'd0) ?  imem_req_ack_rnd : imem_req_ack_stall[0];

//-------------------------------------------------------------------------------
// Instruction memory AHB FSM
//-------------------------------------------------------------------------------
always_ff @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
        imem_ahb_state <= YCR_AHB_STATE_IDLE;
    end else begin
        case (imem_ahb_state)
            YCR_AHB_STATE_IDLE : begin
                if (imem_req_ack) begin
                    case (imem_htrans)
                        YCR_HTRANS_IDLE : begin
                            imem_ahb_state <= YCR_AHB_STATE_IDLE;
                        end
                        YCR_HTRANS_NONSEQ : begin
                            imem_ahb_state <= YCR_AHB_STATE_DATA;
                        end
                        default : begin
                            imem_ahb_state <= YCR_AHB_STATE_ERR;
                        end
                    endcase
                end
            end
            YCR_AHB_STATE_DATA : begin
                if (imem_req_ack) begin
                    case (imem_htrans)
                        YCR_HTRANS_IDLE : begin
                            imem_ahb_state <= YCR_AHB_STATE_IDLE;
                        end
                        YCR_HTRANS_NONSEQ : begin
                            imem_ahb_state <= YCR_AHB_STATE_DATA;
                        end
                        default : begin
                            imem_ahb_state <= YCR_AHB_STATE_ERR;
                        end
                    endcase
                end
            end
            default : begin
                imem_ahb_state <= YCR_AHB_STATE_ERR;
            end
        endcase
    end
end

//-------------------------------------------------------------------------------
// Address data generation
//-------------------------------------------------------------------------------
assign imem_be = ycr_be_form(2'b00, imem_hsize);
assign imem_wr_hazard = (dmem_ahb_wr & (imem_haddr[YCR_AHB_WIDTH-1:2] == dmem_ahb_addr[YCR_AHB_WIDTH-1:2])) ? imem_be & dmem_ahb_be : '0;

always_ff @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
        imem_ahb_addr  <= 'x;
        imem_hrdata_l  <= 'x;
    end else begin
        case (imem_ahb_state)
            YCR_AHB_STATE_IDLE : begin
                if (imem_req_ack) begin
                    case (imem_htrans)
                        YCR_HTRANS_IDLE : begin
                        end
                        YCR_HTRANS_NONSEQ : begin
                            imem_ahb_addr  <= imem_haddr;
                            if(mirage_rangeen & imem_haddr>=mirage_adrlo & imem_haddr<mirage_adrhi)
                                imem_hrdata_l <= ycr_read_mem({imem_haddr[YCR_AHB_WIDTH-1:2], 2'b00}, imem_be, imem_wr_hazard, dmem_hwdata, 1'b1);
                            else
                                imem_hrdata_l <= ycr_read_mem({imem_haddr[YCR_AHB_WIDTH-1:2], 2'b00}, imem_be, imem_wr_hazard, dmem_hwdata, 1'b0);
                        end
                        default : begin
                            imem_ahb_addr  <= 'x;
                            imem_hrdata_l  <= 'x;
                        end
                    endcase
                end
            end
            YCR_AHB_STATE_DATA : begin
                if (imem_req_ack) begin
                    case (imem_htrans)
                        YCR_HTRANS_IDLE : begin
                            imem_ahb_addr  <= 'x;
                            imem_hrdata_l  <= 'x;
                        end
                        YCR_HTRANS_NONSEQ : begin
                            imem_ahb_addr  <= imem_haddr;
                            if(mirage_rangeen & imem_haddr>=mirage_adrlo & imem_haddr<mirage_adrhi)
                                imem_hrdata_l <= ycr_read_mem({imem_haddr[YCR_AHB_WIDTH-1:2], 2'b00}, imem_be, imem_wr_hazard, dmem_hwdata, 1'b1);
                            else
                                imem_hrdata_l <= ycr_read_mem({imem_haddr[YCR_AHB_WIDTH-1:2], 2'b00}, imem_be, imem_wr_hazard, dmem_hwdata, 1'b0);
                        end
                        default : begin
                            imem_ahb_addr  <= 'x;
                            imem_hrdata_l  <= 'x;
                        end
                    endcase
                end
            end
            default : begin
                imem_ahb_addr  <= 'x;
                imem_hrdata_l  <= 'x;
            end
        endcase
    end
end

//-------------------------------------------------------------------------------
// Instruction Memory response
//-------------------------------------------------------------------------------
always_comb begin
    imem_hready = 1'b0;
    imem_hresp  = YCR_HRESP_ERROR;
    imem_hrdata = 'x;
    case (imem_ahb_state)
        YCR_AHB_STATE_IDLE : begin
            if (imem_req_ack) begin
                imem_hready = 1'b1;
            end
        end
        YCR_AHB_STATE_DATA : begin
            if (imem_req_ack) begin
                imem_hready = 1'b1;

                imem_hresp  = YCR_HRESP_OKAY;
                imem_hrdata = imem_hrdata_l;
            end
        end
        default : begin
        end
    endcase
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
// Data memory AHB FSM
//-------------------------------------------------------------------------------
always_ff @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
        dmem_ahb_state <= YCR_AHB_STATE_IDLE;
    end else begin
        case (dmem_ahb_state)
            YCR_AHB_STATE_IDLE : begin
                if (dmem_req_ack) begin
                    case (dmem_htrans)
                        YCR_HTRANS_IDLE : begin
                            dmem_ahb_state <= YCR_AHB_STATE_IDLE;
                        end
                        YCR_HTRANS_NONSEQ : begin
                            dmem_ahb_state    <= YCR_AHB_STATE_DATA;
                        end
                        default : begin
                            dmem_ahb_state    <= YCR_AHB_STATE_ERR;
                        end
                    endcase
                end
            end
            YCR_AHB_STATE_DATA : begin
                if (dmem_req_ack) begin
                    case (dmem_htrans)
                        YCR_HTRANS_IDLE : begin
                            dmem_ahb_state    <= YCR_AHB_STATE_IDLE;
                        end
                        YCR_HTRANS_NONSEQ : begin
                            if (~dmem_hwrite) begin
                                case (dmem_haddr)
                                    YCR_SIM_SOFT_IRQ_ADDR,
                                    YCR_SIM_EXT_IRQ_ADDR
                                    : begin
                                        // Skip access, switch to YCR_AHB_STATE_IDLE
                                        dmem_ahb_state    <= YCR_AHB_STATE_IDLE;
                                    end
                                    default : begin
                                        dmem_ahb_state    <= YCR_AHB_STATE_DATA;
                                    end
                                endcase
                            end
                        end
                        default : begin
                            dmem_ahb_state    <= YCR_AHB_STATE_ERR;
                        end
                    endcase
                end
            end
            default : begin
                dmem_ahb_state    <= YCR_AHB_STATE_ERR;
            end
        endcase
    end
end

//-------------------------------------------------------------------------------
// Address command latch
//-------------------------------------------------------------------------------
assign dmem_be = ycr_be_form(dmem_haddr[1:0], dmem_hsize);
assign dmem_wr_hazard = (dmem_ahb_wr & (dmem_haddr[YCR_AHB_WIDTH-1:2] == dmem_ahb_addr[YCR_AHB_WIDTH-1:2])) ? dmem_be & dmem_ahb_be : '0;
always_ff @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
        dmem_ahb_addr  <= 'x;
        dmem_ahb_wr    <= 1'b0;
        dmem_ahb_size  <= YCR_HSIZE_ERR;
        dmem_ahb_be    <= '0;
    end else begin
        case (dmem_ahb_state)
            YCR_AHB_STATE_IDLE : begin
                if (dmem_req_ack) begin
                    case (dmem_htrans)
                        YCR_HTRANS_IDLE : begin
                        end
                        YCR_HTRANS_NONSEQ : begin
                            dmem_ahb_addr <= dmem_haddr;
                            dmem_ahb_wr   <= dmem_hwrite;
                            dmem_ahb_size <= dmem_hsize;
                            dmem_ahb_be   <= dmem_be;
                            if (~dmem_hwrite) begin
                                case (dmem_haddr)
                                    // Reading Soft IRQ value
                                    YCR_SIM_SOFT_IRQ_ADDR : begin
                                        dmem_hrdata_l <= '0;
                                        dmem_hrdata_l[0] <= soft_irq_reg;
                                    end
`ifdef YCR_IPIC_EN
                                    // Reading IRQ Lines values
                                    YCR_SIM_EXT_IRQ_ADDR : begin
                                        dmem_hrdata_l <= '0;
                                        dmem_hrdata_l[YCR_IRQ_LINES_NUM-1:0] <= irq_lines_reg;
                                    end
`else // YCR_IPIC_EN
                                    // Reading External IRQ value
                                    YCR_SIM_EXT_IRQ_ADDR : begin
                                        dmem_hrdata_l <= '0;
                                        dmem_hrdata_l[0] <= ext_irq_reg;
                                    end
`endif // YCR_IPIC_EN
                                    // Regular read operation
                                    default : begin
                                        if(mirage_rangeen & dmem_haddr>=mirage_adrlo & dmem_haddr<mirage_adrhi)
                                            dmem_hrdata_l <= ycr_read_mem({dmem_haddr[YCR_AHB_WIDTH-1:2], 2'b00}, dmem_be, dmem_wr_hazard, dmem_hwdata, 1'b1);
                                        else
                                            dmem_hrdata_l <= ycr_read_mem({dmem_haddr[YCR_AHB_WIDTH-1:2], 2'b00}, dmem_be, dmem_wr_hazard, dmem_hwdata, 1'b0);
                                    end
                                endcase
                            end
                        end
                        default : begin
                            dmem_ahb_addr  <= 'x;
                            dmem_ahb_wr    <= 'x;
                            dmem_ahb_size  <= YCR_HSIZE_ERR;
                            dmem_hrdata_l  <= 'x;
                        end
                    endcase
                end
            end
            YCR_AHB_STATE_DATA : begin
                if (dmem_req_ack) begin
                    case (dmem_htrans)
                        YCR_HTRANS_IDLE : begin
                            dmem_ahb_addr     <= 'x;
                            dmem_ahb_wr       <= 1'b0;
                            dmem_ahb_size     <= YCR_HSIZE_ERR;
                        end
                        YCR_HTRANS_NONSEQ : begin
                            dmem_ahb_addr <= dmem_haddr;
                            dmem_ahb_wr   <= dmem_hwrite;
                            dmem_ahb_size <= dmem_hsize;
                            dmem_ahb_be   <= dmem_be;
                            if (~dmem_hwrite) begin
                                case (dmem_haddr)
                                    YCR_SIM_SOFT_IRQ_ADDR,
                                    YCR_SIM_EXT_IRQ_ADDR
                                    : begin
                                        // Skip access, switch to YCR_AHB_STATE_IDLE
                                    end
                                    default : begin
                                        if(mirage_rangeen & dmem_haddr>=mirage_adrlo & dmem_haddr<mirage_adrhi)
                                            dmem_hrdata_l <= ycr_read_mem({dmem_haddr[YCR_AHB_WIDTH-1:2], 2'b00}, dmem_be, dmem_wr_hazard, dmem_hwdata, 1'b1);
                                        else
                                            dmem_hrdata_l <= ycr_read_mem({dmem_haddr[YCR_AHB_WIDTH-1:2], 2'b00}, dmem_be, dmem_wr_hazard, dmem_hwdata, 1'b0);
                                    end
                                endcase
                            end
                        end
                        default : begin
                            dmem_ahb_addr  <= 'x;
                            dmem_ahb_wr    <= 'x;
                            dmem_ahb_size  <= YCR_HSIZE_ERR;
                            dmem_ahb_be    <= 'x;
                            dmem_hrdata_l  <= 'x;
                        end
                    endcase
                end
            end
            default : begin
                dmem_ahb_addr  <= 'x;
                dmem_ahb_wr    <= 'x;
                dmem_ahb_size  <= YCR_HSIZE_ERR;
                dmem_hrdata_l  <= 'x;
            end
        endcase
    end
end

//-------------------------------------------------------------------------------
// Data Memory response
//-------------------------------------------------------------------------------
always_comb begin
    dmem_hready = 1'b0;
    dmem_hresp  = YCR_HRESP_ERROR;
    dmem_hrdata = 'x;
    case (dmem_ahb_state)
        YCR_AHB_STATE_IDLE : begin
            if (dmem_req_ack) begin
                dmem_hready = 1'b1;
            end
        end
        YCR_AHB_STATE_DATA : begin
            if (dmem_req_ack) begin
                dmem_hready = 1'b1;
                dmem_hresp  = YCR_HRESP_OKAY;
                if (~dmem_ahb_wr) begin
                    dmem_hrdata = dmem_hrdata_l;
                end
            end
        end
        default : begin
        end
    endcase
end

//-------------------------------------------------------------------------------
// Data Memory write
//-------------------------------------------------------------------------------
always @(negedge rst_n, posedge clk) begin
    if (~rst_n) begin
        soft_irq_reg   <= '0;
`ifdef YCR_IPIC_EN
        irq_lines_reg  <= '0;
`else // YCR_IPIC_EN
        ext_irq_reg    <= '0;
`endif // YCR_IPIC_EN
        if (test_file_init) $readmemh(test_file, memory);
    end else begin
        if ((dmem_ahb_state == YCR_AHB_STATE_DATA) & dmem_req_ack & dmem_ahb_wr) begin
            case (dmem_ahb_addr)
                // Printing character in the simulation console
                YCR_SIM_PRINT_ADDR : begin
                    $write("%c", dmem_hwdata[7:0]);
                end
                // Writing Soft IRQ value
                YCR_SIM_SOFT_IRQ_ADDR : begin
                    soft_irq_reg <= dmem_hwdata[0];
                end
`ifdef YCR_IPIC_EN
                // Writing IRQ Lines values
                YCR_SIM_EXT_IRQ_ADDR : begin
                    irq_lines_reg <= dmem_hwdata[YCR_IRQ_LINES_NUM-1:0];
                end
`else // YCR_IPIC_EN
                // Writing External IRQ value
                YCR_SIM_EXT_IRQ_ADDR : begin
                    ext_irq_reg <= dmem_hwdata[0];
                end
`endif // YCR_IPIC_EN
                // Regular write operation
                default : begin
                    if(mirage_rangeen & dmem_ahb_addr>=mirage_adrlo & dmem_ahb_addr<mirage_adrhi)
                        ycr_write_mem({dmem_ahb_addr[YCR_AHB_WIDTH-1:2], 2'b00}, dmem_ahb_be, dmem_hwdata, 1'b1);
                    else
                        ycr_write_mem({dmem_ahb_addr[YCR_AHB_WIDTH-1:2], 2'b00}, dmem_ahb_be, dmem_hwdata, 1'b0);
                end
            endcase
        end
    end
end

`ifdef YCR_IPIC_EN
assign irq_lines = irq_lines_reg;
`else // YCR_IPIC_EN
assign ext_irq = ext_irq_reg;
`endif // YCR_IPIC_EN
assign soft_irq = soft_irq_reg;

endmodule : ycr_memory_tb_ahb
