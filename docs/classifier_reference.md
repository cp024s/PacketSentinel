# CLASFIER DOCUMENTATION
---
<span style="color:orange; font-weight:bold;">⚠ Warning: </span>  **This file is a reference document for `scripts/classifier.py`**

## 1. Overview

This Python script is a part of a system for generating FPGA-based packet classifiers (e.g., a firewall). It takes in firewall rules, FPGA constraints, and user constraints (all in JSON format) and produces Verilog source code along with memory configuration files. The generated hardware modules perform packet matching at high speed by utilizing specialized memory structures (such as DRAM, BRAM, and even Bloom filters).

---

## 2. Imports and Module-Level Setup

```python
import os
import argparse
# from scripts import memModels, rulesValidator, templates
from scripts.templates import *
from scripts.memModels import *
from scripts.rulesValidator import *
```

- **os & argparse**:  
  - `os` is used to check for and create directories.
  - `argparse` processes command-line arguments.

- **Modules from scripts**:  
  - **templates**: Contains code templates for generating Verilog modules.
  - **memModels**: Contains classes and functions to generate memory structures (e.g., FSBV, Bloom Filter memory).
  - **rulesValidator**: Contains logic to validate and optimize firewall rules.

- **Module-level variables**:  
  - `templates_loc = "templates/"`: Directory where the Verilog templates reside.
  - `HEADER_WIDTH = 8` and `PORT_WIDTH = 16`: Default widths for header and port fields, which may change based on IPv6 support.

---

## 3. The `Classifier` Class

This is the core class of the script. It is responsible for reading input files, validating and classifying rules, selecting the appropriate memory model (DRAM/BRAM/Bloom Filter), and finally generating the source code.

### 3.1 The Constructor: `__init__`

```python
def __init__(self, argsr, argsf, argsu, argso):
```

- **Parameters**:
  - `argsr`: Path to the rule file.
  - `argsf`: Path to the FPGA constraints file.
  - `argsu`: Path to the user constraints file.
  - `argso`: Base path for output files.

- **File Setup**:
  - The constructor saves the locations for templates and output directories for memory files (`memfiles_loc`) and source files (`srcfiles_loc`).
  - It ensures that the output directories exist (creates them if necessary).

- **Reading JSON Files**:
  - Opens the rule file, parses the JSON, and stores the `"rules"` list.
  - Similarly, it reads the FPGA constraints (`"fpga_constraints"`) and user constraints (`"user_constraints"`).

- **Configuration Based on User Constraints**:
  - Checks if IPv6 is enabled (`ipv6` set to "yes") in the user constraints. If not, it sets `header_width` and `port_width` to default values.
  - Reads the allowed maximum false positive rate (`max_false_positive_rate`).
  - Determines if parallel Bloom Filter matching is required (`parallelBFRequired`).

---

### 3.2 Rule Validation: `validateRules`

```python
def validateRules(self):
    print("Validating Rules...")
    rv = RulesValidator(self.rules, self.user_constraints["srcIpCheck"]=="yes", 
                          self.user_constraints["dstIpCheck"]=="yes", 
                          self.user_constraints["protocolCheck"]=="yes", 
                          self.user_constraints["portCheck"]=="yes")
    self.rules = rv.findSubsets(rv.findContradiction())		
```

- **Purpose**:  
  - Validates the input rules using the `RulesValidator` class.
  - It checks for contradictions among the rules and eliminates rules that are subsets of others.

- **Parameters Passed to RulesValidator**:
  - Whether to check source IP, destination IP, protocol, and port fields—all derived from user constraints.
  
- **Output**:  
  - The resulting `self.rules` contains only the valid, non-redundant rules.

---

### 3.3 Rule Classification: `classify`

```python
def classify(self):
```

- **Counting and Filtering**:
  - The total number of rules is printed.
  - It filters the rules to keep only those with an `"ACCEPT"` action (i.e., whitelist rules).

- **Validation and Error Checking**:
  - After filtering, it calls `validateRules()` to further optimize the rule set.
  - It asserts that there is at least one rule available for generating the firewall.

- **Rule Partitioning**:
  - The rules are split into two groups:
    - **Without Range Matching**: Where the minimum and maximum values for both source and destination ports are equal.
    - **With Range Matching**: Where a rule specifies a port range (i.e., the min and max are not identical).

- **Memory Model Selection**:
  - If there are rules with range matching, it calls `FSBVTop()` with `rangeMatching=True`.
  - If there are rules without range matching, it either uses a Bloom Filter approach (`BFTop()`) if false positives are acceptable or again falls back to `FSBVTop()`.

- **Final Module Generation**:
  - Calculates an intermediate width `W = 9 * header_width` (9 fields per rule: 4 for source IP, 4 for destination IP, 1 for protocol).
  - Uses a template called `"topmodule"` to generate the top-level module that consolidates outputs from the various matching modules.

---

### 3.4 Memory Generation Functions

#### 3.4.1 `FSBV_DRAM`
This method is called when using DRAM-based memory modules.

- **Purpose**:  
  - Splits the rules into chunks (if a maximum number of rules per DRAM instance is set).
  - Generates memory files for the IP/protocol fields using an FSBV (Fast Scalable Bit Vector) approach.
  - Calls additional modules to generate DRAM-based Verilog code for matching IP/protocol fields, and then for the ports.

- **Steps**:
  1. Determine the stride and DRAM depth from the FPGA constraints.
  2. Split the rule set if a limit (`DRAM_maxRules`) is imposed.
  3. Create a memory file path based on whether range matching is required.
  4. Generate FSBV memory for IP and protocol using helper functions (e.g., `getIPAndProtocolLists`).
  5. Generate DRAM source files using templates (`dram`, `ipprot_match`).
  6. Handle port matching:
     - If range matching is required and a comparator is to be used, use specialized templates.
     - Otherwise, generate memory using non-range matching versions.
  7. Generate the final matching code module.

#### 3.4.2 `FSBV_BRAM`
Almost identical in structure to `FSBV_DRAM`, but instead uses BRAM (on-chip memory) rather than DRAM.

- **Key Differences**:
  - It uses a different stride and width value based on the BRAM configuration (`bram_input_size` and `bram_width`).
  - Templates used are the BRAM-specific ones.
  - The port matching code is adapted to BRAM memory constraints.

---

### 3.5 Consolidation and Top-Level Memory: `FSBVTop`

```python
def FSBVTop(self, ruleSet, rangeMatching):
```

- **Purpose**:
  - Decides whether to use DRAM or BRAM based on the user constraints (`useDRAM` flag).
  - Calculates the number of instances (memory modules) needed by dividing the total number of rules by the maximum rules per module.
  - Iterates over each instance, calling either `FSBV_DRAM` or `FSBV_BRAM` for each chunk of rules.
  - Finally, generates a consolidator module that merges the outputs of the multiple matching modules into a final matching decision.

---

### 3.6 Bloom Filter-Based Matching: `BFTop` and `BF_BRAM`

#### 3.6.1 `BFTop`

```python
def BFTop(self, ruleSet, fp_accepted):
```

- **Purpose**:
  - Implements an alternative matching strategy using a Bloom Filter when a small false positive rate is acceptable.
  - Calculates the memory required for the Bloom Filter and determines if parallel Bloom Filters are needed.
  - Calls `BF_BRAM` to generate the necessary BRAM modules for the Bloom Filter.

- **Process**:
  1. Extracts lists for source ports, destination ports, and IP/protocol fields.
  2. Instantiates a BloomFilter object (from the memModels module) that computes the memory size `m` and the number of hash functions `k`.
  3. Determines the number of BRAM instances required if parallelism is enabled.
  4. Calls `BF_BRAM` to generate the hardware description.

#### 3.6.2 `BF_BRAM`

```python
def BF_BRAM(self, noOfInstances, rangeMatching, m, k):
```

- **Purpose**:
  - Generates BRAM files and Verilog modules specifically for the Bloom Filter implementation.
  - Uses a dedicated template `"bram_bf"` for BRAM memory used in Bloom filtering.
  - Iterates over the required number of instances to generate each piece of memory and the matching logic.

- **Output**:
  - Produces BRAM source files and the Verilog module (`BF_PACKET_MATCH`) that performs the Bloom filter lookup.

---

### 3.7 Exception Class: `InSufficientBRAMsError`

```python
class InSufficientBRAMsError(Exception):
```

- **Purpose**:  
  - Custom exception to be raised if the FPGA does not have enough BRAM resources available to support the required number of rule instances.
  - It carries a default message, "Insufficient # of BRAMs."

---

## 4. Helper Functions

These functions help extract lists of relevant fields from the rules.

### 4.1 `getSrcPortList`

```python
def getSrcPortList(rules):
```

- Iterates over the rules and extracts the source port (specifically, the minimum value).
- Returns a list (wrapped in another list, likely for compatibility with the memory module’s expected input format).

#### 4.2 `getDstPortList`

```python
def getDstPortList(rules):
```

- Works similarly to `getSrcPortList` but for destination ports.

#### 4.3 `getIPAndProtocolLists`

```python
def getIPAndProtocolLists(rules):
```

- For each rule:
  - Splits the source IP string (e.g., "192.168.0.1") into four separate fields.
  - Splits the destination IP similarly.
  - Also extracts the protocol field.
- Returns a list containing nine sublists:
  - Four sublists for source IP fields.
  - Four sublists for destination IP fields.
  - One sublist for protocols.

---

## 5. The Main Block

```python
if __name__ == "__main__":
```

- **Argument Parsing**:
  - Uses `argparse` to require four arguments:
    - `-r`: Path to the rule file.
    - `-f`: Path to the FPGA constraints file.
    - `-u`: Path to the user constraints file.
    - `-o`: Path to the output folder.
  - Ensures the output path ends with a slash (`/`).

- **Classifier Instantiation and Execution**:
  - Creates an instance of `Classifier` with the provided arguments.
  - Calls the `classify()` method, which triggers the entire flow of:
    1. Validating and splitting rules.
    2. Generating memory files and source code for FPGA implementation.
  - A comment indicates that a testbench generation (e.g., `tb.v`) could be added in the future.

---

## Conclusion

In summary, this script forms a complete backend system that:
- Reads and validates firewall rules.
- Determines whether to match rules using exact values or ranges.
- Decides on the hardware memory structure (DRAM vs. BRAM vs. Bloom Filter) based on FPGA and user constraints.
- Uses template-based code generation to produce Verilog modules that implement the packet classifier on an FPGA.
- Finally, it consolidates the various generated modules into a top-level module ready for synthesis.

This design leverages a mix of memory-efficient data structures and hardware optimizations to meet stringent performance requirements—ideal for high-speed packet filtering in network security applications.
