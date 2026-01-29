# Real-Time Image Haze Removal on FPGA (ZedBoard)

© 2026 Rohan M.

This repository is made public solely for academic evaluation and review.
All rights are reserved. No permission is granted to copy, modify, distribute,
publish, or use this code or accompanying materials, in whole or in part,
for any purpose without the explicit written consent of the author.

---

## Overview

This project presents a hardware-accelerated, real-time image dehazing pipeline, fully implemented in Verilog and synthesized on a Xilinx ZedBoard FPGA (Zynq-7000). The goal is to achieve high-performance image dehazing using a custom pipelined architecture based on the Dark Channel Prior method, optimized for fixed-point arithmetic and stream-based throughput.

The pipeline receives BMP images via UART, processes them to remove haze, and returns the reconstructed haze-free image back to the host PC.

---

## Motivation

Hazy or foggy images reduce visibility and impair the performance of vision-based systems in applications such as:

- Autonomous vehicles  
- Surveillance systems
- Remote Sensing

Real-time haze removal is computationally expensive on general-purpose CPUs. To address this, the design uses a custom FPGA-based hardware accelerator to:

- Achieve parallelism  
- Support stream-based pipelining  
- Enable real-time dehazing on-chip  
- Reduce latency compared to software solutions
- Reduce power consumption by implementing clock gating

---
## Objectives

- Accelerate the Dark Channel Prior based haze removal algorithm using FPGA for real-time performance.
- Modular Verilog Implementation of each processing stage: Atmospheric Light Estimation, Transmission Estimation, Scene Recovery and Saturation Correction.
- Optimize for low-latency and energy efficiency using pipelining, parallelism and Clock Gating techniques
- Enable deployment on embedded platforms (Zynq SoC) with AXI4-stream interface.
---

## Algorithm Overview

### Key Steps:

1. **Window Generation**
2. **Atmospheric Light Estimation**  
3. **Transmission Estimation**  
4. **Scene Recovery and Saturation Correction**
   
---

## Hardware Architecture

The complete hardware pipeline is organized into modular Verilog blocks as follows:

### 1. **WindowGenerator**

- Extracts 3×3 RGB window using 2 line buffers  
- Outputs 9 pixels in parallel  
- Easily scalable to generate larger windows

### 2. **ALE (Atmospheric Light Estimation)**

- Computes per-pixel minimum (R, G, B)  
- Performs 3×3 spatial minimum using comparator trees
- Computes the dark channel per 3x3 RGB window
- Selects brightest pixel from the dark channel of the frame 
- Calculates inverse atmospheric light for TE stage  
- Fully pipelined and stream-compatible

### 3. **TE (Transmission Estimation)**

- Estimates pixel-wise haze using:  
  `t(x)=1 − ω min c∈{R,G,B} (Fc / Ac)`  
- ω = 0.9375 is implemented as a constant  
- All operations use fixed-point arithmetic

### 4. **SRSC (Scene Recovery and Saturation Correction)**

- Computes:  
  `J(x) = {(I(x) - A) / max(t(x), t₀)} + A`  
- Handles division using reciprocal lookup  
- Ensures `t(x) ≥ t₀ = 0.35`  
- Produces a sharp output image with the haze eliminated

---

## Top-Level Design

### **Pipeline Flow**

```
WindowGenerator → ALE → TE → SRSC
```

### **Interface**

- **Input:** RGB pixel stream to WindowGenerator
- **Output:** Corrected RGB pixel stream  

### **Features:**

- Valid signal-based flow control  
- Modular and synthesizable design  
- Fully stream-based datapath
- Pipeline Stalling to obtain the final Atmospheric Light values
- Clock Gating technique to reduce power consumption
---

## Testbench (Top_TB)

- Reads BMP file and extracts pixel data  
- Drives the pipeline and captures results
- Writes output to BMP file
- Parses BMP header and maintains padding

---

## Features

- 3×3 sliding window for local filtering  
- Dark channel estimation with comparator trees  
- Fixed-point multiplication and shifting operations to reduce hardware and execution time
- Transmission floor control (`t₀ = 0.35`)  
- Fully pipelined 10-stage architecture
- Clock Gating for the ALE and TE_SRSC modules to reduce power consumption
- Synthesizable on ZedBoard FPGA  
- Modular, reusable Verilog architecture  
- Verified using waveform simulations and output BMP image comparison

---

## Testing and Simulation

- **Tools Used:** Xilinx Vivado & Vitis 2021.2, MATLAB, Pycharm
- **BMP I/O:**  
  - Header parsed and preserved  
  - Input and output streams verified  
- **Verification:**  
  - Waveform analysis  
  - Visual output inspection  
  - Pixel-wise comparison  

---

### Hardware-Software Co-Design:

- Stored the Input Image in DDR
- Transferred Image Data from DDR to IP using DMA and AXI-4 Stream Interface 
- Transferred the corrected pixel stream back to DDR using DMA and AXI-4 Stream Interface
- Sent the pixel stream to PC via UART
- Interrupt Service Routine indicates when the entire operation in complete

---

## Results

## IP

<img width="1216" height="675" alt="Screenshot 2025-08-09 135758" src="https://github.com/user-attachments/assets/9e84e90f-8107-4c9b-b478-23ad2da632cb" />

## Block Diagram

<img width="1893" height="903" alt="Screenshot 2025-08-09 140851" src="https://github.com/user-attachments/assets/f43d95a3-38f9-4d19-a1f0-9dacdc62bb1d" />

## Utilization

<img width="632" height="269" alt="Screenshot 2025-08-11 191619" src="https://github.com/user-attachments/assets/3acc05e7-c78b-4b4a-ad9e-64d12bd71f1e" />

## Example Results

| Input Image | Result Image |
|-------------|--------------|
| ![canyon_512](https://github.com/user-attachments/assets/b0f36204-ad30-4f53-a093-c8c53ff24914) | ![result_image](https://github.com/user-attachments/assets/2a35c13e-4176-4630-ad66-9814118e3f8d) |


| Input Image | Result Image | 
|-------------|--------------|
| ![building_512](https://github.com/user-attachments/assets/c60748cc-11c5-4420-9a95-2a84e2fb2239) | ![result_image (1)](https://github.com/user-attachments/assets/d428269b-8e91-46e9-8f49-f52b891cd594) |

| Input Image | Result Image | 
|-------------|--------------|
| ![town_bmp](https://github.com/user-attachments/assets/7a467f76-a99e-4641-a100-4847a4cb1220) | ![result_image (1)](https://github.com/user-attachments/assets/b0853c65-79c9-4d1b-a0ca-2deb3dcbce8c) |


---

## Tools & Technologies

- Xilinx Vivado 2021.2 (Synthesis & Implementation)
- Xilinx Vitis 2021.2 for Software Driver Development and FPGA programming
- Hardware used - ZedBoard FPGA (Zynq-7000)  
- Python for algorithm analysis and Look-Up Table Generation (CPU Intel Core i5 - 13450HX)
- MATLAB for algorithm analysis (CPU Intel Core i5 - 13450HX)
- MATLAB Simulink, HDL Coder (CPU Intel Core i5 - 13450HX)
- Putty for Seria C0mmunication with PC via UART
  
---

## References

- **He, Kaiming**, **Jian Sun**, and **Xiaoou Tang**.  
  *"Single Image Haze Removal Using Dark Channel Prior."*  
  *IEEE Transactions on Pattern Analysis and Machine Intelligence (TPAMI), 2011.*

- **IEEE TCSVT Paper**  
  *"Hardware Implementation of a Fast and Efficient Haze Removal Method - "*
  *Yeu-Horng Shiau, Hung-Yu Yang, Pei-Yin Chen, Member, IEEE, and Ya-Zhu Chuang*

- **Image Processing on Zynq**  
  *Vipin Kizheppatt - https://www.youtube.com/@Vipinkmenon*

- **FPGA Image Processing**  
  *Udemy Course by Hui Hu*
  
---

## About

**Hardware Accelerator Design | March–September 2025**  
Designed a complete image dehazing pipeline based on the Dark Channel Prior algorithm using pipelined Verilog modules, optimized for fixed-point hardware on FPGA.
