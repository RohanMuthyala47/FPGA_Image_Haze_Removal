Real-Time Image Haze Removal on FPGA (ZedBoard)
An FPGA-accelerated implementation of a haze removal algorithm using pipelined Verilog modules with UART BMP image I/O and fixed-point math.

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)

Overview
This project presents a hardware-accelerated real-time image dehazing pipeline, fully implemented in Verilog and synthesized on a Xilinx ZedBoard FPGA (Zynq-7000). The goal is to achieve high-performance image dehazing using a custom pipelined architecture based on the Dark Channel Prior and Scene Radiance Recovery methods, optimized for fixed-point arithmetic and real-time throughput.

The pipeline processes BMP images sent via UART, performs dehazing across multiple stages, and outputs the reconstructed haze-free image back to the host.

Motivation
Hazy or foggy images reduce visibility and impair vision-based applications in autonomous vehicles, surveillance, and outdoor robotics. Real-time haze removal is computationally expensive on traditional CPUs. Therefore, we design a dedicated hardware accelerator to:

Achieve parallel processing

Support stream-based pipelining

Enable on-chip real-time dehazing

Reduce latency compared to software-based dehazing

Algorithm Overview
The pipeline implements a hardware-efficient version of the dark channel prior-based dehazing algorithm, inspired by the IEEE TCSVT paper:
"Hardware Implementation of a Fast and Efficient Haze Removal Method".

Key Steps:
Dark Channel Prior Estimation

Atmospheric Light Estimation

Transmission Estimation

Scene Radiance Recovery

Hardware Architecture
The pipeline consists of the following Verilog modules:

1. WindowGenerator
Generates a 3×3 RGB window from a video stream using line buffers. Extracts local regions of pixels for morphological operations.

4 line buffers for storing previous rows

Outputs 9 pixels in parallel (in1 to in9)

Used in both DCP and TE stages

2. DarkChannel
Computes the minimum intensity among RGB values across a 3x3 neighborhood.

Performs per-pixel min(R, G, B)

Then computes spatial min using a comparator tree

Output: grayscale dark channel pixel

3. ALE (Atmospheric Light Estimation)
Estimates the global atmospheric light from the dark channel.

Accumulates the brightest 0.1% pixels

Calculates inverse of A for transmission estimation

Fully pipelined and streamed

4. TE (Transmission Estimation)
Estimates the amount of haze (transmission map) at each pixel using the formula:
t(x) = 1 - ω * min(min(R, G, B)) / A

Uses fixed-point arithmetic (Q0.16)

ω = 0.95 implemented as a constant

Computes pixel-wise t(x)

5. SRSC (Scene Radiance and Scaling Correction)
Recovers the haze-free pixel intensities:
J(x) = (I(x) - A) / max(t(x), t0) + A

Handles division using reciprocal lookup

Ensures t(x) ≥ t0 = 0.1 (Q0.16)

Performs all math in fixed-point

Outputs final RGB image

6. TE_and_SRSC
A 10-stage pipelined Verilog module that combines both transmission estimation and scene radiance recovery in a single processing core.

Increases throughput by avoiding staging delay

Maintains per-pixel data flow with valid signals

7. Top Module
The complete top-level module connecting:

Register_Bank → DarkChannel → ALE → TE_and_SRSC

Valid signal flow control

Input: RGB pixel stream

Output: Dehazed RGB pixel stream

8. Top_TB (Testbench)
Reads a BMP file, extracts pixel data, drives the dehazing pipeline, and writes the output BMP file with haze removed.

Uses $fread and $fwrite for binary BMP I/O

Handles BMP header + padding

Simulates full dataflow operation

Features
✅ 3×3 sliding window for local filtering
✅ Dark channel estimation with comparator trees
✅ Fixed-point implementation of divisions and multiplications
✅ Transmission floor (t₀) control
✅ Full pipelined datapath (10 stages)
✅ Synthesizable on ZedBoard
✅ UART-based image transfer (BMP format)
✅ Modular, scalable Verilog design
✅ Verified using waveform simulations and image output

Fixed-Point Arithmetic
Format used: Q0.16 (16-bit unsigned/signed)

Reciprocal implemented as:
recip_t = 2^16 / t

Signed adders and clamping logic used for final pixel restoration

Testing and Simulation
All modules are tested using ModelSim and GTKWave.

Testbench Capabilities:
BMP file input (input.bmp)

Header parsed and preserved

Writes dehazed output.bmp

Verification done using waveform inspection and visual image output

UART I/O on ZedBoard
Custom serial protocol

BMP image streamed via UART to FPGA

Pixels processed in real-time

Output image streamed back to PC

Future UART Enhancements:
Use FIFO buffers to improve dataflow

AXI UART interface for embedded Linux integration

Results
Original Image	Dehazed Output

Drastic visibility improvement in foggy regions

Preserved contrast and color balance

Edge enhancement due to haze suppression

Tools & Technologies
Verilog HDL

ModelSim / Vivado Simulation

Xilinx Vivado for synthesis and implementation

ZedBoard FPGA (Zynq-7000)

UART for serial communication

GTKWave for waveform analysis

Future Work
Optimize fixed-point dynamic range

Add gamma correction and contrast stretching

Real-time camera integration via HDMI or CMOS sensor

AXI4-Lite and DMA integration for memory-mapped image buffers

Convert to SystemVerilog with assertions and coverage

Add AXI-stream support for SDSoC or Vitis HLS integration

References
He, Kaiming, Jian Sun, and Xiaoou Tang.
"Single image haze removal using dark channel prior."
IEEE Transactions on Pattern Analysis and Machine Intelligence (TPAMI), 2011

📜 License
MIT License – feel free to fork, contribute, and build on this project.
