/*
 *  PicoSoC - A simple example SoC using PicoRV32
 *
 *  Copyright (C) 2017  Claire Xenia Wolf <claire@yosyshq.com>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

`timescale 1 ns / 1 ps

`define cpu_status 5
`define cpu_status_change 6
`define tb_status 7
`define tb_status_change 8
`define result 9
`define fifo_base 10
`define FIFO_DEPTH 8  // Set FIFO depth

  `include "uvm_macros.svh"
import uvm_pkg::*;

`include "mem_backdoor.sv"

//`include "uart_vip/src/top/top.sv"
`include "uart_vip/src/test/test_pkg.sv"
`include "uart_vip/src/env/uart_if.sv"
`include "fifo_cov.sv"

import test_pkg::*;


module testbench;
	memory_backdoor mb=new();
        reg[31:0]  wdata_from_tb;
        reg reset_n;
	reg clk;
  	int select;
	bit[31:0] cpu_status_mon;
	bit[31:0] cpu_status_change_mon;
	bit ff2_rd_data_vld;
        bit ff2_rdn;
        bit psel1;
    	bit ff2_empty;
	bit uart_sel;
        int ram_data;
	bit [7:0] tx_data;
	bit [7:0] rx_data;
        bit [31:0] data;
	int count_0 = 0;
	int count_1 = 1;
	int x;
	int count_2 = 1;
	bit flag_error = 0;

	always #5 clk = (clk === 1'b0);

	localparam ser_half_period = 53;
	
	uart_if intf(.reset(reset_n));

  	initial	begin
	intf.tx=1;
	reset_n=0;
    	#10 reset_n = 1;
  	end
         
	integer file;
	initial begin
		file = $fopen("monitor_output.txt", "w");
		if (!file) begin
			$display("Error: Unable to open file for writing!");
			$stop; // Stop simulation if file cannot be opened
		end
	end

	always @(cpu_status_mon)
		$fdisplay(file, $time," ns | cpu_status = %0d", cpu_status_mon);
	always @( testbench.uut.soc.memory.mem[`tb_status_change])
		$fdisplay(file, $time," ns | tb_status_change = %0d", testbench.uut.soc.memory.mem[`tb_status_change]);
	always @(testbench.uut.soc.memory.mem[`tb_status])
		$fdisplay(file, $time," ns | tb_status = %0d", testbench.uut.soc.memory.mem[`tb_status]);
	always @(testbench.uut.soc.memory.mem[`result])
		$fdisplay(file, $time," ns | result = %0d", testbench.uut.soc.memory.mem[`result]);
	
	final begin
		$fclose(file);
	end

	initial begin
		$dumpfile("dump.vcd");
		$dumpvars();

		repeat (20) begin
		   repeat (50000) @(posedge clk);
		end
		$finish;
	end

	reg[15:0] cycle_cnt = 0;

	 always @(posedge clk)
	begin 
		cpu_status_mon = testbench.uut.soc.memory.mem[`cpu_status];
		cpu_status_change_mon = testbench.uut.soc.memory.mem[`cpu_status_change];
	end
	 
	 always @(*)
        begin
                ff2_rdn  = testbench.uut.soc.ff2_rdn;
		ff2_rd_data_vld = testbench.uut.soc.ff2_rd_data_vld;
                psel1 = testbench.uut.soc.psel1;
		uart_sel = testbench.uut.soc.simpleuart_reg_dat_sel; 
	end 	

    	 initial begin
	 void'($value$plusargs("select=%0d", select));
	 $display("select=%d",select);
	 case(select)
	  	1 : write_test();

		2 : read_test();
		
		3 :begin
		fork
			begin
			write_test();
			end
			begin
			interrupt_trigger();
			end
		join
		end
		4 : cpu_write_to_fifo_test();
		
		5 : fifo2_write_test_from_tb();

		6 : fifo1_full_test();

		7 : fifo2_full_test();

		8 : fifo1_empty_test();

		9 : fifo2_empty_test();	
		
		10 : cpu_write_to_fifo_test();	

		11 : fifo2_data_integrity_test();
		

	  endcase
	end

		
	reg [31:0] irq = 0;

	
	always @(posedge clk) begin
		cycle_cnt <= cycle_cnt + 1;
	end
	wire uart_read;
	wire [7:0] leds;

	wire flash_csb;
	wire flash_clk;
	wire flash_io0;
	wire flash_io1;
	wire flash_io2;
	wire flash_io3;

	always @(leds) begin
		#1 $display("%b", leds);
	end

 	
	hx8kdemo uut (
		.clk      (clk      ),
		.leds     (leds     ),
		.ser_rx   (intf.tx  ),
		.ser_tx   (intf.rx  ),
		.flash_csb(flash_csb),
		.flash_clk(flash_clk),
		.flash_io0(flash_io0),
		.flash_io1(flash_io1),
		.flash_io2(flash_io2),
		.flash_io3(flash_io3)
	);

	spiflash spiflash (
		.csb(flash_csb),
		.clk(flash_clk),
		.io0(flash_io0),
		.io1(flash_io1),
		.io2(flash_io2),
		.io3(flash_io3)
	);

	  
  	initial begin
        uvm_config_db #(virtual uart_if)::set(null,"*","vif",intf);
     	run_test("base_test");
 	end  


//--------------------------------------------------------------------------------

// FIFO read signals
    bit fifo1_rd_en;
    bit [31:0] fifo1_rdata;
    bit fifo1_full;
    assign uut.soc.fifo1_rd_en = fifo1_rd_en;
    assign fifo1_rdata = uut.soc.fifo1_rdata; 
    assign fifo_empty = uut.soc.fifo1_empty;
    assign intf.wr_en = uut.soc.simpleuart.reg_dat_re;
    assign fifo1_full =  uut.soc.ff1_full;


// FIFO write signals
    bit fifo2_wr_en;
    bit [31:0] fifo2_wdata;
    bit fifo2_full;
    bit [31:0] ff2_rdata;

    assign uut.soc.fifo2_wr_en = fifo2_wr_en; // Assign the write enable signal to the FIFO's write enable input
    assign uut.soc.fifo2_wdata = fifo2_wdata; // Assign the data to be written to the FIFO's data input
    assign fifo2_full = uut.soc.fifo2_full; 
    assign ff2_rdata = uut.soc.ff2_rdata;     
    assign ff2_empty =uut.soc.ff2_empty;
//--------------------------------------------------------------------------------
	
	task interrupt_trigger();
	repeat(130000) @(posedge clk);
	force uut.soc.irq_6=1;
	@(posedge clk);
	force uut.soc.irq_6=0;
	endtask
//--------------------------------------------------------------------------------

	task write_test();
	 wait(cpu_status_mon == 1);
	 $display("TB_handshake");
	 mb.write_to_mem(`cpu_status,0);
	 mb.write_to_mem(`cpu_status_change,0);
	 mb.write_to_mem(`tb_status,1);
	 repeat(50000) @(posedge clk);
	 mb.write_to_mem(`tb_status,4);
	 mb.write_to_mem(`tb_status_change,1);
  	 
	 wait(cpu_status_change_mon ==1);
	 mb.write_to_mem(`cpu_status,0);
	 mb.write_to_mem(`cpu_status_change,0);
	 
 	 uvm_config_db #(int)::get(null,"*","tx_data",tx_data);
	 ram_data=mb.read_from_mem('h44);
	 if(ram_data== tx_data) begin
		$display("Comparision success");
		mb.write_to_mem(`result,2);
         end
	 else
	 begin
		$display("comparision failed %d",ram_data);
		mb.write_to_mem(`result,1);
	 end
	 mb.write_to_mem(`tb_status,2);
	 mb.write_to_mem(`tb_status_change,1); 
	endtask

//--------------------------------------------------------------------------------

	task read_test();
	 wait(cpu_status_mon == 1);
	 $display("TB_handshake");
	 mb.write_to_mem(`cpu_status,0);
	 mb.write_to_mem(`cpu_status_change,0);
	 mb.write_to_mem(`tb_status,1);
	 wait(cpu_status_mon ==2);
	 mb.write_to_mem(`cpu_status,0);
	 mb.write_to_mem(`cpu_status_change,0);
	 wait(cpu_status_mon ==4);
	 mb.write_to_mem(`cpu_status,0);
	 mb.write_to_mem(`cpu_status_change,0);
	 repeat(50000) @(posedge clk);
	 uvm_config_db #(int)::get(null,"*","rx_data",rx_data);
	 ram_data=mb.read_from_mem('h44);
	 if(ram_data== rx_data)
		$display("Comparision success ramdata=%d rxdata=%d",ram_data,rx_data);
	 else
		$display("comparision failed %d",rx_data);
	endtask


// --------------------------------------------------------

task cpu_write_to_fifo_test();
   
 wait(cpu_status_mon == 1);
    
// Loop until the FIFO is empty    
    while (!fifo_empty) begin
        @(posedge clk)
        fifo1_rd_en = 1;
        @(posedge clk)
        fifo1_rd_en = 0;
	#5;

// Read data from memory at the FIFO base address plus the current offset (count)
        data = mb.read_from_mem(`fifo_base + count_0);
        $display("fifo read data = %d", fifo1_rdata);
        count_0 = count_0 + 1;
// Check if the data read from memory matches the FIFO read data
        if (data != fifo1_rdata) 
            flag_error = 1;
    end
    
// Write the result to memory based on the error flag    
    if (flag_error == 1)
        mb.write_to_mem(`result, 1);
    else
        mb.write_to_mem(`result, 2);


// Indicate the testbench status and status change       
    mb.write_to_mem(`tb_status, 2);
    mb.write_to_mem(`tb_status_change, 1);
endtask  

//-------------------------------------------------------------------------------- 
// Task for writing to FIFO2 from Testbench (TB)

task fifo2_write_test_from_tb();
    // Declare variables
    int que[$];  // Queue to hold the data written to FIFO2
    int temp;    // Temporary variable for read data
    // Wait until cpu_status_mon is 1
    wait(cpu_status_mon == 1);
    
    // Display a message to indicate handshake with the testbench
    $display("TB_handshake");

    // Reset the memory by writing 0 to cpu_status and cpu_status_change
    mb.write_to_mem(`cpu_status, 0);
    mb.write_to_mem(`cpu_status_change, 0);
    
    // Write data to FIFO2 as long as it's not full
    while (!fifo2_full) begin
        fifo2_wdata = fifo2_wdata + 1;  // Increment the FIFO write data
        @(posedge clk)
        fifo2_wr_en = 1;  // Enable write to FIFO2
        
        // Store the written data in the queue
        que.push_back(fifo2_wdata);
        $display("Writing data to FIFO: %d", fifo2_wdata);
        
        count_1 = count_1 + 1;  // Increment the write count
        
        @(posedge clk)
        fifo2_wr_en = 0;  // Disable write to FIFO2
        
        @(negedge clk);  // Wait for negative edge of the clock
    end

    // Indicate completion of the write operation
    mb.write_to_mem(`tb_status, 1);
    mb.write_to_mem(`tb_status_change, 1);

    // Wait until cpu_status_mon is 3 to begin reading from memory
    wait(cpu_status_mon == 3);
    count_1 = 0;  // Reset the count for reading
    
    // Display a message indicating the start of read operation
    $display("Read data written by CPU in SRAM");
    
    // Reset cpu status and status change flags
    mb.write_to_mem(`cpu_status, 0);
    mb.write_to_mem(`cpu_status_change, 0);
    
    // Display the start of the FIFO2 read process
    $display($time, " Initiated the read from the FIFO2");
    
    // Read and verify data from FIFO2
    while (que.size != 0) begin
        // Pop the first data from the queue
        temp = que.pop_front();
        
        // Read data from memory at FIFO base address plus the current count
        data = mb.read_from_mem(`fifo_base + count_1);
        count_1 = count_1 + 1;  // Increment the read count
        
        // Display the read data and the expected value
        $display($time, " fifo read data = %d", data);
        $display($time, " expected data = %d , actual data = %d", temp, data);
        
        // Check if the expected data matches the actual data
        if (temp != data) 
            flag_error = 1;  // Set the flag if there's a mismatch
    end

    // Display result based on error flag
    if (flag_error == 1)
        $display("FAIL");
    else
        $display("PASS");
endtask

//--------------------------------------------------------------------------------

task fifo1_full_test();
	while(1) begin
    	@(posedge clk) ;
    	if (fifo1_full == 1) begin
    	$display ("FIFO1 is FULL=%0d",fifo1_full);
    	$finish;
    	end
	end
endtask
 
//--------------------------------------------------------------------------------

task fifo2_full_test();  

    while (!fifo2_full) begin 
	    fifo2_wdata = fifo2_wdata + 1;
            @(posedge clk)
            fifo2_wr_en = 1;
            @(posedge clk)
            fifo2_wr_en = 0; 
	    @(negedge clk);
        end
    $display ("FIFO2 is FULL=%d",fifo2_full);
    $finish;    
endtask

// ---------------------------------------------------------------------------------

task fifo1_empty_test();
	while(1) begin
        wait(cpu_status_mon == 1);
    
        // Loop until the FIFO is empty    
        while (!fifo_empty) begin
        @(posedge clk)
        fifo1_rd_en = 1;
        @(posedge clk)
        fifo1_rd_en = 0;
	$display("FIFO1 data = %d",fifo1_rdata);
        end
	@(posedge clk)
	if(fifo_empty == 1) begin
		$display("FIFO1 Empty=%0d",fifo_empty);
		$finish;
	end
	end
endtask

// ---------------------------------------------------------------------------------
task fifo2_empty_test();
    
    wait(cpu_status_mon == 1);
    $display("TB_handshake");

    mb.write_to_mem(`cpu_status, 0);
    mb.write_to_mem(`cpu_status_change, 0);
    
    while (!fifo2_full && count_1 < 5) begin  
    	    fifo2_wdata = fifo2_wdata + 1;
        
	@(posedge clk)
        fifo2_wr_en = 1;
        $display("Writing data to FIFO: %d", fifo2_wdata); 
        count_1 = count_1 + 1;
        @(posedge clk)
        fifo2_wr_en = 0;
        @(negedge clk);
    end

    mb.write_to_mem(`tb_status, 1);
    mb.write_to_mem(`tb_status_change, 1);

    wait(cpu_status_mon == 3);
    count_1 = 0;
    
    if (ff2_empty) begin
        $display($time, " FIFO2 is empty.");
        end    
      endtask

// ---------------------------------------------------------------------------------
task fifo1_data_integrity_test();
 wait(cpu_status_mon == 1);
 $display("cpu_status_mon = %d at time %0t", cpu_status_mon, $time);
     
// Loop until the FIFO is empty    
    while (!fifo_empty) begin
        @(posedge clk)
        fifo1_rd_en = 1;
        @(posedge clk)
        fifo1_rd_en = 0;
	#5;
// Read data from memory at the FIFO base address plus the current offset (count)
        data = mb.read_from_mem(`fifo_base + count_0);
        $display("fifo read data = %d", fifo1_rdata);
        count_0 = count_0 + 1;

// Check if the data read from memory matches the FIFO read data
        if (data != fifo1_rdata) 
            flag_error = 1;
    end
    
// Write the result to memory based on the error flag    
    if (flag_error == 1)
	    ///$display("FAIL");
            mb.write_to_mem(`result, 1);
    else
	   // $display("PASS"); 
            mb.write_to_mem(`result, 2);


// Indicate the testbench status and status change       
    mb.write_to_mem(`tb_status, 2);
    mb.write_to_mem(`tb_status_change, 1);
    
endtask 

// ---------------------------------------------------------------------------------

task fifo2_data_integrity_test();
	
// Declare variables
    int que[$];  // Queue to hold the data written to FIFO2
    int temp;    // Temporary variable for read data
    // Wait until cpu_status_mon is 1
    wait(cpu_status_mon == 1);
    
    // Display a message to indicate handshake with the testbench
    $display("TB_handshake");

    // Reset the memory by writing 0 to cpu_status and cpu_status_change
    mb.write_to_mem(`cpu_status, 0);
    mb.write_to_mem(`cpu_status_change, 0);
    
    // Write data to FIFO2 as long as it's not full
    while (!fifo2_full) begin
        fifo2_wdata = $urandom_range(1, 100); // Generate random value
	    
        //fifo2_wdata = fifo2_wdata + 1;  // Increment the FIFO write data
        @(posedge clk)
        fifo2_wr_en = 1;  // Enable write to FIFO2
        
        // Store the written data in the queue
        que.push_back(fifo2_wdata);
        $display("Writing data to FIFO: %d", fifo2_wdata);
        
        count_1 = count_1 + 1;  // Increment the write count
        
        @(posedge clk)
        fifo2_wr_en = 0;  // Disable write to FIFO2
        
        @(negedge clk);  // Wait for negative edge of the clock
    end

    // Indicate completion of the write operation
    mb.write_to_mem(`tb_status, 1);
    mb.write_to_mem(`tb_status_change, 1);

    // Wait until cpu_status_mon is 3 to begin reading from memory
    wait(cpu_status_mon == 3);
    count_1 = 0;  // Reset the count for reading
    
    // Display a message indicating the start of read operation
    $display("Read data written by CPU in SRAM");
    
    // Reset cpu status and status change flags
    mb.write_to_mem(`cpu_status, 0);
    mb.write_to_mem(`cpu_status_change, 0);
    
    // Display the start of the FIFO2 read process
    $display($time, " Initiated the read from the FIFO2");
    
    // Read and verify data from FIFO2
    while (que.size != 0) begin
        // Pop the first data from the queue
        temp = que.pop_front();
        
        // Read data from memory at FIFO base address plus the current count
        data = mb.read_from_mem(`fifo_base + count_1);
        count_1 = count_1 + 1;  // Increment the read count
        
        // Display the read data and the expected value
        $display($time, " fifo read data = %d", data);
        $display($time, " expected data = %d , actual data = %d", temp, data);
        
        // Check if the expected data matches the actual data
        if (temp != data) 
            flag_error = 1;  // Set the flag if there's a mismatch
    end

    // Display result based on error flag
    
	if (flag_error == 1)
        $display("FAILED: Data mismatch detected!");

	else
        $display("SUCCESS: Data integrity verified!");

endtask
endmodule





