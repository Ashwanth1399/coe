`define MEM testbench.uut.soc.memory //define with hier path to memory

class memory_backdoor extends uvm_pkg::uvm_object;
 `uvm_object_utils (memory_backdoor)
  int mem_data;
  extern function new (string name = "memory_backdoor");
  extern function void write_to_mem(reg[31:0] addr, reg[31:0] data);
  extern function int read_from_mem(reg[31:0] addr);
endclass

function memory_backdoor::new(string name = "memory_backdoor");
  super.new();
endfunction

function void memory_backdoor::write_to_mem(reg[31:0] addr, reg[31:0] data);
  `MEM.mem[addr] = data; //writing data to specific addr of mem
  `uvm_info("MEM_DATA", $sformatf("data %0d is writen in addr %0d", data,addr), UVM_LOW);
endfunction

function int memory_backdoor::read_from_mem(reg[31:0] addr);
  mem_data = `MEM.mem[addr]; //read from specific addr
  `uvm_info("MEM_DATA", $sformatf("data in mem[%0d]: %0d",addr, mem_data), UVM_LOW);
   return mem_data;
endfunction
