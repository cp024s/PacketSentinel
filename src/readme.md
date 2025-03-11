
# <p align = center> Source files </p>


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
<img alt="Code ready" src="https://img.shields.io/badge/Code-READY-green"> <img alt="Syntax check" src="https://img.shields.io/badge/Syntax Check-PASS-green">  <img alt="Linting" src="https://img.shields.io/badge/Linting-PASS-green"> <img alt="Lint Violations" src="https://img.shields.io/badge/Violations-0-GREEN"> 

- ##### Simulation & Verification :
<img alt="Simulation" src="https://img.shields.io/badge/Simulation-PASS-green">  <img alt="Waveform Analysis" src="https://img.shields.io/badge/Waveform Analysis-DONE-orange"> <img alt="Coverage" src="https://img.shields.io/badge/Coverage-0-GREEN"> <should be checked>


- ##### Synthesis :
<img alt="Synthesis completed" src="https://img.shields.io/badge/Synthesis-COMPLETE-green">  

######
| Resource | Utilization| Percentage |
|----------|------------|------------|
| LUT      | 79,975     | 59.42%     |
| FF       | 121,937    | 45.30%     |
| BRAM     | 0          | 0%         |


- ##### Implementation :
<img alt="Implementation" src="https://img.shields.io/badge/Implementation-FAIL-red"> 

| Resource | Utilization| Percentage |
|----------|------------|------------|
| LUT      | 79,967     | 59.77%     |
| FF       | 121,941    | 45.57%     |
| BRAM     | 0          | 0%         |


- ### Advancements done in this version.
    - **handshake** mechanism is introduced (by this way, unconditional running is avoided)
    - **Optimization of FSM :** FSM is neatly & efficietly optimised.

- ### YTBD improvements.
    - **BRAM** should be implemented for efficient memory access.
    - **Dual port** concept should be implemented for sequential data access <span style="color:red;">(note: in this version, it's a one person at a time communication)</span>
    
