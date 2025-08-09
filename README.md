# Real-Time Image Haze Removal on FPGA (ZedBoard)    ![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD--3--Clause-00008B.svg)

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
- Enable deployment on embedded platforms (Zynq SoC) with AXI-stream interface.
---

## Algorithm Overview

### Key Steps:

1. **Atmospheric Light Estimation**  
2. **Transmission Estimation**  
3. **Scene Radiance Recovery**

---

## Hardware Architecture

The complete hardware pipeline is organized into modular Verilog blocks as follows:

### 1. **WindowGenerator**

- Extracts 3×3 RGB window using 2 line buffers  
- Outputs 9 pixels (in1 to in9) in parallel  
- Easily scalable to generate larger windows

### 2. **ALE (Atmospheric Light Estimation)**

- Computes per-pixel minimum(R, G, B)  
- Performs 3×3 spatial minimum using comparator trees
- Computes the dark channel per 3x3 RGB window
- Selects brightest pixel from the dark channel of the frame 
- Calculates inverse atmospheric light for TE stage  
- Fully pipelined and stream-compatible

### 3. **TE (Transmission Estimation)**

- Estimates pixel-wise haze using:  
  `t(x)=1 − ω min c∈{R,G,B} (Pc / Ac)`  
- ω = 0.9375 is implemented as a constant  
- All operations use Q0.16 fixed-point arithmetic

### 4. **SRSC (Scene Recovery and Saturation Correction)**

- Computes:  
  `J(x) = {(I(x) - A) / max(t(x), t₀)} + A`  
- Handles division using reciprocal lookup  
- Ensures `t(x) ≥ t₀ = 0.275` (Q0.16)  
- Produces a sharp output image with the haze eliminated

---

## Top-Level Design

### **Pipeline Flow**

```
WindowGenerator → DarkChannel → ALE → TE_and_SRSC
```

### **Interface**

- **Input:** RGB pixel stream from UART  
- **Output:** Dehazed RGB pixel stream  

### **Features:**

- Valid signal-based flow control  
- Modular and synthesizable design  
- Fully stream-based datapath
- Pipeline Stalling to obtain the final Atmospheric Light value
- Clock Gating technique to reduce power consumption
---

## Testbench (Top_TB)

- Reads BMP file (`input.bmp`) and extracts pixel data  
- Drives the dehazing pipeline and captures results  
- Writes output to BMP file (`output.bmp`)  
- Parses BMP header and maintains padding  
- Simulates full system operation with `$fread` / `$fwrite`

---

## Features

- 3×3 sliding window for local filtering  
- Dark channel estimation with comparator trees  
- Fixed-point division and multiplication  
- Transmission floor control (`t₀ = 0.275`)  
- Fully pipelined 10-stage architecture
- Clock Gating for the ALE and TE_SRSC modules to reduce power consumption
- Synthesizable on ZedBoard FPGA  
- Modular, reusable Verilog architecture  
- Verified using waveform simulations and output BMP image comparison

---

## Fixed-Point Arithmetic

- **Format:** Q0.16 (16-bit signed/unsigned)  
- **Division:**  
  `recip_t = 2^16 / t`  
- **Arithmetic Units:** Signed adders, clamping logic, LUT-based reciprocal  

---

## Testing and Simulation

- **Tools Used:** Vivado Simulator, MATLAB, Pycharm
- **BMP I/O:**  
  - Header parsed and preserved  
  - Input and output streams verified  
- **Verification:**  
  - Waveform analysis  
  - Visual output inspection  
  - Pixel-wise comparison  

---

## UART Communication on ZedBoard

### Implementation:

- Custom serial protocol over UART  
- Image streamed pixel-wise (RGB) from host to FPGA  
- Processed dehazed image returned via UART

---

## Results

## IP

<img width="1216" height="675" alt="Screenshot 2025-08-09 135758" src="https://github.com/user-attachments/assets/9e84e90f-8107-4c9b-b478-23ad2da632cb" />

## Block Diagram

<img width="1893" height="903" alt="Screenshot 2025-08-09 140851" src="https://github.com/user-attachments/assets/f43d95a3-38f9-4d19-a1f0-9dacdc62bb1d" />

## Utilization

<img width="632" height="261" alt="image" src="https://github.com/user-attachments/assets/576bb79a-32da-4f11-a9b4-c98d1c1b4613" />

## Example Results

| Input Image | Result Image |
|-------------|--------------|
| ![canyon_512](https://github.com/user-attachments/assets/b0f36204-ad30-4f53-a093-c8c53ff24914) | ![result_image (2)](https://github.com/user-attachments/assets/d40396a6-113e-4d24-aaaf-2ba8a79968d1) |


| Input Image | Result Image | 
|-------------|--------------|
| ![building_512](https://github.com/user-attachments/assets/c60748cc-11c5-4420-9a95-2a84e2fb2239) | ![result_image (1)](https://github.com/user-attachments/assets/d428269b-8e91-46e9-8f49-f52b891cd594) |

| Input Image | Result Image | 
|-------------|--------------|
| ![town_bmp](https://github.com/user-attachments/assets/7a467f76-a99e-4641-a100-4847a4cb1220) | ![result_image (3)](https://github.com/user-attachments/assets/ca11bccb-6931-4683-bf0f-45437cea2bee) |


---

## Tools & Technologies

- Xilinx Vivado 2023.2 (Synthesis & Implementation)
- Xilinx Vitis 2023.2 for Software coding and FPGA programming
- ZedBoard FPGA (Zynq-7000)  
- Python for algorithm analysis and Look-Up Table Generation
- MATLAB for algorithm analysis
- MATLAB Simulink, HDL Coder
- Tera Term for Serial Communication with PC via UART
  
---

## Future Work

- Optimize fixed-point dynamic range  
- Add gamma correction and contrast enhancement  
- Real-time camera input
- Video Processing

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

## License

**BSD 3-Clause License**  
You are free to fork, contribute, and build upon this project under the terms of the [BSD 3-Clause License](https://opensource.org/licenses/BSD-3-Clause).


---

## About

**Hardware Accelerator Design | February–July 2025**  
Designed a complete image dehazing pipeline based on the Dark Channel Prior algorithm using pipelined Verilog modules, optimized for fixed-point hardware on FPGA.
