### **V3 Architecture: Master Packet Dealer (MPD) - Working and FSM States**

The **Master Packet Dealer (MPD)** is a critical module in the firewall architecture. Its primary role is to manage packet storage, classification, and forwarding based on firewall decisions. In V3 architecture, the MPD is designed for **low latency and efficient parallelism**, tightly integrating with Ethernet IP and the Packet Reference Table (PRT).

---

## **Working of the MPD**
1. **Receiving Packets**
   - The **Ethernet IP RX** receives packets from the PHY layer and stores them in a BRAM buffer.
   - The MPD immediately accesses this buffer **byte-by-byte** to process the packet in an online manner.
   - If a **free slot is available in the PRT**, the packet's payload is stored, and a **slot tag** is assigned.

2. **Extracting and Forwarding Header to the Firewall**
   - As the packet is received, the **header** is extracted.
   - The extracted header (along with the assigned slot tag) is pushed into the **TO_FIREWALL FIFO**.
   - The **hardware Bloom filter firewall** checks whether the packet is **safe or unsafe**.

3. **Firewall Decision Handling**
   - **If the packet is safe:**
     - It is placed in the **TO_SEND_FIFO**.
     - The corresponding payload from the PRT is retrieved and sent out via **Ethernet TX**.
   - **If the packet is unsafe:**
     - The header is stored in the **Circular Buffer FIFO** and sent to the **Shakti CPU** for further rule verification.
     - If the CPU confirms it as unsafe, the corresponding payload is **invalidated in the PRT**.

4. **Transmission of Packets**
   - Safe packets are retrieved from the PRT and sent to the **Ethernet IP TX**.
   - The data is streamed **byte-by-byte** to ensure online transmission.
   - Once transmission is complete, the **slot tag is freed** in the PRT.

---

## **FSM States for MPD Operation**
The MPD operates with **three major Finite State Machines (FSMs)**:

### **1. Packet Reception FSM (RX FSM)**
| **State** | **Description** |
|-----------|---------------|
| **IDLE** | Waits for a new packet to arrive from Ethernet RX. |
| **CHECK_FREE_SLOT** | Checks if a free slot is available in the PRT. |
| **STORE_PAYLOAD** | Stores the payload byte-by-byte in PRT. |
| **EXTRACT_HEADER** | Extracts the packet header while receiving. |
| **PUSH_TO_FIREWALL** | Sends header + slot tag to **TO_FIREWALL FIFO**. |
| **WAIT_FOR_FIREWALL_RESULT** | Waits for the firewall decision. |
| **FORCE_STOP_RX** | If the packet is deemed **unsafe**, reception is immediately stopped. |
| **DONE** | Completes reception and resets the FSM. |

---

### **2. Firewall Decision FSM**
| **State** | **Description** |
|-----------|---------------|
| **IDLE** | Waits for a header from **TO_FIREWALL FIFO**. |
| **CHECK_FIREWALL** | Queries the **Bloom filter firewall** for a decision. |
| **SAFE_PACKET** | If safe, push the packet into **TO_SEND_FIFO** for transmission. |
| **UNSAFE_PACKET** | If unsafe, push the packet into **Circular Buffer FIFO** for further processing. |
| **WAIT_FOR_CPU_RESULT** | If false-positive check is required, wait for **Shakti CPU** result. |
| **INVALIDATE_PRT** | If unsafe, send slot tag to PRT for invalidation. |
| **DONE** | Resets and waits for the next packet. |

---

### **3. Packet Transmission FSM (TX FSM)**
| **State** | **Description** |
|-----------|---------------|
| **IDLE** | Waits for a new packet to be sent from **TO_SEND_FIFO**. |
| **RETRIEVE_PAYLOAD** | Reads the packet payload from PRT byte-by-byte. |
| **SEND_TO_ETHERNET** | Streams packet data to **Ethernet IP TX**. |
| **CHECK_FRAME_COMPLETE** | Checks if the full frame is transmitted. |
| **RESET** | Marks the PRT slot as free and resets FSM. |

---

### **Key Optimizations in V3**
- **Online Processing**: Packet processing starts **as soon as bytes arrive**, unlike V1/V2 where full frames were received first.
- **Low Latency**: Reduces clock cycles to **213 cycles** (compared to 10642 in V1).
- **Tightly Integrated Ethernet IP**: Eliminates Xilinx Ethernet IP limitations (e.g., MAC filtering and AXILite delays).

This FSM-based MPD efficiently handles packet processing while ensuring high-speed classification and forwarding. 🚀

---
---

Yes, having **separate Reception (RX) and Transmission (TX) FSMs** is necessary for efficient **parallel packet processing**. Here’s why:

### **1. Full-Duplex Ethernet Operation**
- Ethernet operates in **full-duplex mode**, meaning **packets can be received and transmitted simultaneously**.
- If RX and TX were combined in a single FSM, processing would be **serialized**, reducing throughput.

### **2. Decoupling RX and TX for Pipeline Efficiency**
- The RX FSM **handles receiving packets from Ethernet**, storing them in the **Packet Reference Table (PRT)**.
- The TX FSM **retrieves packets from PRT and sends them out**.
- Keeping them separate **allows parallelism**: while one packet is being received, another can be transmitted.

### **3. Resource Conflicts and AXI Interleaving**
- The **AXI interface** has separate **read and write queues**, but they cannot be accessed simultaneously.
- By **interleaving** RX and TX operations using independent FSMs, we avoid blocking one process while the other is active.

### **4. Avoiding Latency Bottlenecks**
- The RX FSM **handles packet classification** early by sending headers to the **firewall FIFO** as soon as they arrive.
- Meanwhile, the TX FSM **streams packets to Ethernet** as soon as they are deemed **safe**.
- If both were merged, transmission would **wait** until reception is fully complete, **increasing latency**.

### **5. Flexibility for Future Upgrades**
- In multi-port designs (e.g., **2-port Ethernet on Artix-7 200T**), RX and TX need to be **independent**.
- It allows implementing **prioritization schemes** for TX without affecting RX logic.

---

### **Conclusion**
Yes, RX and TX FSMs **must be separate** to support:
✅ **Full-duplex operation**  
✅ **Parallel processing & pipelining**  
✅ **Efficient AXI resource usage**  
✅ **Lower latency & higher throughput**  

Would you like me to optimize the FSM further for your specific design? 🚀

---
---

### **Pseudo Code for All FSMs in V3 Master Packet Dealer (MPD)**  

The MPD consists of three primary FSMs:
1. **Reception FSM (RX FSM)** – Handles incoming packets.
2. **Firewall Decision FSM** – Processes firewall classification.
3. **Transmission FSM (TX FSM)** – Sends out safe packets.

---

## **1. Reception FSM (RX FSM)**
**Purpose:**  
- Receive Ethernet frame.
- Store payload in the **Packet Reference Table (PRT)**.
- Extract header and send it to the **firewall** for classification.

```pseudo
STATE_IDLE:
    Wait for NEW_FRAME_AVAILABLE_FROM_RX
    If available, transition to STATE_CHECK_FREE_SLOT

STATE_CHECK_FREE_SLOT:
    If FREE_SLOT_AVAILABLE_IN_PRT:
        Assign SLOT_TAG
        Transition to STATE_STORE_PAYLOAD
    Else:
        Wait until slot is free

STATE_STORE_PAYLOAD:
    While RX_DATA_VALID:
        Store RX_DATA in PRT[SLOT_TAG]
        Increment BYTE_COUNT
        If HEADER_RECEIVED_COMPLETE:
            Transition to STATE_PUSH_TO_FIREWALL

STATE_PUSH_TO_FIREWALL:
    Push HEADER + SLOT_TAG to TO_FIREWALL_FIFO
    Transition to STATE_WAIT_FOR_FIREWALL

STATE_WAIT_FOR_FIREWALL:
    If FIREWALL_DECISION_RECEIVED:
        If PACKET_SAFE → Transition to STATE_PUSH_TO_TX_FIFO
        If PACKET_UNSAFE → Transition to STATE_PUSH_TO_CIRCULAR_BUFFER

STATE_PUSH_TO_CIRCULAR_BUFFER:
    Push HEADER + SLOT_TAG to CIRCULAR_BUFFER_FIFO
    Transition to STATE_WAIT_FOR_CPU_RESULT

STATE_WAIT_FOR_CPU_RESULT:
    If CPU_DECISION_RECEIVED:
        If PACKET_SAFE → Transition to STATE_PUSH_TO_TX_FIFO
        If PACKET_UNSAFE → Transition to STATE_INVALIDATE_PRT

STATE_PUSH_TO_TX_FIFO:
    Push SLOT_TAG to TO_SEND_FIFO
    Transition to STATE_IDLE

STATE_INVALIDATE_PRT:
    Invalidate PRT[SLOT_TAG]
    Transition to STATE_IDLE
```

---

## **2. Firewall Decision FSM**
**Purpose:**  
- Retrieve headers from **TO_FIREWALL FIFO**.
- Check against **hardware Bloom filter**.
- If needed, send to **Shakti CPU** for further rule verification.

```pseudo
STATE_IDLE:
    Wait for HEADER + SLOT_TAG from TO_FIREWALL_FIFO
    If available, transition to STATE_CHECK_FIREWALL

STATE_CHECK_FIREWALL:
    Query Bloom Filter
    If HIT_DETECTED:
        Transition to STATE_CHECK_FALSE_POSITIVE
    Else:
        Transition to STATE_PACKET_SAFE

STATE_CHECK_FALSE_POSITIVE:
    Push HEADER to CIRCULAR_BUFFER_FIFO for Shakti CPU check
    Transition to STATE_WAIT_FOR_CPU

STATE_WAIT_FOR_CPU:
    If CPU_RESPONSE_RECEIVED:
        If PACKET_SAFE → Transition to STATE_PACKET_SAFE
        If PACKET_UNSAFE → Transition to STATE_PACKET_UNSAFE

STATE_PACKET_SAFE:
    Push HEADER + SLOT_TAG to TO_SEND_FIFO
    Transition to STATE_IDLE

STATE_PACKET_UNSAFE:
    Push SLOT_TAG to TO_INVALIDATE_FIFO
    Transition to STATE_IDLE
```

---

## **3. Transmission FSM (TX FSM)**
**Purpose:**  
- Retrieve **safe packets** from **TO_SEND_FIFO**.
- Fetch corresponding payload from **PRT**.
- Transmit packet **byte-by-byte** via **Ethernet TX**.

```pseudo
STATE_IDLE:
    Wait for SLOT_TAG from TO_SEND_FIFO
    If available, transition to STATE_FETCH_PAYLOAD

STATE_FETCH_PAYLOAD:
    Retrieve data from PRT[SLOT_TAG]
    Transition to STATE_SEND_TO_ETHERNET

STATE_SEND_TO_ETHERNET:
    While BYTE_COUNT < FRAME_LENGTH:
        Send BYTE to ETHERNET_TX
        If LAST_BYTE_SENT:
            Transition to STATE_RESET

STATE_RESET:
    Free SLOT_TAG in PRT
    Transition to STATE_IDLE
```

---

### **Summary of FSMs**
| FSM | Function |
|------|----------|
| **RX FSM** | Receives packets, extracts headers, stores payloads, and forwards headers to firewall. |
| **Firewall FSM** | Classifies packets as **safe** or **unsafe** using Bloom filter & CPU. |
| **TX FSM** | Fetches **safe packets** from PRT and sends them out via Ethernet TX. |

---

### **Why This Design is Optimal**
✅ **Parallel Processing** → RX and TX run independently for **high throughput**.  
✅ **Low Latency** → Headers are processed **while payload is still arriving**.  
✅ **On-the-Fly Firewall Check** → No need to wait for full frame reception.  

Let me know if you need refinements or hardware-specific details! 🚀