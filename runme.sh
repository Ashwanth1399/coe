#set path = ( /opt/riscv/bin $path )
make hx8kdemo_fw.hex
sh script.sh cmd -design hx8kdemo.v -testbench hx8kdemo_tb.sv -sim_opt +select=12 -nocov -nowaves 
 
