/*****************************************************
           Source clock Gate2:

Flow: 
   1. RISCV set Dst_idle = 1
   2. logic will clock gate the core
   3. core will be wake up based on config mode -> irq1/irq2/irq3
******************************************************/
module ycr_clk_gate2 (
        input  logic         reset_n   ,
        input  logic         clk_in    ,
        input  logic [2:0]   cfg_mode  ,
        input  logic         dst_idle  ,
        input  logic         irq1      , // 1 - indicate destination is ideal
        input  logic         irq2      , // 1 - Source Request
        input  logic         irq3      , // 1 - Source Request

        output logic         wakeup   , // wakeup indication
        output logic         clk_enb  , // clock enable indication
        output logic         clk_out   // clock output
     
       );

parameter NCLK_GATE   = 3'b000 ;// No clock gate
parameter IRQ1_GATE   = 3'b001 ;// IRQ1 Based clock ungate
parameter IRQ2_GATE   = 3'b010 ;// IRQ2 Based clock ungate
parameter IRQ3_GATE   = 3'b011 ;// IRQ3 Based clock ungate
parameter IRQ_GATE    = 3'b100 ;// IRQ Based clock ungate
parameter FOCLK_GATE  = 3'b101 ;// Force   clock gate

parameter  IDLE          = 2'b00;
parameter  WAIT_WAKEUP   = 2'b01;
parameter  WAIT_TIMER    = 2'b10;


logic [1:0] wcnt; // wait cnt

//----------------------------------------------
// Double Sync the dst_idle signal to match clock skew + Riscv core to detect sleep command with clock 
//----------------------------------------------
logic dst_idle_ss;
logic dst_idle_r;
logic [1:0] state;
logic dst_idle_ps;

ctech_dsync_high  #(.WB(1)) u_dsync_idle(
              .in_data    ( dst_idle     ),
              .out_clk    ( clk_in       ),
              .out_rst_n  ( reset_n      ),
              .out_data   ( dst_idle_ss  )
          );

// Detect Positive Edge
assign dst_idle_ps = dst_idle_ss && !dst_idle_r;


//-----------------------------------------------
// Synchronize the target idle indicate
//  Extended the clock-removal by 8 cycle
//-----------------------------------------------
always@(negedge reset_n or posedge clk_in)
begin
   if(reset_n == 1'b0) begin
      dst_idle_r  <= 1'b0;
      wakeup      <= 1'b0;
      wcnt        <= 'h0;
      state       <= IDLE;
   end else begin
      dst_idle_r  <= dst_idle_ss;
      case(state)
      IDLE: begin
          wcnt        <= 'h0;
          wakeup      <= 1'b0;
          case(cfg_mode_ss)
          IRQ1_GATE,IRQ2_GATE,IRQ3_GATE, IRQ_GATE:
                begin
                  if(dst_idle_ps) state <= WAIT_WAKEUP;
                end
          default: begin
               state <= IDLE;
          end
          endcase
       end
       WAIT_WAKEUP: begin
          case(cfg_mode_ss)
          IRQ1_GATE: if(irq1) begin state <= WAIT_TIMER;   wakeup <= 1'b1; end
          IRQ2_GATE: if(irq2) begin state <= WAIT_TIMER;   wakeup <= 1'b1; end
          IRQ3_GATE: if(irq3) begin state <= WAIT_TIMER;   wakeup <= 1'b1; end
          IRQ_GATE:  if(irq)  begin state <= WAIT_TIMER;   wakeup <= 1'b1; end
          default: state <= WAIT_WAKEUP;
          endcase
       end
       // 
       WAIT_TIMER: begin
          wakeup      <= 1'b0;
          if(wcnt == 2'b11) begin
             state <= IDLE;
          end else begin
             wcnt <= wcnt + 1;
          end
      end


      endcase
   
   end
end

//----------------------------------------------
// Double Sync the config signal to match clock skew 
//----------------------------------------------
logic [2:0] cfg_mode_ss;

ctech_dsync_high  #(.WB(3)) u_dsync(
              .in_data    ( cfg_mode     ),
              .out_clk    ( clk_in       ),
              .out_rst_n  ( reset_n      ),
              .out_data   ( cfg_mode_ss  )
          );

// Note: IRQ already double sync at outside the module
wire irq = irq1 | irq2 | irq3;

always_comb begin
   case(cfg_mode_ss)
      // No clock gating 
      NCLK_GATE:   clk_enb = 1'b1;

      // Wake-up on IRQ1
      IRQ1_GATE, IRQ2_GATE, IRQ3_GATE,IRQ_GATE: 
      begin  
         clk_enb = (state  == IDLE) ? 1'b1 : 1'b0;
      end
      // Force Clock Gating
      FOCLK_GATE:   clk_enb = 1'b0;
      default   :   clk_enb = 1;
   endcase
end


// Clock Gating

ctech_clk_gate u_clkgate (.GATE (clk_enb), . CLK(clk_in), .GCLK(clk_out));



endmodule


