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
`include "FIFO.sv"
`include "apb_bus_1.v"
`ifndef PICORV32_REGS
`ifdef PICORV32_V
`error "picosoc.v must be read before picorv32.v!"
`endif

`define PICORV32_REGS picosoc_regs
`endif

`ifndef PICOSOC_MEM
`define PICOSOC_MEM picosoc_mem
`endif

// this macro can be used to check if the verilog files in your
// design are read in the correct order.
`define PICOSOC_V

module picosoc (
	input clk,
	input resetn,

	output        iomem_valid,
	input         iomem_ready,
	output [ 3:0] iomem_wstrb,
	output [31:0] iomem_addr,
	output [31:0] iomem_wdata,
	input  [31:0] iomem_rdata,

	input  irq_5,
	input  irq_6,
	input  irq_7,

	output ser_tx,
	input  ser_rx,

	//FIFO pins added 	
	input  fifo1_rd_en,
	output [31:0]fifo1_rdata,
	output fifo1_empty,	

        input  [31:0] fifo2_wdata, 
        input  fifo2_wr_en,
        output fifo2_full,
	
	
	output flash_csb,
	output flash_clk,	
	output flash_io0_do,
        output flash_io1_do,
	output flash_io0_oe,	
	output flash_io2_do,
	output flash_io1_oe,	
	output flash_io3_do,
	output flash_io2_oe,
	output flash_io3_oe,	
	input  flash_io0_di,
	input  flash_io1_di,
	input  flash_io2_di,
	input  flash_io3_di
);
	parameter [0:0] BARREL_SHIFTER = 1;
	parameter [0:0] ENABLE_MUL = 1;
	parameter [0:0] ENABLE_DIV = 1;
	parameter [0:0] ENABLE_FAST_MUL = 0;
	parameter [0:0] ENABLE_COMPRESSED = 1;
	parameter [0:0] ENABLE_COUNTERS = 1;
	parameter [0:0] ENABLE_IRQ_QREGS = 1;

	parameter integer MEM_WORDS = 256;
	parameter [31:0] STACKADDR = (4*MEM_WORDS);       // end of memory
	parameter [31:0] PROGADDR_RESET = 32'h 0010_0000; // 1 MB into flash
	parameter [31:0] PROGADDR_IRQ = 32'h 0010_0200; //updated
	reg [31:0] irq;
 	reg fifo_clk = 0;

      	wire irq_stall = 0;
	wire irq_uart = 0;
 

 // Additional signals for interrupt
        reg irq_fifo_full;
        reg irq_fifo_full_write;
        reg irq_fifo_empty_read;	

	wire mem_valid;
	wire mem_instr;
	wire mem_ready;
	wire [31:0] mem_addr;
	wire [31:0] mem_wdata;
	wire [3:0] mem_wstrb;
	wire [31:0] mem_rdata;

	wire spimem_ready;
	wire [31:0] spimem_rdata;

	reg ram_ready;
	wire [31:0] ram_rdata;

	assign iomem_valid = mem_valid && (mem_addr[31:24] > 8'h 01);
	assign iomem_wstrb = mem_wstrb;
	assign iomem_addr = mem_addr;
	assign iomem_wdata = mem_wdata;

	
	wire psel0;
	wire psel1;
	
	reg psel0_d1;
	reg psel1_d1;
        
	wire psel_pos_edge_det;
	wire penable;
	wire pwrite;
	wire pslverr;
  	wire [31:0] prdata;
  	wire ff1_wrn;
  	wire ff2_rdn;
  	wire ff1_full;
  	wire ff2_empty;
  	wire pready;
  	wire [31:0] ff1_wdata;
  	wire [31:0] ff2_rdata;
 	reg pready_d1;
  	wire pready_neg_edge_det;

  always@(posedge clk or negedge resetn) begin
    if(!resetn) begin
      pready_d1 <= 1'b0;
    end
    else begin
      pready_d1 <= pready;
    end
  end
  
  always@(posedge clk or negedge resetn) begin
    if(!resetn) begin
      psel0_d1 <= 1'b0;
      psel1_d1 <= 1'b0;
    end
    else begin
      psel0_d1 <= psel0;
      psel1_d1 <= psel1;
    end
  end

  assign pready_neg_edge_det = (pready_d1 == 1'b1 && pready == 1'b0) ? 1'b1 : 1'b0;
  assign psel_pos_edge_det   = ((psel0 && psel0_d1) || (psel1 && psel1_d1)) ? 1'b1 : 1'b0;

  assign psel0 = (mem_addr == 32'h 0500_0004)? (pready_neg_edge_det ? 1'b0 : 1'b1) : 1'b0;
  assign psel1 = (mem_addr == 32'h 0500_0008)? (pready_neg_edge_det ? 1'b0 : 1'b1) : 1'b0;
  assign penable = (psel_pos_edge_det) ? 1'b1 : 1'b0;
  assign pwrite = psel0 ? 1'b1 : psel1 ? 1'b0 : 1'b0;
  
	//apb
	
	APB_BUS #(.PDATA_WIDTH(32),
		  .PADDR_WIDTH(32),
		  .FDATA_WIDTH(32)
		 )
          apb_fifo( 
		  .pclk              (clk),
                  .preset_n          (resetn),
              	  .paddr             (mem_addr), //signal from CPU
                  .pwrite            (pwrite),
                  .psel_0            (psel0),
                  .psel_1            (psel1),
                  .penable           (penable),
                  .pwdata            (mem_wdata), //signal from CPU      
                  .prdata            (prdata), //signal to CPU
                  .pready            (pready), //signal to CPU
                  .pslverr           (pslverr),
  
		  .ff1_wdata         (ff1_wdata),
                  .ff1_full          (ff1_full),
                  .ff1_wrn           (ff1_wrn),
                  .ff2_rdata         (ff2_rdata),
                  .ff2_empty         (ff2_empty),
                  .ff2_rdn           (ff2_rdn),
                  .ff2_rd_data_vld   (ff2_rd_data_vld)
                 );




	always @* begin
		irq = 0;
		irq[3] = irq_stall;
		irq[4] = irq_uart;
		irq[5] = ff1_full; // IRQ for FIFO full
		irq[6] = (ff1_full && ff1_wrn);
		irq[7] = (fifo1_empty && fifo1_rd_en);
		
	end
	
	wire spimemio_cfgreg_sel = mem_valid && (mem_addr == 32'h 0200_0000);
	wire [31:0] spimemio_cfgreg_do;

	wire        simpleuart_reg_div_sel = mem_valid && (mem_addr == 32'h 0200_0004);
	wire [31:0] simpleuart_reg_div_do;

	wire        simpleuart_reg_dat_sel = mem_valid && (mem_addr == 32'h 0200_0008);
	wire [31:0] simpleuart_reg_dat_do;
	wire        simpleuart_reg_dat_wait;

	assign mem_ready = (pready) || (iomem_valid && iomem_ready) || spimem_ready || ram_ready || spimemio_cfgreg_sel ||
			simpleuart_reg_div_sel || (simpleuart_reg_dat_sel && !simpleuart_reg_dat_wait);

        assign mem_rdata =  ff2_rd_data_vld ? prdata : (iomem_valid && iomem_ready) ? iomem_rdata : spimem_ready ? spimem_rdata : ram_ready ? ram_rdata :
			spimemio_cfgreg_sel ? spimemio_cfgreg_do : simpleuart_reg_div_sel ? simpleuart_reg_div_do :
			simpleuart_reg_dat_sel ? simpleuart_reg_dat_do : 32'h 0000_0000;
           
     	// fifo instance
	FIFO cpu_fifo1 ( .clk      (clk),
			.reset     (resetn),
			.write_en  (ff1_wrn),     // data from APB bus
			.read_en   (fifo1_rd_en), // data from IO list
			.data_in   (ff1_wdata),   // data from APB bus
			.data_out  (fifo1_rdata), // data to IO list
			.full      (ff1_full),    // data to APB bus
			.empty     (fifo1_empty)  // data to IO list
	              );
	// fifo instance
	FIFO cpu_fifo2 (.clk       (clk),
			.reset     (resetn),
			.write_en  (fifo2_wr_en),  // data from IO list
			.read_en   (ff2_rdn),      // data from APB bus
			.data_in   (fifo2_wdata),  // data from IO list
			.data_out  (ff2_rdata),    // data to APB bus
			.full      (fifo2_full),   // data to IO list
			.empty     (ff2_empty)     // data to APB bus
	               );
// Interrupt logic
   always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        // Reset signals
        irq_fifo_full <= 0;
        irq_fifo_full_write <= 0;
      //  write_count <= 0;
    end else begin
        // FIFO full interrupt
        if (ff1_full) begin
            irq_fifo_full <= 1;
        end else begin
            irq_fifo_full <= 0;
        end

        // Trigger interrupt when FIFO is full and wr_en is high
        if (ff1_full && ff1_wrn) begin
            irq_fifo_full_write <= 1;
        end else begin
            irq_fifo_full_write <= 0;
        end
    end
// Trigger interrupt when FIFO is empty and rd_en is high
        if (fifo1_empty && fifo1_rd_en) begin
            irq_fifo_empty_read <= 1;
        end else begin
            irq_fifo_empty_read <= 0;
        end
    end

//end


// Toggling FIFO clock
    always @(negedge clk) 
        fifo_clk <= ~fifo_clk;


	picorv32 #(
		.STACKADDR(STACKADDR),
		.PROGADDR_RESET(PROGADDR_RESET),
		.PROGADDR_IRQ(PROGADDR_IRQ),
		.BARREL_SHIFTER(BARREL_SHIFTER),
		.COMPRESSED_ISA(ENABLE_COMPRESSED),
		.ENABLE_COUNTERS(ENABLE_COUNTERS),
		.ENABLE_MUL(ENABLE_MUL),
		.ENABLE_DIV(ENABLE_DIV),
		.ENABLE_FAST_MUL(ENABLE_FAST_MUL),
		.ENABLE_IRQ(1),
		.ENABLE_IRQ_QREGS(ENABLE_IRQ_QREGS)
		//.ENABLE_TRACE(1)
	) cpu (
		.clk         (clk        ),
		.resetn      (resetn     ),
		.mem_valid   (mem_valid  ),
		.mem_instr   (mem_instr  ),
		.mem_ready   (mem_ready  ),
		.mem_addr    (mem_addr   ),
		.mem_wdata   (mem_wdata  ),
		.mem_wstrb   (mem_wstrb  ),
		.mem_rdata   (mem_rdata  ),
		.irq         (irq        )
	);

	spimemio spimemio (
		.clk    (clk),
		.resetn (resetn),
		.valid  (mem_valid && mem_addr >= 4*MEM_WORDS && mem_addr < 32'h 0200_0000),
		.ready  (spimem_ready),
		.addr   (mem_addr[23:0]),
		.rdata  (spimem_rdata),

		.flash_csb    (flash_csb   ),
		.flash_clk    (flash_clk   ),

		.flash_io0_oe (flash_io0_oe),
		.flash_io1_oe (flash_io1_oe),
		.flash_io2_oe (flash_io2_oe),
		.flash_io3_oe (flash_io3_oe),

		.flash_io0_do (flash_io0_do),
		.flash_io1_do (flash_io1_do),
		.flash_io2_do (flash_io2_do),
		.flash_io3_do (flash_io3_do),

		.flash_io0_di (flash_io0_di),
		.flash_io1_di (flash_io1_di),
		.flash_io2_di (flash_io2_di),
		.flash_io3_di (flash_io3_di),

		.cfgreg_we(spimemio_cfgreg_sel ? mem_wstrb : 4'b 0000),
		.cfgreg_di(mem_wdata),
		.cfgreg_do(spimemio_cfgreg_do)
	);

	simpleuart simpleuart (
		.clk         (clk         ),
		.resetn      (resetn      ),

		.ser_tx      (ser_tx      ),
		.ser_rx      (ser_rx      ),

		.reg_div_we  (simpleuart_reg_div_sel ? mem_wstrb : 4'b 0000),
		.reg_div_di  (mem_wdata),
		.reg_div_do  (simpleuart_reg_div_do),

		.reg_dat_we  (simpleuart_reg_dat_sel ? mem_wstrb[0] : 1'b 0),
		.reg_dat_re  (simpleuart_reg_dat_sel && !mem_wstrb),
		.reg_dat_di  (mem_wdata),
		.reg_dat_do  (simpleuart_reg_dat_do),
		.reg_dat_wait(simpleuart_reg_dat_wait)
	);

	always @(posedge clk)
		ram_ready <= mem_valid && !mem_ready && mem_addr < 4*MEM_WORDS;


	`PICOSOC_MEM #(
		.WORDS(MEM_WORDS)
	) memory (
		.clk(clk),
		.wen((mem_valid && !mem_ready && mem_addr < 4*MEM_WORDS) ? mem_wstrb : 4'b0),
		.addr(mem_addr[23:2]),
		.wdata(mem_wdata),
		.rdata(ram_rdata)
	);

endmodule

// Implementation note:
// Replace the following two modules with wrappers for your SRAM cells.

module picosoc_regs (
	input clk, wen,
	input [5:0] waddr,
	input [5:0] raddr1,
	input [5:0] raddr2,
	input [31:0] wdata,
	output [31:0] rdata1,
	output [31:0] rdata2
);
	reg [31:0] regs [0:31];

	always @(posedge clk)
		if (wen) regs[waddr[4:0]] <= wdata;

	assign rdata1 = regs[raddr1[4:0]];
	assign rdata2 = regs[raddr2[4:0]];
endmodule

module picosoc_mem #(
	parameter integer WORDS = 256
) (
	input clk,
	input [3:0] wen,
	input [21:0] addr,
	input [31:0] wdata,
	output reg [31:0] rdata
);
	reg [31:0] mem [0:WORDS-1];

	always @(posedge clk) begin
		rdata <= mem[addr];
		if (wen[0]) mem[addr][ 7: 0] <= wdata[ 7: 0];
		if (wen[1]) mem[addr][15: 8] <= wdata[15: 8];
		if (wen[2]) mem[addr][23:16] <= wdata[23:16];
		if (wen[3]) mem[addr][31:24] <= wdata[31:24];
	end
endmodule


