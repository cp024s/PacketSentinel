# **Packet Reference Table (PRT) – Detailed Documentation**

## **1. Introduction**

The Packet Reference Table (PRT) is a critical component of an FPGA-based packet processing system (e.g., a firewall). Its main responsibility is to serve as a temporary storage for entire packet frames (including headers and payloads) using a table-based memory structure. Unlike a design that would use dedicated BRAM slices, this implementation stores the packet data directly in an array (a table) implemented with registers or LUTRAM. This design choice, while resource-intensive, can be suitable for small-scale or low-traffic systems where simplicity and direct indexing are valued over scalability.

The PRT manages:
- **Allocation** of storage slots to incoming packets.
- **Tracking** of each packet’s reception and transmission progress.
- **Validity** and lifecycle control (from writing to reading and eventual invalidation).

---

## **2. Components of the PRT**

The PRT module is parameterized by:
- **DATA_WIDTH**: Bit-width of each data word (default 8 bits).
- **MEM_DEPTH**: Maximum number of words per packet (default 1518, typical of an Ethernet frame size).
- **NUM_SLOTS**: Number of packet storage slots available (default 10).

Each PRT entry (or slot) consists of the following fields and signals:

### **2.1 Data Storage (Packet Table)**
- **prt_table**  
  - **Structure**: A 2D array `prt_table[NUM_SLOTS][MEM_DEPTH]`  
  - **Purpose**: Holds the full packet data (header and payload) word-by-word.

### **2.2 Metadata Signals and Registers**
- **valid**  
  - **Type**: Array of 1-bit flags (one per slot)  
  - **Purpose**: Indicates whether the slot currently holds a valid packet.  
    - `1`: The slot contains a valid packet.  
    - `0`: The slot is free.
  
- **bytes_rcvd**  
  - **Type**: 16-bit counter per slot  
  - **Purpose**: Tracks the number of bytes written (received) into the slot. This count represents the total length of the stored packet.
  
- **bytes_sent**  
  - **Type**: 16-bit counter per slot  
  - **Purpose**: Tracks the number of bytes read (transmitted) from the slot.
  
- **frame_complete**  
  - **Type**: 1-bit flag per slot  
  - **Purpose**: Indicates whether the full frame (packet) has been received and written into the table.

### **2.3 Pointers and Slot Management**
- **write_ptr**  
  - **Type**: log₂(MEM_DEPTH)-bit pointer per slot  
  - **Purpose**: Points to the next location in the slot where new incoming data will be stored.
  
- **read_ptr**  
  - **Type**: log₂(MEM_DEPTH)-bit pointer per slot  
  - **Purpose**: Points to the next byte in the slot to be read during transmission.
  
- **current_slot**  
  - **Type**: log₂(NUM_SLOTS)-bit register  
  - **Purpose**: Keeps track of which slot is currently active for a write or read operation.
  
- **free_slot**  
  - **Type**: log₂(NUM_SLOTS)-bit value (computed combinationally)  
  - **Purpose**: Determines an available slot for a new packet. In our simple logic, it checks the first two slots and selects the one that is not valid.
  
- **invalidate_ptr**  
  - **Type**: log₂(MEM_DEPTH)-bit pointer  
  - **Purpose**: Used during invalidation to clear the contents of a slot word-by-word.

---

## **3. Complete Working Logic**

The PRT module uses a finite state machine (FSM) to sequence through various operations. The main operations are:
1. **Starting a write** (allocation and initialization).
2. **Writing packet data** into the table.
3. **Finishing the write** (marking the frame as complete and valid).
4. **Starting a read** (initializing pointers for transmission).
5. **Reading packet data** from the table.
6. **Invalidating a slot** (erasing a packet that is no longer needed).

### **3.1 FSM Overview and States**

The FSM is defined by the following states:
- **S_IDLE**:  
  - The default waiting state.
  - Checks for any enable signals indicating a new operation (write start, read start, or invalidation).

- **S_WRITE_START**:  
  - Allocates a free slot.
  - Resets the write pointer and counters (`bytes_rcvd`, `bytes_sent`) for that slot.
  - Clears the `frame_complete` flag.

- **S_WRITE**:  
  - Continues writing incoming data into the allocated slot.
  - On each clock cycle with `EN_write_prt_entry` asserted:
    - Writes the provided `write_prt_entry_data` to the current slot at the current write pointer.
    - Increments the write pointer and `bytes_rcvd`.

- **S_WRITE_FINISH**:  
  - Marks the end of the write operation.
  - Sets the `frame_complete` flag and marks the slot as valid.
  - The FSM then returns to S_IDLE.

- **S_READ_START**:  
  - Prepares for reading from a specified slot.
  - Sets `current_slot` to the slot indicated by `start_reading_prt_entry_slot`.
  - Resets the read pointer and `bytes_sent` counter for that slot.

- **S_READ**:  
  - Reads data from the current slot.
  - On each clock cycle with `EN_read_prt_entry` asserted:
    - Increments the read pointer and `bytes_sent`.
    - Data is output via the `read_prt_entry` signal.
  - Once all received bytes have been read (`read_ptr >= bytes_rcvd`), the state returns to S_IDLE.

- **S_INVALIDATE_INIT**:  
  - Begins the invalidation process when a slot needs to be cleared.
  - Resets the invalidate pointer to start at the beginning of the slot.

- **S_INVALIDATE_RUN**:  
  - Iteratively clears all data in the targeted slot by writing zero to each location in the table.
  - Once the invalidate pointer reaches `MEM_DEPTH - 1`, the slot’s metadata is reset:
    - `valid` is set to `0`.
    - `bytes_rcvd` and `bytes_sent` are reset.
    - `frame_complete` is cleared.
  - The FSM then returns to S_IDLE.

### **3.2 Detailed Data Flow**

#### **3.2.1 Writing a Packet (Reception Flow)**
1. **Slot Allocation (S_IDLE → S_WRITE_START):**
   - When `EN_start_writing_prt_entry` is asserted and there is at least one free slot (checked by `is_prt_slot_free`), the FSM transitions from S_IDLE to S_WRITE_START.
   - In S_WRITE_START, `current_slot` is set to the available free slot (determined by the combinational logic for `free_slot`).
   - The slot’s write pointer, `bytes_rcvd`, and `bytes_sent` are reset to zero. The `frame_complete` flag is cleared.

2. **Data Writing (S_WRITE):**
   - With `EN_write_prt_entry` asserted, each incoming byte (`write_prt_entry_data`) is written into `prt_table[current_slot][write_ptr[current_slot]]`.
   - After each write, the `write_ptr` and `bytes_rcvd` for the current slot are incremented.
   - This continues until either the entire memory depth is reached or an external signal (`EN_finish_writing_prt_entry`) indicates the end of the frame.

3. **Finalizing the Write (S_WRITE_FINISH):**
   - When finishing criteria are met (either by reaching maximum memory or receiving a finish signal), the FSM transitions to S_WRITE_FINISH.
   - In this state, `frame_complete[current_slot]` is set to `1` and `valid[current_slot]` is set to `1`, indicating that the packet has been fully received and is ready for subsequent processing.
   - The FSM then returns to S_IDLE, waiting for further commands.

#### **3.2.2 Reading a Packet (Transmission Flow)**
1. **Initiate Read (S_IDLE → S_READ_START):**
   - When `EN_start_reading_prt_entry` is asserted and the slot indicated by `start_reading_prt_entry_slot` is valid, the FSM transitions from S_IDLE to S_READ_START.
   - The `current_slot` is updated to the provided slot.
   - The read pointer and `bytes_sent` counter for that slot are reset.

2. **Data Reading (S_READ):**
   - With `EN_read_prt_entry` asserted, the FSM outputs data from `prt_table[current_slot][read_ptr[current_slot]]` via `read_prt_entry`.
   - The read pointer and `bytes_sent` counter are incremented for each byte read.
   - This continues until `read_ptr[current_slot]` equals or exceeds `bytes_rcvd[current_slot]`, meaning the entire packet has been read.
   - The FSM then returns to S_IDLE.

#### **3.2.3 Invalidation of a Slot (Dropping a Packet)**
1. **Start Invalidation (S_IDLE → S_INVALIDATE_INIT):**
   - When `EN_invalidate_prt_entry` is asserted, the FSM transitions from S_IDLE to S_INVALIDATE_INIT.
   - The `invalidate_ptr` is reset to zero to begin clearing the targeted slot.

2. **Clear the Slot (S_INVALIDATE_RUN):**
   - In S_INVALIDATE_RUN, the FSM writes zeros to each word of the slot identified by `invalidate_prt_entry_slot` at the address pointed to by `invalidate_ptr`.
   - The pointer increments until all memory words (up to MEM_DEPTH-1) are cleared.
   - After clearing the data, the metadata is reset:
     - `valid[invalidate_prt_entry_slot]` is set to `0`.
     - `bytes_rcvd` and `bytes_sent` for that slot are reset.
     - `frame_complete` is cleared.
   - The FSM then returns to S_IDLE.

---

## **4. Summary of Signal Interfaces**

### **Input Signals**
- **CLK, RST_N**: Clock and asynchronous reset.
- **EN_start_writing_prt_entry**: Start a new packet write.
- **write_prt_entry_data**: Data to write into the table.
- **EN_write_prt_entry**: Enable writing of data.
- **EN_finish_writing_prt_entry**: Signal to finish writing the current packet.
- **invalidate_prt_entry_slot**: Slot to invalidate (when packet is dropped).
- **EN_invalidate_prt_entry**: Enable invalidation of a slot.
- **start_reading_prt_entry_slot**: Slot to begin reading from.
- **EN_start_reading_prt_entry**: Enable read start.
- **EN_read_prt_entry**: Enable reading of data.

### **Output Signals**
- **start_writing_prt_entry**: Indicates which slot is used for writing.
- **RDY_start_writing_prt_entry**: Ready signal for starting write.
- **RDY_write_prt_entry**: Ready signal for ongoing writes.
- **RDY_finish_writing_prt_entry**: Ready signal after finishing a write.
- **RDY_invalidate_prt_entry**: Ready signal for invalidation.
- **RDY_start_reading_prt_entry**: Ready signal for starting read.
- **read_prt_entry**: Data read from the table.
- **RDY_read_prt_entry**: Ready signal for reading.
- **is_prt_slot_free**: Indicates availability of at least one free slot.
- **RDY_is_prt_slot_free**: Always ready in this design.

---

## **5. Conclusion**

This detailed documentation describes the complete design and working of the Packet Reference Table (PRT) module based on a table-based (array) memory structure. Key points include:

- **Components**:  
  The module uses a table (`prt_table`) to store the entire packet data, along with metadata arrays for validity (`valid`), counters (`bytes_rcvd`, `bytes_sent`), flags (`frame_complete`), and pointers (`write_ptr`, `read_ptr`, `invalidate_ptr`).

- **Working Logic**:  
  The FSM guides the PRT through several states—from slot allocation (S_WRITE_START) and data writing (S_WRITE) to finalizing the write (S_WRITE_FINISH), then reading (S_READ_START, S_READ), and, if needed, invalidation (S_INVALIDATE_INIT, S_INVALIDATE_RUN). Each state carefully updates pointers and counters, ensuring correct operation and resource management.

- **Design Trade-offs**:  
  Storing the entire packet in a table (using registers/LUTRAM) simplifies indexing and may offer faster access for small-scale systems but is resource-intensive and less scalable compared to a BRAM-based design.