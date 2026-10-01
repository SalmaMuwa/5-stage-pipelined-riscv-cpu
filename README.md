# RISC-V 5-Stage Pipelined CPU Core & Assembler

A comprehensive RISC-V processor implementation written in Verilog, progressing from a single-cycle baseline to a fully pipelined architecture with hazard resolution. This project features a custom-built C++ assembler toolchain designed specifically for our modified instruction set.

### 👥 The Team
This core was collaboratively built as a single engineering unit for the ARC 2 course at PSUT by:
* Salma Muwahed
* Tania Fostuq
* Omar Osama

---

## 🛠️ Custom Hardware Modifications (35-Bit Architecture)
Unlike standard online RISC-V implementations, this core was heavily modified to break compatibility with standard 32-bit compilers, demonstrating a deep, fundamental understanding of datapath engineering and instruction mapping. 

Key modifications include:
* **35-Bit Instruction Width:** Expanded from the standard 32-bit architecture to support custom operational requirements.
* **6-Bit Register Addressing:** Modified the register file to accommodate 64 total registers instead of the standard 32. 
* **Custom Opcode Mapping:** Utilized tailored opcodes, necessitating the development of a completely custom C++ assembler to translate our modified assembly into machine code. 
* **Hardware Performance Counters:** Integrated dedicated hardware registers for cycle and instruction counting to monitor pipeline efficiency.

---

## 📁 Repository Structure

| File | Type | Description |
| :--- | :--- | :--- |
| `single_cycle.v` | Verilog Source | Single-cycle baseline core implementation. |
| `basic_pipeline.v` | Verilog Source | Basic 5-stage pipelined CPU core. |
| `full_pipeline.v` | Verilog Source | Complete 5-stage pipelined CPU core featuring data forwarding and hazard detection. |
| `main.cpp` | C++ Source | Custom assembler built specifically to translate assembly into our 35-bit hex format. |

## 🚀 Architectural Overview

### 1. Basic Pipelined Core (`basic_pipeline.v`)
* Implements a standard 5-stage RISC pipeline:
  1. **IF** — Instruction Fetch
  2. **ID** — Instruction Decode / Register Read
  3. **EX** — Execute / Address Calculation
  4. **MEM** — Memory Access
  5. **WB** — Write Back

### 2. Full Pipelined Core (`full_pipeline.v`)
* **Data Hazard Resolution:** Uses register forwarding / bypassing units to eliminate pipeline stalls wherever possible.
* **Control Hazard Resolution:** Implements a 2-bit dynamic branch predictor to manage branch decisions and flush invalid speculative instructions. 
* **Hazard Detection Unit:** Automatically inserts stalls/bubbles for unresolvable dependencies (e.g., Load-Use data hazards).
