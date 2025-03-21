//  ###########################################################################
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
//  ###########################################################################
//   Use of Include Guards
//`ifndef _slave_driver_INCLUDED_
//`define _slave_driver_INCLUDED_

//-------------------------------------------------------------------------------------------------
//class:slave_driver
//A driver is written by extending the uvm_driver.uvm_driver is inherited from uvm_component, 
//Methods and TLM port (seq_item_port) are defined for communication between sequencer and driver.
//The uvm_driver is a parameterized class and it is parameterized with the type of the request
//sequence_item and the type of the response sequence_item.
//-------------------------------------------------------------------------------------------------
class slave_driver extends uvm_driver #(slave_xtn);


 //-------------------------------------------------------------------------------------------------
 //Factory registration is done by passing class name as argument.
 //Factory Method in UVM enables us to register a class, object and variables inside the factory 
 //so that we can override their type (if needed) from the test bench without needing to make any
//significant change in component structure.
  //-----------------------------------------------------------------------------------------------
		`uvm_component_utils(slave_driver)

    //Virtual interface holds the pointer to the Interface.    
		 virtual uart_if vif;
		 real bit_time=1060;
    //------------------------------------------------------------------------------------------
    //Defining external tasks and functions
    //------------------------------------------------------------------------------------------
		 extern function new (string name="slave_driver", uvm_component parent);
		 extern function void build_phase(uvm_phase phase);
		 extern task run_phase(uvm_phase phase);	

endclass:slave_driver

  //-------------------------------------------------------------------------------------------------
  //constructor:new
  //The new function is called as class constructor. On calling the new method it allocates the 
  //memory and returns the address to the class handle. For the component class two arguments to be 
  //passed. 
  //-----------------------------------------------------------------------------------------------
	function slave_driver::new(string name = "slave_driver", uvm_component parent);
		super.new(name, parent);
	endfunction:new


//-----------------------------------------------------------------------------------------------//
//  phase:Build
//  The build phases are executed at the start of the UVM Testbench simulation and their overall 
//  purpose is to construct, configure and connect the Testbench component hierarchy.
//  All the build phase methods are functions and therefore execute in zero simulation time.	
//------------------------------------------------------------------------------------------------//
function void slave_driver::build_phase(uvm_phase phase);
    if(!(uvm_config_db#(virtual uart_if)::get(this,"","vif",vif)))
      begin
        `uvm_fatal("No vif",$sformatf("No vif in config db"))
      end
  endfunction


	
//------------------------------------------------------------------------------------------------
//task:run
//The run phase is used for the stimulus generation and checking activities of the Testbench. 
//The run phase is implemented as a task, and all uvm_component run tasks are executed in parallel.
//-------------------------------------------------------------------------------------------------
	task slave_driver::run_phase(uvm_phase phase);
			
 //   real bit_time;
  //bit_time = (1/(buard_rate));

            

	     seq_item_port.get_next_item(req);

            // TODO: Create new task - sample_data

            // Waiting for the start condition
            @(negedge vif.slavedrv_cb.rx);    

            //#(((vif.bit_time)/2)*1);

            // To make sure the sampling happens
            // at the middle of the clock
            #(bit_time/2);

            // sampling the data from rx line
            for(int i=0;i<8;i++)
            begin
              req.rx_data[i] <= vif.rx;   
              #bit_time;
            end

            // Waiting for the stop condition
              if(vif.rx == 1'b1) begin
                $display("Stop condition detected \n");
              end
              #bit_time;
           
	seq_item_port.item_done();
					 
	endtask:run_phase 


    
