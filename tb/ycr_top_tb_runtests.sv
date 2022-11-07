/// @file       <ycr_top_tb_runtests.sv>
/// @brief      YCR testbench run tests
///


//-------------------------------------------------------------------------------
// Run tests
//-------------------------------------------------------------------------------

initial begin
    $value$plusargs("imem_pattern=%h", imem_req_ack_stall);
    $value$plusargs("dmem_pattern=%h", dmem_req_ack_stall);

    $display("imem_pattern:%x",imem_req_ack_stall);
    $display("dmem_pattern:%x",dmem_req_ack_stall);
`ifdef SIGNATURE_OUT
    $value$plusargs("test_name=%s", s_testname);
    b_single_run_flag = 1;
`else // SIGNATURE_OUT

    $value$plusargs("test_info=%s", s_info);
    $value$plusargs("test_results=%s", s_results);

    f_info      = $fopen(s_info, "r");
    f_results   = $fopen(s_results, "a");
`endif // SIGNATURE_OUT

    fuse_mhartid = 0;


end
/***
// Debug message - dinesh A
 logic [`YCR_DMEM_AWIDTH-1:0]           core2imem_addr_o_r;           // DMEM address
 logic [`YCR_DMEM_AWIDTH-1:0]           core2dmem_addr_o_r;           // DMEM address
 logic                                   core2dmem_cmd_o_r;
 
 `define RISC_CORE  i_top.i_core_top_0
 
 always@(posedge `RISC_CORE.clk) begin
     if(`RISC_CORE.imem2core_req_ack_i && `RISC_CORE.core2imem_req_o)
           core2imem_addr_o_r <= `RISC_CORE.core2imem_addr_o;
 
     if(`RISC_CORE.dmem2core_req_ack_i && `RISC_CORE.core2dmem_req_o) begin
           core2dmem_addr_o_r <= `RISC_CORE.core2dmem_addr_o;
           core2dmem_cmd_o_r  <= `RISC_CORE.core2dmem_cmd_o;
     end
 
     if(`RISC_CORE.imem2core_resp_i !=0)
           $display("RISCV-DEBUG => IMEM ADDRESS: %x Read Data : %x Resonse: %x", core2imem_addr_o_r,`RISC_CORE.imem2core_rdata_i,`RISC_CORE.imem2core_resp_i);
     if((`RISC_CORE.dmem2core_resp_i !=0) && core2dmem_cmd_o_r)
           $display("RISCV-DEBUG => DMEM ADDRESS: %x Write Data: %x Resonse: %x", core2dmem_addr_o_r,`RISC_CORE.core2dmem_wdata_o,`RISC_CORE.dmem2core_resp_i);
     if((`RISC_CORE.dmem2core_resp_i !=0) && !core2dmem_cmd_o_r)
           $display("RISCV-DEBUG => DMEM ADDRESS: %x READ Data : %x Resonse: %x", core2dmem_addr_o_r,`RISC_CORE.dmem2core_rdata_i,`RISC_CORE.dmem2core_resp_i);
 end
**/

  logic [31:0] pc_count;
  logic [31:0] instr_count;
 `define RISC_CORE  i_top.i_core_top_0
 `define RISC_EXU  i_top.i_core_top_0.i_pipe_top.i_pipe_exu
 `define RISC_IFU  i_top.i_core_top_0.i_pipe_top.i_pipe_ifu

 initial begin
	 pc_count    = 0;
	 instr_count = 0;
 end

 /**
 always@(posedge `RISC_CORE.clk) begin
	 if(rst_init) begin
	     pc_count = 0;
	 end else if(`RISC_EXU.pc_curr_upd) begin
             $display("RISCV-DEBUG => Cnt: %x PC: %x", pc_count,`RISC_EXU.pc_curr_ff);
             pc_count = pc_count+1;
	  end
 end
 ***/
/** 
 always@(posedge `RISC_CORE.clk) begin
	 if(rst_init) begin
	     instr_count = 0;
	 end else if(`RISC_IFU.ifu2idu_vd_o & `RISC_IFU.idu2ifu_rdy_i) begin
             $display("RISCV-DEBUG => Cnt: %x Instr: %x", instr_count,`RISC_IFU.ifu2idu_instr_o);
             instr_count = instr_count+1;
	  end
 end
**/
`ifdef GL
//  wire [31:0] func_return_val = {i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][31],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][30],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][29],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][28],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][27],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][26],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][25],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][24],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][23],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][22],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][21],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][20],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][19],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][18],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][17],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][16],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][15],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][14],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][13],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][12],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][11],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][10],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][9],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][8],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][7],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][6],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][5],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][4],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][3],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][2],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][1],
//	                         i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10][0]};
//
  wire [31:0] func_return_val = i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.func_return_val; //
`else
  wire [31:0] func_return_val = i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10];
`endif

always @(posedge clk) begin
    bit test_pass;
    int unsigned                            f_test;
    int unsigned                            f_test_ram;
    if (test_running) begin
        test_pass = 1;
        rst_init <= 1'b0;
	if(i_top.i_core_top_0.i_pipe_top.i_pipe_exu.pc_curr_ff === 32'hxxxx_xxxx) begin
	   $display("ERROR: CURRENT PC Counter State is Known");
	   $finish;
	end
        if ((i_top.i_core_top_0.i_pipe_top.i_pipe_exu.exu2pipe_pc_curr_o == YCR_SIM_EXIT_ADDR) & ~rst_init & &rst_cnt) begin

            `ifdef VERILATOR
                logic [255:0] full_filename;
                full_filename = test_file;
            `else // VERILATOR
                string full_filename;
                full_filename = test_file;
            `endif // VERILATOR

            if (is_compliance(test_file)) begin
                logic [31:0] tmpv, start, stop, ref_data, test_data;
                integer fd;
                `ifdef VERILATOR
                logic [2047:0] tmpstr;
                `else // VERILATOR
                string tmpstr;
                `endif // VERILATOR

	        // Flush the content of dcache for signature validation at app
	        // memory	
	        force i_top.u_intf.u_dcache.cfg_force_flush = 1'b1;
	        wait(i_top.u_intf.u_dcache.force_flush_done == 1'b1);
	        release i_top.u_intf.u_dcache.cfg_force_flush;
		$display("STATUS: Checking Complaince Test Status .... ");
                test_running <= 1'b0;
                test_pass = 1;

                $sformat(tmpstr, "riscv64-unknown-elf-readelf -s %s | grep 'begin_signature\\|end_signature' | awk '{print $2}' > elfinfo", get_filename(test_file));
                fd = $fopen("script.sh", "w");
                if (fd == 0) begin
                    $write("Can't open script.sh\n");
                    $display("ERRIR:Can't open script.sh\n");
                    test_pass = 0;
                end
                $fwrite(fd, "%s", tmpstr);
                $fclose(fd);

                $system("sh script.sh");

                fd = $fopen("elfinfo", "r");
                if (fd == 0) begin
                    $write("Can't open elfinfo\n");
                    $display("ERROR: Can't open elfinfo\n");
                    test_pass = 0;
                end
                if ($fscanf(fd,"%h\n%h", start, stop) != 2) begin
                    $write("Wrong elfinfo data\n");
                    $display("ERROR:Wrong elfinfo data: start: %x stop: %x\n",start,stop);
                    test_pass = 0;
                end
                if (start > stop) begin
                    tmpv = start;
                    start = stop;
                    stop = tmpv;
                end
                $fclose(fd);
		start = start & 32'h07FF_FFFF;
	        stop  = stop & 32'h07FF_FFFF;
		$display("Complaince Signature Start Address: %x End Address:%x",start,stop);

		//if((start & 32'h1FFF) > 512)
		//	$display("ERROR: Start address is more than 512, Start: %x",start & 32'h1FFF);
		//if((stop & 32'h1FFF) > 512)
		//	$display("ERROR: Stop address is more than 512, Start: %x",stop & 32'h1FFF);

                `ifdef SIGNATURE_OUT

                    $sformat(tmpstr, "%s.signature.output", s_testname);
`ifdef VERILATOR
                    tmpstr = remove_trailing_whitespaces(tmpstr);
`endif
                    fd = $fopen(tmpstr, "w");
                    while ((start != stop)) begin
			$display("Checking Signature at: %x",start);
                        test_data = {i_dmem_tb.memory[start+3], i_dmem_tb.memory[start+2], i_dmem_tb.memory[start+1], i_dmem_tb.memory[start]};
                        //test_data[31:24] = u_tsram0_2kb.mem[(start & 32'h1FFF)+3];
                        //test_data[23:16] = u_tsram0_2kb.mem[(start & 32'h1FFF)+2];
                        //test_data[15:8]  = u_tsram0_2kb.mem[(start & 32'h1FFF)+1];
                        //test_data[7:0]   = u_tsram0_2kb.mem[(start & 32'h1FFF)+0];
                        $fwrite(fd, "%x", test_data);
                        $fwrite(fd, "%s", "\n");
                        start += 4;
                    end
                    $fclose(fd);
                `else //SIGNATURE_OUT
                    $sformat(tmpstr, "riscv_compliance/ref_data/%s", get_ref_filename(test_file));
`ifdef VERILATOR
                tmpstr = remove_trailing_whitespaces(tmpstr);
`endif
                    fd = $fopen(tmpstr,"r");
                    if (fd == 0) begin
                        $write("Can't open reference_data file: %s\n", tmpstr);
                        $display("ERROR: Can't open reference_data file: %s\n", tmpstr);
                        test_pass = 0;
                    end
                    while (!$feof(fd) && (start != stop)) begin
                        $fscanf(fd, "0x%h,\n", ref_data);
		        //$writememh("sram0_out.hex",u_tsram0_2kb.mem,0,511);
                       // test_data = u_tsram0_2kb.mem[((start >> 2) & 32'h1FFF)];
			//$display("Compare Addr: %x ref_data : %x, test_data: %x",start,ref_data,test_data);
                        test_data = {i_dmem_tb.memory[start+3], i_dmem_tb.memory[start+2], i_dmem_tb.memory[start+1], i_dmem_tb.memory[start]};
                        test_pass &= (ref_data == test_data);
			if(ref_data != test_data)
			   $display("ERROR: Compare Addr: %x Mem Addr: %x ref_data : %x, test_data: %x",start,start & 32'h1FFF,ref_data,test_data);
                        start += 4;
                    end
                    $fclose(fd);
                    tests_total += 1;
                    tests_passed += test_pass;
                    if (test_pass) begin
                        $write("\033[0;32mTest passed\033[0m\n");
                    end else begin
                        $write("\033[0;31mTest failed\033[0m\n");
                    end
                `endif  // SIGNATURE_OUT
            end else begin // Non compliance mode
                test_running <= 1'b0;
		//if(i_top.i_core_top_0.i_pipe_top.i_pipe_mprf.mprf_int[10] != 0)
		if(func_return_val != 0)
		   $display("ERROR: mprf_int[10]: %x not zero",func_return_val);
                test_pass = (func_return_val == 0);
                tests_total     += 1;
                tests_passed    += test_pass;
                `ifndef SIGNATURE_OUT
                    if (test_pass) begin
                        $write("\033[0;32mTest passed\033[0m\n");
                    end else begin
                        $write("\033[0;31mTest failed\033[0m\n");
                    end
                `endif //SIGNATURE_OUT
            end
            $fwrite(f_results, "%s\t\t%s\t%s\n", test_file, "OK" , (test_pass ? "PASS" : "__FAIL"));
        end
    end else begin
`ifdef VERILATOR
    `ifdef SIGNATURE_OUT
        if ((s_testname.len() != 0) && (b_single_run_flag)) begin
            $sformat(test_file, "%s.bin", s_testname);
    `else //SIGNATURE_OUT
        if ($fgets(test_file,f_info)) begin
            test_file = test_file >> 8; // < Removing trailing LF symbol ('\n')
    `endif //SIGNATURE_OUT
`else // VERILATOR
        if (!$feof(f_info)) begin
            $fscanf(f_info, "%s\n", test_file);
	    $sformat(test_ram_file, "%s.ram",test_file);
`endif // VERILATOR
            f_test = $fopen(test_file,"r");
            if (f_test != 0) begin
            // Launch new test
                `ifdef YCR_TRACE_LOG_EN
                    i_top.i_core_top_0.i_pipe_top.i_tracelog.test_name = test_file;
                `endif // YCR_TRACE_LOG_EN
                //i_imem_tb.test_file = test_file;
                //i_imem_tb.test_file_init = 1'b1;
                $readmemh(test_file, i_imem_tb.memory);
	        $display("i_imem_tb: Loading Memory file: %s",test_file);
           
	        // If <test>.hex.ram file available	
		f_test_ram = $fopen(test_ram_file,"r");
                if (f_test_ram != 0) begin
                   //i_dmem_tb.test_file = test_ram_file;
                   //i_dmem_tb.test_file_init = 1'b1;
                   $readmemh(test_ram_file, i_dmem_tb.memory);
	           $display("i_dmem_tb: Loading Memory file: %s",test_ram_file);
		end

                `ifndef SIGNATURE_OUT
                    $write("\033[0;34m---Test: %s\033[0m\n", test_file);
                `endif //SIGNATURE_OUT
                test_running <= 1'b1;
                rst_init <= 1'b1;
                `ifdef SIGNATURE_OUT
                    b_single_run_flag = 0;
                `endif
            end else begin
                $fwrite(f_results, "%s\t\t%s\t%s\n", test_file, "__FAIL", "--------");
            end
        end else begin
            // Exit
            `ifndef SIGNATURE_OUT
                $display("\n#--------------------------------------");
                $display("# Summary: %0d/%0d tests passed", tests_passed, tests_total);
                $display("#--------------------------------------\n");
                $fclose(f_info);
                $fclose(f_results);
            `endif
            $finish();
        end
    end
end
