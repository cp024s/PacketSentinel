# <p align = center> Makefile usage <p>

### What’s Included and How to Use It

1. **Multiple Simulation Tools**  
   - **Icarus Verilog:** Default mode (use `make` or `make SIMULATOR=iverilog`).
   - **Verilator:** Use with `make SIMULATOR=verilator`.
   - **GHDL:** For VHDL or mixed designs (use with `make SIMULATOR=ghdl`).
   - **Cocotb:** Python-based testbench (run with `make SIMULATOR=cocotb`).

2. **Directory Structure Awareness**  
   - **src/** contains your Verilog design files.
   - **tb/** holds your testbench files.
   - **sim/** is used for simulation outputs (like VCD files).
   - **build/** is where compiled outputs and synthesis results are stored.
   - **reports/** holds log/report files.
   - **cocotb/** is available for Cocotb-based testing.

3. **Testbench Automation**  
   - The **test** target runs the simulation (using your selected tool) and checks if the expected waveform file is generated.
   - Adjust or expand this section for more detailed unit testing if needed.

4. **Synthesis Support with Yosys**  
   - The **synth** target runs Yosys to synthesize your design.
   - It uses the design files from **src/** and outputs a synthesized Verilog file in **build/synthesized.v**.
   - Make sure to update `DESIGN_TOP` to match your design’s top module.

5. **Easy Switching and Cleanup**  
   - You can switch between simulation tools on the fly by setting the `SIMULATOR` variable.
   - The **clean** target removes generated build files, simulation outputs, and tool-specific directories.

---

### Example Usage

- **Compile, Run, and View (default with Icarus Verilog):**
  ```sh
  make
  ```
- **Using Verilator:**
  ```sh
  make SIMULATOR=verilator
  ```
- **Run automated tests:**
  ```sh
  make test
  ```
- **Synthesize your design:**
  ```sh
  make synth
  ```
- **Clean all generated files:**
  ```sh
  make clean
  ```