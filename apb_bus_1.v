`timescale 1ns/1ps

module APB_BUS
#(parameter PDATA_WIDTH = 32,
  parameter PADDR_WIDTH = 32,
  parameter FDATA_WIDTH = 32
)
(
  input                          pclk,
  input                          preset_n,
  input        [PADDR_WIDTH-1:0] paddr,
  input                          pwrite,
  input                          psel_0,
  input                          psel_1,
  input                          penable,
  input        [PDATA_WIDTH-1:0] pwdata,
  output reg   [PDATA_WIDTH-1:0] prdata,
  output reg                     pready,
  output reg                     pslverr,
  
  input                          ff1_full,
  output reg   [FDATA_WIDTH-1:0] ff1_wdata,
  output reg                     ff1_wrn,
  
  input        [FDATA_WIDTH-1:0] ff2_rdata,
  input                          ff2_empty,
  output reg                     ff2_rdn,
  output reg                     ff2_rd_data_vld
);

localparam IDLE_ST  = 2'b00;
localparam WRITE_ST = 2'b01;
localparam READ_ST  = 2'b10;
localparam WAIT_ST  = 2'b11;


reg [1:0] state;

always @(posedge pclk or negedge preset_n) begin
  if (preset_n == 1'b0) begin
    prdata          <= {PDATA_WIDTH{1'b0}};
    pready          <= 1'b0;
    pslverr         <= 1'b0;
    ff1_wdata       <= {FDATA_WIDTH{1'b0}};
    ff1_wrn         <= 1'b0;
    ff2_rdn         <= 1'b0;
    ff2_rd_data_vld <= 1'b0;
    state           <= IDLE_ST;
  end
  else begin
    case (state)
      IDLE_ST : begin
        prdata          <= prdata;
	pslverr         <= 1'b0;
        pready          <= 1'b0;
        ff1_wrn         <= 1'b0;
        ff2_rdn         <= 1'b0;
	ff2_rd_data_vld <= 1'b0;
	if ((psel_0 || psel_1) && penable && (ff2_rd_data_vld == 1'b0)) begin
          if (pwrite) begin
            state <= WRITE_ST;
          end
          else begin
            if(ff2_empty == 1'b0)
	  //if((ff2_empty == 1'b0) && psel_1)
	       begin
	         ff2_rdn <= 1'b1;
		 pslverr <= 1'b0;
                 state   <= WAIT_ST;
	       end
            else
	      begin
                ff2_rdn <= 1'b0;
		pslverr <= 1'b1;
                state   <= READ_ST;
	      end
            //state <= READ_ST;
	    end
          end
	  else begin
	    state <= IDLE_ST;
	  end
      end

      WRITE_ST : begin
        if(psel_0 && (ff1_full == 1'b0)) begin
	  ff1_wdata <= pwdata;
          ff1_wrn   <= 1'b1;		  
          pready    <= 1'b1; 
          state     <= IDLE_ST;		  
        end
        else begin
	  ff1_wdata <= 1'b0;
	  ff1_wrn   <= 1'b0;
	  pready    <= 1'b0;
	  pslverr   <= 1'b1;
	  state     <= IDLE_ST;
        end		
      end

      READ_ST : begin
	//if(psel_1 && (ff2_empty == 1'b0)) begin
	  prdata          <= ff2_rdata;
          pready          <= 1'b1;
	  ff2_rd_data_vld <= 1'b1;
          state           <= IDLE_ST;
        //end		
        //else begin
        //  prdata          <= 32'd0;
      	//  pready          <= 1'b0;
	//  ff2_rd_data_vld <= 1'b0;
      	//  pslverr         <= 1'b1;
      	//end
      end
      WAIT_ST : begin
	state   <= READ_ST;
        ff2_rdn <= 1'b0;
      end
      default: begin
        state <= IDLE_ST;
      end
    endcase
  end
end 


endmodule
