# Create a new project
create_project my_project ../output -part xc7a200tfbg484-2
set_property target_language Verilog [current_project]

# Add source files
add_files ../src/fifo/fifo_base.sv

# Add constraints file
add_files -fileset constrs_1 ../constraints/constr.xdc

# Add testbench
add_files -fileset sim_1 ../tb/fifo/fifo_base_TB.sv
set_property top fifo_base_TB [get_filesets sim_1]

# Set synthesis and implementation strategies (Performance Optimized)
set_property strategy Performance_Explore [get_runs synth_1]
set_property strategy Performance_Explore [get_runs impl_1]

# Run Synthesis
launch_runs synth_1
wait_on_run synth_1

# Run Implementation
launch_runs impl_1
wait_on_run impl_1

# Generate Bitstream
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1

# Run Simulation
launch_simulation

# Generate reports
open_run impl_1
report_utilization -file ../output/reports/utilization_report.txt
report_timing_summary -file ../output/reports/timing_report.txt
report_power -file ../output/reports/power_report.txt
report_drc -file ../output/reports/drc_report.txt
report_clock_utilization -file ../output/reports/clock_utilization_report.txt

# Save and close the project
close_project
