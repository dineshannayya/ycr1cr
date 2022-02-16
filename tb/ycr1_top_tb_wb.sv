/// @file       <ycr1_top_tb_ahb.sv>
/// @brief      YCR1 top testbench Wishbone
///

`include "ycr1_arch_description.svh"
`include "ycr1_ahb.svh"
`ifdef YCR1_IPIC_EN
`include "ycr1_ipic.svh"
`endif // YCR1_IPIC_EN

`include "uprj_netlists.v"
`include "ycr1_memory_tb_wb.sv"
`include "ycr1_dmem_tb_wb.sv"
`include "sky130_sram_2kbyte_1rw1r_32x512_8.v"
`include "DFFRAM.v"

localparam [31:0]      YCR1_SIM_EXIT_ADDR      = 32'h0000_00F8;
localparam [31:0]      YCR1_SIM_PRINT_ADDR     = 32'hF000_0000;
localparam [31:0]      YCR1_SIM_EXT_IRQ_ADDR   = 32'hF000_0100;
localparam [31:0]      YCR1_SIM_SOFT_IRQ_ADDR  = 32'hF000_0200;

module ycr1_top_tb_wb (
`ifdef VERILATOR
    input logic clk
`endif // VERILATOR
);

//-------------------------------------------------------------------------------
// Local parameters
//-------------------------------------------------------------------------------
localparam                          YCR1_MEM_SIZE       = 1024*1024;

//-------------------------------------------------------------------------------
// Local signal declaration
//-------------------------------------------------------------------------------
logic                                   rst_n;
`ifndef VERILATOR
logic                                   clk         = 1'b0;
`endif // VERILATOR
logic                                   rtc_clk     = 1'b0;
`ifdef YCR1_IPIC_EN
logic [YCR1_IRQ_LINES_NUM-1:0]          irq_lines;
`else // YCR1_IPIC_EN
logic                                   ext_irq;
`endif // YCR1_IPIC_EN
logic                                   soft_irq;
logic [31:0]                            fuse_mhartid;
integer                                 imem_req_ack_stall;
integer                                 dmem_req_ack_stall;

logic                                   test_mode   = 1'b0;
`ifdef YCR1_DBG_EN
logic                                   trst_n;
logic                                   tck;
logic                                   tms;
logic                                   tdi;
logic                                   tdo;
logic                                   tdo_en;
`endif // YCR1_DBG_EN
logic                                   wb_rst_n;       // Wish bone reset
logic                                   wb_clk = 1'b0;  // wish bone clock
// Instruction Memory Interface
logic                                   wbd_imem_stb_o; // strobe/request
logic   [YCR1_WB_WIDTH-1:0]             wbd_imem_adr_o; // address
logic                                   wbd_imem_we_o;  // write
logic   [YCR1_WB_WIDTH-1:0]             wbd_imem_dat_o; // data output
logic   [3:0]                           wbd_imem_sel_o; // byte enable
logic   [YCR1_WB_WIDTH-1:0]             wbd_imem_dat_i; // data input
logic                                   wbd_imem_ack_i; // acknowlegement
logic                                   wbd_imem_err_i;  // error

// Data Memory Interface
logic                                   wbd_dmem_stb_o; // strobe/request
logic   [YCR1_WB_WIDTH-1:0]             wbd_dmem_adr_o; // address
logic                                   wbd_dmem_we_o;  // write
logic   [YCR1_WB_WIDTH-1:0]             wbd_dmem_dat_o; // data output
logic   [3:0]                           wbd_dmem_sel_o; // byte enable
logic   [YCR1_WB_WIDTH-1:0]             wbd_dmem_dat_i; // data input
logic                                   wbd_dmem_ack_i; // acknowlegement
logic                                   wbd_dmem_err_i; // error

int unsigned                            f_results     ;
int unsigned                            f_info        ;

string                                  s_results     ;
string                                  s_info        ;
`ifdef SIGNATURE_OUT
string                                  s_testname    ;
bit                                     b_single_run_flag;
`endif  //  SIGNATURE_OUT
`ifdef VERILATOR
logic [255:0]                           test_file     ;
logic [255:0]                           test_ram_file;
`else // VERILATOR
string                                  test_file     ;
string                                  test_ram_file;
`endif // VERILATOR

bit                                     test_running  ;
int unsigned                            tests_passed  ;
int unsigned                            tests_total   ;

bit [1:0]                               rst_cnt       ;
bit                                     rst_init      ;
logic [31:0] riscv_dmem_req_cnt; // cnt dmem req
event	                                reinit_event;
logic  [31:0]                           tem_mem[0:1047];

`ifndef YCR1_TCM_MEM
  // DFFRAM I/F

   logic                             tcm_dffram_clk0    ; // CLK
   logic                             tcm_dffram_cs0     ; // Chip Select
   logic    [7:0]                    tcm_dffram_addr0   ; // Address
   logic    [3:0]                    tcm_dffram_wmask0  ; // Write Mask
   logic    [31:0]                   tcm_dffram_din0    ; // Write Data
   logic    [31:0]                   tcm_dffram_dout0   ; // Read Data
   
   logic                             tcm_dffram_clk1    ; // CLK
   logic                             tcm_dffram_cs1     ; // Chip Select
   logic    [7:0]                    tcm_dffram_addr1   ; // Address
   logic    [3:0]                    tcm_dffram_wmask1  ; // Write Mask
   logic    [31:0]                   tcm_dffram_din1    ; // Write Data
   logic    [31:0]                   tcm_dffram_dout1   ; // Read Data
`endif

`ifdef YCR1_ICACHE_EN
   // Wishbone ICACHE I/F
   logic                             wb_icache_stb_o; // strobe/request
   logic   [YCR1_WB_WIDTH-1:0]       wb_icache_adr_o; // address
   logic                             wb_icache_we_o;  // write
   logic   [YCR1_WB_WIDTH-1:0]       wb_icache_dat_o; // data output
   logic   [3:0]                     wb_icache_sel_o; // byte enable
   logic   [9:0]                     wb_icache_bl_o;  // Burst Length
   logic                             wb_icache_bry_o; // Burst Length

   logic   [YCR1_WB_WIDTH-1:0]       wb_icache_dat_i; // data input
   logic                             wb_icache_ack_i; // acknowlegement
   logic                             wb_icache_lack_i;// last acknowlegement
   logic                             wb_icache_err_i;  // error

  // DFFRAM I/F

   logic                             icache_dffram_clk0    ; // CLK
   logic                             icache_dffram_cs0     ; // Chip Select
   logic    [7:0]                    icache_dffram_addr0   ; // Address
   logic    [3:0]                    icache_dffram_wmask0  ; // Write Mask
   logic    [31:0]                   icache_dffram_din0    ; // Write Data
   logic    [31:0]                   icache_dffram_dout0   ; // Read Data
   
   logic                             icache_dffram_clk1    ; // CLK
   logic                             icache_dffram_cs1     ; // Chip Select
   logic    [7:0]                    icache_dffram_addr1   ; // Address
   logic    [3:0]                    icache_dffram_wmask1  ; // Write Mask
   logic    [31:0]                   icache_dffram_din1    ; // Write Data
   logic    [31:0]                   icache_dffram_dout1   ; // Read Data

`endif

`ifdef YCR1_DCACHE_EN
   // Wishbone ICACHE I/F
   logic                             wb_dcache_stb_o; // strobe/request
   logic   [YCR1_WB_WIDTH-1:0]       wb_dcache_adr_o; // address
   logic                             wb_dcache_we_o;  // write
   logic   [YCR1_WB_WIDTH-1:0]       wb_dcache_dat_o; // data output
   logic   [3:0]                     wb_dcache_sel_o; // byte enable
   logic   [9:0]                     wb_dcache_bl_o;  // Burst Length
   logic                             wb_dcache_bry_o; // Burst Ready

   logic   [YCR1_WB_WIDTH-1:0]       wb_dcache_dat_i; // data input
   logic                             wb_dcache_ack_i; // acknowlegement
   logic                             wb_dcache_lack_i;// last acknowlegement
   logic                             wb_dcache_err_i;  // error

    // DFFRAM I/F

   logic                             dcache_dffram_clk0    ; // CLK
   logic                             dcache_dffram_cs0     ; // Chip Select
   logic    [7:0]                    dcache_dffram_addr0   ; // Address
   logic    [3:0]                    dcache_dffram_wmask0  ; // Write Mask
   logic    [31:0]                   dcache_dffram_din0    ; // Write Data
   logic    [31:0]                   dcache_dffram_dout0   ; // Read Data
   
   logic                             dcache_dffram_clk1    ; // CLK
   logic                             dcache_dffram_cs1     ; // Chip Select
   logic    [7:0]                    dcache_dffram_addr1   ; // Address
   logic    [3:0]                    dcache_dffram_wmask1  ; // Write Mask
   logic    [31:0]                   dcache_dffram_din1    ; // Write Data
   logic    [31:0]                   dcache_dffram_dout1   ; // Read Data
`endif

`ifdef VERILATOR
function bit is_compliance (logic [255:0] testname);
    bit res;
    logic [79:0] pattern;
begin
    pattern = 80'h636f6d706c69616e6365; // compliance
    res = 0;
    for (int i = 0; i<= 176; i++) begin
        if(testname[i+:80] == pattern) begin
            return ~res;
        end
    end
    `ifdef SIGNATURE_OUT
        return ~res;
    `else
        return res;
    `endif
end
endfunction : is_compliance

function logic [255:0] get_filename (logic [255:0] testname);
logic [255:0] res;
int i, j;
begin
    testname[7:0] = 8'h66;
    testname[15:8] = 8'h6C;
    testname[23:16] = 8'h65;

    for (i = 0; i <= 248; i += 8) begin
        if (testname[i+:8] == 0) begin
            break;
        end
    end
    i -= 8;
    for (j = 255; i >= 0;i -= 8) begin
        res[j-:8] = testname[i+:8];
        j -= 8;
    end
    for (; j >= 0;j -= 8) begin
        res[j-:8] = 0;
    end

    return res;
end
endfunction : get_filename

function logic [255:0] get_ref_filename (logic [255:0] testname);
logic [255:0] res;
int i, j;
logic [79:0] pattern;
begin
    pattern = 80'h636f6d706c69616e6365; // compliance

    for(int i = 0; i <= 176; i++) begin
        if(testname[i+:80] == pattern) begin
            testname[(i-8)+:88] = 0;
            break;
        end
    end

    for(i = 32; i <= 248; i += 8) begin
        if(testname[i+:8] == 0) break;
    end
    i -= 8;
    for(j = 255; i > 24; i -= 8) begin
        res[j-:8] = testname[i+:8];
        j -= 8;
    end
    for(; j >=0;j -= 8) begin
        res[j-:8] = 0;
    end

    return res;
end
endfunction : get_ref_filename

function logic [2047:0] remove_trailing_whitespaces (logic [2047:0] str);
int i;
begin
    for (i = 0; i <= 2040; i += 8) begin
        if (str[i+:8] != 8'h20) begin
            break;
        end
    end
    str = str >> i;
    return str;
end
endfunction: remove_trailing_whitespaces

`else // VERILATOR
function bit is_compliance (string testname);
begin
    return (testname.substr(0, 9) == "compliance");
end
endfunction : is_compliance

function string get_filename (string testname);
int length;
begin
    length = testname.len();
    testname[length-1] = "f";
    testname[length-2] = "l";
    testname[length-3] = "e";

    return testname;
end
endfunction : get_filename

function string get_ref_filename (string testname);
begin
    return testname.substr(11, testname.len() - 5);
end
endfunction : get_ref_filename

`endif // VERILATOR

`ifndef VERILATOR
always #5   clk     = ~clk;         // 100 MHz
always #5   wb_clk  = ~wb_clk;      // 100 MHz
always #500 rtc_clk = ~rtc_clk;     // 1 MHz
`endif // VERILATOR

// Reset logic
assign rst_n = &rst_cnt;

always_ff @(posedge clk) begin
     if (rst_init)       begin
	rst_cnt <= '0;
	-> reinit_event;
    end
    else if (~&rst_cnt) rst_cnt <= rst_cnt + 1'b1;
end


`ifdef YCR1_DBG_EN
initial begin
    trst_n  = 1'b0;
    tck     = 1'b0;
    tdi     = 1'b0;
    #900ns trst_n   = 1'b1;
    #500ns tms      = 1'b1;
    #800ns tms      = 1'b0;
    #500ns trst_n   = 1'b0;
    #100ns tms      = 1'b1;
end
`endif // YCR1_DBG_EN


always @reinit_event
begin
   // Initialize the SPI memory with hex content
   // Wait for reset removal
   //wait (rst_n == 1);
   // some of the RISCV test need SRAM area for specific
   // instruction execution like fence
   //$sformat(test_ram_file, "%s.ram",test_file);
   //// Load the RAM content to local temp memory
   //$readmemh(test_ram_file,tem_mem);
   //// Split the Temp memory content to two sram file
   //$readmemh(test_ram_file,tem_mem);
   //$writememh("sram0.hex",tem_mem,0,511);
   //$writememh("sram1.hex",tem_mem,512,1023);
   //// Load the SRAM0/SRAM1 with 2KB data
   //$write("\033[0;34m---Initializing the u_tsram0_2kb Memory with Hexfile: sram0.hex\033[0m\n");
   //$readmemh("sram0.hex",u_tsram0_2kb.mem);
   //$write("\033[0;34m---Initializing the u_tsram1_2kb Memory with Hexfile: sram1.hex\033[0m\n");
   //$readmemh("sram1.hex",u_tsram1_2kb.mem);
   
   //for(i =32'h00; i < 32'h100; i = i+1)
   //    $display("Location: %x, Data: %x", i, u_tsram0_2kb.mem[i]);
end

//-------------------------------------------------------------------------------
// Run tests
//-------------------------------------------------------------------------------

`include "ycr1_top_tb_runtests.sv"
//-------------------------------------------------------------------------------
// Core instance
//-------------------------------------------------------------------------------
ycr1_top_wb i_top (
    // Reset
    .pwrup_rst_n            (rst_n                  ),
    .rst_n                  (rst_n                  ),
    .cpu_rst_n              (rst_n                  ),
`ifdef YCR1_DBG_EN
    .sys_rst_n_o            (                       ),
    .sys_rdc_qlfy_o         (                       ),
`endif // YCR1_DBG_EN

    // Clock
    .core_clk               (clk                    ),
    .rtc_clk                (rtc_clk                ),
    .riscv_debug            (                       ),

    // Fuses
    .fuse_mhartid           (fuse_mhartid           ),
`ifdef YCR1_DBG_EN
    .fuse_idcode            (`YCR1_TAP_IDCODE       ),
`endif // YCR1_DBG_EN

`ifndef YCR1_TCM_MEM
     // DFFRAM I/F
    .tcm_dffram_clk0                 (tcm_dffram_clk0    ), // CLK
    .tcm_dffram_cs0                  (tcm_dffram_cs0     ), // Chip Select
    .tcm_dffram_addr0                (tcm_dffram_addr0   ), // Address
    .tcm_dffram_wmask0               (tcm_dffram_wmask0  ), // Write Mask
    .tcm_dffram_din0                 (tcm_dffram_din0    ), // Write Data
    .tcm_dffram_dout0                (tcm_dffram_dout0   ), // Read Data
                                                         
    .tcm_dffram_clk1                 (tcm_dffram_clk1    ), // CLK
    .tcm_dffram_cs1                  (tcm_dffram_cs1     ), // Chip Select
    .tcm_dffram_addr1                (tcm_dffram_addr1   ), // Address
    .tcm_dffram_wmask1               (tcm_dffram_wmask1  ), // Write Mask
    .tcm_dffram_din1                 (tcm_dffram_din1    ), // Write Data
    .tcm_dffram_dout1                (tcm_dffram_dout1   ), // Read Data
`endif

    // IRQ
`ifdef YCR1_IPIC_EN
    .irq_lines              (irq_lines              ),
`else // YCR1_IPIC_EN
    .ext_irq                (ext_irq                ),
`endif // YCR1_IPIC_EN
    .soft_irq               (soft_irq               ),

    // DFT
    //.test_mode              (1'b0                   ),
    //.test_rst_n             (1'b1                   ),

`ifdef YCR1_DBG_EN
    // JTAG
    .trst_n                 (trst_n                 ),
    .tck                    (tck                    ),
    .tms                    (tms                    ),
    .tdi                    (tdi                    ),
    .tdo                    (tdo                    ),
    .tdo_en                 (tdo_en                 ),
`endif // YCR1_DBG_EN

    .wb_rst_n               (rst_n                  ),
    .wb_clk                 (clk                    ),
   `ifdef YCR1_ICACHE_EN
   // Wishbone ICACHE I/F
    .wb_icache_stb_o                    (wb_icache_stb_o  ), // strobe/request
    .wb_icache_adr_o                    (wb_icache_adr_o  ), // address
    .wb_icache_we_o                     (wb_icache_we_o   ),  // write
    .wb_icache_sel_o                    (wb_icache_sel_o  ), // byte enable
    .wb_icache_bl_o                     (wb_icache_bl_o   ),  // Burst Length
    .wb_icache_bry_o                    (wb_icache_bry_o  ),  // Burst Ready
                                                          
    .wb_icache_dat_i                    (wb_icache_dat_i  ), // data input
    .wb_icache_ack_i                    (wb_icache_ack_i  ), // acknowlegement
    .wb_icache_lack_i                   (wb_icache_lack_i ),// last acknowlegement
    .wb_icache_err_i                    (wb_icache_err_i  ),  // error

     // DFFRAM I/F
    .icache_dffram_clk0                 (icache_dffram_clk0    ), // CLK
    .icache_dffram_cs0                  (icache_dffram_cs0     ), // Chip Select
    .icache_dffram_addr0                (icache_dffram_addr0   ), // Address
    .icache_dffram_wmask0               (icache_dffram_wmask0  ), // Write Mask
    .icache_dffram_din0                 (icache_dffram_din0    ), // Write Data
    .icache_dffram_dout0                (icache_dffram_dout0   ), // Read Data
                                                         
    .icache_dffram_clk1                 (icache_dffram_clk1    ), // CLK
    .icache_dffram_cs1                  (icache_dffram_cs1     ), // Chip Select
    .icache_dffram_addr1                (icache_dffram_addr1   ), // Address
    .icache_dffram_wmask1               (icache_dffram_wmask1  ), // Write Mask
    .icache_dffram_din1                 (icache_dffram_din1    ), // Write Data
    .icache_dffram_dout1                (icache_dffram_dout1   ), // Read Data

   `endif

   `ifdef YCR1_DCACHE_EN
   // Wishbone DCACHE I/F
    .wb_dcache_stb_o                    (wb_dcache_stb_o  ), // strobe/request
    .wb_dcache_adr_o                    (wb_dcache_adr_o  ), // address
    .wb_dcache_we_o                     (wb_dcache_we_o   ), // write
    .wb_dcache_dat_o                    (wb_dcache_dat_o  ), // data output
    .wb_dcache_sel_o                    (wb_dcache_sel_o  ), // byte enable
    .wb_dcache_bl_o                     (wb_dcache_bl_o   ), // Burst Length
    .wb_dcache_bry_o                    (wb_dcache_bry_o   ), // Burst Ready
                                                          
    .wb_dcache_dat_i                    (wb_dcache_dat_i  ), // data input
    .wb_dcache_ack_i                    (wb_dcache_ack_i  ), // acknowlegement
    .wb_dcache_lack_i                   (wb_dcache_lack_i ),// last acknowlegement
    .wb_dcache_err_i                    (wb_dcache_err_i  ),  // error

     // DFFRAM I/F
    .dcache_dffram_clk0                 (dcache_dffram_clk0    ), // CLK
    .dcache_dffram_cs0                  (dcache_dffram_cs0     ), // Chip Select
    .dcache_dffram_addr0                (dcache_dffram_addr0   ), // Address
    .dcache_dffram_wmask0               (dcache_dffram_wmask0  ), // Write Mask
    .dcache_dffram_din0                 (dcache_dffram_din0    ), // Write Data
    .dcache_dffram_dout0                (dcache_dffram_dout0   ), // Read Data
                                                         
    .dcache_dffram_clk1                 (dcache_dffram_clk1    ), // CLK
    .dcache_dffram_cs1                  (dcache_dffram_cs1     ), // Chip Select
    .dcache_dffram_addr1                (dcache_dffram_addr1   ), // Address
    .dcache_dffram_wmask1               (dcache_dffram_wmask1  ), // Write Mask
    .dcache_dffram_din1                 (dcache_dffram_din1    ), // Write Data
    .dcache_dffram_dout1                (dcache_dffram_dout1   ), // Read Data

   `endif

    //.wbd_imem_stb_o         (wbd_imem_stb_o         ),
    //.wbd_imem_adr_o         (wbd_imem_adr_o         ),
    //.wbd_imem_we_o          (wbd_imem_we_o          ),
    //.wbd_imem_dat_o         (wbd_imem_dat_o         ),
    //.wbd_imem_sel_o         (wbd_imem_sel_o         ),
    //.wbd_imem_dat_i         (wbd_imem_dat_i         ),
    //.wbd_imem_ack_i         (wbd_imem_ack_i         ),
    //.wbd_imem_err_i         (wbd_imem_err_i         ),

    .wbd_dmem_stb_o         (wbd_dmem_stb_o         ),
    .wbd_dmem_adr_o         (wbd_dmem_adr_o         ),
    .wbd_dmem_we_o          (wbd_dmem_we_o          ),
    .wbd_dmem_dat_o         (wbd_dmem_dat_o         ),
    .wbd_dmem_sel_o         (wbd_dmem_sel_o         ),
    .wbd_dmem_dat_i         (wbd_dmem_dat_i         ),
    .wbd_dmem_ack_i         (wbd_dmem_ack_i         ),
    .wbd_dmem_err_i         (wbd_dmem_err_i         )

);


`ifndef YCR1_TCM_MEM

DFFRAM u_tcm_1kb_mem0 (
`ifdef USE_POWER_PINS
    input VPWR,
    input VGND,
`endif
    .CLK   (tcm_dffram_clk0),
    .WE    (tcm_dffram_wmask0),
    .EN    (tcm_dffram_cs0),
    .Di    (tcm_dffram_din0),
    .Do    (tcm_dffram_dout0),
    .A     (tcm_dffram_addr0)
);

DFFRAM u_tcm_1kb_mem1 (
`ifdef USE_POWER_PINS
    input VPWR,
    input VGND,
`endif
    .CLK   (tcm_dffram_clk1),
    .WE    (tcm_dffram_wmask1),
    .EN    (tcm_dffram_cs1),
    .Di    (tcm_dffram_din1),
    .Do    (tcm_dffram_dout1),
    .A     (tcm_dffram_addr1)
);
`endif


`ifdef YCR1_ICACHE_EN

DFFRAM u_icache_1kb_mem0 (
`ifdef USE_POWER_PINS
    input VPWR,
    input VGND,
`endif
    .CLK    (icache_dffram_clk0),
    .WE    (icache_dffram_wmask0),
    .EN    (icache_dffram_cs0),
    .Di    (icache_dffram_din0),
    .Do    (icache_dffram_dout0),
    .A     (icache_dffram_addr0)
);

DFFRAM u_icache_1kb_mem1 (
`ifdef USE_POWER_PINS
    input VPWR,
    input VGND,
`endif
    .CLK   (icache_dffram_clk1),
    .WE    (icache_dffram_wmask1),
    .EN    (icache_dffram_cs1),
    .Di    (icache_dffram_din1),
    .Do    (icache_dffram_dout1),
    .A     (icache_dffram_addr1)
);


`endif

`ifdef YCR1_DCACHE_EN

DFFRAM u_dcache_1kb_mem0 (
`ifdef USE_POWER_PINS
    input VPWR,
    input VGND,
`endif
    .CLK   (dcache_dffram_clk0),
    .WE    (dcache_dffram_wmask0),
    .EN    (dcache_dffram_cs0),
    .Di    (dcache_dffram_din0),
    .Do    (dcache_dffram_dout0),
    .A     (dcache_dffram_addr0)
);

DFFRAM u_idache_1kb_mem1 (
`ifdef USE_POWER_PINS
    input VPWR,
    input VGND,
`endif
    .CLK   (dcache_dffram_clk1),
    .WE    (dcache_dffram_wmask1),
    .EN    (dcache_dffram_cs1),
    .Di    (dcache_dffram_din1),
    .Do    (dcache_dffram_dout1),
    .A     (dcache_dffram_addr1)
);

`endif

//-------------------------------------------------------------------------------
// Memory instance
//-------------------------------------------------------------------------------
ycr1_memory_tb_wb #(
    .YCR1_MEM_POWER_SIZE    ($clog2(YCR1_MEM_SIZE))
) i_imem_tb (
    // Control
    .rst_n                  (rst_n                  ),
    .clk                    (clk                    ),
`ifdef YCR1_IPIC_EN
    .irq_lines              (irq_lines              ),
`else // YCR1_IPIC_EN
    .ext_irq                (ext_irq                ),
`endif // YCR1_IPIC_EN
    .soft_irq               (soft_irq               ),
    .imem_req_ack_stall_in  (imem_req_ack_stall     ),
    .dmem_req_ack_stall_in  (dmem_req_ack_stall     ),

   `ifdef YCR1_ICACHE_EN

    .wbd_imem_stb_i         (wb_icache_stb_o       ),
    .wbd_imem_adr_i         (wb_icache_adr_o       ),
    .wbd_imem_we_i          (wb_icache_we_o        ),
    .wbd_imem_dat_i         ('h0                   ), // Unused for icache
    .wbd_imem_sel_i         (wb_icache_sel_o       ),
    .wbd_imem_bl_i          (wb_icache_bl_o        ),
    .wbd_imem_bry_i         (wb_icache_bry_o        ),
    .wbd_imem_dat_o         (wb_icache_dat_i       ),
    .wbd_imem_ack_o         (wb_icache_ack_i       ),
    .wbd_imem_lack_o        (wb_icache_lack_i      ),
    .wbd_imem_err_o         (wb_icache_err_i       ),


   `else 

    .wbd_imem_stb_i         (wbd_imem_stb_o         ),
    .wbd_imem_adr_i         (wbd_imem_adr_o         ),
    .wbd_imem_we_i          (wbd_imem_we_o          ),
    .wbd_imem_dat_i         (wbd_imem_dat_o         ),
    .wbd_imem_sel_i         (wbd_imem_sel_o         ),
    .wbd_imem_bl_i          (10'h1                  ),
    .wbd_imem_bry_i         (1'b1                   ),
    .wbd_imem_dat_o         (wbd_imem_dat_i         ),
    .wbd_imem_ack_o         (wbd_imem_ack_i         ),
    .wbd_imem_lack_o        (                       ),
    .wbd_imem_err_o         (wbd_imem_err_i         ),

    `endif

    .wbd_dmem_stb_i         (wbd_dmem_stb_o         ),
    .wbd_dmem_adr_i         (wbd_dmem_adr_o         ),
    .wbd_dmem_we_i          (wbd_dmem_we_o          ),
    .wbd_dmem_dat_i         (wbd_dmem_dat_o         ),
    .wbd_dmem_sel_i         (wbd_dmem_sel_o         ),
    .wbd_dmem_bl_i          ('h1                    ),
    .wbd_dmem_dat_o         (wbd_dmem_dat_i         ),
    .wbd_dmem_ack_o         (wbd_dmem_ack_i         ),
    .wbd_dmem_err_o         (wbd_dmem_err_i         )

);


// dcache application memory
`ifdef YCR1_DCACHE_EN
ycr1_dmem_tb_wb #(
    .YCR1_MEM_POWER_SIZE    ($clog2(YCR1_MEM_SIZE))
) i_dmem_tb (
    // Control
    .rst_n                  (rst_n                 ),
    .clk                    (clk                   ),
    .mem_req_ack_stall_in   (dmem_req_ack_stall    ),


    .wbd_mem_stb_i          (wb_dcache_stb_o       ),
    .wbd_mem_adr_i          (wb_dcache_adr_o       ),
    .wbd_mem_we_i           (wb_dcache_we_o        ),
    .wbd_mem_dat_i          (wb_dcache_dat_o       ),
    .wbd_mem_sel_i          (wb_dcache_sel_o       ),
    .wbd_mem_bl_i           (wb_dcache_bl_o        ),
    .wbd_mem_bry_i          (wb_dcache_bry_o       ),
    .wbd_mem_dat_o          (wb_dcache_dat_i       ),
    .wbd_mem_ack_o          (wb_dcache_ack_i       ),
    .wbd_mem_lack_o         (wb_dcache_lack_i      ),
    .wbd_mem_err_o          (wb_dcache_err_i       )


);
`endif

wire  dmem_req =  i_top.core_dmem_req & i_top.core_dmem_req_ack;



initial begin
   riscv_dmem_req_cnt = 0;

end

always @(posedge dmem_req)
begin
    riscv_dmem_req_cnt = riscv_dmem_req_cnt+1;
    if((riscv_dmem_req_cnt %200) == 0)
        $display("STATUS: Total DMEM Req: %d",riscv_dmem_req_cnt);
end

`ifdef WFDUMP
initial
begin
   $dumpfile("simx.vcd");
   $dumpvars(0,ycr1_top_tb_wb);
   //$dumpvars(0,ycr1_top_tb_wb.i_top);
   //$dumpvars(0,ycr1_top_tb_wb.i_top.i_core_top.i_pipe_top.i_pipe_mprf);
end
`endif



endmodule : ycr1_top_tb_wb

