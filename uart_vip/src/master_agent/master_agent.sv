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
//  Use of Include Guards
//`ifndef _master_agent_INCLUDED_
//`define _master_agent_INCLUDED_

//------------------------------------------------------------------------------------------------//
//  Class: master_agent
//  master_agent is extended from uvm_agent, uvm_agent is inherited by uvm_component.
//  An agent typically contains: a driver,sequencer, and monitor. Agents can be configured either
//  active or passive.
//------------------------------------------------------------------------------------------------//
class master_agent extends uvm_agent;

//  Factory registration is done by passing class name as argument.

 	`uvm_component_utils(master_agent)
	

//  Handles for the driver, monitor, sequencer is also defined here
	master_driver drvh;
	master_monitor monh;
	master_sequencer seqr;
 

//------------------------------------------------------------------------------------------------//
//  The extern qualifier indicates that the body of the method (its implementation) is to be found 
//  outside the declaration.
//------------------------------------------------------------------------------------------------//
  extern function new(string name="master_agent", uvm_component parent);
	extern function void build_phase(uvm_phase phase);
	extern function void connect_phase (uvm_phase phase);
endclass


//-----------------------------------------------------------------------------------------------//
//constructor:new
//The new function is called as class constructor. On calling the new method it allocates the 
//  memory and returns the address to the class handle.
//------------------------------------------------------------------------------------------------//
function master_agent::new(string name="master_agent", uvm_component parent);
	super.new(name, parent);
endfunction:new


//-----------------------------------------------------------------------------------------------//
//  phase:build
//  The build phases are executed at the start of the UVM Testbench simulation and their overall 
//  purpose is to construct, configure and connect the Testbench component hierarchy.
//  All the build phase methods are functions and therefore execute in zero simulation time.
//------------------------------------------------------------------------------------------------//
function void master_agent::build_phase(uvm_phase phase);
	super.build_phase(phase);

//  For Active UVM Agent monitor class is created along with the Sequencer and Driver but for the
	monh=master_monitor::type_id::create("monh", this);
	drvh=master_driver::type_id::create("drvh", this);
	seqr=master_sequencer::type_id::create("seqr", this);
endfunction:build_phase


//-----------------------------------------------------------------------------------------------//
//  phase:connect
//  The connect phase is used to make TLM connections between components or to assign handles to 
//  testbench resources. It has to occur after the build method so that Testbench component 
//  hierarchy could be in place and it works from the bottom-up of the hierarchy upwards.
//------------------------------------------------------------------------------------------------//
function void master_agent::connect_phase(uvm_phase phase);
	drvh.seq_item_port.connect(seqr.seq_item_export);
endfunction:connect_phase
