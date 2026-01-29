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

## Hardware Architecture

<img width="1887" height="769" alt="image" src="https://github.com/user-attachments/assets/9a1d54d4-8bb3-4a11-8547-68d973de808f" />

## IP

<img width="1231" height="778" alt="image" src="https://github.com/user-attachments/assets/f477af0c-9ea9-4c48-bc85-22c2b13b2800" />

## Block Diagram

<img width="1887" height="615" alt="image" src="https://github.com/user-attachments/assets/cf990cbf-254f-4ba3-98dd-f6400e60d3cb" />

## FPGA Resource Utilization

<img width="697" height="262" alt="image" src="https://github.com/user-attachments/assets/b6759f65-5a27-4555-a706-3aeb8aec3d35" />

## Example Results

| Input Image | Result Image |
|-------------|--------------|
| <img width="688" height="691" alt="image" src="https://github.com/user-attachments/assets/732b026b-2018-4b39-af9f-b45e189c6a5e" /> | <img width="689" height="688" alt="image" src="https://github.com/user-attachments/assets/02f5f06b-06d4-49cb-951b-cf6e691e243a" /> |


| Input Image | Result Image | 
|-------------|--------------|
| <img width="691" height="691" alt="image" src="https://github.com/user-attachments/assets/85c274da-8cf4-4c9a-a672-9605a79d861e" /> | <img width="690" height="689" alt="image" src="https://github.com/user-attachments/assets/33fae1cd-68b7-43d9-b6e8-000f82724f1d" /> |

| Input Image | Result Image | 
|-------------|--------------|
| <img width="689" height="688" alt="image" src="https://github.com/user-attachments/assets/712408a9-1d17-4eed-aa07-739040f410a3" /> | <img width="689" height="691" alt="image" src="https://github.com/user-attachments/assets/9b3adf6c-9d93-49f1-a2ef-ca75a6f59d5c" /> |


---

## Tools & Technologies

- Xilinx Vivado 2021.2 (Synthesis & Implementation)
- Xilinx Vitis 2021.2 for Software Driver Development and FPGA programming
- Hardware used - ZedBoard FPGA (Zynq-7000)  
- Python for algorithm analysis and Look-Up Table Generation (CPU Intel Core i5 - 13450HX)
- MATLAB for algorithm analysis (CPU - Intel Core i5-13450HX)
- MATLAB Simulink, HDL Coder (CPU - Intel Core i5-13450HX)
- Putty for Serial Communication with Host PC via UART
  
---

## References

- He, K., Sun, J., Tang, X.: Single image haze removal using dark channel prior. In:
2009 IEEE Conference on Computer Vision and Pattern Recognition. pp. 1956
1963 (2009). https://doi.org/10.1109/CVPR.2009.5206515

- Shiau, Y.H., Yang, H.Y., Chen, P.Y., Chuang, Y.Z.: Hardware implementation
of a fast and efficient haze removal method. IEEE Transactions on Circuits and
Systems for Video Technology 23(8), 1369–1374 (2013). https://doi.org/10.1109/
TCSVT.2013.2243650

- Hu, H.: Fpga image processing. Udemy online course, https://www.udemy.com/
course/fpga-image-processing/

- Kizheppatt, V.: Image processing on zynq. YouTube playlist 
  
---

## About

**Hardware Accelerator Design | April–November 2025**  
Designed a complete image dehazing pipeline based on the Dark Channel Prior algorithm using pipelined Verilog modules, optimized for fixed-point hardware on FPGA.
