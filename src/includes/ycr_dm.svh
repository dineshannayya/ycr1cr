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
////  yifive Debug Module header file                                     ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     Debug Module header file                                         ////
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

`ifndef YCR_INCLUDE_DM_DEFS
`define YCR_INCLUDE_DM_DEFS

`include "ycr_arch_description.svh"
`include "ycr_hdu.svh"
`include "ycr_csr.svh"

parameter YCR_DBG_DMI_ADDR_WIDTH                  = 6'd7;
parameter YCR_DBG_DMI_DATA_WIDTH                  = 6'd32;
parameter YCR_DBG_DMI_OP_WIDTH                    = 2'd2;

parameter YCR_DBG_DMI_CH_ID_WIDTH                 = 2'd2;
parameter YCR_DBG_DMI_DR_DTMCS_WIDTH              = 6'd32;
parameter YCR_DBG_DMI_DR_DMI_ACCESS_WIDTH         = YCR_DBG_DMI_OP_WIDTH +
                                                     YCR_DBG_DMI_DATA_WIDTH +
                                                     YCR_DBG_DMI_ADDR_WIDTH;

// Debug Module addresses
parameter YCR_DBG_DATA0                           = 7'h4;
parameter YCR_DBG_DATA1                           = 7'h5;
parameter YCR_DBG_DMCONTROL                       = 7'h10;
parameter YCR_DBG_DMSTATUS                        = 7'h11;
parameter YCR_DBG_HARTINFO                        = 7'h12;
parameter YCR_DBG_ABSTRACTCS                      = 7'h16;
parameter YCR_DBG_COMMAND                         = 7'h17;
parameter YCR_DBG_ABSTRACTAUTO                    = 7'h18;
parameter YCR_DBG_PROGBUF0                        = 7'h20;
parameter YCR_DBG_PROGBUF1                        = 7'h21;
parameter YCR_DBG_PROGBUF2                        = 7'h22;
parameter YCR_DBG_PROGBUF3                        = 7'h23;
parameter YCR_DBG_PROGBUF4                        = 7'h24;
parameter YCR_DBG_PROGBUF5                        = 7'h25;
parameter YCR_DBG_HALTSUM0                        = 7'h40;

// DMCONTROL
parameter YCR_DBG_DMCONTROL_HALTREQ               = 5'd31;
parameter YCR_DBG_DMCONTROL_RESUMEREQ             = 5'd30;
parameter YCR_DBG_DMCONTROL_HARTRESET             = 5'd29;
parameter YCR_DBG_DMCONTROL_ACKHAVERESET          = 5'd28;
parameter YCR_DBG_DMCONTROL_RESERVEDB             = 5'd27;
parameter YCR_DBG_DMCONTROL_HASEL                 = 5'd26;
parameter YCR_DBG_DMCONTROL_HARTSELLO_HI          = 5'd25;
parameter YCR_DBG_DMCONTROL_HARTSELLO_LO          = 5'd16;
parameter YCR_DBG_DMCONTROL_HARTSELHI_HI          = 5'd15;
parameter YCR_DBG_DMCONTROL_HARTSELHI_LO          = 5'd6;
parameter YCR_DBG_DMCONTROL_RESERVEDA_HI          = 5'd5;
parameter YCR_DBG_DMCONTROL_RESERVEDA_LO          = 5'd2;
parameter YCR_DBG_DMCONTROL_NDMRESET              = 5'd1;
parameter YCR_DBG_DMCONTROL_DMACTIVE              = 5'd0;

// DMSTATUS
parameter YCR_DBG_DMSTATUS_RESERVEDC_HI           = 5'd31;
parameter YCR_DBG_DMSTATUS_RESERVEDC_LO           = 5'd23;
parameter YCR_DBG_DMSTATUS_IMPEBREAK              = 5'd22;
parameter YCR_DBG_DMSTATUS_RESERVEDB_HI           = 5'd21;
parameter YCR_DBG_DMSTATUS_RESERVEDB_LO           = 5'd20;
parameter YCR_DBG_DMSTATUS_ALLHAVERESET           = 5'd19;
parameter YCR_DBG_DMSTATUS_ANYHAVERESET           = 5'd18;
parameter YCR_DBG_DMSTATUS_ALLRESUMEACK           = 5'd17;
parameter YCR_DBG_DMSTATUS_ANYRESUMEACK           = 5'd16;
parameter YCR_DBG_DMSTATUS_ALLNONEXISTENT         = 5'd15;
parameter YCR_DBG_DMSTATUS_ANYNONEXISTENT         = 5'd14;
parameter YCR_DBG_DMSTATUS_ALLUNAVAIL             = 5'd13;
parameter YCR_DBG_DMSTATUS_ANYUNAVAIL             = 5'd12;
parameter YCR_DBG_DMSTATUS_ALLRUNNING             = 5'd11;
parameter YCR_DBG_DMSTATUS_ANYRUNNING             = 5'd10;
parameter YCR_DBG_DMSTATUS_ALLHALTED              = 5'd9;
parameter YCR_DBG_DMSTATUS_ANYHALTED              = 5'd8;
parameter YCR_DBG_DMSTATUS_AUTHENTICATED          = 5'd7;
parameter YCR_DBG_DMSTATUS_AUTHBUSY               = 5'd6;
parameter YCR_DBG_DMSTATUS_RESERVEDA              = 5'd5;
parameter YCR_DBG_DMSTATUS_DEVTREEVALID           = 5'd4;
parameter YCR_DBG_DMSTATUS_VERSION_HI             = 5'd3;
parameter YCR_DBG_DMSTATUS_VERSION_LO             = 5'd0;

// COMMANDS
parameter YCR_DBG_COMMAND_TYPE_HI                 = 5'd31;
parameter YCR_DBG_COMMAND_TYPE_LO                 = 5'd24;
parameter YCR_DBG_COMMAND_TYPE_WDTH               = YCR_DBG_COMMAND_TYPE_HI
                                                   - YCR_DBG_COMMAND_TYPE_LO;

parameter YCR_DBG_COMMAND_ACCESSREG_RESERVEDB     = 5'd23;
parameter YCR_DBG_COMMAND_ACCESSREG_SIZE_HI       = 5'd22;
parameter YCR_DBG_COMMAND_ACCESSREG_SIZE_LO       = 5'd20;
parameter YCR_DBG_COMMAND_ACCESSREG_SIZE_WDTH     = YCR_DBG_COMMAND_ACCESSREG_SIZE_HI
                                                   - YCR_DBG_COMMAND_ACCESSREG_SIZE_LO;
parameter YCR_DBG_COMMAND_ACCESSREG_RESERVEDA     = 5'd19;
parameter YCR_DBG_COMMAND_ACCESSREG_POSTEXEC      = 5'd18;
parameter YCR_DBG_COMMAND_ACCESSREG_TRANSFER      = 5'd17;
parameter YCR_DBG_COMMAND_ACCESSREG_WRITE         = 5'd16;
parameter YCR_DBG_COMMAND_ACCESSREG_REGNO_HI      = 5'd15;
parameter YCR_DBG_COMMAND_ACCESSREG_REGNO_LO      = 5'd0;

parameter YCR_DBG_COMMAND_ACCESSMEM_AAMVIRTUAL    = 5'd23;
parameter YCR_DBG_COMMAND_ACCESSMEM_AAMSIZE_HI    = 5'd22;
parameter YCR_DBG_COMMAND_ACCESSMEM_AAMSIZE_LO    = 5'd20;
parameter YCR_DBG_COMMAND_ACCESSMEM_AAMPOSTINC    = 5'd19;
parameter YCR_DBG_COMMAND_ACCESSMEM_RESERVEDB_HI  = 5'd18;
parameter YCR_DBG_COMMAND_ACCESSMEM_RESERVEDB_LO  = 5'd17;
parameter YCR_DBG_COMMAND_ACCESSMEM_WRITE         = 5'd16;
parameter YCR_DBG_COMMAND_ACCESSMEM_RESERVEDA_HI  = 5'd13;
parameter YCR_DBG_COMMAND_ACCESSMEM_RESERVEDA_LO  = 5'd0;

// ABSTRACTCS
parameter YCR_DBG_ABSTRACTCS_RESERVEDD_HI         = 5'd31;
parameter YCR_DBG_ABSTRACTCS_RESERVEDD_LO         = 5'd29;
parameter YCR_DBG_ABSTRACTCS_PROGBUFSIZE_HI       = 5'd28;
parameter YCR_DBG_ABSTRACTCS_PROGBUFSIZE_LO       = 5'd24;
parameter YCR_DBG_ABSTRACTCS_RESERVEDC_HI         = 5'd23;
parameter YCR_DBG_ABSTRACTCS_RESERVEDC_LO         = 5'd13;
parameter YCR_DBG_ABSTRACTCS_BUSY                 = 5'd12;
parameter YCR_DBG_ABSTRACTCS_RESERVEDB            = 5'd11;
parameter YCR_DBG_ABSTRACTCS_CMDERR_HI            = 5'd10;
parameter YCR_DBG_ABSTRACTCS_CMDERR_LO            = 5'd8;
parameter YCR_DBG_ABSTRACTCS_CMDERR_WDTH          = YCR_DBG_ABSTRACTCS_CMDERR_HI
                                                   - YCR_DBG_ABSTRACTCS_CMDERR_LO;
parameter YCR_DBG_ABSTRACTCS_RESERVEDA_HI         = 5'd7;
parameter YCR_DBG_ABSTRACTCS_RESERVEDA_LO         = 5'd4;
parameter YCR_DBG_ABSTRACTCS_DATACOUNT_HI         = 5'd3;
parameter YCR_DBG_ABSTRACTCS_DATACOUNT_LO         = 5'd0;

// HARTINFO
parameter YCR_DBG_HARTINFO_RESERVEDB_HI           = 5'd31;
parameter YCR_DBG_HARTINFO_RESERVEDB_LO           = 5'd24;
parameter YCR_DBG_HARTINFO_NSCRATCH_HI            = 5'd23;
parameter YCR_DBG_HARTINFO_NSCRATCH_LO            = 5'd20;
parameter YCR_DBG_HARTINFO_RESERVEDA_HI           = 5'd19;
parameter YCR_DBG_HARTINFO_RESERVEDA_LO           = 5'd17;
parameter YCR_DBG_HARTINFO_DATAACCESS             = 5'd16;
parameter YCR_DBG_HARTINFO_DATASIZE_HI            = 5'd15;
parameter YCR_DBG_HARTINFO_DATASIZE_LO            = 5'd12;
parameter YCR_DBG_HARTINFO_DATAADDR_HI            = 5'd11;
parameter YCR_DBG_HARTINFO_DATAADDR_LO            = 5'd0;


`endif // YCR_INCLUDE_DM_DEFS
