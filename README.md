# Predicated RISC Processor — ENCS4370 Project 2

A simplified 32-bit predicated RISC processor designed and implemented in Verilog, as part of a Computer Architecture course.

## Overview

This processor implements a predicated execution model where every instruction carries a predicate register `Rp`. An instruction executes only if `Reg[Rp] ≠ 0`, enabling branch-free conditional execution. Setting `Rp = R0` makes any instruction execute unconditionally (since R0 is hardwired to zero).

## Processor Specifications

| Property | Value |
|---|---|
| Word / Instruction size | 32 bits |
| General-purpose registers | 32 (R0–R31) |
| R0 | Hardwired to 0 |
| R30 | Program Counter (PC) |
| R31 | Return address register |
| Memory | Separate instruction & data memory (word-addressable) |

## Instruction Set Architecture

### Instruction Formats

| Format | Fields |
|---|---|
| R-Type | `Opcode[5] Rp[5] Rd[5] Rs[5] Rt[5] Unused[7]` |
| I-Type | `Opcode[5] Rp[5] Rd[5] Rs[5] Immediate[12]` |
| J-Type | `Opcode[5] Rp[5] Offset[22]` |

### Supported Instructions

| Instruction | Type | Opcode | Operation |
|---|---|---|---|
| ADD Rd, Rs, Rt, Rp | R | 0 | Rd = Rs + Rt |
| SUB Rd, Rs, Rt, Rp | R | 1 | Rd = Rs - Rt |
| OR Rd, Rs, Rt, Rp | R | 2 | Rd = Rs \| Rt |
| NOR Rd, Rs, Rt, Rp | R | 3 | Rd = ~(Rs \| Rt) |
| AND Rd, Rs, Rt, Rp | R | 4 | Rd = Rs & Rt |
| ADDI Rd, Rs, Imm, Rp | I | 5 | Rd = Rs + Imm (sign-extended) |
| ORI Rd, Rs, Imm, Rp | I | 6 | Rd = Rs \| Imm (zero-extended) |
| NORI Rd, Rs, Imm, Rp | I | 7 | Rd = ~(Rs \| Imm) (zero-extended) |
| ANDI Rd, Rs, Imm, Rp | I | 9 | Rd = Rs & Imm (zero-extended) |
| LW Rd, Imm(Rs), Rp | I | 10 | Rd = Mem[Rs + Imm] |
| SW Rd, Imm(Rs), Rp | I | 11 | Mem[Rs + Imm] = Rd |
| J Label, Rp | J | 12 | PC = PC + sign-ext(Offset) |
| CALL Label, Rp | J | 13 | R31 = PC+1; PC = PC + sign-ext(Offset) |
| JR Rs, Rp | R | 14 | PC = Rs |

> All instructions execute only if `Reg[Rp] ≠ 0`. Immediate values are zero-extended for logical instructions and sign-extended for all others. Jump targets are computed as `PC + sign-ext(Offset)`.

## Project Structure

```
src/
├── datapath/         # Datapath modules (ALU, register file, memory, etc.)
├── control/          # Control path (decoder, control unit)
├── top/              # Top-level processor module
└── tb/               # Testbenches and test programs
```

## Pipeline Stages

The processor is implemented as a five-stage pipeline:

1. **Fetch** — Read instruction from instruction memory using PC (R30)
2. **Decode** — Decode opcode, read registers, evaluate predicate Rp
3. **Execute** — ALU performs the operation (or computes memory address)
4. **Memory** — Load/store data memory access
5. **Write-back** — Write result to destination register

## Simulation & Verification

The testbench loads binary test programs into instruction memory and verifies correct execution via waveform simulation. Test programs cover:

- All arithmetic and logical instructions (R-type and I-type)
- Memory access (LW/SW)
- Predicated execution (instructions skipped when Rp = 0)
- Control flow (J, CALL, JR)

## Tools

- **HDL:** Verilog
- **Simulation:** ModelSim / Vivado Simulator

## Team

| Names |
|---|---|
|Lara Fuqaha| |
|Tawba Abdallah| |
|Dana Taher | |
