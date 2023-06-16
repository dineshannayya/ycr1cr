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
////  yifive Architecture description file                                ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     Architecture description file                                    ////
////                                                                      ////
////  To Do:                                                              ////
////    nothing                                                           ////
////                                                                      ////
////  Author(s):                                                          ////
////     - syntacore, https://github.com/syntacore/scr1                   ////
////     - Dinesh Annayya, dinesha@opencores.org                          ////
////                                                                      ////
////  Revision :                                                          ////
////     v0:    Jan 2021- Initial version picked from syntacore/scr1      ////
////     v1:    June 7, 2021, Dinesh A                                    ////
////             opentool(iverilog/yosys) related cleanup                 ////
////                                                                      ////
//////////////////////////////////////////////////////////////////////////////


`ifndef YCR_ARCH_DESCRIPTION_SVH
`define YCR_ARCH_DESCRIPTION_SVH


//------------------------------------------------------------------------------
// CORE FUNDAMENTAL PARAMETERS
//------------------------------------------------------------------------------

// YCR1 core identifiers
`define YCR_MIMPID             32'h23060100 // <YY[7:0]:MON[7:0]:DAY[7:0]:INTRA DAY[7:0]>
`define YCR_MVENDORID          32'h52444530 // RDS0 - RiscDuino S0
`define YCR_NUMCORES           32'h00000001

// Width of main registers and buses
`define YCR_XLEN               32
`define YCR_IMEM_AWIDTH        `YCR_XLEN
`define YCR_IMEM_DWIDTH        `YCR_XLEN
`define YCR_DMEM_AWIDTH        `YCR_XLEN
`define YCR_DMEM_DWIDTH        `YCR_XLEN
`define YCR_IMEM_BSIZE         3          // BURST SIZE

/****************************
 TAP IDCODE
31-28  - 4 bit Version
27-16  - 12 bit Part Number 
15-12  - 4 bit Core Number
11-1   - 11 bit Manufacturer
0      - Pre-set to logic 1

*****************************/

//`define YCR_TAP_IDCODE         'hDEB11001
`define YCR_TAP_VER_IDCODE   4'hD
`define YCR_TAP_PART_IDCODE  12'hEB1
`define YCR_TAP_MANU_IDCODE  11'h000


`ifdef YCR_ARCH_CUSTOM
//------------------------------------------------------------------------------
// INCLUDE YCR_ARCH_CUSTOM.SVH
//------------------------------------------------------------------------------

// The external file ycr_arch_custom.svh is used for the open YCR-SDK project,
// and can also be used for any custom projects.

// The file sets:
// - target platform (FPGA/ASIC), which affects the choice of logical constructs;
// - device build ID;
// - address constants;
// - could enables configuration parameters.

// Possible targets:
// `define YCR_TRGT_FPGA_INTEL         // target platform is Intel FPGAs
// `define YCR_TRGT_FPGA_INTEL_MAX10   // target platform is Intel MAX 10 FPGAs (used in the YCR1-SDK project)
// `define YCR_TRGT_FPGA_INTEL_ARRIAV  // target platform is Intel Arria V FPGAs (used in the YCR1-SDK project)
// `define YCR_TRGT_FPGA_XILINX        // target platform is Xilinx FPGAs (used in the YCR1-SDK project)
// `define YCR_TRGT_ASIC               // target platform is ASIC
// `define YCR_TRGT_SIMULATION         // target is simulation (enable simulation code)

 `include "ycr_arch_custom.svh"

`endif // YCR_ARCH_CUSTOM


//------------------------------------------------------------------------------
// RECOMMENDED CORE ARCHITECTURE CONFIGURATIONS
//------------------------------------------------------------------------------

// Uncomment one of these defines to set the recommended configuration:

`define YCR_CFG_RV32IMC_MAX
//`define YCR_CFG_RV32IC_BASE
//`define YCR_CFG_RV32EC_MIN

// If all defines are commented, custom configuration will be used (see below)

`define YCR_ICACHE_EN   // Enable ICACHE
`define YCR_DCACHE_EN   // Enable ICACHE

//------------------------------------------------------------------------------
// READ-ONLY: settings for recommended configurations
`ifdef  YCR_CFG_RV32IMC_MAX
  `define YCR_RVI_EXT
  `define YCR_RVM_EXT
  `define YCR_RVC_EXT
  parameter int unsigned YCR_MTVEC_BASE_WR_BITS = 26;
  `define YCR_MTVEC_MODE_EN          // enable writable MTVEC.mode field to allow vectored irq mode, otherwise only direct mode is possible
//  `define YCR_FAST_MUL               // enable fast one-cycle multiplication, otherwise multiplication takes 32 cycles
//`define YCR_MPRF_RST_EN - yosys fix, two dimensional array init not allowed
  `define YCR_MCOUNTEN_EN            // enable custom MCOUNTEN CSR for counter control
`define YCR_DBG_EN                 // enable Debug Subsystem (TAPC, DM, SCU, HDU)
`define YCR_TDU_EN                 // enable Trigger Debug Unit (hardware breakpoints)
  parameter int unsigned YCR_TDU_TRIG_NUM = 4;
 `define YCR_TDU_ICOUNT_EN          // enable hardware triggers on instruction counter
  `define YCR_IPIC_EN                // enable Integrated Programmable Interrupt Controller
  `define YCR_IPIC_SYNC_EN           // enable IPIC synchronizer
  `define YCR_TCM_EN
  //`define SCR1_TCM_MEM
  `define YCR_IMEM_ROUTER_EN
  `define YCR_NEW_PC_REG             // enable register in IFU for New_PC value
  `define YCRC1_MPRF_STAGE            // enabled register at Read path of MPRF
`elsif  YCR_CFG_RV32IC_BASE
  `define YCR_RVI_EXT
  `define YCR_RVC_EXT
  parameter int unsigned YCR_MTVEC_BASE_WR_BITS = 16;
  `define YCR_MTVEC_MODE_EN
  `define YCR_NO_DEC_STAGE
  `define YCR_MPRF_RST_EN
  `define YCR_MCOUNTEN_EN
  `define YCR_DBG_EN
  `define YCR_TDU_EN
  parameter int unsigned YCR_TDU_TRIG_NUM = 2;
  `define YCR_TDU_ICOUNT_EN
  `define YCR_IPIC_EN
  `define YCR_IPIC_SYNC_EN
  `define YCR_TCM_EN
`elsif  YCR_CFG_RV32EC_MIN
  `define YCR_RVE_EXT
  `define YCR_RVC_EXT
  parameter int unsigned YCR_MTVEC_BASE_WR_BITS = 0;
  `define YCR_NO_DEC_STAGE
  `define YCR_NO_EXE_STAGE
  `define YCR_TCM_EN

`else // begin custom configuration section


//------------------------------------------------------------------------------
// CUSTOM CORE ARCHITECTURE CONFIGURATION
//------------------------------------------------------------------------------

// To fine-tune custom configuration, you can change the values in this section.
// Make sure that the defines of the recommended configurations are commented,
// otherwise this section will be inactive.

// RISC-V ISA options
//`define YCR_RVE_EXT                // enable RV32E base integer instruction set, otherwise RV32I will be used
`define YCR_RVM_EXT                // enable standard extension "M" for integer hardware multiplier and divider
`define YCR_RVC_EXT                // enable standard extension "C" for compressed instructions
parameter int unsigned YCR_MTVEC_BASE_WR_BITS = 26;    // number of writable high-order bits in MTVEC.base field
                                                            // legal values are 0 to 26
                                                            // read-only bits are hardwired to reset value
`define YCR_MTVEC_MODE_EN          // enable writable MTVEC.mode field to allow vectored irq mode, otherwise only direct mode is possible

`ifndef YCR_RVE_EXT
  `define YCR_RVI_EXT // RV32E base integer instruction set if YCR_RVE_EXT is not enabled
`endif // ~YCR_RVE_EXT

// Core pipeline options (power-performance-area optimization)
`define YCR_NO_DEC_STAGE           // disable register between IFU and IDU
`define YCR_NO_EXE_STAGE           // disable register between IDU and EXU
`define YCR_NEW_PC_REG             // enable register in IFU for New_PC value
`define YCR_FAST_MUL               // enable fast one-cycle multiplication, otherwise multiplication takes 32 cycles
`define YCR_CLKCTRL_EN             // enable global clock gating
`define YCR_MPRF_RST_EN            // enable reset for MPRF
`define YCR_MCOUNTEN_EN            // enable custom MCOUNTEN CSR for counter control

// Uncore options
`define YCR_DBG_EN                 // enable Debug Subsystem (TAPC, DM, SCU, HDU)
`define YCR_TDU_EN                 // enable Trigger Debug Unit (hardware breakpoints)
parameter int unsigned YCR_TDU_TRIG_NUM = 2;   // number of hardware triggers
`define YCR_TDU_ICOUNT_EN          // enable hardware triggers on instruction counter
`define YCR_IPIC_EN                // enable Integrated Programmable Interrupt Controller
`define YCR_IPIC_SYNC_EN           // enable IPIC synchronizer
`define YCR_TCM_EN                 // enable Tightly-Coupled Memory

`endif // end custom configuration section


//------------------------------------------------------------------------------
// CORE INTEGRATION OPTIONS
//------------------------------------------------------------------------------

// Bypasses on AXI/AHB bridge I/O
`define YCR_IMEM_AHB_IN_BP         // bypass instruction memory AHB bridge input register
`define YCR_IMEM_AHB_OUT_BP        // bypass instruction memory AHB bridge output register
`define YCR_DMEM_AHB_IN_BP         // bypass data memory AHB bridge input register
`define YCR_DMEM_AHB_OUT_BP        // bypass data memory AHB bridge output register
`define YCR_IMEM_AXI_REQ_BP        // bypass instruction memory AXI bridge request register
`define YCR_IMEM_AXI_RESP_BP       // bypass instruction memory AXI bridge response register
`define YCR_DMEM_AXI_REQ_BP        // bypass data memory AXI bridge request register
`define YCR_DMEM_AXI_RESP_BP       // bypass data memory AXI bridge response register

`ifndef YCR_ARCH_CUSTOM
// Default address constants (if ycr_arch_custom.svh is not used)
parameter bit [`YCR_XLEN-1:0]          YCR_ARCH_RST_VECTOR        = 'h200;            // Reset vector value (start address after reset)
parameter bit [`YCR_XLEN-1:0]          YCR_ARCH_MTVEC_BASE        = 'h1C0;            // MTVEC.base field reset value, or constant value for MTVEC.base bits that are hardwired

// icache address range 0x0000_0000 to 0x07FF_FFFF - 128MB
parameter bit [`YCR_DMEM_AWIDTH-1:0]   YCR_ICACHE_ADDR_MASK       = 'hF8000000;       // ICACHE mask and size; size in bytes is two's complement of the mask value
parameter bit [`YCR_DMEM_AWIDTH-1:0]   YCR_ICACHE_ADDR_PATTERN    = 'h00000000;       // ICACHE address match pattern

// dcache address range 0x0800_0000 to 0x0BFF_FFFF - 64MB
parameter bit [`YCR_DMEM_AWIDTH-1:0]   YCR_DCACHE_ADDR_MASK       = 'hFC000000;       // DCACHE mask and size; size in bytes is two's complement of the mask value
parameter bit [`YCR_DMEM_AWIDTH-1:0]   YCR_DCACHE_ADDR_PATTERN    = 'h08000000;       // DCACHE address match pattern

parameter bit [`YCR_DMEM_AWIDTH-1:0]   YCR_TCM_ADDR_MASK          = 'hFFFF0000;       // TCM mask and size; size in bytes is two's complement of the mask value
parameter bit [`YCR_DMEM_AWIDTH-1:0]   YCR_TCM_ADDR_PATTERN       = 'h0C480000;       // TCM address match pattern


parameter bit [`YCR_DMEM_AWIDTH-1:0]   YCR_LOCAL_ADDR_MASK        = 'hFFFF0000;       // RISC LOCAL Address Map
parameter bit [`YCR_DMEM_AWIDTH-1:0]   YCR_LOCAL_ADDR_PATTERN     = 'h0C490000;       // pattern - 0x0C490000 - 0x0C49FFFF

parameter bit [`YCR_DMEM_AWIDTH-1:0]   YCR_TIMER_ADDR_MASK        = 'hFFFFFFE0;       // Timer mask
parameter bit [`YCR_DMEM_AWIDTH-1:0]   YCR_TIMER_ADDR_PATTERN     = 'h0C490000;       // Timer address match pattern - 0x0C490000 - 0x0C49001F

parameter bit [`YCR_DMEM_AWIDTH-1:0]   YCR_AES_ADDR_MASK          = 'hFFFFFF80;       // AES MASK
parameter bit [`YCR_DMEM_AWIDTH-1:0]   YCR_AES_ADDR_PATTERN       = 'h0C490080;       // AES Address Match Pattern    -0x0C490080 - 0x0C4900FF

parameter bit [`YCR_DMEM_AWIDTH-1:0]   YCR_FPU_ADDR_MASK          = 'hFFFFFF80;       // FPU MASK
parameter bit [`YCR_DMEM_AWIDTH-1:0]   YCR_FPU_ADDR_PATTERN       = 'h0C490100;       // FPU Address Match Pattern    -0x0C490100 - 0x0C49017F

// Device build ID
 `define YCR_ARCH_BUILD_ID             `YCR_MIMPID

`endif // YCR_ARCH_CUSTOM


//------------------------------------------------------------------------------
// TARGET-SPECIFIC OPTIONS
//------------------------------------------------------------------------------

// RAM-based MPRF can be used for Intel FPGAs only
`ifdef YCR_TRGT_FPGA_INTEL
  `define YCR_MPRF_RAM           // implements MPRF with dedicated RAM blocks
`endif

// EXU_STAGE_BYPASS and MPRF_RST_EN must be disabled for RAM-based MPRF
`ifdef YCR_MPRF_RAM
  `undef  YCR_NO_EXE_STAGE
  `undef  YCR_MPRF_RST_EN
`endif


//------------------------------------------------------------------------------
// SIMULATION OPTIONS
//------------------------------------------------------------------------------

//`define YCR_TRGT_SIMULATION            // enable simulation code (automatically defined by root makefile)
//`define YCR_TRACE_LOG_EN               // enable tracelog
//`define YCR_XPROP_EN                   // enable X-propagation

// Addresses used in testbench
//localparam [`YCR_XLEN-1:0]      YCR_SIM_EXIT_ADDR      = 32'h0000_00F8;
//localparam [`YCR_XLEN-1:0]      YCR_SIM_PRINT_ADDR     = 32'hF000_0000;
//localparam [`YCR_XLEN-1:0]      YCR_SIM_EXT_IRQ_ADDR   = 32'h3000_000C; // Bit [15:0]
//localparam [`YCR_XLEN-1:0]      YCR_SIM_SOFT_IRQ_ADDR  = 32'h3000_000C; // Bit[16]

`endif // YCR_ARCH_DESCRIPTION_SVH
