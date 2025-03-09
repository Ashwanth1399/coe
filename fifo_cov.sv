module fifo_coverage ();

	covergroup cg_fifo1 @(posedge testbench.uut.soc.clk);
	
	write_cover1 : coverpoint testbench.uut.soc.ff1_wrn {
       	    bins fifo1_wr_en_1[] = {1'b1};   
        }

        read_cover1 : coverpoint testbench.uut.soc.fifo1_rd_en{
            bins fifo1_rd_en_1[] = {1'b1};  
        }

        full_cover1 : coverpoint testbench.uut.soc.ff1_full {
            bins fifo1_full_covered1[] = {1'b1};
        }

        empty_cover1 : coverpoint testbench.uut.soc.fifo1_empty {
            bins empty_covered1[] = {1'b1};
        }  
	
        wr_data_cover1 : coverpoint testbench.uut.soc.ff1_wdata {
            bins fifo1_data_in_low     = {[32'h0:32'h2]};
            bins fifo1_data_in_mid     = {[32'h3:32'h5]};
	    bins fifo1_data_in_high    = {[32'h6:32'h8]};
        }   

        rd_data_cover1 : coverpoint testbench.uut.soc.fifo1_rdata {
            bins fifo1_data_out_low     = {[32'h0:32'h2]};
            bins fifo1_data_out_mid     = {[32'h3:32'h5]};
	    bins fifo1_data_out_high    = {[32'h6:32'h8]};
        } 
	endgroup	

	
	covergroup cg_fifo2 @(posedge testbench.uut.soc.clk);

	write_cover2 : coverpoint testbench.uut.soc.fifo2_wr_en {
       	    bins write_covered2[] = {1'b1};
        }
        
	read_cover2 : coverpoint testbench.uut.soc.ff2_rdn{
            bins read_covered2[] = {1'b1};
        }

        full_cover2 : coverpoint testbench.uut.soc.fifo2_full {
            bins full_covered2[] = {1'b1};
        }

        empty_cover2 : coverpoint testbench.uut.soc.ff2_empty {
            bins empty_covered2[] = {1'b1};
        }  
	
        wr_data_cover2 : coverpoint testbench.uut.soc.fifo2_wdata {
            bins fifo2_data_in_low     = {[32'h0:32'h2]};
            bins fifo2_data_in_mid     = {[32'h3:32'h5]};
	    bins fifo2_data_in_high    = {[32'h6:32'h8]};
        }   
        
	rd_data_cover2 : coverpoint testbench.uut.soc.ff2_rdata {
            bins fifo2_data_out_low     = {[32'h0:32'h2]};
            bins fifo2_data_out_mid     = {[32'h3:32'h5]};
	    bins fifo2_data_out_high    = {[32'h6:32'h8]};
        }   	
	endgroup

	covergroup cg_uart @(posedge testbench.uut.soc.clk);

        uart_tx_cover : coverpoint testbench.intf.tx { 
	bins tx    = {0};
        }
	uart_rx_cover : coverpoint testbench.intf.rx {
	bins rx    = {1};

        }
 
      	endgroup

	cg_fifo1 cg_fifo_inst1 = new;
   	cg_fifo2 cg_fifo_inst2 = new;
	cg_uart  cg_uart_inst1 = new;
	

endmodule

