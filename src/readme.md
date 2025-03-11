
# <p align = center> Source files Log </p>

---
## 1. AXI Stream

---
## 2. Bloom Filter

---
## 3. Master packet dealer



---
## 4. Packet Reference Table

### `prt_base` - base version of packet reference table.
- PRT with all the FSM states was written and the `base version` is been tested with `prt_tb_1.sv` and `prt_tb_2.sv` **(refer testbench log for testbench related queries)**




### `prt_v2` - Version 2 with Improvements of packet reference table.
<span style="color:red; font-weight:bold;">🚨 coverage and stuffs are YTBD</span>
<span style="color:red; font-weight:bold;">🚨 Error: IMPLEMENTATION IS FAILING</span>

- ##### Design & Code development
<img alt="Code ready" src="https://img.shields.io/badge/Code-READY-green"> 
<img alt="Syntax check" src="https://img.shields.io/badge/Syntax Check-PASS-green">  
<img alt="Linting" src="https://img.shields.io/badge/Linting-PASS-green">
<img alt="Lint Violations" src="https://img.shields.io/badge/Violations-0-GREEN"> 

- ##### Simulation & Verification :
<img alt="Simulation" src="https://img.shields.io/badge/Simulation-PASS-green"> 
<img alt="Testbench coverage" src="https://img.shields.io/badge/Testbench coverage-PASS-green"> <should be in %>
<img alt="Waveform Analysis" src="https://img.shields.io/badge/Waveform Analysis-DONE-orange">
<img alt="Coverage" src="https://img.shields.io/badge/Coverage-0-GREEN"> <should be checked>


- ##### Synthesis :
<img alt="Synthesis completed" src="https://img.shields.io/badge/Synthesis-COMPLETE-green">  


```verilog
    - Utilization:
        LUT : 79975
        FF  : 121937
```

- ##### Implementation :
<img alt="Implementation" src="https://img.shields.io/badge/Implementation-FAIL-red"> 
<placement - done, Routing - Done, DRC - pass, Power analysis - done> 

```verilog
    - Utilization:
        LUT : 79975
        FF  : 121937
```

- ### Advancements done in this version.
    - **handshake** mechanism is introduced (by this way, unconditional running is avoided)
    - **Optimization of FSM :** FSM is neatly & efficietly optimised.

- ### YTBD improvements.
    - **BRAM** should be implemented for efficient memory access.
    - **Dual port** concept should be implemented for sequential data access <span style="color:red;">(note: in this version, it's a one person at a time communication)</span>

##### Testbench :
- **Testcases** :
    
