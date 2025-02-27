## <p align = center> MAKEFILE REFERENCE DOCUMENT <p>

### Overview

The Makefile integrates multiple open-source tools (like Icarus Verilog, Verilator, GHDL, Cocotb, Yosys, and GTKWave) alongside Xilinx Vivado tools. It’s organized into sections that help you compile, simulate, synthesize, lint, format, and clean your project files. It also includes utility targets to print the environment configuration and list available commands.

---

### Open-Source Simulation & Synthesis Flow

- **`all`**  
  *Purpose:* Runs the entire simulation flow by invoking the compile, run, and view steps sequentially.  
  *How it works:*  
  1. **Compile:** Depending on the `SIMULATOR` variable (default is `iverilog`), it compiles the design and testbench files.  
  2. **Run:** Executes the simulation with the appropriate tool (e.g., running `vvp` for Icarus Verilog).  
  3. **View:** Opens the resulting waveform file (VCD) in GTKWave.

- **`compile`**  
  *Purpose:* Compiles the Verilog source files (in `src/`) and testbench files (in `tb/`) using the selected simulator.  
  *How it works:*  
  - Checks the value of `SIMULATOR` and uses the corresponding command:  
    - **Icarus Verilog:** Compiles with `iverilog`.  
    - **Verilator:** Compiles with Verilator’s build system.  
    - **GHDL:** Analyzes the files using GHDL.  
    - **Cocotb:** Invokes a Python script to set up a Cocotb simulation.

- **`run`**  
  *Purpose:* Executes the simulation after compilation.  
  *How it works:*  
  - For each simulator, it runs the corresponding simulation command (for example, executing the compiled output with `vvp` for Icarus Verilog or generating a VCD file with GHDL).

- **`view`**  
  *Purpose:* Opens the generated VCD waveform file in GTKWave.  
  *How it works:*  
  - It simply calls GTKWave with the VCD file as an argument, allowing you to visually inspect the simulation results.

- **`test`**  
  *Purpose:* Performs a basic check to ensure that the simulation produced output (e.g., a VCD file).  
  *How it works:*  
  - It looks for the presence of the VCD file. If found, the test passes; otherwise, it flags an error.

- **`synth`**  
  *Purpose:* Uses Yosys to synthesize your Verilog design.  
  *How it works:*  
  - Yosys reads the source files, synthesizes the design with the top module defined by `DESIGN_TOP`, and writes the output to a synthesized Verilog file in the build directory.

---

### Xilinx Vivado Flow

For projects targeting Xilinx FPGAs, the Makefile provides several Vivado-specific targets that assume you have accompanying TCL scripts (located in a designated `tcl/` folder).

- **`vivado_synth`**  
  *Purpose:* Runs synthesis using Vivado.  
  *How it works:*  
  - Calls Vivado in batch mode with a synthesis TCL script (e.g., `vivado_synth.tcl`), automating the synthesis process.

- **`vivado_impl`**  
  *Purpose:* Runs the implementation (Place & Route) phase using Vivado.  
  *How it works:*  
  - Invokes a TCL script (e.g., `vivado_impl.tcl`) in batch mode to carry out placement and routing.

- **`vivado_bit`**  
  *Purpose:* Generates the FPGA bitstream.  
  *How it works:*  
  - Either the implementation script or a dedicated bitstream generation step is called via Vivado in batch mode (using a TCL script, sometimes with additional arguments).

- **`vivado_sim`**  
  *Purpose:* Runs simulation using Vivado’s XSim.  
  *How it works:*  
  - A Vivado simulation TCL script (e.g., `vivado_sim.tcl`) is executed in batch mode, automating the simulation using XSim.

- **`vivado_program`**  
  *Purpose:* Programs the FPGA with the generated bitstream.  
  *How it works:*  
  - Calls Vivado in batch mode with a programming TCL script (e.g., `vivado_prog.tcl`) to download the bitstream onto your FPGA board.

---

### Code Quality and Utility Targets

- **`lint`**  
  *Purpose:* Checks the quality of your Verilog code using Verilator’s lint-only mode.  
  *How it works:*  
  - It scans the source and testbench files for potential issues, helping to catch coding errors early.

- **`format`**  
  *Purpose:* Automatically formats your Verilog files for better readability.  
  *How it works:*  
  - Uses `verible-verilog-format` (if installed) to reformat all Verilog source and testbench files in place.

- **`env`**  
  *Purpose:* Prints out the current configuration of key environment variables used in the Makefile.  
  *How it works:*  
  - Displays variables like `SIMULATOR`, directory paths, and the names of top modules, providing a quick overview of your project setup.

- **`help`**  
  *Purpose:* Lists all available Makefile targets and provides a brief description of each.  
  *How it works:*  
  - It echoes a simple help message to the terminal, guiding you on how to use the various commands.

---

### Cleanup Targets

- **`clean`**  
  *Purpose:* Removes all generated files from the open-source simulation flow.  
  *How it works:*  
  - Deletes build directories, simulation outputs (like VCD files), logs, and other intermediate files to reset the project state.

- **`clean_vivado`**  
  *Purpose:* Specifically cleans up files generated by Vivado (such as project files, logs, and backup files).  
  *How it works:*  
  - It removes Vivado project directories and associated temporary files, ensuring a clean workspace for a new Vivado run.

---

### Summary

This enhanced Makefile is a comprehensive project tool designed to:

- **Streamline the simulation flow** using various open-source tools.
- **Integrate synthesis and implementation steps** for both open-source flows (via Yosys) and Xilinx FPGA flows (via Vivado and TCL scripts).
- **Automate quality checks and code formatting** with linting and formatting targets.
- **Provide useful utility functions** to display environment settings and available commands.
- **Offer cleanup routines** to maintain a tidy workspace after builds and simulations.

By integrating these commands, the Makefile becomes a one-stop solution for managing the entire hardware design process—from writing and testing your Verilog code to synthesizing and programming your FPGA.