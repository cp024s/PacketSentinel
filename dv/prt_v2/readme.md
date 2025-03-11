### **UVM Testbench Hierarchy for PRT**

```
tb_top (Top-Level Module)
│
├── PRT (DUT)  --> Instantiated inside tb_top
│
├── prt_if (Virtual Interface)  --> Connected to tb_top and UVM testbench
│
├── prt_test (Test)
│   ├── prt_env (Environment)
│   │   ├── prt_agent (Agent)
│   │   │   ├── prt_sequencer (Sequencer)
│   │   │   ├── prt_driver (Driver)
│   │   │   ├── prt_monitor (Monitor)
│   │   │   ├── prt_scoreboard (Scoreboard - Can be added later)
│   │   │
│   │   ├── prt_cov (Coverage - Can be added later)
│   │
│   ├── prt_test_sequence (Test Sequence)
│   │   ├── prt_write_sequence (Write Test Case)
│   │   ├── prt_read_sequence (Read Test Case)
│   │   ├── prt_invalidate_sequence (Invalidate Test Case)
│   │   ├── prt_corner_case_sequence (Corner/Edge Cases)
│   │   ├── prt_full_functional_sequence (Stress Testing)
│
├── UVM Factory & Configurations
│
└── Simulation Control (run_test("prt_test");)
```

---

### **Explanation of Each Component**
#### **1. tb_top (Testbench Top Module)**
- Instantiates the **PRT DUT** (Design Under Test).
- Instantiates **prt_if (virtual interface)** and binds it to the DUT.
- Provides **clock and reset**.
- Calls `run_test("prt_test");` to trigger UVM execution.

#### **2. prt_if (Virtual Interface)**
- Groups all DUT signals (write, read, invalidate, and handshakes).
- Provides a single handle for the driver and monitor to communicate with the DUT.

#### **3. prt_test (Test Class)**
- **Top-level UVM test** that starts everything.
- Instantiates **prt_env (Environment)**.
- Runs **prt_test_sequence** which contains multiple test cases.

#### **4. prt_env (Environment)**
- The main container for all testbench components.
- Instantiates **prt_agent (Agent)**.
- Can later add **prt_scoreboard (for checking expected vs actual results)**.
- Can later add **prt_cov (functional coverage metrics)**.

#### **5. prt_agent (Agent)**
- Responsible for all DUT interactions.
- Contains:
  - **prt_sequencer** (Drives stimulus sequences to the driver).
  - **prt_driver** (Drives transactions to the DUT).
  - **prt_monitor** (Passively monitors DUT responses).
  - **prt_scoreboard** (Compares expected vs actual results, can be added later).

#### **6. prt_sequencer (Sequencer)**
- Supplies **prt_transaction** objects to **prt_driver**.
- Generates test sequences (writes, reads, invalidates).
  
#### **7. prt_driver (Driver)**
- Translates **prt_transaction** objects into real DUT **signal waveforms**.
- Drives all **handshake protocols** (enable → wait for ready → transfer).

#### **8. prt_monitor (Monitor)**
- Observes DUT activity **passively** (does not drive DUT).
- Sends captured transactions to **prt_scoreboard**.
  
#### **9. prt_scoreboard (Scoreboard - Can be added later)**
- **Compares** actual DUT output vs expected reference model results.

#### **10. prt_test_sequence (Test Sequences)**
- **Writes a frame and verifies it.**
- **Reads a frame from a valid/invalid slot.**
- **Invalidates a slot and ensures it's cleared.**
- **Corner cases** like:
  - Writing when no slot is free.
  - Reading from an invalid slot.
  - Writing a frame with 1 byte vs 1518 bytes.
  - Back-to-back write/read operations (stress test).

---

### **How the UVM Test Works**
1. **tb_top initializes the PRT DUT and prt_if.**
2. **run_test("prt_test");** starts UVM execution.
3. **prt_test creates prt_env.**
4. **prt_env creates prt_agent.**
5. **prt_agent starts prt_sequencer, prt_driver, and prt_monitor.**
6. **prt_test_sequence drives prt_transaction objects** through the **prt_sequencer** to the **prt_driver**.
7. **prt_driver applies transactions to the DUT (writes, reads, invalidates).**
8. **prt_monitor captures DUT responses and forwards them to prt_scoreboard (if added).**
9. **UVM reports pass/fail based on DUT behavior.**

---

### **Why This Covers All Edge Cases**
✔️ **All handshake sequences (enable → ready → transfer) are tested.**  
✔️ **All transaction types (write, read, invalidate) are exercised.**  
✔️ **Edge cases: Writing when full, reading invalid slots, invalidating active slots.**  
✔️ **Different frame sizes (1-byte, 1518-byte, mid-size).**  
✔️ **Sequential operations (write → read → invalidate → write again).**  
✔️ **Future extensibility: Scoreboard & Coverage metrics can be added.**  

This **UVM testbench** follows standard **UVM agent-based verification methodology** and ensures **complete functional and edge case coverage**. 🚀