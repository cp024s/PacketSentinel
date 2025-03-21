
---

## **📌 Overview**
This Python script is designed to **validate and optimize firewall rules** by:
1. **Detecting and removing contradictions** – When two rules are identical in matching conditions but have opposite actions (e.g., one allows traffic while the other denies it).
2. **Eliminating redundant (shadowed) rules** – When a more specific rule is completely covered by a broader rule, making it unnecessary.
3. **Ensuring uniqueness** – Preventing duplicate rules.

The script achieves this by checking:
- **Source IP addresses** (`src_ip`)
- **Destination IP addresses** (`dst_ip`)
- **Protocol types** (`protocol`)
- **Port ranges** (`src_port_min`, `src_port_max`, `dst_port_min`, `dst_port_max`)

It offers **configurability** through boolean flags, allowing users to **selectively enable or disable** specific checks.

---

## **🔹 1. The `RulesValidator` Class**
This class encapsulates the entire rule validation and optimization logic.

```python
class RulesValidator:
    def __init__(self, rules, srcIpCheck, dstIpCheck, protocolCheck, portCheck):
        self.rules = rules
        self.srcIpCheck = srcIpCheck
        self.dstIpCheck = dstIpCheck
        self.protocolCheck = protocolCheck
        self.portCheck = portCheck
```

### **📌 What this does**
- **Stores firewall rules (`rules`)** in a list of dictionaries.
- **Stores user preferences** for whether to check source IPs, destination IPs, protocols, and ports.

### **🔹 Example Usage**
```python
rules = [
    {"src_ip": "192.168.1.1", "dst_ip": "10.0.0.1", "protocol": "TCP", "src_port_min": 1000, "src_port_max": 2000, "dst_port_min": 3000, "dst_port_max": 4000, "action": "ALLOW"},
    {"src_ip": "192.168.1.2", "dst_ip": "10.0.0.1", "protocol": "TCP", "src_port_min": 1500, "src_port_max": 1800, "dst_port_min": 3200, "dst_port_max": 3500, "action": "ALLOW"}
]
rv = RulesValidator(rules, True, True, True, True)
```
- This will enable **all** validation checks.

---

## **🔹 2. Checking Source IP (`src_ip` method)**
```python
def src_ip(self, i, j):
    x = i['src_ip'].split('.')
    y = j['src_ip'].split('.')
    
    if x[0] == '*' or x[0] == y[0]:
        if x[1] == '*' or x[1] == y[1]:
            if x[2] == '*' or x[2] == y[2]:
                if x[3] == '*' or x[3] == y[3]:
                    return True
    return False
```

### **📌 What this does**
- Compares two source IPs **octet by octet**.
- Supports **wildcards (`*`)** to allow partial matches.

### **🔹 Example Matches**
| Rule 1 `src_ip`  | Rule 2 `src_ip`  | Match? |
|------------------|------------------|--------|
| 192.168.1.1     | 192.168.1.1       | ✅ Yes  |
| 192.168.*.1     | 192.168.2.1       | ✅ Yes  |
| 10.0.0.1        | 192.168.1.1       | ❌ No   |

**Performance Consideration**:  
- **Splitting strings (`split('.')`)** takes **O(1)** time since an IP has only **4 octets**.
- **Four comparisons** are always performed.

---

## **🔹 3. Checking Destination IP (`dst_ip` method)**
```python
def dst_ip(self, i, j):
    x = i['dst_ip'].split('.')
    y = j['dst_ip'].split('.')

    if x[0] == '*' or x[0] == y[0]:
        if x[1] == '*' or x[1] == y[1]:
            if x[2] == '*' or x[2] == y[2]:
                if x[3] == '*' or x[3] == y[3]:
                    return True
    return False
```

### **📌 What this does**
- Exactly **the same** as `src_ip`, but checks **destination IPs**.

---

## **🔹 4. Checking Protocols (`protocol` method)**
```python
def protocol(self, i, j):
    if i['protocol'] == j['protocol']:
        return True
    else:
        return False
```

### **📌 What this does**
- **Compares two protocol values** (e.g., `TCP`, `UDP`).
- Returns `True` if they match.

### **🔹 Example Matches**
| Rule 1 `protocol` | Rule 2 `protocol` | Match? |
|-------------------|-------------------|--------|
| TCP              | TCP                | ✅ Yes  |
| UDP              | UDP                | ✅ Yes  |
| TCP              | UDP                | ❌ No   |

**Performance Consideration**:  
- A **direct string comparison (`O(1)`)** is extremely fast.

---

## **🔹 5. Checking Port Ranges (`check_subset` method)**
```python
def check_subset(self, i, j):
    if int(i['src_port_min']) <= int(j['src_port_min']):
        if int(i['src_port_max']) >= int(j['src_port_max']):
            if int(i['dst_port_min']) <= int(j['dst_port_min']):
                if int(i['dst_port_max']) >= int(j['dst_port_max']): 
                    return True
    return False
```

### **📌 What this does**
- Checks if **rule `j` is fully contained within rule `i`'s port range**.

### **🔹 Example Matches**
| Rule 1 Ports          | Rule 2 Ports          | Match? |
|----------------------|----------------------|--------|
| 1000 - 2000, 3000 - 4000 | 1200 - 1800, 3200 - 3500 | ✅ Yes  |
| 1000 - 2000, 3000 - 4000 | 500 - 1500, 3500 - 4500  | ❌ No   |

**Performance Consideration**:  
- **4 integer comparisons** (`O(1)`) are **very fast**.

---

## **🔹 6. Removing Contradictory Rules (`findContradiction` method)**
```python
def findContradiction(self):
    uniqueRules = self.unique_rules()
    length = len(uniqueRules)
    k = []
    contra = []

    for i in range(length):
        for j in range(i+1, length):
            count = 0
            if self.srcIpCheck and self.src_ip(uniqueRules[i], uniqueRules[j]):
                count += 1
            if self.dstIpCheck and self.dst_ip(uniqueRules[i], uniqueRules[j]):
                count += 1
            if self.protocolCheck and self.protocol(uniqueRules[i], uniqueRules[j]):
                count += 1
            if self.portCheck and self.check_subset(uniqueRules[i], uniqueRules[j]):
                count += 1
            if count == 4:
                if uniqueRules[i]['action'] != uniqueRules[j]['action']:
                    contra.append((i, j))
                    k.extend([i, j])

    return [uniqueRules[p] for p in range(length) if p not in k]
```
### **📌 What this does**
- **Finds rules that match in all conditions but have opposite actions.**
- If a contradiction is found, **removes** both rules.

---

## **🔹 7. Finding and Removing Redundant Rules (`findSubsets` method)**
Similar to `findContradiction`, but removes rules **completely contained in another rule with the same action**.

---

## **🚀 Summary**
This script is **highly optimized** for detecting and eliminating **conflicting or redundant firewall rules**.  
It can **improve firewall performance** by reducing rule evaluation time.

Would you like an **even deeper breakdown** into optimizations or improvements? 🚀