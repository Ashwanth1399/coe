class scoreboard extends uvm_scoreboard;
  `uvm_component_utils(scoreboard)
  `uvm_analysis_imp_decl(_mon_tx2scb)
  `uvm_analysis_imp_decl(_mon_rx2scb)
  master_xtn mtr_seq_queue[$:10];
  slave_xtn slv_seq_queue[$]; 
  uvm_analysis_imp_mon_tx2scb#(master_xtn,scoreboard) tx2scb; 
  uvm_analysis_imp_mon_rx2scb#(slave_xtn,scoreboard) rx2scb; 
 // uvm_blocking_put_imp#(seq_items, scoreboard) sb_put_export_B;
  
  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    tx2scb=new("tx2scb",this);
    rx2scb=new("rx2scb",this);
  endfunction
  
  task write_mon_tx2scb(master_xtn t);
    mtr_seq_queue.push_back(t);
  endtask
  
  task write_mon_rx2scb(slave_xtn t);
    slv_seq_queue.push_back(t);
  endtask
  
  virtual task run_phase(uvm_phase phase);
    forever begin
      master_xtn tx;
      slave_xtn rx;
      wait(mtr_seq_queue.size > 0);
      tx=mtr_seq_queue.pop_back();

      if(tx.tx_data == 12) begin
	      slv_seq_queue.delete();
	      wait(slv_seq_queue.size > 0);
	      tx=mtr_seq_queue.pop_back();
	      rx=slv_seq_queue.pop_back();
	      if(tx.tx_data==rx.rx_data)
	      	      `uvm_info("scoreboard:","---Loop Back Test passed---",UVM_NONE)
	      else
      	      begin
	    	      `uvm_error("scoreboard","---Test fail---")
	    	      `uvm_info("TEST FAIL",$sformatf("expected output %d",tx.tx_data),UVM_NONE)
	    	      `uvm_info("TEST FAIL",$sformatf("actual output %d",rx.rx_data),UVM_NONE)
      	      end
      end
      else
      begin
	      slv_seq_queue.delete();
	      mtr_seq_queue.delete();
      end
    end
  endtask
endclass
