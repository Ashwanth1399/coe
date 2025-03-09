// ################################################################################################
//
//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.
//
//  ###############################################################################################
//   Use of Include Guards
//`ifndef _slave_monitor_INCLUDED_
//`define _slave_monitor_INCLUDED_

//-------------------------------------------------------------------------------------------------
//class:slave_monitor
//The user-defined monitor is extended from uvm_monitor, uvm_monitor is inherited by uvm_component.
//A monitor is a passive entity that samples the DUT signals through the virtual interface and 
//converts the signal level activity to the transaction level. Monitor samples DUT signals but does
//not drive them.
//-------------------------------------------------------------------------------------------------
class slave_monitor extends uvm_monitor;


  //----------------------------------------------------------------------------------------------
  //Factory registration is done by passing class name as argument.
  //Factory Method in UVM enables us to register a class, object and variables inside the factory 
  //so that we can override their type (if needed) from the test bench without needing to make any
  //significant change in component structure.
  //-----------------------------------------------------------------------------------------------
	`uvm_component_utils(slave_monitor)
	uvm_analysis_port #(slave_xtn) mon_rx2scb;

  //-----------------------------------------------------------------------------------------------
  //Virtual interface holds the pointer to the Interface.  
  //w_cfg is the handle of slave_agent_config which is extended from the configuration class    
  //-----------------------------------------------------------------------------------------------  
  virtual uart_if vif;
  real bit_time;
  slave_xtn trans_collected;
 // slave_driver s_drv;
 


  //-----------------------------------------------------------------------------------------------
  //Defining external tasks and functions
  //-----------------------------------------------------------------------------------------------
	extern function new(string name = "slave_monitor", uvm_component parent);
	extern function void build_phase(uvm_phase phase);
	extern task run_phase(uvm_phase phase);


endclass

//-------------------------------------------------------------------------------------------------
//constructor:new
  //The new function is called as class constructor. On calling the new method it allocates the 
  //memory and returns the address to the class handle. For the component class two arguments to be 
  //passed. 
  //-----------------------------------------------------------------------------------------------
	function slave_monitor :: new(string name ="slave_monitor",uvm_component parent);
		super.new(name, parent);
		mon_rx2scb =new("mon_rx2scb",this);
	endfunction:new


  //-----------------------------------------------------------------------------------------------//
//  phase:Build
//  The build phases are executed at the start of the UVM Testbench simulation and their overall 
//  purpose is to construct, configure and connect the Testbench component hierarchy.
//  All the build phase methods are functions and therefore execute in zero simulation time.	
//------------------------------------------------------------------------------------------------//
function void slave_monitor::build_phase(uvm_phase phase);
    if(!(uvm_config_db#(virtual uart_if)::get(this,"","vif",vif)))
      begin
        `uvm_fatal("No vif",$sformatf("No vif in config db"))
      end
      trans_collected=slave_xtn::type_id::create("trans_collected");
  endfunction


//------------------------------------------------------------------------------------------------
//phase:run
//The run phase is used for the stimulus generation and checking activities of the Testbench. 
//The run phase is implemented as a task, and all uvm_component run tasks are executed in parallel.
//-------------------------------------------------------------------------------------------------
	task slave_monitor::run_phase(uvm_phase phase);
	reg [7:0] buffer;
	int ser_half_period=53;
	forever begin
		@(negedge vif.rx);
            
		repeat (ser_half_period) #10;
		
		repeat (8) begin
			repeat (ser_half_period) #10;
			repeat (ser_half_period) #10;
			buffer = {vif.rx, buffer[7:1]};
		end

		repeat (ser_half_period) #10;
		repeat (ser_half_period) #10;
		
		if (buffer < 32 || buffer >= 127)
		`uvm_info(get_type_name, $sformatf("rx data = %d", buffer), UVM_MEDIUM)
		else
		`uvm_info(get_type_name, $sformatf("rx data =%c", buffer), UVM_MEDIUM)

		uvm_config_db #(int)::set(null,"*","rx_data",buffer);
		trans_collected.rx_data = buffer;
		mon_rx2scb.write(trans_collected);
	end

		
	endtask



	

