# Report timing summary

report_timing_summary -delay_type min_max -file timing_summary.rpt
report_timing_summary -file reports/timing_summary.rpt

# fOR DETAILE DDELAY ON SPECIFIC paths
report_timing -delay_type min_max -path_type full_clock_expanded

# Report clock latency in TCL
report_clock_networks

# clock tree latency
report_clocks

# report logical latency
report_timing -max_paths 10 -delay_type max
