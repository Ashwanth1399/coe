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
//`ifndef _tb_INCLUDED_
//`define _tb_INCLUDED_


//------------------------------------------------------------------------------------------------//
//  Class: tb
//  Class tb is derived from uvm_env, contains all the components such as agent, scoreboard, 
//  coverage, virtual sequencer.
//------------------------------------------------------------------------------------------------//
class tb extends uvm_env;
	`uvm_component_utils(tb)

//Declaring  handles different components
	
	master_agent wagent;
	slave_agent ragent;
	virtual_sequencer v_seqrh;
	scoreboard scb;	

//---------------------------------------------
// Externally defined tasks and functions
//---------------------------------------------
	extern function new ( string name="tb", uvm_component parent);
	extern function void build_phase(uvm_phase phase);
	extern function void connect_phase(uvm_phase phase);
endclass


//-----------------------------------------------------------------------------
// Constructor: new
// Initializes the config_template class object
//
// Parameters:
//  name - instance name of the config_template
//  parent - parent under which this component is created
//-----------------------------------------------------------------------------
function tb::new(string name = "tb", uvm_component parent);
	super.new(name, parent);
endfunction:new


//-----------------------------------------------------------------------------
// Function: build_phase
// Creates the required ports
//
// Parameters:
//  phase - stores the current phase 
//----------------------------------------------------------------------------- 
function void tb::build_phase(uvm_phase phase);
	super.build_phase(phase);
	v_seqrh=virtual_sequencer::type_id::create("v_seqrh",this);
 	wagent=master_agent::type_id::create("wagent",this);
	ragent=slave_agent::type_id::create("ragent",this); 
        scb = scoreboard::type_id::create("scb",this);	
endfunction:build_phase

 
//------------------------------------------------------------------------------------------------
//phase:connect
//here the connection is done between virtual sequences in test and environment and
//connection between monitor to scoreboard
//------------------------------------------------------------------------------------------------
function void tb::connect_phase (uvm_phase phase);
	 v_seqrh.master_seqrh = wagent.seqr;
	 wagent.monh.mon_tx2scb.connect(scb.tx2scb);
	 ragent.monh.mon_rx2scb.connect(scb.rx2scb); 
endfunction:connect_phase


