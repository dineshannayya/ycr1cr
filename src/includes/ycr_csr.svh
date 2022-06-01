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
////  yifive CSR mapping/description file                                 ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     CSR mapping/description file                                     ////
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

`ifndef YCR_CSR_SVH
`define YCR_CSR_SVH

`include "ycr_arch_description.svh"
`include "ycr_arch_types.svh"
`include "ycr_ipic.svh"

`ifdef YCR_RVE_EXT
`define YCR_CSR_REDUCED_CNT
`endif // YCR_RVE_EXT

`ifdef YCR_CSR_REDUCED_CNT
`undef YCR_MCOUNTEN_EN
`endif // YCR_CSR_REDUCED_CNT

//-------------------------------------------------------------------------------
// CSR addresses (standard)
//-------------------------------------------------------------------------------

// Machine Information Registers (read-only)
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_MVENDORID     = 'hF11;
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_MARCHID       = 'hF12;
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_MIMPID        = 'hF13;
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_MHARTID       = 'hF14;
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_NUMCORES      = 'hFC1;

// Machine Trap Setup (read-write)
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_MSTATUS       = 'h300;
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_MISA          = 'h301;
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_MIE           = 'h304;
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_MTVEC         = 'h305;

// Machine Trap Handling (read-write)
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_MSCRATCH      = 'h340;
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_MEPC          = 'h341;
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_MCAUSE        = 'h342;
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_MTVAL         = 'h343;
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_MIP           = 'h344;

// Machine Counters/Timers (read-write)
`ifndef YCR_CSR_REDUCED_CNT
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_MCYCLE        = 'hB00;
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_MINSTRET      = 'hB02;
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_MCYCLEH       = 'hB80;
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_MINSTRETH     = 'hB82;
`endif // YCR_CSR_REDUCED_CNT

// Shadow Counters/Timers (read-only)
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_TIME          = 'hC01;
`ifndef YCR_CSR_REDUCED_CNT
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_CYCLE         = 'hC00;
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_INSTRET       = 'hC02;
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_TIMEH         = 'hC81;
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_CYCLEH        = 'hC80;
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_INSTRETH      = 'hC82;
`endif // YCR_CSR_REDUCED_CNT

`ifdef YCR_DBG_EN
//parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_DBGC_SCRATCH  = 'h7C8;
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_HDU_MBASE    = 'h7B0;
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_HDU_MSPAN    = 'h004;    // must be power of 2
`endif // YCR_DBG_EN

//-------------------------------------------------------------------------------
// CSR addresses (non-standard)
//-------------------------------------------------------------------------------
`ifdef YCR_MCOUNTEN_EN
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_MCOUNTEN      = 'h7E0;
`endif // YCR_MCOUNTEN_EN

`ifdef YCR_TDU_EN
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_TDU_MBASE    = 'h7A0;
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_TDU_MSPAN    = 'h008;    // must be power of 2
`endif // YCR_TDU_EN

`ifdef YCR_IPIC_EN
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_IPIC_BASE     = 'hBF0;
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_IPIC_CISV     = (YCR_CSR_ADDR_IPIC_BASE + YCR_IPIC_CISV );
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_IPIC_CICSR    = (YCR_CSR_ADDR_IPIC_BASE + YCR_IPIC_CICSR);
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_IPIC_IPR      = (YCR_CSR_ADDR_IPIC_BASE + YCR_IPIC_IPR  );
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_IPIC_ISVR     = (YCR_CSR_ADDR_IPIC_BASE + YCR_IPIC_ISVR );
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_IPIC_EOI      = (YCR_CSR_ADDR_IPIC_BASE + YCR_IPIC_EOI  );
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_IPIC_SOI      = (YCR_CSR_ADDR_IPIC_BASE + YCR_IPIC_SOI  );
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_IPIC_IDX      = (YCR_CSR_ADDR_IPIC_BASE + YCR_IPIC_IDX  );
parameter bit [YCR_CSR_ADDR_WIDTH-1:0] YCR_CSR_ADDR_IPIC_ICSR     = (YCR_CSR_ADDR_IPIC_BASE + YCR_IPIC_ICSR );
`endif // YCR_IPIC_EN


//-------------------------------------------------------------------------------
// CSR definitions
//-------------------------------------------------------------------------------

// General
parameter bit [`YCR_XLEN-1:0] YCR_RST_VECTOR      = YCR_ARCH_RST_VECTOR;

// Reset values TBD
parameter bit YCR_CSR_MIE_MSIE_RST_VAL             = 1'b0;
parameter bit YCR_CSR_MIE_MTIE_RST_VAL             = 1'b0;
parameter bit YCR_CSR_MIE_MEIE_RST_VAL             = 1'b0;

parameter bit YCR_CSR_MIP_MSIP_RST_VAL             = 1'b0;
parameter bit YCR_CSR_MIP_MTIP_RST_VAL             = 1'b0;
parameter bit YCR_CSR_MIP_MEIP_RST_VAL             = 1'b0;

parameter bit YCR_CSR_MSTATUS_MIE_RST_VAL          = 1'b0;
parameter bit YCR_CSR_MSTATUS_MPIE_RST_VAL         = 1'b1;

// MISA
`define YCR_RVC_ENC                                `YCR_XLEN'h0004
`define YCR_RVE_ENC                                `YCR_XLEN'h0010
`define YCR_RVI_ENC                                `YCR_XLEN'h0100
`define YCR_RVM_ENC                                `YCR_XLEN'h1000
parameter bit [1:0]             YCR_MISA_MXL_32    = 2'd1;
parameter bit [`YCR_XLEN-1:0]  YCR_CSR_MISA       = (YCR_MISA_MXL_32 << (`YCR_XLEN-2))
`ifndef YCR_RVE_EXT
                                                    | `YCR_RVI_ENC
`else // YCR_RVE_EXT
                                                    | `YCR_RVE_ENC
`endif // YCR_RVE_EXT
`ifdef YCR_RVC_EXT
                                                    | `YCR_RVC_ENC
`endif // YCR_RVC_EXT
`ifdef YCR_RVM_EXT
                                                    | `YCR_RVM_ENC
`endif // YCR_RVM_EXT
                                                    ;

// MVENDORID
parameter bit [`YCR_XLEN-1:0] YCR_CSR_MVENDORID   = `YCR_MVENDORID;

// MARCHID
parameter bit [`YCR_XLEN-1:0] YCR_CSR_MARCHID     = `YCR_XLEN'd8;

// MIMPID
parameter bit [`YCR_XLEN-1:0] YCR_CSR_MIMPID      = `YCR_MIMPID;

// NUMCORES
parameter bit [`YCR_XLEN-1:0] YCR_CSR_NUMCORES    = `YCR_NUMCORES;

// MSTATUS
parameter bit [1:0] YCR_CSR_MSTATUS_MPP            = 2'b11;
parameter int unsigned YCR_CSR_MSTATUS_MIE_OFFSET  = 3;
parameter int unsigned YCR_CSR_MSTATUS_MPIE_OFFSET = 7;
parameter int unsigned YCR_CSR_MSTATUS_MPP_OFFSET  = 11;

// MTVEC
// bits [5:0] are always zero
parameter bit [`YCR_XLEN-1:YCR_CSR_MTVEC_BASE_ZERO_BITS] YCR_CSR_MTVEC_BASE_RST_VAL  = YCR_CSR_MTVEC_BASE_WR_RST_VAL;

parameter bit YCR_CSR_MTVEC_MODE_DIRECT            = 1'b0;
`ifdef YCR_MTVEC_MODE_EN
parameter bit YCR_CSR_MTVEC_MODE_VECTORED          = 1'b1;
`endif // YCR_MTVEC_MODE_EN

// MIE, MIP
parameter int unsigned YCR_CSR_MIE_MSIE_OFFSET     = 3;
parameter int unsigned YCR_CSR_MIE_MTIE_OFFSET     = 7;
parameter int unsigned YCR_CSR_MIE_MEIE_OFFSET     = 11;

`ifdef YCR_MCOUNTEN_EN
// MCOUNTEN
parameter int unsigned YCR_CSR_MCOUNTEN_CY_OFFSET  = 0;
parameter int unsigned YCR_CSR_MCOUNTEN_IR_OFFSET  = 2;
`endif // YCR_MCOUNTEN_EN

// MCAUSE
typedef logic [`YCR_XLEN-2:0]      type_ycr_csr_mcause_ec_v;

// MCYCLE, MINSTRET
`ifdef YCR_CSR_REDUCED_CNT
parameter int unsigned YCR_CSR_COUNTERS_WIDTH      = 32;
`else // ~YCR_CSR_REDUCED_CNT
parameter int unsigned YCR_CSR_COUNTERS_WIDTH      = 64;
`endif // ~YCR_CSR_REDUCED_CNT

// HPM
parameter bit [6:0] YCR_CSR_ADDR_HPMCOUNTER_MASK   = 7'b1100000;
parameter bit [6:0] YCR_CSR_ADDR_HPMCOUNTERH_MASK  = 7'b1100100;
parameter bit [6:0] YCR_CSR_ADDR_MHPMCOUNTER_MASK  = 7'b1011000;
parameter bit [6:0] YCR_CSR_ADDR_MHPMCOUNTERH_MASK = 7'b1011100;
parameter bit [6:0] YCR_CSR_ADDR_MHPMEVENT_MASK    = 7'b0011001;

//-------------------------------------------------------------------------------
// Types declaration
//-------------------------------------------------------------------------------
typedef enum logic {
    YCR_CSR_RESP_OK,
    YCR_CSR_RESP_ER
`ifdef YCR_XPROP_EN
    ,
    YCR_CSR_RESP_ERROR = 'x
`endif // YCR_XPROP_EN
} type_ycr_csr_resp_e;

`endif // YCR_CSR_SVH
