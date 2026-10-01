# riscv-cpu-core
# RISC-V Processor Architectures & Assembler Toolchain

A comprehensive RISC-V processor implementation written in Verilog, progressing from a single-cycle baseline to a fully pipelined architecture with hazard resolution, accompanied by a custom C++ assembler toolchain. 

### 👥 The Team
This core was collaboratively built as a single engineering unit for the ARC 2 course at PSUT by:
* Salma Muwahed
* Tania Fostuq
* Omar Osama

---

## 📁 Repository Structure

| File | Type | Description |
| :--- | :--- | :--- |
| `single_cycle.v` | Verilog Source | Single-cycle RISC-V CPU core implementation. |
| `basic_pipeline.v` | Verilog Source | Basic 5-stage pipelined RISC-V CPU core. |
| `full_pipeline.v` | Verilog Source | Complete 5-stage pipelined CPU core featuring hazard handling, forwarding, and stall logic. |
| `main.cpp` | C++ Source | Custom assembler for translating assembly instructions into 32-bit hex machine code. |

## 🚀 Architectural Overview

### 1. Single-Cycle Core (`single_cycle.v`)
* Executes every instruction in a single clock cycle.
* Straightforward datapath and control unit design.
* Serves as the functional baseline for verifying ISA correctness.

### 2. Basic Pipelined Core (`basic_pipeline.v`)
* Implements a standard 5-stage RISC pipeline:
  1. **IF** — Instruction Fetch
  2. **ID** — Instruction Decode / Register Read
  3. **EX** — Execute / Address Calculation
  4. **MEM** — Memory Access
  5. **WB** — Write Back
* Increases overall clock throughput compared to single-cycle execution.

### 3. Full Pipelined Core (`full_pipeline.v`)
* **Data Hazard Resolution:** Uses register forwarding / bypassing units to eliminate pipeline stalls wherever possible.
* **Control Hazard Resolution:** Manages branch decisions and flushes invalid speculative instructions.
* **Hazard Detection Unit:** Automatically inserts stalls/bubbles for unresolvable dependencies (e.g., Load-Use data hazards).
