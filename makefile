# Directories
BUILD_DIR = build
SIM_DIR = sim
REPORTS_DIR = reports
TCL_DIR = scripts
COCOTB_DIR = cocotb

# Tools
IVERILOG = iverilog
VVP = vvp
VERILATOR = verilator
GHDL = ghdl
VIVADO = vivado
GTKWAVE = gtkwave
PYTHON = python3

# Files
SRC_FILES = $(wildcard src/*.v src/*.sv)
TB_FILES = $(wildcard tb/*.v tb/*.sv)
TOP_MODULE = top_tb
VCD_FILE = $(SIM_DIR)/waves.vcd
COMPILE_OUTPUT = $(BUILD_DIR)/sim.out

# Simulator Selection (Defaults to iverilog)
SIMULATOR ?= iverilog

.PHONY: all compile run view clean clean_vivado lint test vivado vivado_bit

all: compile run

# Compilation Step
compile:
	@mkdir -p $(BUILD_DIR)
	@bash -c ' 
		if [ "$(SIMULATOR)" = "iverilog" ]; then \
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
			echo "Unknown simulator: $(SIMULATOR)"; exit 1; \
		fi'
	@echo "Compilation complete!"

# Run Simulation
run: compile
	@mkdir -p $(SIM_DIR)
	@bash -c ' 
		if [ "$(SIMULATOR)" = "iverilog" ]; then \
			echo "Running simulation with vvp..."; \
			$(VVP) $(COMPILE_OUTPUT) +dumpfile=$(VCD_FILE) +dumpvars; \
		elif [ "$(SIMULATOR)" = "verilator" ]; then \
			echo "Running simulation with Verilator..."; \
			./obj_dir/Vtop_tb; \
		elif [ "$(SIMULATOR)" = "ghdl" ]; then \
			echo "Running simulation with GHDL..."; \
			$(GHDL) -r $(TOP_MODULE) --wave=$(VCD_FILE); \
		elif [ "$(SIMULATOR)" = "cocotb" ]; then \
			echo "Cocotb simulation executed during compile step."; \
		else \
			echo "Unknown simulator: $(SIMULATOR)"; exit 1; \
		fi'
	@echo "Simulation complete!"

# Open waveform in GTKWave
view:
	@mkdir -p $(SIM_DIR)
	@if [ -f $(VCD_FILE) ]; then \
		echo "Opening waveform..."; \
		$(GTKWAVE) $(VCD_FILE) & \
	else \
		echo "VCD file not found! Run 'make run' first."; exit 1; \
	fi

# Clean Build and Simulation Files
clean:
	@echo "Cleaning build and simulation files..."
	rm -rf $(BUILD_DIR) $(SIM_DIR)/*.vcd $(COMPILE_OUTPUT) $(REPORTS_DIR)/*.log obj_dir
	rm -rf *.jou *.log
	@echo "Cleanup done!"

# Clean Vivado Project Files
clean_vivado:
	@echo "Cleaning Vivado project files..."
	rm -rf *.jou *.log vivado*.backup .Xil *.str *.xpr *.xsa *.bit
	@echo "Vivado cleanup done!"

# Run Verilog Linter
lint:
	@echo "Running lint with Verilator..."
	$(VERILATOR) --lint-only $(SRC_FILES) $(TB_FILES) || exit 1
	@echo "Lint complete!"

# Run Tests
test: run
	@echo "Running automated tests..."
	@if [ -f $(VCD_FILE) ]; then \
		echo "Test passed: Waveform generated."; \
	else \
		echo "Test failed: Waveform not generated."; exit 1; \
	fi
	@if grep -q "FAIL" $(BUILD_DIR)/simulation.log; then \
		echo "Test failed: Errors detected in simulation log."; exit 1; \
	fi
	@echo "All tests passed!"

# Run Vivado Implementation
vivado:
	@echo "Running Vivado implementation..."
	$(VIVADO) -mode batch -source $(TCL_DIR)/vivado_impl.tcl
	@echo "Vivado implementation complete!"

# Generate Bitstream with Vivado
vivado_bit:
	@echo "Generating bitstream with Vivado..."
	$(VIVADO) -mode batch -source $(TCL_DIR)/vivado_bitgen.tcl
	@echo "Bitstream generation complete!"