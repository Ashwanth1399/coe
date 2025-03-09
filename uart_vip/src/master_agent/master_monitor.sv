//  ################################################################################################
//
//  Licensed to the Apache Software Foundation (ASF) under one or more contributor license 
//  agreements. See the NOTICE file distributed with this work for additional information
//  regarding copyright ownership. The ASF licenses this file to you under the Apache License,
//  Version 2.0 (the"License"); you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software distributed under the 
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, 
//  either express or implied. See the License for the specific language governing permissions and 
//  limitations under the License.
//
//  ################################################################################################
// Use of Include Guards
//`ifndef _master_monitor_INCLUDED_
//`define _master_monitor_INCLUDED_


//------------------------------------------------------------------------------------------------//
//  Class: master_monitor
//  The user-defined monitor is extended from uvm_monitor, uvm_monitor is inherited by uvm_component.
//  A monitor is a passive entity that samples the DUT signals through the virtual interface and 
//  converts the signal level activity to the transaction level. Monitor samples DUT signals but 
//  does not drive them.
//------------------------------------------------------------------------------------------------//
class master_monitor extends uvm_monitor;

//  Factory Method in UVM enables us to register a class, object and variables inside the factory 
  	`uvm_component_utils(master_monitor)
	uvm_analysis_port#(master_xtn) mon_tx2scb;
//  Virtual interface holds the pointer to the Interface.  
	virtual uart_if vif;
	master_xtn trans_collected;
  	master_driver m_drv;
	real bit_time=1060;

//------------------------------------------------------------------------------------------------//
//  The extern qualifier indicates that the body of the method (its implementation) is to be found 
//  outside the declaration.
//------------------------------------------------------------------------------------------------//
	extern function new(string name = "master_monitor", uvm_component parent);
	extern function void build_phase(uvm_phase phase);
	extern task run_phase(uvm_phase phase);
	extern task collect_data();
endclass:master_monitor


//------------------------------------------------------------------------------------------------//
//  constructor:new
//  The new function is called as class constructor. On calling the new method it allocates the 
//  memory and returns the address to the class handle. For the component class two arguments to be 
//  passed. 
//------------------------------------------------------------------------------------------------//
function master_monitor :: new(string name ="master_monitor",uvm_component parent);
  	super.new(name, parent);
	mon_tx2scb = new("mon_tx2scb", this);
endfunction:new


//-----------------------------------------------------------------------------------------------//
//  phase:Build
//  The build phases are executed at the start of the UVM Testbench simulation and their overall 
//  purpose is to construct, configure and connect the Testbench component hierarchy.
//  All the build phase methods are functions and therefore execute in zero simulation time.	
//------------------------------------------------------------------------------------------------//
function void master_monitor::build_phase(uvm_phase phase);
    if(!(uvm_config_db#(virtual uart_if)::get(this,"","vif",vif)))
      begin
        `uvm_fatal("No vif",$sformatf("No vif in config db"))
      end
      trans_collected = master_xtn::type_id::create("trans_collected");
  endfunction:build_phase



//-----------------------------------------------------------------------------------------------//
//  phase:run
//  The run phase is used for the stimulus generation and checking activities of the Testbench. 
//  The run phase is implemented as a task, and all uvm_component run tasks are executed in parallel.
//------------------------------------------------------------------------------------------------//
task master_monitor::run_phase(uvm_phase phase);
  	forever
  	begin
	collect_data();
	end 
endtask:run_phase

  
//------------------------------------------------------------------------------------------------//
//  Task: collect_data
//  Collect_data will collect the data from the interface and converts it to class master_txn type
//  which will be used by the scoreboard and coverage
//------------------------------------------------------------------------------------------------//
task master_monitor::collect_data();
  	reg [7:0] buffer;
	int ser_half_period=53;
	forever begin
		@(negedge vif.tx);
            
		repeat (ser_half_period) #10;
		
		repeat (8) begin
			repeat (ser_half_period) #10;
			repeat (ser_half_period) #10;
			buffer = {vif.tx, buffer[7:1]};
		end

		repeat (ser_half_period) #10;
		repeat (ser_half_period) #10;
		uvm_config_db #(int)::set(null,"*","tx_data",buffer);
		
		`uvm_info(get_type_name, $sformatf("tx data = %d", buffer), UVM_MEDIUM)
		trans_collected.tx_data = buffer;
		mon_tx2scb.write(trans_collected);

	end
endtask:collect_data


