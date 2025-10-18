/**
 * @file Image_HazeRemoval.v
 * @brief Top-level module for real-time image haze removal processing
 * @description This module implements a complete haze removal pipeline using atmospheric
 *              scattering models. The system processes streaming video data through AXI4-Stream
 *              interfaces and performs atmospheric light estimation, transmission map calculation,
 *              and scene radiance recovery with saturation correction.
 * 
 * @author Rohan M.
 * @date 15th July 2025
 * @version 1.0
 * 
 * Key Features:
 * - AXI4-Stream compliant interfaces for seamless integration
 * - 3x3 sliding window processing for local atmospheric analysis
 * - Two-stage processing: Atmospheric Light Estimation (ALE) followed by 
 *   Transmission Estimation and Scene Recovery (TE_SRSC)
 * - Power optimization through selective clock gating
 * - Real-time processing capability for video streams
 * 
 * Processing Pipeline:
 * 1. Input pixels buffered into 3x3 sliding windows
 * 2. Atmospheric light estimation across entire image
 * 3. Transmission map estimation and scene recovery per window
 * 4. Saturation correction for enhanced output quality
 */

module Image_HazeRemoval (
    //==================================================================================
    // AXI4-Stream Global Clock and Reset Signals
    //==================================================================================
    input         ACLK,          /**< Global system clock for AXI4-Stream interface */
    input         ARESETn,       /**< Active-low global reset signal */
    
    //==================================================================================
    // System Control Signals
    //==================================================================================
    input         enable,        /**< IP core enable signal - set to 1'b1 for normal operation
                                      Allows external control of processing pipeline */
    
    //==================================================================================
    // AXI4-Stream Slave Interface (Input Side)
    // Receives incoming pixel data stream
    //==================================================================================
    input [31:0]  S_AXIS_TDATA,  /**< Input pixel data stream
                                      [31:24] - Reserved/unused bits
                                      [23:16] - Red channel (8-bit)
                                      [15:8]  - Green channel (8-bit)
                                      [7:0]   - Blue channel (8-bit) */
    input         S_AXIS_TVALID, /**< Input data valid signal - indicates valid pixel data */
    // input         S_AXIS_TLAST,  /**< End of line/frame marker (unused in this implementation) */
    output        S_AXIS_TREADY, /**< Input ready signal - indicates readiness to accept data */
    
    //==================================================================================
    // AXI4-Stream Master Interface (Output Side)  
    // Transmits processed (haze-removed) pixel data
    //==================================================================================
    output [31:0] M_AXIS_TDATA,  /**< Output pixel data stream (same format as input)
                                      Contains dehazed RGB pixel values */
    output        M_AXIS_TVALID, /**< Output data valid signal */
    // output        M_AXIS_TLAST,  /**< End of line/frame marker (unused) */
    input         M_AXIS_TREADY  /**< Output ready signal from downstream module */
);
    
    //==================================================================================
    // Internal Clock Signals
    //==================================================================================
    wire IP_CLK;                 /**< Gated internal processing clock derived from ACLK */
    
    //==================================================================================
    // AXI4-Stream Flow Control
    // Simple pass-through ready signal - system is ready when downstream is ready
    //==================================================================================
    assign S_AXIS_TREADY = M_AXIS_TREADY;

    //==================================================================================
    // 3x3 Sliding Window Pixel Data
    // Represents a 3x3 neighborhood around the current pixel being processed
    // Essential for local atmospheric analysis and spatial filtering
    //==================================================================================
    wire [23:0] Pixel_00, Pixel_01, Pixel_02;  /**< Top row of 3x3 window (left to right) */
    wire [23:0] Pixel_10, Pixel_11, Pixel_12;  /**< Middle row - Pixel_11 is center pixel */
    wire [23:0] Pixel_20, Pixel_21, Pixel_22;  /**< Bottom row of 3x3 window */
    
    wire window_valid;           /**< Indicates when 3x3 window contains valid data
                                      Accounts for border conditions and initialization */

    //==================================================================================
    // 3x3 Sliding Window Generator Instance
    // Buffers incoming pixel stream and generates overlapping 3x3 windows
    // Uses line buffers to maintain spatial relationships
    //==================================================================================
    WindowGeneratorTop WindowGenerator (
        .clk(IP_CLK),                           // Internal gated clock
        .rst(~ARESETn),                         // Active-high reset
        
        // Input: Single pixel from stream
        .input_pixel(S_AXIS_TDATA[23:0]),       // Extract RGB channels only
        .input_is_valid(S_AXIS_TVALID & S_AXIS_TREADY), // Valid when both sides ready
        
        // Output: 3x3 window of pixels
        .output_pixel_1(Pixel_00), .output_pixel_2(Pixel_01), .output_pixel_3(Pixel_02),
        .output_pixel_4(Pixel_10), .output_pixel_5(Pixel_11), .output_pixel_6(Pixel_12),
        .output_pixel_7(Pixel_20), .output_pixel_8(Pixel_21), .output_pixel_9(Pixel_22),
        .output_is_valid(window_valid)          // Window validity signal
    );
    
    //==================================================================================
    // Atmospheric Light Estimation (ALE) Control Signals
    // ALE runs first to determine global atmospheric light parameters
    //==================================================================================
    wire ALE_clk;                /**< Gated clock for ALE module */
    wire ALE_done;               /**< ALE completion flag - high when estimation complete */
    wire ALE_enable = ~ALE_done; /**< ALE enable logic - runs until completion */

    //==================================================================================
    // Atmospheric Light Parameters
    // Global atmospheric light values for each RGB channel
    // Used in atmospheric scattering model: I = J*t + A*(1-t)
    //==================================================================================
    wire [7:0] A_R, A_G, A_B;    /**< Atmospheric light RGB values (0-255) */
    wire [9:0] Inv_AR, Inv_AG, Inv_AB; /**< Inverse atmospheric light values
                                              Pre-calculated for division optimization
                                              Fixed-point format for hardware efficiency */

    //==================================================================================
    // Atmospheric Light Estimation Module Instance
    // Analyzes entire image to estimate atmospheric light parameters
    // Uses dark channel prior and brightest pixel analysis
    //==================================================================================
    ALE ALE (
        .clk(ALE_clk),                          // Dedicated gated clock
        .rst(~ARESETn),                         // Active-low reset
        
        // Input: 3x3 pixel windows for analysis
        .input_valid(window_valid),
        .input_pixel_1(Pixel_00), .input_pixel_2(Pixel_01), .input_pixel_3(Pixel_02),
        .input_pixel_4(Pixel_10), .input_pixel_5(Pixel_11), .input_pixel_6(Pixel_12),
        .input_pixel_7(Pixel_20), .input_pixel_8(Pixel_21), .input_pixel_9(Pixel_22),
        
        // Output: Estimated atmospheric light parameters
        .A_R(A_R), .A_G(A_G), .A_B(A_B),       // Direct atmospheric light values
        .Inv_A_R(Inv_AR), .Inv_A_G(Inv_AG), .Inv_A_B(Inv_AB), // Inverse values for optimization
        
        .ALE_done(ALE_done)                     // Completion signal
    );

    //==================================================================================
    // Transmission Estimation and Scene Recovery Control Signals  
    // TE_SRSC runs after ALE completion using estimated atmospheric parameters
    //==================================================================================
    wire TE_SRSC_clk;            /**< Gated clock for TE_SRSC module */
    wire TE_SRSC_enable = ALE_done; /**< Enable TE_SRSC only after ALE completes */
    
    //==================================================================================
    // Output Pixel Data
    // Final processed RGB values after haze removal
    //==================================================================================
    wire [7:0] J_R, J_G, J_B;    /**< Recovered scene radiance (dehazed RGB values) */
    wire output_valid;           /**< Output validity signal */
    
    // Pack output RGB into AXI4-Stream format (upper 8 bits unused)
    assign M_AXIS_TDATA = {8'd0000_0000, J_R, J_G, J_B};
    
    //==================================================================================
    // Transmission Estimation, Scene Recovery and Saturation Correction Instance
    // Core processing module that performs the actual haze removal
    // Uses atmospheric scattering model inversion: J = (I - A) / t + A
    //==================================================================================
    TE_and_SRSC TE_SRSC (
        .clk(TE_SRSC_clk),                      // Dedicated gated clock
        .rst(~ARESETn),                         // Active-low reset
        
        // Input: 3x3 pixel windows for processing
        .input_valid(window_valid),
        .input_pixel_1(Pixel_00), .input_pixel_2(Pixel_01), .input_pixel_3(Pixel_02),
        .input_pixel_4(Pixel_10), .input_pixel_5(Pixel_11), .input_pixel_6(Pixel_12),
        .input_pixel_7(Pixel_20), .input_pixel_8(Pixel_21), .input_pixel_9(Pixel_22),
        
        // Atmospheric light parameters from ALE
        .A_R(A_R), .A_G(A_G), .A_B(A_B),       // Direct values for computation
        .Inv_AR(Inv_AR), .Inv_AG(Inv_AG), .Inv_AB(Inv_AB), // Inverse values for optimization
        
        // Output: Processed pixel data
        .J_R(J_R), .J_G(J_G), .J_B(J_B),       // Dehazed RGB values
        .output_valid(M_AXIS_TVALID)            // Output validity (connected to AXI)
    );

    //==================================================================================
    // POWER OPTIMIZATION: CLOCK GATING CELLS
    // Selective clock gating reduces dynamic power consumption by disabling
    // clock trees when modules are not actively processing
    //==================================================================================

    /**
     * @brief Clock gating for Atmospheric Light Estimation
     * ALE only needs to run during initial image analysis phase
     * Once atmospheric parameters are estimated, ALE can be clock-gated off
     */
    Clock_Gating_Cell ALE_CGC (
        .clk(IP_CLK),                           // Source clock
        .clk_enable(ALE_enable),                // Enable during estimation phase
        .rst(~ARESETn),                         // Reset control
        .clk_gated(ALE_clk)                     // Gated output clock
    );
    
    /**
     * @brief Clock gating for Transmission Estimation and Scene Recovery
     * TE_SRSC only runs after ALE completes and atmospheric parameters are available
     * This sequential operation allows for significant power savings
     */
    Clock_Gating_Cell TE_SRSC_CGC (
        .clk(IP_CLK),                           // Source clock  
        .clk_enable(TE_SRSC_enable),            // Enable after ALE completion
        .rst(~ARESETn),                         // Reset control
        .clk_gated(TE_SRSC_clk)                 // Gated output clock
    );

    /**
     * @brief Master clock gating for entire IP core
     * Allows external disable of entire processing pipeline
     * Useful for power management and system-level control
     */
    Clock_Gating_Cell Core_Enable (
        .clk(ACLK),                             // System clock input
        .clk_enable(enable),                    // External enable signal
        .rst(~ARESETn),                         // Reset control
        .clk_gated(IP_CLK)                      // Internal processing clock
    );
    
endmodule

//==========================================================================================
// CLOCK GATING CELL IMPLEMENTATION
// Provides glitch-free clock gating for power optimization
//==========================================================================================

/**
 * @brief Glitch-free clock gating cell for power optimization
 * @description Implements a standard clock gating cell that safely enables/disables
 *              clock signals without introducing glitches. Uses a latch to ensure
 *              enable signal changes only occur during clock low periods.
 * 
 * @param clk         Input clock signal to be gated
 * @param clk_enable  Enable control signal (active high)
 * @param rst         Reset signal (active high)  
 * @param clk_gated   Output gated clock signal
 * 
 * Operation:
 * - When clk_enable is high, clk_gated follows clk
 * - When clk_enable is low, clk_gated is held low
 * - Enable changes are latched on positive clock edge to prevent glitches
 * - Reset forces latch to disabled state
 * 
 * Power Benefits:
 * - Reduces dynamic power consumption when modules are idle
 * - Eliminates unnecessary clock tree switching activity
 * - Maintains timing closure and signal integrity
 */
module Clock_Gating_Cell (
    input  clk,        /**< Input clock to be gated */
    input  clk_enable, /**< Clock enable control signal */
    input  rst,        /**< Active-high reset signal */
    
    output clk_gated   /**< Gated output clock */
);
    
    //==================================================================================
    // Enable Latch Register
    // Captures enable signal on positive clock edge to ensure glitch-free operation
    //==================================================================================
    reg latch;  /**< Enable signal latch - prevents glitches during enable transitions */
    
    /**
     * @brief Enable signal latching logic
     * Synchronizes enable changes to clock edge to prevent glitches
     * Reset takes priority and forces latch to disabled state
     */
    always @(posedge clk) begin
        if (rst)
            latch <= 1'b0;      // Reset forces clock gating off
        else
            latch <= clk_enable; // Latch enable signal on clock edge
    end

    //==================================================================================
    // Clock Gating Logic  
    // AND gate provides actual clock gating - only passes clock when latch is high
    // Since latch changes are synchronized to clock edges, output is glitch-free
    //==================================================================================
    assign clk_gated = latch & clk;

endmodule
