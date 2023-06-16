//////////////////////////////////////////////////////////////////////////////
// SPDX-FileCopyrightText: 2021, Dinesh Annayya                           ////
//                                                                        ////
// Licenseunder the Apache License, Vers2.0(the "License");               ////
// you maynot use this file except in compliance with the License.       ////
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
// SPDX-FileContributor: Dinesh Annayya <dinesh.annayya@gmail.com>        ////
//////////////////////////////////////////////////////////////////////////////
/*****************************************************************************
             Risc core clock gate control

   Main feature implemented
       1. Clock gate AES
       2. Clock Gate for FPU
       3. Clock Gate for Individual Riscv Core

******************************************************************************/
module ycr_cclk_ctrl_top (
     input   logic                           rst_n               ,
     input   logic                           core_clk_int        , // core clock without skew
   
     input   logic [23:0]                    riscv_clk_cfg       ,
     input   logic                           aes_idle            ,
     input   logic                           aes_req             ,

     input   logic                           fpu_idle            ,
     input   logic                           fpu_req             ,

     input   logic  [7:0]                    riscv_sleep         ,
     output  logic  [7:0]                    riscv_wakeup        ,

     input   logic                           timer_irq           ,
     input   logic [YCR_IRQ_LINES_NUM-1:0]   core_irq_lines_i    , // External interrupt request lines
     input   logic                           core_irq_soft_i     , // Software generated interrupt request

     output   logic                          core0_clk           ,
     output   logic                          core1_clk           ,
     output   logic                          cpu_clk_fpu         ,
     output   logic                          cpu_clk_aes         ,
     output   logic                          cpu_clk_intf        


    );


//--------------------------------------------------------------------------------------
// Dummy clock gate to balence avoid clk-skew between two branch for simulation handling
//--------------------------------------------------------------------------------------
ctech_clk_gate u_intf_clkgate (.GATE (1'b1), . CLK(core_clk_int), .GCLK(cpu_clk_intf));


//-----------------------------------------------------------------------------------
// Set a clock tree node for clock gate logic
//-----------------------------------------------------------------------------------
logic cclk_gate_cts;
ctech_mux2x1   u_cclk_gate_cts  (.A0(core_clk_int), .A1(1'b0), .S(1'b0), .X(cclk_gate_cts));


//----------------------------------------
// Reset Sync
//----------------------------------------
logic rst_ssn;

ycr_reset_sync  u_rst_sync (
	      .scan_mode  (1'b0               ),
          .dclk       (cclk_gate_cts      ), // Destination clock domain
	      .arst_n     (rst_n              ), // active low async reset
          .srst_n     (rst_ssn            )
          );


ctech_dsync_high  #(.WB(1)) u_timer_irq(
              .in_data    ( timer_irq        ),
              .out_clk    ( cclk_gate_cts    ),
              .out_rst_n  ( rst_ssn          ),
              .out_data   ( timer_irq_ss     )
          );

wire ext_irq = |(core_irq_lines_i);

ctech_dsync_high  #(.WB(1)) u_ext_irq(
              .in_data    ( ext_irq        ),
              .out_clk    ( cclk_gate_cts  ),
              .out_rst_n  ( rst_ssn        ),
              .out_data   ( ext_irq_ss     )
          );

ctech_dsync_high  #(.WB(1)) u_soft_irq(
              .in_data    ( core_irq_soft_i),
              .out_clk    ( cclk_gate_cts  ),
              .out_rst_n  ( rst_ssn        ),
              .out_data   ( soft_irq_ss    )
          );


//----------------------------
// Source Clock Gating for AES
//----------------------------
ycr_clk_gate1  u_aes_s0(
                        .reset_n               (rst_ssn             ),
                        .clk_in                (cclk_gate_cts       ),
                        .cfg_mode              (riscv_clk_cfg[1:0]  ),
                        .dst_idle              (aes_idle            ), // 1 - indicate destination is ideal
                        .src_req               (aes_req             ), // 1 - Source Request

                        .clk_enb               (                    ), // clock enable indication
                        .clk_out               (cpu_clk_aes         )  // clock output
     
       );

//----------------------------
// Source Clock Gating for FPU
//----------------------------
ycr_clk_gate1  u_fpu_s0(
                        .reset_n               (rst_ssn             ),
                        .clk_in                (cclk_gate_cts       ),
                        .cfg_mode              (riscv_clk_cfg[3:2]  ),
                        .dst_idle              (fpu_idle            ), // 1 - indicate destination is ideal
                        .src_req               (fpu_req             ), // 1 - Source Request

                        .clk_enb               (                    ), // clock enable indication
                        .clk_out               (cpu_clk_fpu         )  // clock output
     
       );
//----------------------------
// Source Clock Gating for Core0
//----------------------------
ycr_clk_gate2  u_core_s0(
                        .reset_n               (rst_ssn             ),
                        .clk_in                (cclk_gate_cts       ),
                        .cfg_mode              (riscv_clk_cfg[6:4]  ),
                        .dst_idle              (riscv_sleep[0]      ), // 1 - indicate destination is ideal
                        .irq1                  (timer_irq_ss        ), // 1 - Timer Interrupt
                        .irq2                  (ext_irq_ss          ), // 1 - Source Request
                        .irq3                  (soft_irq_ss         ), // 1 - Source Request

                        .wakeup                (riscv_wakeup[0]     ), // wakeup indication
                        .clk_enb               (                    ), // clock enable indication
                        .clk_out               (core0_clk           )  // clock output
     
       );

//----------------------------
// Source Clock Gating for Core1
//----------------------------
ycr_clk_gate2  u_core_s1(
                        .reset_n               (rst_ssn             ),
                        .clk_in                (cclk_gate_cts       ),
                        .cfg_mode              (riscv_clk_cfg[10:8] ),
                        .dst_idle              (riscv_sleep[1]      ), // 1 - indicate destination is ideal
                        .irq1                  (timer_irq_ss        ), // 1 - Timer Interrupt
                        .irq2                  (ext_irq_ss          ), // 1 - Source Request
                        .irq3                  (soft_irq_ss         ), // 1 - Source Request

                        .wakeup                (riscv_wakeup[1]     ), // wakeup indication
                        .clk_enb               (                    ), // clock enable indication
                        .clk_out               (core1_clk           )  // clock output
     
       );


assign riscv_wakeup[7:2] = 'h0;


endmodule

