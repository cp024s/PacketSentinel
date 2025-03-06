This Verilog module, named `mkPRT`, implements a Packet Reception Table (PRT) with the functionality for managing packets in two slots, each of which has its own read and write pointers, valid flags, and other associated state information. The module allows operations like writing entries, reading entries, invalidating entries, and checking if slots are free. Below is a detailed breakdown of the code:

### Parameters:

- **DATA_WIDTH (default = 8)**: This defines the width of the data being stored in the Packet Reception Table. It can be changed if needed to store wider data words.
- **MEM_DEPTH (default = 2000)**: This is the depth of each slot in the PRT, indicating how many entries can be stored in each slot.
- **NUM_SLOTS (default = 2)**: This defines the number of slots in the PRT (fixed to 2 in this design).

### I/O Ports:

#### Inputs:
- **CLK**: Clock signal for the module.
- **RST_N**: Active-low reset signal to reset the module.
  
#### Action and Value Methods:
- **EN_start_writing_prt_entry**: Enables the start of the writing process for an entry in the PRT.
- **write_prt_entry_data**: Data that is to be written to the PRT.
- **EN_write_prt_entry**: Enables the actual writing of the PRT entry.
- **EN_finish_writing_prt_entry**: Signals the end of writing an entry to the PRT.
- **invalidate_prt_entry_slot**: Selects the slot (0 or 1) to be invalidated.
- **EN_invalidate_prt_entry**: Enables the invalidation of a slot.
- **start_reading_prt_entry_slot**: Selects the slot (0 or 1) to read from.
- **EN_start_reading_prt_entry**: Enables the start of a read operation.
- **EN_read_prt_entry**: Enables the actual reading from the PRT.

#### Outputs:
- **start_writing_prt_entry**: Returns the chosen slot (0 or 1) for writing a new entry.
- **RDY_start_writing_prt_entry**: Indicates readiness to start writing to the PRT (i.e., if a slot is free).
- **RDY_write_prt_entry**: Indicates readiness to write a new entry into the PRT.
- **RDY_finish_writing_prt_entry**: Indicates readiness to finish writing an entry.
- **RDY_invalidate_prt_entry**: Indicates readiness to invalidate a slot.
- **RDY_start_reading_prt_entry**: Indicates readiness to start reading from the PRT.
- **RDY_read_prt_entry**: Indicates readiness to read an entry from the PRT.
- **is_prt_slot_free**: Indicates if at least one of the slots in the PRT is free (not valid).
- **RDY_is_prt_slot_free**: Indicates readiness to check if any slot is free.
- **read_prt_entry**: Data read from the PRT concatenated with a completion flag.

### FSM States:
The FSM (Finite State Machine) controls the operation of the module. The states are as follows:
- **S_IDLE**: Initial state where no operation is happening.
- **S_WRITE_START**: Begin the write operation by selecting a free slot and resetting counters.
- **S_WRITE**: Actively writing data to the table.
- **S_WRITE_FINISH**: Mark the entry as valid and complete after writing.
- **S_READ_START**: Begin the read operation by selecting the requested slot and resetting pointers.
- **S_READ**: Read data from the table.
- **S_INVALIDATE**: Invalidate a selected slot.

### Registers:
- **state, next_state**: These hold the current and next state of the FSM.
- **current_slot**: A register that holds the current slot being used for read/write operations (either 0 or 1).
- **wr_addr, rd_addr**: The write and read pointers for each slot. These pointers are used to determine where the next read or write operation should occur.
- **prt_bytes_rcvd, prt_bytes_sent_req, prt_bytes_sent_res**: Counters to track the number of bytes received, sent, and requested in each slot.
- **prt_is_frame_full**: Flag that indicates whether the current frame in a slot is full.
- **prt_valid**: Flag that indicates whether the current slot holds a valid entry.
- **prt_table**: A 2D array representing the Packet Reception Table, where data is stored for each slot.

### FSM Logic:
The state transitions and operations are described in the sequential and combinational logic sections:

#### Sequential Logic (State Transitions):
- **Reset**: On reset (`!RST_N`), the module goes into the `S_IDLE` state, and all registers are cleared (slot pointers, counters, flags).
  
- **State Transitions**: The module enters the next state based on the current state and conditions:
  - **S_IDLE**: It checks if any of the start commands (write, read, invalidate) are active. If a slot is free and a write command is issued, it moves to `S_WRITE_START`. If a valid slot is selected and a read command is issued, it moves to `S_READ_START`. If an invalidate command is issued, it moves to `S_INVALIDATE`.
  - **S_WRITE_START**: The FSM chooses a free slot (preferably slot 0 if free) and initializes the write pointer and counter. It then moves to `S_WRITE`.
  - **S_WRITE**: The module writes data to the PRT if the `EN_write_prt_entry` signal is active, updating the table and the write pointer. It transitions to `S_WRITE_FINISH` when `EN_finish_writing_prt_entry` is active.
  - **S_WRITE_FINISH**: After finishing the write operation, it marks the slot as valid and full, then transitions back to `S_IDLE`.
  - **S_READ_START**: The FSM sets up the read pointers for the selected slot and moves to `S_READ`.
  - **S_READ**: The FSM reads data from the PRT, updating the read pointer as long as the `EN_read_prt_entry` signal is active. If reading is finished (when `EN_read_prt_entry` is deasserted), it moves back to `S_IDLE`.
  - **S_INVALIDATE**: The FSM invalidates the specified slot and transitions back to `S_IDLE`.

#### Combinational Logic (Next State Logic):
This part determines the next state based on the current state and input signals. For example:
- If the FSM is in the `S_IDLE` state and a write command is issued with a free slot, it transitions to `S_WRITE_START`.
- If the FSM is in `S_WRITE` and the finish write signal is asserted, it transitions to `S_WRITE_FINISH`.

### Output Assignments:
- **Ready Signals**: The ready signals (`RDY_*`) indicate when the module is ready to perform a given action. For example:
  - **RDY_start_writing_prt_entry**: The module is ready to start writing if the state is `S_IDLE` and at least one slot is free.
  - **RDY_write_prt_entry**: The module is ready to write data if the state is `S_WRITE`.
  - **RDY_finish_writing_prt_entry**: Ready when the state is `S_WRITE`.
  - **RDY_invalidate_prt_entry**: Ready when the state is `S_IDLE`.
  - **RDY_start_reading_prt_entry**: Ready when the state is `S_IDLE` and the selected slot is valid.
  - **RDY_read_prt_entry**: Ready when the state is `S_READ`.
  - **RDY_is_prt_slot_free**: Always `1` in this design as it doesn't depend on the FSM.

- **Data Signals**:
  - **start_writing_prt_entry**: The chosen slot for writing is returned (0 or 1).
  - **is_prt_slot_free**: A logic signal indicating if at least one of the slots is free (i.e., invalid).
  - **read_prt_entry**: Concatenates the data from the table with a completion flag, indicating whether the entry is complete or still being received.

### Summary:
This module provides a flexible mechanism to manage a Packet Reception Table with two slots. It supports writing, reading, invalidating slots, and checking the availability of slots for new entries. The module is controlled by an FSM that transitions between various states to handle the different actions efficiently.