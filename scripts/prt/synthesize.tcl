open_project PRT_Project
read_verilog PRT.sv
read_verilog dual_port_bram.sv
synth_design -top PRT -part xc7a200tfbg676-2
write_checkpoint -force reports/synthesis.dcp
report_timing_summary -file reports/timing_synth.rpt
report_utilization -file reports/utilization_synth.rpt
exit
