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
//`ifndef _virtual_seqs_INCLUDED_
//`define _virtual_seqs_INCLUDED_


//-----------------------------------------------------------------------------
//  Class: vbase_seq
//  A virtual sequence is a container to start multiple sequences on different sequencers in the
//  environment.
//-----------------------------------------------------------------------------
class vbase_seq extends uvm_sequence #(uvm_sequence_item);
	`uvm_object_utils(vbase_seq)
	 
	 master_seqs m_seq; 
	 //slave_seqs s_seq;

	 `uvm_declare_p_sequencer(virtual_sequencer)

//---------------------------------------------
// Externally defined tasks and functions
//---------------------------------------------
extern function new(string name="vbase_seq");
	extern task body();
endclass


//------------------------------------------------------------------------------------------------------
// Constructor: new
// Initializes the config_template class object
//
// Parameters:
//  name - instance name of the config_template
//  parent - parent under which this component is created
//-------------------------------------------------------------------------------------------------------
function vbase_seq::new(string name="vbase_seq");
	super.new(name);
endfunction


//---------------------------------------------------------------------------------------------
//task:vbase_seq body()
//we are casting the m-sequencer in the test to the virtual sequencer handle in environment
//---------------------------------------------------------------------------------------------
task vbase_seq::body();
	
	m_seq=master_seqs::type_id::create("m_seq");
	//s_seq=slave_seq::type_id::create("s_seq"); 

 	m_seq.start(p_sequencer.master_seqrh);

endtask: body

