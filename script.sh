#!/bin/bash
# Default file names
default_design_file=""
default_testbench_file="testbench.sv"
default_interface_file="fifo_if.sv"
mode=""
design_file=""
testbench_file=""
skip_coverage=0
skip_waves=0
sim_opts=""
tool="questa"  # Default tool is Questa
clean=1
cleanall=0
hdl_language="verilog"  # Default HDL language is Verilog
top_module="" # Variable to store the top module name

# Function to display script usage
display_help() {
    echo "Usage: $0 [-design <design_file>] [-testbench <testbench_file>] [-nocov] [-nowaves] [-tool <tool>] [-clean] [-cleanall] [-language <verilog|vhdl>] [-top <top_module_name>] <mode>"
    echo "Options:"
    echo "  -design <design_file>: Specify the design file name (default: design.sv)"
    echo "  -testbench <testbench_file>: Specify the testbench file name (default:testbench.sv)"
    echo "  -interface <interface_file>: Specify the Interface file name (default:fifo_if.sv)"
    echo "  -nocov: Skip coverage generation"
    echo "  -nowaves: Skip waveform viewing"
    echo "  -tool <tool>: Specify the simulation tool vcs,xcelium,icarus,AldecHDL for Verilog simulations (default: questa)"
    echo "  -clean: Clean simulation files and directories but not the transcript"
    echo "  -cleanall: Clean the transcript"
    echo "  -language <verilog|vhdl>: Specify the hardware description language (default: verilog)"
    echo "  <mode>: Simulation mode ('gui' or 'cmd')"
    echo "  -top top_module_name: Use the top_module_name"       
    exit 0
}

if [ "$1" == "-help" ]; then
    display_help
fi

if [ "$#" -eq 0 ]; then
    display_help
fi

while [ "$#" -gt 0 ]; do
    case "$1" in
        -design)
            design_file="$2"
            shift 2
            ;;
        -testbench)
            testbench_file="$2"
            shift 2
            ;;
         -interface)
            interface_file="$3"
            shift 2
            ;;
        -sim_opt)
            sim_opts="$2"
            shift 2
	    ;;
	-nocov)
            skip_coverage=1
            shift
            ;;
        -nowaves)
            skip_waves=1
            shift
            ;;
        -tool)
            tool="$2"
            shift 2
            ;;
        -clean)
            clean=1
            shift
            ;;
        -cleanall)
            cleanall=1
            shift
            ;;
        -language)
            hdl_language="$2"
            shift 2
            ;;
         -top)
          top_module="$2"
          shift 2
          ;;           
        *)
            mode="$1"
            shift
            ;;
    esac
done

# Check if cleanup all flag is set
if [ "$cleanall" -eq 1 ] ;then
     echo 'cleaning the scripts removing transcript'
    # Cleanup all operations
    rm transcript
fi

# Check if cleanup flag is set
if [ "$clean" -eq 1 ]; then
     echo 'cleaning the scripts cleaning all files'
     rm -rf *.mti *.mpf transcript *.wlf *.log *.key *.history *.shm *.ucdb *.trn *.dsn *.tops vc_hdrs.h verdi_config_file
     rm -rf work
     rm -rf INCA_libs
     rm -rf DVEfiles csrc 
     rm -rf ucli.key inter.vpd
     rm -rf simv simv.vdb simv.daidir
     rm -rf covhtmlreport
fi

# If mode is not specified, prompt the user
if [ -z "$mode" ]; then
    read -p "Enter mode ('gui' or 'cmd'): " mode
fi

# If design file is not specified, use the default
if [ -z "$design_file" ]; then
    read -p "Enter the design file name (default: $default_design_file): " design_file
    design_file="${design_file:-$default_design_file}"
fi

# If testbench file is not specified, use the default
if [ -z "$testbench_file" ]; then
     read -p "Enter the testbench file name (default: $default_testbench_file): " testbench_file
     testbench_file="${testbench_file:-$default_testbench_file}"
fi

if [ "$tool" == "questa" ]; then
    if [[ "$mode" == 'gui' ]]; then
        echo 'Running in GUI mode'
        # GUI Command for Questa
        vsim
    elif [[ "$mode" == 'cmd' ]]; then
        echo 'Running in Command line mode for Questa'

        if [ "$hdl_language" == "verilog" ]; then
            # Compile and simulate with Questa for Verilog
            if vlog +define+DEBUG_ENABLE=0 -writetoplevels questa.tops -coveropt 5 +cover "$design_file" "$testbench_file" ; then
                # Run and generate dump and coverage if not skipped
                vsim -f questa.tops -coverage -c  -wlf wave.wlf "$sim_opts" +firmware=hx8kdemo_fw.hex -do "coverage clear; coverage save -onexit coverage.ucdb ; add wave -r /*; run -all ; exit"
                
                # Generate HTML if not skipped
                if [ "$skip_coverage" -eq 0 ] ; then
                    vcover report -details -html coverage.ucdb &
                    firefox covhtmlreport/index.html &
                fi

                # View the waveform if not skipped
                if [ "$skip_waves" -eq 0 ]; then
                    vsim -view wave.wlf
                fi
            else
                echo 'Compilation failed. Coverage and waves will not be generated.'
                display_help
            fi
        elif [ "$hdl_language" == "vhdl" ]; then
            # Compile and simulate with Questa for VHDL
            if vcom -coveropt 3 +cover +acc -2008 "$design_file" "$testbench_file"; then
                # Run and generate dump and coverage if not skipped
                if [ "$skip_coverage" -eq 0 ] || [ "$skip_waves" -eq 0 ]; then
                vsim -coverage -c -wlf "wave.wlf" -do "coverage clear; coverage save -onexit coverage.ucdb ; add wave -r /*; run -all ; exit" "$top_module"
                fi
                # Generate HTML if not skipped
                if [ "$skip_coverage" -eq 0 ] ; then
                    vcover report -details -html coverage.ucdb &
                    firefox covhtmlreport/index.html &
                fi
                # View the waveform if not skipped
                if [ "$skip_waves" -eq 0 ]; then
                    vsim -view wave.wlf
                fi
            else
                echo 'Compilation failed. Coverage and waves will not be generated.'
                display_help
            fi
        else
            echo 'Unsupported HDL language for Questa.'
            display_help
        fi
    else
        echo 'Please pass valid arguments for Questa.'
        display_help
    fi
elif [ "$tool" == "vcs" ]; then
    if [[ "$mode" == 'cmd' ]]; then
        echo 'Running in Command line mode for VCS'
        # VCS Compile Command
        if vcs -full64 +v2k -debug_acc+all -kdb -sverilog -cm line+cond+fsm+tgl -ntb_opts uvm "$design_file" "$testbench_file"; then
            # Run and generate dump and coverage
            if [ "$skip_coverage" -eq 0 ] || [ "$skip_waves" -eq 0 ]; then
                # Run and generate dump and coverage
                ./simv -cm line+cond+fsm+tgl

                if [ "$skip_coverage" -eq 0 ]; then
                    dve -cov -covdir simv.vdb &
                fi

                # View the waveform if not skipped
                if [ "$skip_waves" -eq 0 ]; then
                    ./simv -gui &
                fi
            fi
        else
            echo 'Compilation failed. No simulation will be executed.'
            display_help
        fi
    else
        echo 'Please pass valid arguments for VCS.'
        display_help
    fi
elif [ "$tool" == "xcelium" ]; then
    if [[ "$mode" == 'gui' ]]; then
        echo 'Running in GUI mode'
        # GUI Command for Xcelium
        irun -access +rw -coverage all -gui -covoverwrite "$design_file" "$testbench_file"
    elif [[ "$mode" == 'cmd' ]]; then
        echo 'Running in Command line mode for Xcelium'
        # Compile and simulate with Xcelium
        irun -coverage all -covoverwrite "$design_file" "$testbench_file"
        # Generate HTML if not skipped
        if [ "$skip_coverage" -eq 0 ]; then
          imc -load cov_work/scope/test
                fi
        # View the waveform if not skipped
        if [ "$skip_waves" -eq 0 ]; then
            simvision dump.vcd
        fi
    else
        echo 'Please pass valid arguments for Xcelium.'
        display_help
    fi
elif [ "$tool" == "verilator" ]; then
    echo 'Running Verilator'
     	verilator --cc --coverage "$design_file"
   	verilator -Wall --cc "$design_file" --exe "$testbench_file" --trace --coverage
   	make -j -C obj_dir -f V"$top_module".mk V"$top_module"
   	./obj_dir/V"$top_module"
  	gtkwave waveform.vcd
        echo 'Please pass valid arguments for verilator'
        display_help
 
elif [ "$tool" == "icarus" ]; then
    echo 'Running Icarus'
    iverilog -o a.out "$design_file" "$testbench_file"
    vvp a.out
    gtkwave dump.vcd

else
    echo 'Invalid tool option. Supported tools: Aldec HDL, questa, vcs, xcelium, verilator, iverilog'
    display_help
fi
