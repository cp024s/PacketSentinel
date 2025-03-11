# This makefile is used to run the testbench for the PRT module using CoCoTB

SIM = icarus
TOPLEVEL_LANG = verilog
VERILOG_SOURCES = $(PWD)/PRT.v
TOPLEVEL = PRT
MODULE = prt_tb
PYTHONPATH := $(PWD)

include $(shell cocotb-config --makefiles)/Makefile.sim
