# Default Simulator (set SIMULATOR variable to change tool)
# Options: iverilog, verilator, ghdl, cocotb
SIMULATOR ?= iverilog

# Tools
IVERILOG   = iverilog
VVP        = vvp
VERILATOR  = verilator
GHDL       = ghdl
GTKWAVE    = gtkwave
YOSYS      = yosys
PYTHON     = python3

# Directories (matching your project layout)
SRC_DIR      = src
TB_DIR       = tb
SIM_DIR      = sim         # Stores simulation outputs (e.g., VCD files)
BUILD_DIR    = build       # Stores compiled outputs
REPORTS_DIR  = reports
COCOTB_DIR   = cocotb      # Optional: for Python-based testbenches

# Files and Modules
TOP_MODULE   = top_tb      # Top-level module for simulation (testbench)
DESIGN_TOP   = design_top  # Top-level design module for synthesis (update as needed)
SRC_FILES    = $(wildcard $(SRC_DIR)/*.v)
TB_FILES     = $(wildcard $(TB_DIR)/*.v)
SYNTH_SRC    = $(SRC_FILES)  # For synthesis, only use design sources (modify if necessary)
COMPILE_OUTPUT = $(BUILD_DIR)/compiled.out
VCD_FILE     = $(SIM_DIR)/waves.vcd

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
# Clean target: removes generated files and directories
clean:
	@echo "Cleaning build and simulation files..."
	rm -rf $(BUILD_DIR) $(SIM_DIR)/*.vcd $(COMPILE_OUTPUT) $(REPORTS_DIR)/*.log obj_dir
	@echo "Cleanup done!"

# Phony targets to prevent conflicts with files of the same name
.PHONY: all compile run view test synth clean
