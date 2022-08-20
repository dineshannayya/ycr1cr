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
////  yifive Instruction Decoder Unit (IDU)                               ////
////                                                                      ////
////  This file is part of the yifive cores project                       ////
////  https://github.com/dineshannayya/ycr.git                           ////
////                                                                      ////
////  Description:                                                        ////
////     Instruction Decoder Unit (IDU)                                   ////
////                                                                      ////
////                                                                      ////
//// Functionality:                                                       ////
////  - Decodes the instruction and creates the appropriate control       ////
////    signals for EXU                                                   ////
////                                                                      ////
//// Structure:                                                           ////
//// - Instruction decoder                                                ////
//// - IDU <-> IFU i/f                                                    ////
//// - IDU <-> EXU i/f                                                    ////
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
////                                                                      ////
//////////////////////////////////////////////////////////////////////////////

`include "ycr_memif.svh"
`include "ycr_arch_types.svh"
`include "ycr_riscv_isa_decoding.svh"
`include "ycr_arch_description.svh"

module ycr_pipe_idu
(
`ifdef YCR_TRGT_SIMULATION
    input   logic                           rst_n,                  // IDU reset
    input   logic                           clk,                    // IDU clock
`endif // YCR_TRGT_SIMULATION

    // IFU <-> IDU interface
    output  logic                           idu2ifu_rdy_o,          // IDU ready for new data
    input   logic [`YCR_IMEM_DWIDTH-1:0]   ifu2idu_instr_i,        // IFU instruction
    input   logic                           ifu2idu_imem_err_i,     // Instruction access fault exception
    input   logic                           ifu2idu_err_rvi_hi_i,   // 1 - imem fault when trying to fetch second half of an unaligned RVI instruction
    input   logic                           ifu2idu_vd_i,           // IFU request

    // IDU <-> EXU interface
    output  logic                           idu2exu_req_o,          // IDU request
    output  type_ycr_exu_cmd_s             idu2exu_cmd_o,          // IDU command
    output  logic                           idu2exu_use_rs1_o,      // Instruction uses rs1
    output  logic                           idu2exu_use_rs2_o,      // Instruction uses rs2
    output  logic                           idu2exu_use_rd_o,       // Instruction uses rd
    output  logic                           idu2exu_use_imm_o,      // Instruction uses immediate
    input   logic                           exu2idu_rdy_i           // EXU ready for new data
);

//-------------------------------------------------------------------------------
// Local parameters declaration
//-------------------------------------------------------------------------------

localparam [YCR_GPR_FIELD_WIDTH-1:0] YCR_MPRF_ZERO_ADDR   = 5'd0;
localparam [YCR_GPR_FIELD_WIDTH-1:0] YCR_MPRF_RA_ADDR     = 5'd1;
localparam [YCR_GPR_FIELD_WIDTH-1:0] YCR_MPRF_SP_ADDR     = 5'd2;

//-------------------------------------------------------------------------------
// Local signals declaration
//-------------------------------------------------------------------------------

logic [`YCR_IMEM_DWIDTH-1:0]       instr;
logic [1:0]                         instr_type;
logic [6:2]                         rvi_opcode;
logic                               rvi_illegal;
logic [2:0]                         funct3;
logic [6:0]                         funct7;
logic [11:0]                        funct12;
logic [4:0]                         shamt;
`ifdef YCR_RVC_EXT
logic                               rvc_illegal;
`endif  // YCR_RVC_EXT
`ifdef YCR_RVE_EXT
logic                               rve_illegal;
`endif  // YCR_RVE_EXT

//-------------------------------------------------------------------------------
// Instruction decoding
//-------------------------------------------------------------------------------

assign idu2ifu_rdy_o  = exu2idu_rdy_i;
assign idu2exu_req_o  = ifu2idu_vd_i;
assign instr          = ifu2idu_instr_i;

// RVI / RVC
assign instr_type   = instr[1:0];

// RVI / RVC fields
assign rvi_opcode   = instr[6:2];                          // RVI
assign funct3       = (instr_type == YCR_INSTR_RVI) ? instr[14:12] : instr[15:13]; // RVI / RVC
assign funct7       = instr[31:25];                                                 // RVI
assign funct12      = instr[31:20];                                                 // RVI (SYSTEM)
assign shamt        = instr[24:20];                                                 // RVI

// RV32I(MC) decode
always_comb begin
    // Defaults
    idu2exu_cmd_o.instr_rvc   = 1'b0;
    idu2exu_cmd_o.ialu_op     = YCR_IALU_OP_REG_REG;
    idu2exu_cmd_o.ialu_cmd    = YCR_IALU_CMD_NONE;
    idu2exu_cmd_o.sum2_op     = YCR_SUM2_OP_PC_IMM;
    idu2exu_cmd_o.lsu_cmd     = YCR_LSU_CMD_NONE;
    idu2exu_cmd_o.csr_op      = YCR_CSR_OP_REG;
    idu2exu_cmd_o.csr_cmd     = YCR_CSR_CMD_NONE;
    idu2exu_cmd_o.rd_wb_sel   = YCR_RD_WB_NONE;
    idu2exu_cmd_o.jump_req    = 1'b0;
    idu2exu_cmd_o.branch_req  = 1'b0;
    idu2exu_cmd_o.mret_req    = 1'b0;
    idu2exu_cmd_o.fencei_req  = 1'b0;
    idu2exu_cmd_o.wfi_req     = 1'b0;
    idu2exu_cmd_o.rs1_addr    = '0;
    idu2exu_cmd_o.rs2_addr    = '0;
    idu2exu_cmd_o.rd_addr     = '0;
    idu2exu_cmd_o.imm         = '0;
    idu2exu_cmd_o.exc_req     = 1'b0;
    idu2exu_cmd_o.exc_code    = YCR_EXC_CODE_INSTR_MISALIGN;

    // Clock gating
    idu2exu_use_rs1_o         = 1'b0;
    idu2exu_use_rs2_o         = 1'b0;
    idu2exu_use_rd_o          = 1'b0;
    idu2exu_use_imm_o         = 1'b0;

    rvi_illegal             = 1'b0;
`ifdef YCR_RVE_EXT
    rve_illegal             = 1'b0;
`endif  // YCR_RVE_EXT
`ifdef YCR_RVC_EXT
    rvc_illegal             = 1'b0;
`endif  // YCR_RVC_EXT

    // Check for IMEM access fault
    if (ifu2idu_imem_err_i) begin
        idu2exu_cmd_o.exc_req     = 1'b1;
        idu2exu_cmd_o.exc_code    = YCR_EXC_CODE_INSTR_ACCESS_FAULT;
        idu2exu_cmd_o.instr_rvc   = ifu2idu_err_rvi_hi_i;
    end else begin  // no imem fault
        case (instr_type)
            YCR_INSTR_RVI  : begin
                idu2exu_cmd_o.rs1_addr    = instr[19:15];
                idu2exu_cmd_o.rs2_addr    = instr[24:20];
                idu2exu_cmd_o.rd_addr     = instr[11:7];
                case (rvi_opcode)
                    YCR_OPCODE_AUIPC           : begin
                        idu2exu_use_rd_o          = 1'b1;
                        idu2exu_use_imm_o         = 1'b1;
                        idu2exu_cmd_o.sum2_op     = YCR_SUM2_OP_PC_IMM;
                        idu2exu_cmd_o.rd_wb_sel   = YCR_RD_WB_SUM2;
                        idu2exu_cmd_o.imm         = {instr[31:12], 12'b0};
`ifdef YCR_RVE_EXT
                        if (instr[11])          rve_illegal = 1'b1;
`endif  // YCR_RVE_EXT
                    end // YCR_OPCODE_AUIPC

                    YCR_OPCODE_LUI             : begin
                        idu2exu_use_rd_o          = 1'b1;
                        idu2exu_use_imm_o         = 1'b1;
                        idu2exu_cmd_o.rd_wb_sel   = YCR_RD_WB_IMM;
                        idu2exu_cmd_o.imm         = {instr[31:12], 12'b0};
`ifdef YCR_RVE_EXT
                        if (instr[11])          rve_illegal = 1'b1;
`endif  // YCR_RVE_EXT
                    end // YCR_OPCODE_LUI

                    YCR_OPCODE_JAL             : begin
                        idu2exu_use_rd_o          = 1'b1;
                        idu2exu_use_imm_o         = 1'b1;
                        idu2exu_cmd_o.sum2_op     = YCR_SUM2_OP_PC_IMM;
                        idu2exu_cmd_o.rd_wb_sel   = YCR_RD_WB_INC_PC;
                        idu2exu_cmd_o.jump_req    = 1'b1;
                        idu2exu_cmd_o.imm         = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
`ifdef YCR_RVE_EXT
                        if (instr[11])          rve_illegal = 1'b1;
`endif  // YCR_RVE_EXT
                    end // YCR_OPCODE_JAL

                    YCR_OPCODE_LOAD            : begin
                        idu2exu_use_rs1_o         = 1'b1;
                        idu2exu_use_rd_o          = 1'b1;
                        idu2exu_use_imm_o         = 1'b1;
                        idu2exu_cmd_o.sum2_op     = YCR_SUM2_OP_REG_IMM;
                        idu2exu_cmd_o.rd_wb_sel   = YCR_RD_WB_LSU;
                        idu2exu_cmd_o.imm         = {{21{instr[31]}}, instr[30:20]};
                        case (funct3)
                            3'b000  : idu2exu_cmd_o.lsu_cmd = YCR_LSU_CMD_LB;
                            3'b001  : idu2exu_cmd_o.lsu_cmd = YCR_LSU_CMD_LH;
                            3'b010  : idu2exu_cmd_o.lsu_cmd = YCR_LSU_CMD_LW;
                            3'b100  : idu2exu_cmd_o.lsu_cmd = YCR_LSU_CMD_LBU;
                            3'b101  : idu2exu_cmd_o.lsu_cmd = YCR_LSU_CMD_LHU;
                            default : rvi_illegal = 1'b1;
                        endcase // funct3
`ifdef YCR_RVE_EXT
                        if (instr[11] | instr[19])  rve_illegal = 1'b1;
`endif  // YCR_RVE_EXT
                    end // YCR_OPCODE_LOAD

                    YCR_OPCODE_STORE           : begin
                        idu2exu_use_rs1_o         = 1'b1;
                        idu2exu_use_rs2_o         = 1'b1;
                        idu2exu_use_imm_o         = 1'b1;
                        idu2exu_cmd_o.sum2_op     = YCR_SUM2_OP_REG_IMM;
                        idu2exu_cmd_o.imm         = {{21{instr[31]}}, instr[30:25], instr[11:7]};
                        case (funct3)
                            3'b000  : idu2exu_cmd_o.lsu_cmd = YCR_LSU_CMD_SB;
                            3'b001  : idu2exu_cmd_o.lsu_cmd = YCR_LSU_CMD_SH;
                            3'b010  : idu2exu_cmd_o.lsu_cmd = YCR_LSU_CMD_SW;
                            default : rvi_illegal = 1'b1;
                        endcase // funct3
`ifdef YCR_RVE_EXT
                        if (instr[19] | instr[24])  rve_illegal = 1'b1;
`endif  // YCR_RVE_EXT
                    end // YCR_OPCODE_STORE

                    YCR_OPCODE_OP              : begin
                        idu2exu_use_rs1_o         = 1'b1;
                        idu2exu_use_rs2_o         = 1'b1;
                        idu2exu_use_rd_o          = 1'b1;
                        idu2exu_cmd_o.ialu_op     = YCR_IALU_OP_REG_REG;
                        idu2exu_cmd_o.rd_wb_sel   = YCR_RD_WB_IALU;
                        case (funct7)
                            7'b0000000 : begin
                                case (funct3)
                                    3'b000  : idu2exu_cmd_o.ialu_cmd  = YCR_IALU_CMD_ADD;
                                    3'b001  : idu2exu_cmd_o.ialu_cmd  = YCR_IALU_CMD_SLL;
                                    3'b010  : idu2exu_cmd_o.ialu_cmd  = YCR_IALU_CMD_SUB_LT;
                                    3'b011  : idu2exu_cmd_o.ialu_cmd  = YCR_IALU_CMD_SUB_LTU;
                                    3'b100  : idu2exu_cmd_o.ialu_cmd  = YCR_IALU_CMD_XOR;
                                    3'b101  : idu2exu_cmd_o.ialu_cmd  = YCR_IALU_CMD_SRL;
                                    3'b110  : idu2exu_cmd_o.ialu_cmd  = YCR_IALU_CMD_OR;
                                    3'b111  : idu2exu_cmd_o.ialu_cmd  = YCR_IALU_CMD_AND;
                                endcase // funct3
                            end // 7'b0000000

                            7'b0100000 : begin
                                case (funct3)
                                    3'b000  : idu2exu_cmd_o.ialu_cmd  = YCR_IALU_CMD_SUB;
                                    3'b101  : idu2exu_cmd_o.ialu_cmd  = YCR_IALU_CMD_SRA;
                                    default : rvi_illegal = 1'b1;
                                endcase // funct3
                            end // 7'b0100000
`ifdef YCR_RVM_EXT
                            7'b0000001 : begin
                                case (funct3)
                                    3'b000  : idu2exu_cmd_o.ialu_cmd  = YCR_IALU_CMD_MUL;
                                    3'b001  : idu2exu_cmd_o.ialu_cmd  = YCR_IALU_CMD_MULH;
                                    3'b010  : idu2exu_cmd_o.ialu_cmd  = YCR_IALU_CMD_MULHSU;
                                    3'b011  : idu2exu_cmd_o.ialu_cmd  = YCR_IALU_CMD_MULHU;
                                    3'b100  : idu2exu_cmd_o.ialu_cmd  = YCR_IALU_CMD_DIV;
                                    3'b101  : idu2exu_cmd_o.ialu_cmd  = YCR_IALU_CMD_DIVU;
                                    3'b110  : idu2exu_cmd_o.ialu_cmd  = YCR_IALU_CMD_REM;
                                    3'b111  : idu2exu_cmd_o.ialu_cmd  = YCR_IALU_CMD_REMU;
                                endcase // funct3
                            end // 7'b0000001
`endif  // YCR_RVM_EXT
                            default : rvi_illegal = 1'b1;
                        endcase // funct7
`ifdef YCR_RVE_EXT
                        if (instr[11] | instr[19] | instr[24])  rve_illegal = 1'b1;
`endif  // YCR_RVE_EXT
                    end // YCR_OPCODE_OP

                    YCR_OPCODE_OP_IMM          : begin
                        idu2exu_use_rs1_o         = 1'b1;
                        idu2exu_use_rd_o          = 1'b1;
                        idu2exu_use_imm_o         = 1'b1;
                        idu2exu_cmd_o.imm         = {{21{instr[31]}}, instr[30:20]};
                        idu2exu_cmd_o.ialu_op     = YCR_IALU_OP_REG_IMM;
                        idu2exu_cmd_o.rd_wb_sel   = YCR_RD_WB_IALU;
                        case (funct3)
                            3'b000  : idu2exu_cmd_o.ialu_cmd  = YCR_IALU_CMD_ADD;        // ADDI
                            3'b010  : idu2exu_cmd_o.ialu_cmd  = YCR_IALU_CMD_SUB_LT;     // SLTI
                            3'b011  : idu2exu_cmd_o.ialu_cmd  = YCR_IALU_CMD_SUB_LTU;    // SLTIU
                            3'b100  : idu2exu_cmd_o.ialu_cmd  = YCR_IALU_CMD_XOR;        // XORI
                            3'b110  : idu2exu_cmd_o.ialu_cmd  = YCR_IALU_CMD_OR;         // ORI
                            3'b111  : idu2exu_cmd_o.ialu_cmd  = YCR_IALU_CMD_AND;        // ANDI
                            3'b001  : begin
                                case (funct7)
                                    7'b0000000  : begin
                                        // SLLI
                                        idu2exu_cmd_o.imm         = `YCR_XLEN'(shamt);   // zero-extend
                                        idu2exu_cmd_o.ialu_cmd    = YCR_IALU_CMD_SLL;
                                    end
                                    default     : rvi_illegal   = 1'b1;
                                endcase // funct7
                            end
                            3'b101  : begin
                                case (funct7)
                                    7'b0000000  : begin
                                        // SRLI
                                        idu2exu_cmd_o.imm         = `YCR_XLEN'(shamt);   // zero-extend
                                        idu2exu_cmd_o.ialu_cmd    = YCR_IALU_CMD_SRL;
                                    end
                                    7'b0100000  : begin
                                        // SRAI
                                        idu2exu_cmd_o.imm         = `YCR_XLEN'(shamt);   // zero-extend
                                        idu2exu_cmd_o.ialu_cmd    = YCR_IALU_CMD_SRA;
                                    end
                                    default     : rvi_illegal   = 1'b1;
                                endcase // funct7
                            end
                        endcase // funct3
`ifdef YCR_RVE_EXT
                        if (instr[11] | instr[19])  rve_illegal = 1'b1;
`endif  // YCR_RVE_EXT
                    end // YCR_OPCODE_OP_IMM

                    YCR_OPCODE_MISC_MEM    : begin
                        case (funct3)
                            3'b000  : begin
                                if (~|{instr[31:28], instr[19:15], instr[11:7]}) begin
                                    // FENCE = NOP
                                end
                                else rvi_illegal = 1'b1;
                            end
                            3'b001  : begin
                                if (~|{instr[31:15], instr[11:7]}) begin
                                    // FENCE.I
                                    idu2exu_cmd_o.fencei_req    = 1'b1;
                                end
                                else rvi_illegal = 1'b1;
                            end
                            default : rvi_illegal = 1'b1;
                        endcase // funct3
                    end // YCR_OPCODE_MISC_MEM

                    YCR_OPCODE_BRANCH          : begin
                        idu2exu_use_rs1_o         = 1'b1;
                        idu2exu_use_rs2_o         = 1'b1;
                        idu2exu_use_imm_o         = 1'b1;
                        idu2exu_cmd_o.imm         = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
                        idu2exu_cmd_o.branch_req  = 1'b1;
                        idu2exu_cmd_o.sum2_op     = YCR_SUM2_OP_PC_IMM;
                        idu2exu_cmd_o.ialu_op     = YCR_IALU_OP_REG_REG;
                        case (funct3)
                            3'b000  : idu2exu_cmd_o.ialu_cmd = YCR_IALU_CMD_SUB_EQ;
                            3'b001  : idu2exu_cmd_o.ialu_cmd = YCR_IALU_CMD_SUB_NE;
                            3'b100  : idu2exu_cmd_o.ialu_cmd = YCR_IALU_CMD_SUB_LT;
                            3'b101  : idu2exu_cmd_o.ialu_cmd = YCR_IALU_CMD_SUB_GE;
                            3'b110  : idu2exu_cmd_o.ialu_cmd = YCR_IALU_CMD_SUB_LTU;
                            3'b111  : idu2exu_cmd_o.ialu_cmd = YCR_IALU_CMD_SUB_GEU;
                            default : rvi_illegal = 1'b1;
                        endcase // funct3
`ifdef YCR_RVE_EXT
                        if (instr[19] | instr[24])  rve_illegal = 1'b1;
`endif  // YCR_RVE_EXT
                    end // YCR_OPCODE_BRANCH

                    YCR_OPCODE_JALR        : begin
                        idu2exu_use_rs1_o     = 1'b1;
                        idu2exu_use_rd_o      = 1'b1;
                        idu2exu_use_imm_o     = 1'b1;
                        case (funct3)
                            3'b000  : begin
                                // JALR
                                idu2exu_cmd_o.sum2_op   = YCR_SUM2_OP_REG_IMM;
                                idu2exu_cmd_o.rd_wb_sel = YCR_RD_WB_INC_PC;
                                idu2exu_cmd_o.jump_req  = 1'b1;
                                idu2exu_cmd_o.imm       = {{21{instr[31]}}, instr[30:20]};
                            end
                            default : rvi_illegal = 1'b1;
                        endcase
`ifdef YCR_RVE_EXT
                        if (instr[11] | instr[19])  rve_illegal = 1'b1;
`endif  // YCR_RVE_EXT
                    end // YCR_OPCODE_JALR

                    YCR_OPCODE_SYSTEM      : begin
                        idu2exu_use_rd_o      = 1'b1;
                        idu2exu_use_imm_o     = 1'b1;
                        idu2exu_cmd_o.imm     = `YCR_XLEN'({funct3, instr[31:20]});      // {funct3, CSR address}
                        case (funct3)
                            3'b000  : begin
                                idu2exu_use_rd_o    = 1'b0;
                                idu2exu_use_imm_o   = 1'b0;
                                case ({instr[19:15], instr[11:7]})
                                    10'd0 : begin
                                        case (funct12)
                                            12'h000 : begin
                                                // ECALL
                                                idu2exu_cmd_o.exc_req     = 1'b1;
                                                idu2exu_cmd_o.exc_code    = YCR_EXC_CODE_ECALL_M;
                                            end
                                            12'h001 : begin
                                                // EBREAK
                                                idu2exu_cmd_o.exc_req     = 1'b1;
                                                idu2exu_cmd_o.exc_code    = YCR_EXC_CODE_BREAKPOINT;
                                            end
                                            12'h302 : begin
                                                // MRET
                                                idu2exu_cmd_o.mret_req    = 1'b1;
                                            end
                                            12'h105 : begin
                                                // WFI
                                                idu2exu_cmd_o.wfi_req     = 1'b1;
                                            end
                                            default : rvi_illegal = 1'b1;
                                        endcase // funct12
                                    end
                                    default : rvi_illegal = 1'b1;
                                endcase // {instr[19:15], instr[11:7]}
                            end
                            3'b001  : begin
                                // CSRRW
                                idu2exu_use_rs1_o             = 1'b1;
                                idu2exu_cmd_o.rd_wb_sel       = YCR_RD_WB_CSR;
                                idu2exu_cmd_o.csr_cmd         = YCR_CSR_CMD_WRITE;
                                idu2exu_cmd_o.csr_op          = YCR_CSR_OP_REG;
`ifdef YCR_RVE_EXT
                                if (instr[11] | instr[19])  rve_illegal = 1'b1;
`endif  // YCR_RVE_EXT
                            end
                            3'b010  : begin
                                // CSRRS
                                idu2exu_use_rs1_o             = 1'b1;
                                idu2exu_cmd_o.rd_wb_sel       = YCR_RD_WB_CSR;
                                idu2exu_cmd_o.csr_cmd         = YCR_CSR_CMD_SET;
                                idu2exu_cmd_o.csr_op          = YCR_CSR_OP_REG;
`ifdef YCR_RVE_EXT
                                if (instr[11] | instr[19])  rve_illegal = 1'b1;
`endif  // YCR_RVE_EXT
                            end
                            3'b011  : begin
                                // CSRRC
                                idu2exu_use_rs1_o             = 1'b1;
                                idu2exu_cmd_o.rd_wb_sel       = YCR_RD_WB_CSR;
                                idu2exu_cmd_o.csr_cmd         = YCR_CSR_CMD_CLEAR;
                                idu2exu_cmd_o.csr_op          = YCR_CSR_OP_REG;
`ifdef YCR_RVE_EXT
                                if (instr[11] | instr[19])  rve_illegal = 1'b1;
`endif  // YCR_RVE_EXT
                            end
                            3'b101  : begin
                                // CSRRWI
                                idu2exu_use_rs1_o             = 1'b1;             // zimm
                                idu2exu_cmd_o.rd_wb_sel       = YCR_RD_WB_CSR;
                                idu2exu_cmd_o.csr_cmd         = YCR_CSR_CMD_WRITE;
                                idu2exu_cmd_o.csr_op          = YCR_CSR_OP_IMM;
`ifdef YCR_RVE_EXT
                                if (instr[11])              rve_illegal = 1'b1;
`endif  // YCR_RVE_EXT
                            end
                            3'b110  : begin
                                // CSRRSI
                                idu2exu_use_rs1_o             = 1'b1;             // zimm
                                idu2exu_cmd_o.rd_wb_sel       = YCR_RD_WB_CSR;
                                idu2exu_cmd_o.csr_cmd         = YCR_CSR_CMD_SET;
                                idu2exu_cmd_o.csr_op          = YCR_CSR_OP_IMM;
`ifdef YCR_RVE_EXT
                                if (instr[11])              rve_illegal = 1'b1;
`endif  // YCR_RVE_EXT
                            end
                            3'b111  : begin
                                // CSRRCI
                                idu2exu_use_rs1_o             = 1'b1;             // zimm
                                idu2exu_cmd_o.rd_wb_sel       = YCR_RD_WB_CSR;
                                idu2exu_cmd_o.csr_cmd         = YCR_CSR_CMD_CLEAR;
                                idu2exu_cmd_o.csr_op          = YCR_CSR_OP_IMM;
`ifdef YCR_RVE_EXT
                                if (instr[11])              rve_illegal = 1'b1;
`endif  // YCR_RVE_EXT
                            end
                            default : rvi_illegal = 1'b1;
                        endcase // funct3
                    end // YCR_OPCODE_SYSTEM

                    default : begin
                        rvi_illegal = 1'b1;
                    end
                endcase // rvi_opcode
            end // YCR_INSTR_RVI

`ifdef YCR_RVC_EXT

            // Quadrant 0
            YCR_INSTR_RVC0 : begin
                idu2exu_cmd_o.instr_rvc   = 1'b1;
                idu2exu_use_rs1_o         = 1'b1;
                idu2exu_use_imm_o         = 1'b1;
                case (funct3)
                    3'b000  : begin
                        if (~|instr[12:5])      rvc_illegal = 1'b1;
                        // C.ADDI4SPN
                        idu2exu_use_rd_o          = 1'b1;
                        idu2exu_cmd_o.ialu_cmd    = YCR_IALU_CMD_ADD;
                        idu2exu_cmd_o.ialu_op     = YCR_IALU_OP_REG_IMM;
                        idu2exu_cmd_o.rd_wb_sel   = YCR_RD_WB_IALU;
                        idu2exu_cmd_o.rs1_addr    = YCR_MPRF_SP_ADDR;
                        idu2exu_cmd_o.rd_addr     = {2'b01, instr[4:2]};
                        idu2exu_cmd_o.imm         = {22'd0, instr[10:7], instr[12:11], instr[5], instr[6], 2'b00};
                    end
                    3'b010  : begin
                        // C.LW
                        idu2exu_use_rd_o          = 1'b1;
                        idu2exu_cmd_o.sum2_op     = YCR_SUM2_OP_REG_IMM;
                        idu2exu_cmd_o.lsu_cmd     = YCR_LSU_CMD_LW;
                        idu2exu_cmd_o.rd_wb_sel   = YCR_RD_WB_LSU;
                        idu2exu_cmd_o.rs1_addr    = {2'b01, instr[9:7]};
                        idu2exu_cmd_o.rd_addr     = {2'b01, instr[4:2]};
                        idu2exu_cmd_o.imm         = {25'd0, instr[5], instr[12:10], instr[6], 2'b00};
                    end
                    3'b110  : begin
                        // C.SW
                        idu2exu_use_rs2_o         = 1'b1;
                        idu2exu_cmd_o.sum2_op     = YCR_SUM2_OP_REG_IMM;
                        idu2exu_cmd_o.lsu_cmd     = YCR_LSU_CMD_SW;
                        idu2exu_cmd_o.rs1_addr    = {2'b01, instr[9:7]};
                        idu2exu_cmd_o.rs2_addr    = {2'b01, instr[4:2]};
                        idu2exu_cmd_o.imm         = {25'd0, instr[5], instr[12:10], instr[6], 2'b00};
                    end
                    default : begin
                        rvc_illegal = 1'b1;
                    end
                endcase // funct3
            end // Quadrant 0

            // Quadrant 1
            YCR_INSTR_RVC1 : begin
                idu2exu_cmd_o.instr_rvc   = 1'b1;
                idu2exu_use_rd_o          = 1'b1;
                idu2exu_use_imm_o         = 1'b1;
                case (funct3)
                    3'b000  : begin
                        // C.ADDI / C.NOP
                        idu2exu_use_rs1_o         = 1'b1;
                        idu2exu_cmd_o.ialu_cmd    = YCR_IALU_CMD_ADD;
                        idu2exu_cmd_o.ialu_op     = YCR_IALU_OP_REG_IMM;
                        idu2exu_cmd_o.rd_wb_sel   = YCR_RD_WB_IALU;
                        idu2exu_cmd_o.rs1_addr    = instr[11:7];
                        idu2exu_cmd_o.rd_addr     = instr[11:7];
                        idu2exu_cmd_o.imm         = {{27{instr[12]}}, instr[6:2]};
`ifdef YCR_RVE_EXT
                        if (instr[11])          rve_illegal = 1'b1;
`endif  // YCR_RVE_EXT
                    end
                    3'b001  : begin
                        // C.JAL
                        idu2exu_cmd_o.sum2_op     = YCR_SUM2_OP_PC_IMM;
                        idu2exu_cmd_o.rd_wb_sel   = YCR_RD_WB_INC_PC;
                        idu2exu_cmd_o.jump_req    = 1'b1;
                        idu2exu_cmd_o.rd_addr     = YCR_MPRF_RA_ADDR;
                        idu2exu_cmd_o.imm         = {{21{instr[12]}}, instr[8], instr[10:9], instr[6], instr[7], instr[2], instr[11], instr[5:3], 1'b0};
                    end
                    3'b010  : begin
                        // C.LI
                        idu2exu_cmd_o.rd_wb_sel   = YCR_RD_WB_IMM;
                        idu2exu_cmd_o.rd_addr     = instr[11:7];
                        idu2exu_cmd_o.imm         = {{27{instr[12]}}, instr[6:2]};
`ifdef YCR_RVE_EXT
                        if (instr[11])          rve_illegal = 1'b1;
`endif  // YCR_RVE_EXT
                    end
                    3'b011  : begin
                        if (~|{instr[12], instr[6:2]}) rvc_illegal = 1'b1;
                        if (instr[11:7] == YCR_MPRF_SP_ADDR) begin
                            // C.ADDI16SP
                            idu2exu_use_rs1_o         = 1'b1;
                            idu2exu_cmd_o.ialu_cmd    = YCR_IALU_CMD_ADD;
                            idu2exu_cmd_o.ialu_op     = YCR_IALU_OP_REG_IMM;
                            idu2exu_cmd_o.rd_wb_sel   = YCR_RD_WB_IALU;
                            idu2exu_cmd_o.rs1_addr    = YCR_MPRF_SP_ADDR;
                            idu2exu_cmd_o.rd_addr     = YCR_MPRF_SP_ADDR;
                            idu2exu_cmd_o.imm         = {{23{instr[12]}}, instr[4:3], instr[5], instr[2], instr[6], 4'd0};
                        end else begin
                            // C.LUI
                            idu2exu_cmd_o.rd_wb_sel   = YCR_RD_WB_IMM;
                            idu2exu_cmd_o.rd_addr     = instr[11:7];
                            idu2exu_cmd_o.imm         = {{15{instr[12]}}, instr[6:2], 12'd0};
`ifdef YCR_RVE_EXT
                            if (instr[11])          rve_illegal = 1'b1;
`endif  // YCR_RVE_EXT
                        end
                    end
                    3'b100  : begin
                        idu2exu_cmd_o.rs1_addr    = {2'b01, instr[9:7]};
                        idu2exu_cmd_o.rd_addr     = {2'b01, instr[9:7]};
                        idu2exu_cmd_o.rs2_addr    = {2'b01, instr[4:2]};
                        idu2exu_use_rs1_o         = 1'b1;
                        idu2exu_use_rd_o          = 1'b1;
                        case (instr[11:10])
                            2'b00   : begin
                                if (instr[12])          rvc_illegal = 1'b1;
                                // C.SRLI
                                idu2exu_use_imm_o         = 1'b1;
                                idu2exu_cmd_o.imm         = {27'd0, instr[6:2]};
                                idu2exu_cmd_o.ialu_cmd    = YCR_IALU_CMD_SRL;
                                idu2exu_cmd_o.ialu_op     = YCR_IALU_OP_REG_IMM;
                                idu2exu_cmd_o.rd_wb_sel   = YCR_RD_WB_IALU;
                            end
                            2'b01   : begin
                                if (instr[12])          rvc_illegal = 1'b1;
                                // C.SRAI
                                idu2exu_use_imm_o         = 1'b1;
                                idu2exu_cmd_o.imm         = {27'd0, instr[6:2]};
                                idu2exu_cmd_o.ialu_cmd    = YCR_IALU_CMD_SRA;
                                idu2exu_cmd_o.ialu_op     = YCR_IALU_OP_REG_IMM;
                                idu2exu_cmd_o.rd_wb_sel   = YCR_RD_WB_IALU;
                            end
                            2'b10   : begin
                                // C.ANDI
                                idu2exu_use_imm_o         = 1'b1;
                                idu2exu_cmd_o.ialu_cmd    = YCR_IALU_CMD_AND;
                                idu2exu_cmd_o.ialu_op     = YCR_IALU_OP_REG_IMM;
                                idu2exu_cmd_o.rd_wb_sel   = YCR_RD_WB_IALU;
                                idu2exu_cmd_o.imm         = {{27{instr[12]}}, instr[6:2]};
                            end
                            2'b11   : begin
                                idu2exu_use_rs2_o         = 1'b1;
                                case ({instr[12], instr[6:5]})
                                    3'b000  : begin
                                        // C.SUB
                                        idu2exu_cmd_o.ialu_cmd    = YCR_IALU_CMD_SUB;
                                        idu2exu_cmd_o.ialu_op     = YCR_IALU_OP_REG_REG;
                                        idu2exu_cmd_o.rd_wb_sel   = YCR_RD_WB_IALU;
                                    end
                                    3'b001  : begin
                                        // C.XOR
                                        idu2exu_cmd_o.ialu_cmd    = YCR_IALU_CMD_XOR;
                                        idu2exu_cmd_o.ialu_op     = YCR_IALU_OP_REG_REG;
                                        idu2exu_cmd_o.rd_wb_sel   = YCR_RD_WB_IALU;
                                    end
                                    3'b010  : begin
                                        // C.OR
                                        idu2exu_cmd_o.ialu_cmd    = YCR_IALU_CMD_OR;
                                        idu2exu_cmd_o.ialu_op     = YCR_IALU_OP_REG_REG;
                                        idu2exu_cmd_o.rd_wb_sel   = YCR_RD_WB_IALU;
                                    end
                                    3'b011  : begin
                                        // C.AND
                                        idu2exu_cmd_o.ialu_cmd    = YCR_IALU_CMD_AND;
                                        idu2exu_cmd_o.ialu_op     = YCR_IALU_OP_REG_REG;
                                        idu2exu_cmd_o.rd_wb_sel   = YCR_RD_WB_IALU;
                                    end
                                    default : begin
                                        rvc_illegal = 1'b1;
                                    end
                                endcase // {instr[12], instr[6:5]}
                            end
                        endcase // instr[11:10]
                    end // funct3 == 3'b100
                    3'b101  : begin
                        // C.J
                        idu2exu_use_imm_o         = 1'b1;
                        idu2exu_cmd_o.sum2_op     = YCR_SUM2_OP_PC_IMM;
                        idu2exu_cmd_o.jump_req    = 1'b1;
                        idu2exu_cmd_o.imm         = {{21{instr[12]}}, instr[8], instr[10:9], instr[6], instr[7], instr[2], instr[11], instr[5:3], 1'b0};
                    end
                    3'b110  : begin
                        // C.BEQZ
                        idu2exu_use_rs1_o         = 1'b1;
                        idu2exu_use_rs2_o         = 1'b1;
                        idu2exu_use_imm_o         = 1'b1;
                        idu2exu_cmd_o.ialu_cmd    = YCR_IALU_CMD_SUB_EQ;
                        idu2exu_cmd_o.ialu_op     = YCR_IALU_OP_REG_REG;
                        idu2exu_cmd_o.sum2_op     = YCR_SUM2_OP_PC_IMM;
                        idu2exu_cmd_o.branch_req  = 1'b1;
                        idu2exu_cmd_o.rs1_addr    = {2'b01, instr[9:7]};
                        idu2exu_cmd_o.rs2_addr    = YCR_MPRF_ZERO_ADDR;
                        idu2exu_cmd_o.imm         = {{24{instr[12]}}, instr[6:5], instr[2], instr[11:10], instr[4:3], 1'b0};
                    end
                    3'b111  : begin
                        // C.BNEZ
                        idu2exu_use_rs1_o         = 1'b1;
                        idu2exu_use_rs2_o         = 1'b1;
                        idu2exu_use_imm_o         = 1'b1;
                        idu2exu_cmd_o.ialu_cmd    = YCR_IALU_CMD_SUB_NE;
                        idu2exu_cmd_o.ialu_op     = YCR_IALU_OP_REG_REG;
                        idu2exu_cmd_o.sum2_op     = YCR_SUM2_OP_PC_IMM;
                        idu2exu_cmd_o.branch_req  = 1'b1;
                        idu2exu_cmd_o.rs1_addr    = {2'b01, instr[9:7]};
                        idu2exu_cmd_o.rs2_addr    = YCR_MPRF_ZERO_ADDR;
                        idu2exu_cmd_o.imm         = {{24{instr[12]}}, instr[6:5], instr[2], instr[11:10], instr[4:3], 1'b0};
                    end
                endcase // funct3
            end // Quadrant 1

            // Quadrant 2
            YCR_INSTR_RVC2 : begin
                idu2exu_cmd_o.instr_rvc   = 1'b1;
                idu2exu_use_rs1_o         = 1'b1;
                case (funct3)
                    3'b000  : begin
                        if (instr[12])          rvc_illegal = 1'b1;
                        // C.SLLI
                        idu2exu_use_rd_o          = 1'b1;
                        idu2exu_use_imm_o         = 1'b1;
                        idu2exu_cmd_o.rs1_addr    = instr[11:7];
                        idu2exu_cmd_o.rd_addr     = instr[11:7];
                        idu2exu_cmd_o.imm         = {27'd0, instr[6:2]};
                        idu2exu_cmd_o.ialu_cmd    = YCR_IALU_CMD_SLL;
                        idu2exu_cmd_o.ialu_op     = YCR_IALU_OP_REG_IMM;
                        idu2exu_cmd_o.rd_wb_sel   = YCR_RD_WB_IALU;
`ifdef YCR_RVE_EXT
                        if (instr[11])          rve_illegal = 1'b1;
`endif  // YCR_RVE_EXT
                    end
                    3'b010  : begin
                        if (~|instr[11:7])      rvc_illegal = 1'b1;
                        // C.LWSP
                        idu2exu_use_rd_o          = 1'b1;
                        idu2exu_use_imm_o         = 1'b1;
                        idu2exu_cmd_o.sum2_op     = YCR_SUM2_OP_REG_IMM;
                        idu2exu_cmd_o.lsu_cmd     = YCR_LSU_CMD_LW;
                        idu2exu_cmd_o.rd_wb_sel   = YCR_RD_WB_LSU;
                        idu2exu_cmd_o.rs1_addr    = YCR_MPRF_SP_ADDR;
                        idu2exu_cmd_o.rd_addr     = instr[11:7];
                        idu2exu_cmd_o.imm         = {24'd0, instr[3:2], instr[12], instr[6:4], 2'b00};
`ifdef YCR_RVE_EXT
                        if (instr[11])          rve_illegal = 1'b1;
`endif  // YCR_RVE_EXT
                    end
                    3'b100  : begin
                        if (~instr[12]) begin
                            if (|instr[6:2]) begin
                                // C.MV
                                idu2exu_use_rs2_o         = 1'b1;
                                idu2exu_use_rd_o          = 1'b1;
                                idu2exu_cmd_o.ialu_cmd    = YCR_IALU_CMD_ADD;
                                idu2exu_cmd_o.ialu_op     = YCR_IALU_OP_REG_REG;
                                idu2exu_cmd_o.rd_wb_sel   = YCR_RD_WB_IALU;
                                idu2exu_cmd_o.rs1_addr    = YCR_MPRF_ZERO_ADDR;
                                idu2exu_cmd_o.rs2_addr    = instr[6:2];
                                idu2exu_cmd_o.rd_addr     = instr[11:7];
`ifdef YCR_RVE_EXT
                                if (instr[11]|instr[6]) rve_illegal = 1'b1;
`endif  // YCR_RVE_EXT
                            end else begin
                                if (~|instr[11:7])      rvc_illegal = 1'b1;
                                // C.JR
                                idu2exu_use_imm_o         = 1'b1;
                                idu2exu_cmd_o.sum2_op     = YCR_SUM2_OP_REG_IMM;
                                idu2exu_cmd_o.jump_req    = 1'b1;
                                idu2exu_cmd_o.rs1_addr    = instr[11:7];
                                idu2exu_cmd_o.imm         = 0;
`ifdef YCR_RVE_EXT
                                if (instr[11])          rve_illegal = 1'b1;
`endif  // YCR_RVE_EXT
                            end
                        end else begin  // instr[12] == 1
                            if (~|instr[11:2]) begin
                                // C.EBREAK
                                idu2exu_cmd_o.exc_req     = 1'b1;
                                idu2exu_cmd_o.exc_code    = YCR_EXC_CODE_BREAKPOINT;
                            end else if (~|instr[6:2]) begin
                                // C.JALR
                                idu2exu_use_rs1_o         = 1'b1;
                                idu2exu_use_rd_o          = 1'b1;
                                idu2exu_use_imm_o         = 1'b1;
                                idu2exu_cmd_o.sum2_op     = YCR_SUM2_OP_REG_IMM;
                                idu2exu_cmd_o.rd_wb_sel   = YCR_RD_WB_INC_PC;
                                idu2exu_cmd_o.jump_req    = 1'b1;
                                idu2exu_cmd_o.rs1_addr    = instr[11:7];
                                idu2exu_cmd_o.rd_addr     = YCR_MPRF_RA_ADDR;
                                idu2exu_cmd_o.imm         = 0;
`ifdef YCR_RVE_EXT
                                if (instr[11])          rve_illegal = 1'b1;
`endif  // YCR_RVE_EXT
                            end else begin
                                // C.ADD
                                idu2exu_use_rs1_o         = 1'b1;
                                idu2exu_use_rs2_o         = 1'b1;
                                idu2exu_use_rd_o          = 1'b1;
                                idu2exu_cmd_o.ialu_cmd    = YCR_IALU_CMD_ADD;
                                idu2exu_cmd_o.ialu_op     = YCR_IALU_OP_REG_REG;
                                idu2exu_cmd_o.rd_wb_sel   = YCR_RD_WB_IALU;
                                idu2exu_cmd_o.rs1_addr    = instr[11:7];
                                idu2exu_cmd_o.rs2_addr    = instr[6:2];
                                idu2exu_cmd_o.rd_addr     = instr[11:7];
`ifdef YCR_RVE_EXT
                                if (instr[11]|instr[6]) rve_illegal = 1'b1;
`endif  // YCR_RVE_EXT
                            end
                        end // instr[12] == 1
                    end
                    3'b110  : begin
                        // C.SWSP
                        idu2exu_use_rs1_o         = 1'b1;
                        idu2exu_use_rs2_o         = 1'b1;
                        idu2exu_use_imm_o         = 1'b1;
                        idu2exu_cmd_o.sum2_op     = YCR_SUM2_OP_REG_IMM;
                        idu2exu_cmd_o.lsu_cmd     = YCR_LSU_CMD_SW;
                        idu2exu_cmd_o.rs1_addr    = YCR_MPRF_SP_ADDR;
                        idu2exu_cmd_o.rs2_addr    = instr[6:2];
                        idu2exu_cmd_o.imm         = {24'd0, instr[8:7], instr[12:9], 2'b00};
`ifdef YCR_RVE_EXT
                        if (instr[6])           rve_illegal = 1'b1;
`endif  // YCR_RVE_EXT
                    end
                    default : begin
                        rvc_illegal = 1'b1;
                    end
                endcase // funct3
            end // Quadrant 2

            default         : begin
            end
`else   // YCR_RVC_EXT
            default         : begin
                idu2exu_cmd_o.instr_rvc   = 1'b1;
                rvi_illegal             = 1'b1;
            end
`endif  // YCR_RVC_EXT
        endcase // instr_type
    end // no imem fault

    // At this point the instruction is fully decoded
    // given that no imem fault has happened

    // Check illegal instruction
    if (
    rvi_illegal
`ifdef YCR_RVC_EXT
    | rvc_illegal
`endif
`ifdef YCR_RVE_EXT
    | rve_illegal
`endif
    ) begin
        idu2exu_cmd_o.ialu_cmd        = YCR_IALU_CMD_NONE;
        idu2exu_cmd_o.lsu_cmd         = YCR_LSU_CMD_NONE;
        idu2exu_cmd_o.csr_cmd         = YCR_CSR_CMD_NONE;
        idu2exu_cmd_o.rd_wb_sel       = YCR_RD_WB_NONE;
        idu2exu_cmd_o.jump_req        = 1'b0;
        idu2exu_cmd_o.branch_req      = 1'b0;
        idu2exu_cmd_o.mret_req        = 1'b0;
        idu2exu_cmd_o.fencei_req      = 1'b0;
        idu2exu_cmd_o.wfi_req         = 1'b0;

        idu2exu_use_rs1_o             = 1'b0;
        idu2exu_use_rs2_o             = 1'b0;
        idu2exu_use_rd_o              = 1'b0;

`ifndef YCR_MTVAL_ILLEGAL_INSTR_EN
        idu2exu_use_imm_o             = 1'b0;
`else // YCR_MTVAL_ILLEGAL_INSTR_EN
        idu2exu_use_imm_o             = 1'b1;
        idu2exu_cmd_o.imm             = instr;
`endif // YCR_MTVAL_ILLEGAL_INSTR_EN

        idu2exu_cmd_o.exc_req         = 1'b1;
        idu2exu_cmd_o.exc_code        = YCR_EXC_CODE_ILLEGAL_INSTR;
    end

end // RV32I(MC) decode

`ifdef YCR_TRGT_SIMULATION
//-------------------------------------------------------------------------------
// Assertion
//-------------------------------------------------------------------------------

// X checks

YCR_SVA_IDU_XCHECK : assert property (
    @(negedge clk) disable iff (~rst_n)
    !$isunknown({ifu2idu_vd_i, exu2idu_rdy_i})
    ) else $error("IDU Error: unknown values");

YCR_SVA_IDU_XCHECK2 : assert property (
    @(negedge clk) disable iff (~rst_n)
    ifu2idu_vd_i |-> !$isunknown({ifu2idu_imem_err_i, (ifu2idu_imem_err_i ? 0 : ifu2idu_instr_i)})
    ) else $error("IDU Error: unknown values");

// Behavior checks

YCR_SVA_IDU_IALU_CMD_RANGE : assert property (
    @(negedge clk) disable iff (~rst_n)
    (ifu2idu_vd_i & ~ifu2idu_imem_err_i) |->
    ((idu2exu_cmd_o.ialu_cmd >= YCR_IALU_CMD_NONE) &
    (idu2exu_cmd_o.ialu_cmd <=
`ifdef YCR_RVM_EXT
                            YCR_IALU_CMD_REMU
`else
                            YCR_IALU_CMD_SRA
`endif // YCR_RVM_EXT
        ))
    ) else $error("IDU Error: IALU_CMD out of range");

`endif // YCR_TRGT_SIMULATION

endmodule : ycr_pipe_idu
