Here's a detailed explanation of the logic in the **Packet Routing Table (PRT) module** along with embedded comments to clarify the code's functionality.

---

## **Overview of the Module**
The `PRT` module acts as a **dual-slot memory buffer** that stores and retrieves packet routing information. It implements **two independent memory slots**, each capable of storing up to `MEM_DEPTH` (2000) bytes of 8-bit data. The module follows a **finite state machine (FSM) design**, supporting operations like:
- Writing packet entries
- Reading packet entries
- Invalidating packet entries

Each slot has its own **write and read pointers**, **validity flags**, and **counters** to track the number of bytes written and read.

---

## **Parameter and Port Definitions**
```systemverilog
module PRT #(
  parameter DATA_WIDTH = 8,      // Data width per entry (default 8 bits)
  parameter MEM_DEPTH  = 2000,   // Number of entries per slot
  parameter NUM_SLOTS  = 2       // Number of PRT slots (fixed at 2)
  ) (
```
- The module uses `DATA_WIDTH = 8` to store 8-bit packet data.
- Each slot has `MEM_DEPTH = 2000` entries.
- There are `NUM_SLOTS = 2` (slots 0 and 1).

### **Clock and Reset Signals**
```systemverilog
  input  logic                   CLK,    // System clock
  input  logic                   RST_N,  // Active-low reset
```
- **`CLK`** is used to synchronize all operations.
- **`RST_N`** resets all registers and pointers.

### **Write Operation Ports**
```systemverilog
  input  logic                   EN_start_writing_prt_entry, // Start write command
  output logic                   start_writing_prt_entry,    // Selected slot (0 or 1)
  output logic                   RDY_start_writing_prt_entry,// Indicates ready to start writing

  input  logic [DATA_WIDTH-1:0]  write_prt_entry_data, // Data to write
  input  logic                   EN_write_prt_entry,   // Enable write
  output logic                   RDY_write_prt_entry,  // Ready to accept data

  input  logic                   EN_finish_writing_prt_entry, // Finish writing command
  output logic                   RDY_finish_writing_prt_entry // Ready signal for finishing
```
- These signals control **starting, writing, and finishing** the write process.
- The module chooses a **free slot** before writing.
- The `RDY` signals indicate when the module is ready.

### **Read Operation Ports**
```systemverilog
  input  logic                   start_reading_prt_entry_slot, // Slot selection for reading
  input  logic                   EN_start_reading_prt_entry,   // Start read command
  output logic                   RDY_start_reading_prt_entry,  // Ready to start reading

  input  logic                   EN_read_prt_entry,            // Enable read command
  output logic [DATA_WIDTH:0]    read_prt_entry,               // Data read + completion flag
  output logic                   RDY_read_prt_entry            // Ready to read
```
- These signals **start and perform reading** from a slot.
- The `read_prt_entry` signal outputs **data + a flag** indicating the last byte of a frame.

### **Invalidate Entry Ports**
```systemverilog
  input  logic                   invalidate_prt_entry_slot, // Slot to be invalidated
  input  logic                   EN_invalidate_prt_entry,   // Invalidate command
  output logic                   RDY_invalidate_prt_entry   // Ready to invalidate
```
- Used to **mark a slot as invalid**.

### **Slot Status Signals**
```systemverilog
  output logic                   is_prt_slot_free,   // Indicates if at least one slot is free
  output logic                   RDY_is_prt_slot_free // Always ready
```
- **`is_prt_slot_free`** helps check if there is an empty slot.

---

## **FSM (Finite State Machine)**
### **State Definitions**
```systemverilog
typedef enum logic [2:0] {
  S_IDLE,         
  S_WRITE_START,  
  S_WRITE,        
  S_WRITE_FINISH, 
  S_READ_START,   
  S_READ,         
  S_INVALIDATE    
} state_t;
```
- `S_IDLE`: The module is waiting for a command.
- `S_WRITE_START`: Choose a free slot for writing.
- `S_WRITE`: Write data into memory.
- `S_WRITE_FINISH`: Mark the slot as valid after writing.
- `S_READ_START`: Set up for reading.
- `S_READ`: Read data from memory.
- `S_INVALIDATE`: Clear a slot.

---

## **Registers and Memory**
```systemverilog
state_t state, next_state; 
logic      current_slot; // Holds the active slot (0 or 1)
```
- **Tracks the current slot** being used.

```systemverilog
logic [15:0] wr_addr [NUM_SLOTS-1:0]; // Write addresses
logic [15:0] rd_addr [NUM_SLOTS-1:0]; // Read addresses
logic [15:0] prt_bytes_rcvd [NUM_SLOTS-1:0]; // Bytes received (written)
logic [15:0] prt_bytes_sent_req [NUM_SLOTS-1:0]; // Bytes sent (requested)
logic [15:0] prt_bytes_sent_res [NUM_SLOTS-1:0]; // Bytes sent (actual)
logic        prt_is_frame_full [NUM_SLOTS-1:0]; // Marks full frames
logic        prt_valid [NUM_SLOTS-1:0]; // Indicates valid slots
```
- **Each slot maintains counters** for tracking write/read progress.

```systemverilog
logic [DATA_WIDTH-1:0] prt_table [NUM_SLOTS-1:0][0:MEM_DEPTH-1]; 
```
- **Memory array storing 8-bit data in 2 slots**.

---

## **FSM Logic**
### **Sequential State Transitions**
```systemverilog
always_ff @(posedge CLK or negedge RST_N) begin
  if (!RST_N) begin
    state <= S_IDLE;
    current_slot <= 0;
    for (i = 0; i < NUM_SLOTS; i = i + 1) begin
      wr_addr[i]           <= 16'd0;
      rd_addr[i]           <= 16'd0;
      prt_bytes_rcvd[i]    <= 16'd0;
      prt_bytes_sent_req[i] <= 16'd0;
      prt_bytes_sent_res[i] <= 16'd0;
      prt_is_frame_full[i]  <= 1'b0;
      prt_valid[i]          <= 1'b0;
    end
  end else begin
    state <= next_state;
```
- On reset, **all slots are cleared**.
- The **state machine transitions on every clock cycle**.

### **Write Logic**
```systemverilog
S_WRITE: begin
  if (EN_write_prt_entry) begin
    prt_table[current_slot][wr_addr[current_slot]]  <= write_prt_entry_data;
    wr_addr[current_slot]                           <= wr_addr[current_slot] + 16'd1;
    prt_bytes_rcvd[current_slot]                    <= prt_bytes_rcvd[current_slot] + 16'd1;
  end
end
```
- Writes data to the memory table.

### **Read Logic**
```systemverilog
S_READ: begin
  if (EN_read_prt_entry) begin
    rd_addr[current_slot]            <= rd_addr[current_slot] + 16'd1;
    prt_bytes_sent_req[current_slot] <= rd_addr[current_slot] + 16'd1;
  end
end
```
- Reads data **sequentially**.

### **Invalidate Slot**
```systemverilog
S_INVALIDATE: begin
  prt_valid[invalidate_prt_entry_slot]           <= 1'b0;
  prt_is_frame_full[invalidate_prt_entry_slot]   <= 1'b0;
end
```
- Marks a slot as **invalid**.

---

## **Output Assignments**
```systemverilog
assign read_prt_entry = { 
  prt_table[current_slot][rd_addr[current_slot]], 
  (rd_addr[current_slot] == prt_bytes_rcvd[current_slot])
};
```
- Reads **data** plus a **completion flag**.

```systemverilog
assign is_prt_slot_free = (!prt_valid[0] || !prt_valid[1]);
```
- Checks for **free slots**.

---

### **Final Thoughts**
This module **efficiently manages** reading/writing in two slots while tracking **validity and completion**. It **ensures parallel processing** and **sequential read/write access**, making it ideal for **packet-based systems**. 🚀