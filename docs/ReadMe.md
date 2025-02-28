# <p align = center> Shakti Firewall </p>
##### A Comprehensive Hardware-Based Packet Filtering System
---

The Shakti Firewall project is an advanced research and development endeavor that focuses on the design, implementation, and optimization of a high-performance, hardware-based firewall. Developed as a dual degree project at IIT Madras under the guidance of Professor Chester Rebeiro and Professor Nitin Chandrachoodan, the project tackles the ever-growing challenge of securing high-speed networks against increasingly sophisticated cyber threats.

This project is driven by the need to overcome the limitations of conventional software firewalls when faced with modern network speeds—ranging from 100Gbps to 1Tbps—and the immense packet-processing demands of such environments. By leveraging the flexibility and parallelism of Field-Programmable Gate Arrays (FPGAs), the Shakti Firewall achieves ultra-fast packet classification with minimal resource overhead.

---

## Detailed Overview

### The Problem Space

In today's digital landscape, the rapid integration of information technology has escalated both the volume and complexity of network traffic. Traditional software-based firewalls often become performance bottlenecks due to their sequential processing nature and inability to handle hundreds of millions of packets per second. This challenge is magnified when network speeds increase dramatically, as even small packets require the firewall to process up to 312.5 million packets per second to maintain throughput.

### The Shakti Firewall Solution

The Shakti Firewall project addresses these challenges through a hybrid hardware-software approach that incorporates:

- **Hardware-Accelerated Bloom Filter:**  
  A central component of the system is the Bloom filter—a probabilistic data structure that can determine the membership of an element in constant time, O(1). Implemented directly in hardware on an FPGA, this Bloom filter rapidly screens incoming packet headers against a set of predefined firewall rules. Its design is optimized for speed, allowing near-instantaneous classification while operating with a very low memory footprint. Although Bloom filters inherently introduce a possibility of false positives, their zero false-negativity ensures that no legitimate threat is missed.

- **Software-Based Linear Search Verification:**  
  To counterbalance the potential for false positives in the Bloom filter, the system incorporates a secondary validation step using a conventional linear search algorithm executed by the Shakti CPU. This two-tiered approach—quick initial classification followed by detailed verification—ensures both high throughput and robust security. Packets flagged as potentially unsafe by the Bloom filter undergo an exhaustive check, confirming whether they truly match any of the firewall’s rules.

- **Dynamic Rule Management and Updates:**  
  Recognizing that network environments are dynamic and threats evolve rapidly, the Shakti Firewall supports continuous rule updates. This is achieved via an interface that allows rules to be refreshed in real-time over a USB connection, ensuring that the firewall remains adaptive and responsive to new security challenges.

---

## Architectural Insights

The project’s architecture has evolved through several iterations, each addressing the limitations observed in its predecessor:

### Version 1 (V1): The Prototype
- **Basic Design:**  
  The initial prototype introduced key components such as the Ethernet transactor, Master Packet Dealer (MPD), and Packet Reference Table (PRT). In V1, incoming Ethernet packets are divided into header and payload. The header is sent to the Bloom filter for a fast classification, while the payload is stored in the PRT for subsequent retrieval.
- **Limitations:**  
  While functional, V1 faced challenges with resource utilization and latency. Storing entire frames in registers and the sequential processing of packets led to inefficiencies, especially under high-speed conditions.

### Version 2 (V2): Enhanced Pipelining and Resource Optimization
- **Improved Data Flow:**  
  V2 introduced pipelining improvements where the Ethernet transactor immediately forwards the header to the firewall as soon as it is received, even before the entire frame is captured. This change allowed for simultaneous reception, processing, and transmission of packets.
- **Resource Utilization:**  
  By leveraging BRAM slices instead of registers for temporary storage, V2 reduced resource consumption significantly. However, when tested in a loopback configuration, the improvements in latency were not as pronounced due to inherent limitations of the testing setup.

### Version 3 (V3): The Integrated High-Performance Solution
- **Custom Ethernet IP:**  
  V3 represents a major breakthrough in reducing latency and resource usage. By eliminating reliance on third-party Ethernet IP (like the Xilinx AXI EthernetLite MAC) and developing a custom Ethernet IP tightly integrated with the transactor, V3 achieves a near-seamless data flow.
- **Performance Gains:**  
  The architecture of V3 has demonstrated dramatic improvements—reducing latency to as low as 213 clock cycles while significantly lowering the utilization of Slice LUTs, registers, and BRAM slices. This version is optimized for high-speed networks and is capable of processing data with minimal delay.
- **Robust System Integration:**  
  V3 not only enhances packet processing but also integrates seamlessly with the Shakti CPU for advanced rule verification. The overall system is designed to operate in parallel, ensuring that even under maximum network load, the firewall can keep pace without becoming a bottleneck.

---

## Technical Components and Methodologies

### Hardware Bloom Filter

- **Functionality:**  
  The Bloom filter in the Shakti Firewall is programmed with a set of firewall rules. Each incoming packet header is hashed using multiple fast hash functions (e.g., Jenkins hash) and mapped to an array of bits. If all corresponding bits are set, the packet is flagged as potentially unsafe.
- **Design Trade-offs:**  
  The design carefully balances the number of rules, size of the bit array, and number of hash functions. A larger array size decreases the false positive rate but increases memory consumption, while a higher number of hash functions can either improve or worsen performance based on collision rates.

### Packet Reference Table (PRT) and Master Packet Dealer (MPD)

- **Packet Management:**  
  The PRT stores the payload of each incoming packet, indexed by a unique tag. The MPD coordinates the extraction of headers, interacts with the Bloom filter for quick classification, and retrieves payloads from the PRT for further processing or transmission.
- **Seamless Integration:**  
  By decoupling the storage and processing of packet data, the system ensures that only the critical header information is sent for rapid classification, thereby reducing processing overhead.

### Ethernet Transactor and Custom Ethernet IP

- **Data Handling:**  
  The Ethernet transactor interfaces between the physical Ethernet IP and the MPD. It is responsible for efficiently receiving and transmitting Ethernet frames. In V3, the custom Ethernet IP is designed to immediately process incoming data (byte-by-byte), significantly reducing the delay traditionally introduced by frame buffering.
- **Clock Domain Crossing:**  
  To manage differences in operating frequencies between the PHY layer and the FPGA logic, synchronization FIFOs based on dual-port BRAM are used, ensuring reliable data transfer and minimal latency.

### Shakti CPU and Software Linear Search

- **Enhanced Verification:**  
  The Shakti CPU, especially the modified Shakti-C class employing the FIDES scheme, performs a detailed linear search on packets flagged by the Bloom filter. The FIDES approach introduces hardware-level compartmentalization, isolating different software components to enhance overall system security.
- **Safety and Isolation:**  
  By compartmentalizing the software, vulnerabilities in one module do not compromise the entire system. This is crucial given that traditional memory-unsafe languages like C and C++ are often the source of critical security vulnerabilities.

---

## Performance, Testing, and Results

Testing and synthesis of the Shakti Firewall have been conducted on multiple FPGA platforms, including the Artix-7 100T Arty board and the Alinx AX7203 FPGA board. Key findings include:

- **Latency Improvements:**  
  - V1 and V2 architectures exhibited latencies in the range of 10,600 clock cycles.
  - The V3 architecture dramatically reduced this latency to just 213 clock cycles, highlighting the benefits of custom Ethernet IP integration and pipelined processing.
- **Resource Utilization:**  
  V3 also shows a significant decrease in the consumption of Slice LUTs, registers, and BRAM slices compared to V1 and V2. This efficient use of hardware resources not only enhances performance but also makes the design scalable for future, even higher-speed networks.

---

## Research Impact and Future Directions

The Shakti Firewall project stands as a significant advancement in the field of network security and FPGA-based hardware design. Its contributions include:

- **Demonstrating Feasibility:**  
  The project validates the potential of hardware-based firewalls to achieve high-speed packet processing without the bottlenecks inherent in software-only solutions.
- **Innovative Use of Probabilistic Data Structures:**  
  By integrating a Bloom filter in hardware, the system provides a novel approach to fast, parallel packet classification, setting the stage for further research in optimizing false positive rates and memory usage.
- **Foundation for Future Enhancements:**  
  Future work may focus on extending support for 1000 Mbps (Gigabit Ethernet) standards, further reducing false positives in the Bloom filter through adaptive techniques, and integrating even more advanced memory-safe software architectures.
- **Scalable and Adaptive Rule Management:**  
  With continuous updates via USB and the ability to reconfigure firewall rules in real time, the Shakti Firewall is designed to adapt to evolving network threats, ensuring long-term relevance and robustness.

In conclusion, the Shakti Firewall project represents a groundbreaking fusion of hardware and software techniques, offering a scalable, efficient, and highly secure solution for modern network environments. It not only addresses current challenges in high-speed packet processing and cybersecurity but also lays a robust foundation for future innovations in firewall technology.
