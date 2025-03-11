################################################################################
# Vivado Flow Script: RTL Analysis, Synthesis, & Implementation with Lint Checks
#
# This script performs:
#   1. Project creation and RTL source/constraint file import.
#   2. RTL analysis and lint checks (CDC and DRC reports) before synthesis.
#   3. Synthesis using the default strategy with timing, utilization, and power reports.
#   4. Implementation (placement & routing) with further timing and power reports.
#   5. Storage of all reports in the "reports" folder.
#
# Adjust the below variables to match your project environment.
################################################################################

#--- User-Defined Variables ---
set project_name       "pkt_ref_table"    ;# <-- Update this to your project name.
set top_module         "PRT_v2"           ;# <-- Update this to your design's top module name.
set part               "xc7a200tfbg676-2" ;# <-- Update this with your target FPGA part.
set src_dir            "./src/prt"        ;# <-- Folder containing your RTL source files.
set constraints_dir    "./constraints"    ;# <-- Folder containing your XDC files.
set reports_dir        "./reports"        ;# <-- Folder where reports will be stored.

#--- Create Reports Directory if Needed ---
if {![file isdirectory $reports_dir]} {
    file mkdir $reports_dir
}

#--- Create the Project ---
puts "Creating project: $project_name"
create_project $project_name $PWD -part $part

# Set the target language to Verilog (change if using VHDL/BSV)
set_property target_language Verilog [current_project]

#--- Add RTL Source Files ---
puts "Adding RTL source files from: $src_dir"
add_files -norecurse [glob -absolute $src_dir/*.v]
update_compile_order -fileset sources_1

#--- Add Constraint Files ---
puts "Adding constraint files from: $constraints_dir"
add_files -norecurse [glob -absolute $constraints_dir/*.xdc]
update_compile_order -fileset constrs_1

#--- RTL Analysis & Initial Lint Checks ---
puts "Running RTL Analysis and performing initial lint checks..."
# Report Clock Domain Crossing (CDC) issues (if any)
report_cdc -file $reports_dir/cdc_report_before_synth.txt
# Report Design Rule Check (DRC) results
report_drc -file $reports_dir/drc_report_before_synth.txt

#--- Synthesis Stage ---
puts "Starting synthesis..."
synth_design -top $top_module -part $part

# Wait for synthesis run to complete
if {[catch {wait_on_run synth_1} result]} {
    puts "Synthesis failed: $result"
    exit 1
}
puts "Synthesis completed successfully."

#--- Generate Synthesis Reports ---
puts "Generating synthesis reports..."
# Timing report from synthesis
report_timing_summary -file $reports_dir/timing_summary_synth.txt
# Utilization report from synthesis
report_utilization -file $reports_dir/utilization_synth.txt
# Power report from synthesis
report_power -file $reports_dir/power_synth.txt

#--- Implementation Stage ---
puts "Starting implementation (placement and routing)..."
launch_runs impl_1 -to_step route_design
if {[catch {wait_on_run impl_1} impl_result]} {
    puts "Implementation failed: $impl_result"
    exit 1
}
puts "Implementation completed successfully."

# Open the implementation run for reporting
open_run impl_1

#--- Generate Implementation Reports ---
puts "Generating implementation reports..."
# Timing summary after implementation
report_timing_summary -file $reports_dir/timing_summary_impl.txt
# Utilization report after implementation
report_utilization -file $reports_dir/utilization_impl.txt
# Power analysis report after implementation
report_power -file $reports_dir/power_impl.txt

#--- Additional Lint Checks (Post-Synthesis) ---
puts "Running additional lint checks post-synthesis..."
report_cdc -file $reports_dir/cdc_report_after_synth.txt
report_drc -file $reports_dir/drc_report_after_synth.txt

puts "Vivado flow completed successfully. All reports are stored in the directory: $reports_dir"

exit
