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




//------------------------------------------------------------------------------------------------//
//  Class: virtual_sequencer
//  A virtual sequence is a container to start multiple sequences on different sequencers in
//  the environment. 
//------------------------------------------------------------------------------------------------//
class virtual_sequencer extends uvm_sequencer #(uvm_sequence_item);

       `uvm_component_utils(virtual_sequencer)
	
	master_sequencer master_seqrh;
	slave_sequencer slave_seqrh;

	extern function new(string name = "virtual_sequencer", uvm_component parent);

endclass


//----------------------------------------------------------------------------------------------------
// Constructor: new
// Initializes the config_template class object
//
// Parameters:
//  name - instance name of the config_template
//  parent - parent under which this component is created
//---------------------------------------------------------------------------------------------------
function virtual_sequencer::new(string name= "virtual_sequencer", uvm_component parent);
	super.new(name, parent);
endfunction



