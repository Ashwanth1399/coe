// License copy
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

// Use of Include Guards
//`ifndef _base_test_INCLUDED_
//`define _base_test_INCLUDED_


//-----------------------------------------------------------------------------------------------
//class:base_test
//In this we provide information about setting env_config and starting the base test
//------------------------------------------------------------------------------------------------
class base_test extends uvm_test;
	`uvm_component_utils(base_test)

//Declaring handles for different components
    	 tb envh;
	 vbase_seq vseq;
  //---------------------------------------------
  // Externally defined tasks and functions
  //---------------------------------------------
	extern function new(string name = "base_test" , uvm_component parent);
	extern function void build_phase(uvm_phase phase);
  	extern task run_phase(uvm_phase phase);

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction
endclass:base_test


//-----------------------------------------------------------------------------
// Constructor: new
// Initializes the config_template class object
//
// Parameters:
//  name - instance name of the config_template
//  parent - parent under which this component is created
//-----------------------------------------------------------------------------
function base_test::new(string name = "base_test" , uvm_component parent);
	super.new(name,parent);
endfunction:new


//-----------------------------------------------------------------------------
// Function: build_phase
// Creates the required ports
//
// Parameters:
//  phase - stores the current phase 
//-----------------------------------------------------------------------------
function void base_test::build_phase(uvm_phase phase);
	super.build_phase(phase);
	envh = tb::type_id::create("envh",this);
        vseq = vbase_seq::type_id::create("vseq"); 
	
endfunction:build_phase

  //--------------------------------------------------------------------------------
  //Task:run_phase
  //--------------------------------------------------------------------------------

task base_test::run_phase(uvm_phase phase);
      phase.raise_objection(this);
      vseq.start(envh.v_seqrh);
      #100000000;
      phase.drop_objection(this);
endtask



