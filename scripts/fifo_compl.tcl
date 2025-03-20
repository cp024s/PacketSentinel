# Create necessary directories if they don't exist
file mkdir output
file mkdir reports

# Open a new project
create_project fifo_project output -part xc7a200tfbg484-2 -force

# Set the top-level design and add files
add_files -norecurse src/fifo/fifo_base.sv
add_files -fileset sim_1 -norecurse tb/fifo/fifo_base_TB.sv
set_property top fifo_base_TB [get_filesets sim_1]

# Linting (Syntax Check)
puts "Running Linter..."
check_syntax -files [get_files src/fifo/fifo_base.sv]

# Simulation
puts "Running Simulation..."
launch_simulation
run all
close_sim

# Move Simulation Reports
file rename -force fifo_project.sim reports/simulation_reports

# Synthesis
puts "Running Synthesis..."
synth_design -top fifo_base -part xc7a200tfbg484-2
write_checkpoint -force reports/post_synth.dcp
report_timing_summary -file reports/timing_synth.rpt
report_utilization -file reports/utilization_synth.rpt

# Implementation
puts "Running Implementation..."
opt_design
place_design
route_design
write_checkpoint -force reports/post_impl.dcp
report_timing_summary -file reports/timing_impl.rpt
report_power -file reports/power_impl.rpt
report_utilization -file reports/utilization_impl.rpt

# Generate Bitstream
puts "Generating Bitstream..."
write_bitstream -force output/fifo_base.bit

# Remove unwanted files (.jou and .log)
puts "Cleaning up log and journal files..."
file delete -force vivado.jou
file delete -force vivado.log
