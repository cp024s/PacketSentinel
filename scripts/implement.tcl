open_project PRT_Project
opt_design
place_design
route_design
write_checkpoint -force reports/implementation.dcp
report_timing_summary -file reports/timing_impl.rpt
report_utilization -file reports/utilization_impl.rpt
exit
