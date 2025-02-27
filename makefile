# -----------------------------------------------------------------------------
# User-selectable Simulator: set SIMULATOR to one of: iverilog, verilator, ghdl, cocotb
SIMULATOR ?= iverilog

# -----------------------------------------------------------------------------
# Open-source Tools
IVERILOG   = iverilog
VVP        = vvp
VERILATOR  = verilator
GHDL       = ghdl
GTKWAVE    = gtkwave
YOSYS      = yosys
PYTHON     = python3

# -----------------------------------------------------------------------------
# Xilinx Vivado Tools (assumed to be in your PATH)
VIVADO     = vivado
XSIM       = xsim

# -----------------------------------------------------------------------------
# Directory Structure
SRC_DIR      = src
TB_DIR       = tb
SIM_DIR      = sim         # Stores simulation outputs (e.g., VCD files)
BUILD_DIR    = build       # Stores compiled outputs
REPORTS_DIR  = reports
COCOTB_DIR   = cocotb      # Optional: for Python-based testbenches

# Vivado TCL scripts directory (you should create these scripts)
TCL_DIR      = tcl
VIVADO_SYNTH_SCRIPT = $(TCL_DIR)/vivado_synth.tcl
VIVADO_IMPL_SCRIPT  = $(TCL_DIR)/vivado_impl.tcl
VIVADO_SIM_SCRIPT   = $(TCL_DIR)/vivado_sim.tcl
VIVADO_PROG_SCRIPT  = $(TCL_DIR)/vivado_prog.tcl

# -----------------------------------------------------------------------------
# Files and Modules
TOP_MODULE   = top_tb      # Top-level module for simulation (testbench)
DESIGN_TOP   = design_top  # Top-level design module for synthesis (update as needed)
SRC_FILES    = $(wildcard $(SRC_DIR)/*.v)
TB_FILES     = $(wildcard $(TB_DIR)/*.v)
SYNTH_SRC    = $(SRC_FILES)  # For synthesis, only use design sources (modify if necessary)
COMPILE_OUTPUT = $(BUILD_DIR)/compiled.out
VCD_FILE     = $(SIM_DIR)/waves.vcd

# -----------------------------------------------------------------------------
# Default target: compile, run, and view simulation waveform
all: compile run view

# ------------------------------------------------------------------
# Compile target: choose the appropriate compilation command based on SIMULATOR
compile:
	@mkdir -p $(BUILD_DIR)
	@if [ "$(SIMULATOR)" = "iverilog" ]; then \
		echo "Compiling with Icarus Verilog..."; \
		$(IVERILOG) -o $(COMPILE_OUTPUT) $(SRC_FILES) $(TB_FILES); \
	elif [ "$(SIMULATOR)" = "verilator" ]; then \
		echo "Compiling with Verilator..."; \
		$(VERILATOR) --cc --exe --build $(TB_FILES) $(SRC_FILES); \
	elif [ "$(SIMULATOR)" = "ghdl" ]; then \
		echo "Compiling with GHDL..."; \
		$(GHDL) -a $(SRC_FILES) $(TB_FILES); \
	elif [ "$(SIMULATOR)" = "cocotb" ]; then \
		echo "Preparing Cocotb simulation..."; \
		cd $(COCOTB_DIR) && $(PYTHON) run_cocotb.py; \
	else \
		echo "Unknown simulator: $(SIMULATOR)"; \
		exit 1; \
	fi
	@echo "Compilation complete!"

# ------------------------------------------------------------------
# Run target: executes the simulation based on SIMULATOR
run: compile
	@if [ "$(SIMULATOR)" = "iverilog" ]; then \
		echo "Running simulation with vvp..."; \
		$(VVP) $(COMPILE_OUTPUT); \
	elif [ "$(SIMULATOR)" = "verilator" ]; then \
		echo "Running simulation with Verilator..."; \
		./obj_dir/Vtop_tb; \
	elif [ "$(SIMULATOR)" = "ghdl" ]; then \
		echo "Running simulation with GHDL..."; \
		$(GHDL) -r $(TOP_MODULE) --wave=$(VCD_FILE); \
	elif [ "$(SIMULATOR)" = "cocotb" ]; then \
		echo "Cocotb simulation executed during compile step."; \
	else \
		echo "Unknown simulator: $(SIMULATOR)"; \
		exit 1; \
	fi
	@echo "Simulation complete!"

# ------------------------------------------------------------------
# View target: opens the simulation waveform with GTKWave
view:
	@echo "Opening waveform..."
	$(GTKWAVE) $(VCD_FILE) &

# ------------------------------------------------------------------
# Test target: basic automation to verify simulation outputs
test: run
	@echo "Running automated tests..."
	@if [ -f $(VCD_FILE) ]; then \
		echo "Test passed: Waveform generated."; \
	else \
		echo "Test failed: Waveform not generated."; \
		exit 1; \
	fi

# ------------------------------------------------------------------
# Synthesis target: runs Yosys to synthesize the design from SRC_DIR
synth:
	@mkdir -p $(BUILD_DIR)
	@echo "Synthesizing design with Yosys..."
	$(YOSYS) -p "synth -top $(DESIGN_TOP); write_verilog $(BUILD_DIR)/synthesized.v" $(SYNTH_SRC)
	@echo "Synthesis complete! Output: $(BUILD_DIR)/synthesized.v"

# ------------------------------------------------------------------
# Vivado Targets: Synthesis, Implementation, Simulation, Bitstream & Programming
vivado_synth:
	@echo "Starting Vivado synthesis..."
	$(VIVADO) -mode batch -source $(VIVADO_SYNTH_SCRIPT)
	@echo "Vivado synthesis complete!"

vivado_impl:
	@echo "Starting Vivado implementation (Place & Route)..."
	$(VIVADO) -mode batch -source $(VIVADO_IMPL_SCRIPT)
	@echo "Vivado implementation complete!"

vivado_bit:
	@echo "Generating bitstream with Vivado..."
	# This target assumes your implementation TCL script handles bitstream generation,
	# or you may pass an argument to specify this step.
	$(VIVADO) -mode batch -source $(VIVADO_IMPL_SCRIPT) -tclargs bit
	@echo "Bitstream generation complete!"

vivado_sim:
	@echo "Running simulation with Vivado XSim..."
	$(VIVADO) -mode batch -source $(VIVADO_SIM_SCRIPT)
	@echo "Vivado simulation complete!"

vivado_program:
	@echo "Programming FPGA with Vivado..."
	$(VIVADO) -mode batch -source $(VIVADO_PROG_SCRIPT)
	@echo "FPGA programming complete!"

# ------------------------------------------------------------------
# Lint target: run linting using Verilator's lint-only mode
lint:
	@echo "Running lint with Verilator..."
	$(VERILATOR) --lint-only $(SRC_FILES) $(TB_FILES)
	@echo "Lint complete!"

# ------------------------------------------------------------------
# Format target: auto-format Verilog sources using verible-verilog-format (if installed)
format:
	@echo "Formatting Verilog files with verible-verilog-format..."
	@for file in $(SRC_FILES) $(TB_FILES); do \
		echo "Formatting $$file"; \
		verible-verilog-format -i $$file; \
	done
	@echo "Formatting complete!"

# ------------------------------------------------------------------
# Environment Info: print current configuration variables
env:
	@echo "Current environment settings:"
	@echo "  SIMULATOR      = $(SIMULATOR)"
	@echo "  SRC_DIR        = $(SRC_DIR)"
	@echo "  TB_DIR         = $(TB_DIR)"
	@echo "  BUILD_DIR      = $(BUILD_DIR)"
	@echo "  SIM_DIR        = $(SIM_DIR)"
	@echo "  TOP_MODULE     = $(TOP_MODULE)"
	@echo "  DESIGN_TOP     = $(DESIGN_TOP)"
	@echo "  VIVADO Script Directory = $(TCL_DIR)"

# ------------------------------------------------------------------
# Help target: list all available targets
help:
	@echo "Available targets:"
	@echo "  all             - Compile, run simulation, and view waveform"
	@echo "  compile         - Compile design and testbench"
	@echo "  run             - Run simulation"
	@echo "  view            - Open waveform in GTKWave"
	@echo "  test            - Run automated tests"
	@echo "  synth           - Synthesize design using Yosys (open source)"
	@echo "  vivado_synth    - Synthesize design using Xilinx Vivado"
	@echo "  vivado_impl     - Run implementation (Place & Route) using Vivado"
	@echo "  vivado_bit      - Generate bitstream using Vivado"
	@echo "  vivado_sim      - Run simulation using Vivado's XSim"
	@echo "  vivado_program  - Program FPGA using Vivado"
	@echo "  lint            - Run linting with Verilator"
	@echo "  format          - Format Verilog source files using verible-verilog-format"
	@echo "  env             - Print current environment settings"
	@echo "  clean           - Clean build and simulation files"
	@echo "  clean_vivado    - Clean Vivado-generated files and logs"

# ------------------------------------------------------------------
# Clean target: removes generated files and directories (open source)
clean:
	@echo "Cleaning build and simulation files..."
	rm -rf $(BUILD_DIR) $(SIM_DIR)/*.vcd $(COMPILE_OUTPUT) $(REPORTS_DIR)/*.log obj_dir
	clear
	@echo "Cleanup done!"

# ------------------------------------------------------------------
# Clean Vivado target: removes Vivado-generated project files and logs
clean_vivado:
	@echo "Cleaning Vivado generated files..."
	rm -rf vivado_project *.log *.jou *.str *.backup
	clear	
	@echo "Vivado cleanup done!"

# -----------------------------------------------------------------------------
# Phony targets to prevent conflicts with files of the same name
.PHONY: all compile run view test synth vivado_synth vivado_impl vivado_bit vivado_sim vivado_program lint format env help clean clean_vivado
