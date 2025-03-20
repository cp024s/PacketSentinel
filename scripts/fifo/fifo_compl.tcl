# Set Paths
set root_dir "./"
set design_file "$root_dir/src/fifo/fifo_base.sv"
set testbench_file "$root_dir/tb/fifo/fifo_base_TB.sv"
set output_dir "$root_dir/output"
set reports_dir "$root_dir/reports"

# Create necessary directories if they don't exist
file mkdir $output_dir
file mkdir $reports_dir

# Open a new project
create_project fifo_project $output_dir -part xc7a200tfbg484-2 -force

# Set the top-level design and add files
add_files $design_file
add_files -fileset sim_1 $testbench_file
set_property top fifo_base_TB [get_filesets sim_1]

# Linting (Syntax Check)
puts "Running Linter..."
read_verilog $design_file
check_syntax

# Simulation
puts "Running Simulation..."
launch_simulation
run all
close_sim

# Move Simulation Reports
file rename -force fifo_project.sim $reports_dir/simulation_reports

# Synthesis
puts "Running Synthesis..."
synth_design -top fifo_base -part xc7a200tfbg484-2
write_checkpoint -force $reports_dir/post_synth.dcp
report_timing_summary -file $reports_dir/timing_synth.rpt
report_utilization -file $reports_dir/utilization_synth.rpt

# Implementation
puts "Running Implementation..."
opt_design
place_design
route_design
write_checkpoint -force $reports_dir/post_impl.dcp
report_timing_summary -file $reports_dir/timing_impl.rpt
report_power -file $reports_dir/power_impl.rpt
report_utilization -file $reports_dir/utilization_impl.rpt

# Generate Bitstream
puts "Generating Bitstream..."
write_bitstream -force $output_dir/fifo_base.bit

# Remove unwanted files (.jou and .log)
puts "Cleaning up log and journal files..."
file delete -force vivado.jou
file delete -force vivado.log
