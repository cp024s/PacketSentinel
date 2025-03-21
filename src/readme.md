
# <p align = center> SOURCE FILES </p>



## 1. AXI Stream


## 2. Bloom Filter
####  `bloom_filter` - V1 of Bloom filter
- Base version of `Bloom filter` with BRAM integration done.
- Bloom filter: `./src/bloom_filter/bram/bram_2.sv`

- ##### Advancements to be done
    - Refinement of Codebase.
    - Optimization of FSM logic

- ##### Design & Code development
    <img alt="Code ready" src="https://img.shields.io/badge/Code-READY-green"> <img alt="Syntax check" src="https://img.shields.io/badge/Syntax Check-PASS-green">  <img alt="Linting" src="https://img.shields.io/badge/Linting-PASS-green"> <img alt="Lint Violations" src="https://img.shields.io/badge/Violations-0-GREEN"> 

- ##### Simulation & Verification :
    <img alt="Simulation" src="https://img.shields.io/badge/Simulation-PASS-green">  <img alt="Waveform Analysis" src="https://img.shields.io/badge/Waveform Analysis-DONE-orange"> <img alt="Coverage" src="https://img.shields.io/badge/Coverage-0-GREEN"> <should be checked>

- ##### Synthesis :
    <img alt="Synthesis completed" src="https://img.shields.io/badge/Synthesis-COMPLETE-green"> 

    | Resource | Estimation | Available  | Utilization % |
    |----------|------------|------------|---------------|
    | LUT      | 282        | 134600     | 0.21          |
    | FF       | 209        | 2692200    | 0.08          |
    | BRAM     | 0.5        | 365        | 0.14          |
    | IO       | 36         | 285        | 12.63         |
    | BUFG     | 1          | 32         | 3.13          |
- ##### Implementation :
    <img alt="Implementation completed" src="https://img.shields.io/badge/Implementation-DONE-green">  

## 3. Master packet dealer


#### `mpd_base` - V1 of Master packet dealer
- base version of Master packet dealer with `MPD` module logic without `AXI stream` and other module integration

- ##### Advancements to be done in the next version:
    - Refinement of `MPD`'s FSM.
    - Addition of `AXI stream` to the `MPD` module.
    


## 4. Packet Reference Table

#### `prt_base` - V1 of packet reference table. (brut force approach)
- PRT with all the FSM states was written and the `base version` is been tested with `prt_tb_1.sv` and `prt_tb_2.sv` **(refer testbench log for testbench related queries)**

#### `prt_v2` - V2 with Improvements of packet reference table.
- <span style="color:red;">🚨 coverage and stuffs are YTBD</span>
- <span style="color:red;">🚨 Error: IMPLEMENTATION IS FAILING</span>
- <span style="color:orange; font-weight:bold;"> ⚠ `prt_v3` is fixed as release module as of now.</span> 

- ##### Design & Code development
    <img alt="Code ready" src="https://img.shields.io/badge/Code-READY-green"> <img alt="Syntax check" src="https://img.shields.io/badge/Syntax Check-PASS-green">  <img alt="Linting" src="https://img.shields.io/badge/Linting-PASS-green"> <img alt="Lint Violations" src="https://img.shields.io/badge/Violations-0-GREEN"> 

- ##### Simulation & Verification :
    <img alt="Simulation" src="https://img.shields.io/badge/Simulation-PASS-green">  <img alt="Waveform Analysis" src="https://img.shields.io/badge/Waveform Analysis-DONE-orange"> <img alt="Coverage" src="https://img.shields.io/badge/Coverage-0-GREEN"> <should be checked>


- ##### Synthesis :
    <img alt="Synthesis completed" src="https://img.shields.io/badge/Synthesis-COMPLETE-green">  

######
| Resource | Utilization| Percentage | Total     |
|----------|------------|------------|-----------|
| LUT      | 79,975     | 59.42%     | 134600    |
| FF       | 121,937    | 45.30%     | 2692200   |
| BRAM     | 0          | 0%         | 365       |

- ##### Implementation :
    <img alt="Implementation" src="https://img.shields.io/badge/Implementation-FAIL-red"> 

    - **Cause:** Junction temperature exceeded to `103°c` due to excessicve resource utilization
    - **Timing:** As the storage was implemented in the `LUT` timing was increased. $↑$

- ### Advancements done in this version.
    - **handshake** mechanism is introduced (by this way, unconditional running is avoided)
    - **Optimization of FSM :** FSM is neatly & efficietly optimised.

- ### YTBD improvements.
    - **BRAM** should be implemented for efficient memory access.
    - **Dual port** concept should be implemented for sequential data access <span style="color:red;">(note: in this version, it's a one person at a time communication)</span>

### `prt_v3` - V3 of Packet reference table with BRAM integrated.

- ##### Design & Code development
    <img alt="Code ready" src="https://img.shields.io/badge/Code-READY-green"> <img alt="Syntax check" src="https://img.shields.io/badge/Syntax Check-PASS-green">  <img alt="Linting" src="https://img.shields.io/badge/Linting-PASS-green"> <img alt="Lint Violations" src="https://img.shields.io/badge/Violations-0-green"> 

- ##### Simulation & Verification :
    <img alt="Simulation" src="https://img.shields.io/badge/Simulation-DONE-green">  <img alt="Waveform Analysis" src="https://img.shields.io/badge/Waveform Analysis-DONE-green">

- ##### Synthesis :
    <img alt="Synthesis completed" src="https://img.shields.io/badge/Synthesis-DONE-green">  

     | Resource | Estimation | Available  | Utilization % |
     |----------|------------|------------|---------------|
     | LUT      | 179        | 134600     | 0.13          |
     | FF       | 99         | 2692200    | 0.04          |
     | BRAM     | 1          | 365        | 0.27          |
     | IO       | 36         | 285        | 12.63         |
     | BUFG     | 1          | 32         | 3.13          |

- ##### Implementation :
    <img alt="Implementation completed" src="https://img.shields.io/badge/Implementation-DONE-green">  

     | Resource | Estimation | Available  | Utilization % |
     |----------|------------|------------|---------------|
     | LUT      | 161        | 134600     | 0.13          |
     | FF       | 99         | 2692200    | 0.04          |
     | BRAM     | 1          | 365        | 0.27          |
     | IO       | 36         | 285        | 12.63         |
     | BUFG     | 1          | 32         | 3.13          |

- ##### Timing 
    <img alt="Implementation completed" src="https://img.shields.io/badge/WNS-4.762-blue">  <img alt="Implementation completed" src="https://img.shields.io/badge/TNS-0.0-blue">  <img alt="Implementation completed" src="https://img.shields.io/badge/WHS-0.160-blue">      <img alt="Implementation completed" src="https://img.shields.io/badge/THS-0.0-blue">

    (should be double checked afterwards)



- ### Advancemens done in this version
    - **BRAM** is introduced for the memory addess.
    - **Dual port** concept must be inplemented in `ethernet_transactor` and not in `prt` or `mpd` module <span style = "color:red;"> (this was notified only on 12, Mar)       (Explanation must be given by CP) </span> 
    - `Resource utilization` has been brought down by implementing `BRAM`

<br><span style = "color:red;"> All the improvements that is said by `Nithish` has been implemented and the things that are not done have a **valid** reason</span> 

<span style="color: orange; font-weight: bold; text-align: center; font-size: 17px;">
    PRT module has been completed and Implementation was done on <code>13, March</code>
</span>
    <br> <br>
<span style = "color:red; font-weight: bold; font-size=17px;"> Testing and analysis for <code>prt_v3</code> is done by <code>Nithish</code> and approves for working on <code>19, March</span>


## 5. FIFO module

#### Status:

- ##### design & code developement
    <img alt="Code ready" src="https://img.shields.io/badge/Code-READY-green"> <img alt="Syntax check" src="https://img.shields.io/badge/Syntax Check-PASS-green">

- ##### Simulation & Verification
    <img alt="Simulation" src="https://img.shields.io/badge/Simulation-DONE-green">  <img alt="Waveform Analysis" src="https://img.shields.io/badge/Waveform Analysis-DONE-green">

- ##### Synthesis
    <img alt="Synthesis completed" src="https://img.shields.io/badge/Synthesis-DONE-green"> 