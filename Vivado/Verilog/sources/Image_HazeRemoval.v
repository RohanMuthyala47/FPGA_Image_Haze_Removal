// Top Module 
module Image_HazeRemoval (
    // AXI4-Stream Global Signals
    input         ACLK,          // Global clock 
    input         ARESETn,       // Global reset signal
    
    // Enable Signal
    input         enable,        // IP enable signal set to constant 1 for operation
    
    // AXI4-Stream Slave Interface
    input [31:0]  S_AXIS_TDATA,  // Input pixel stream
    input         S_AXIS_TVALID, // Input valid signal
    // input         S_AXIS_TLAST,  // Unused signal
    output        S_AXIS_TREADY,
    
    // AXI4-Stream Master Interface
    output [31:0] M_AXIS_TDATA,  // Output pixel stream
    output        M_AXIS_TVALID, // Output valid signal
    // output        M_AXIS_TLAST,  // Unused signal
    input         M_AXIS_TREADY
);
    
    wire IP_CLK;
    
    assign S_AXIS_TREADY = M_AXIS_TREADY;

    // 3x3 Window of RGB pixels generated from Line Buffers
    wire [23:0] Pixel_00, Pixel_01, Pixel_02;
    wire [23:0] Pixel_10, Pixel_11, Pixel_12;
    wire [23:0] Pixel_20, Pixel_21, Pixel_22;
    
    // Window valid signal
    wire window_valid;

    // Instance of 3x3 Window Generator
    WindowGeneratorTop WindowGenerator (
        .clk(IP_CLK),
        .rst(~ARESETn),
        
        .input_pixel(S_AXIS_TDATA[23:0]),
        .input_is_valid(S_AXIS_TVALID & S_AXIS_TREADY),
        
        .output_pixel_1(Pixel_00), .output_pixel_2(Pixel_01), .output_pixel_3(Pixel_02),
        .output_pixel_4(Pixel_10), .output_pixel_5(Pixel_11), .output_pixel_6(Pixel_12),
        .output_pixel_7(Pixel_20), .output_pixel_8(Pixel_21), .output_pixel_9(Pixel_22),
        .output_is_valid(window_valid)
    );
    
    wire ALE_clk;
    wire ALE_done;
    wire ALE_enable = ~ALE_done;

    wire [7:0] A_R, A_G, A_B;
    wire [15:0] Inv_AR, Inv_AG, Inv_AB;

    // Instance of Atmospheric Light Estimation
    ALE ALE (
        .clk(ALE_clk),
        .rst(~ARESETn),
        
        .input_valid(window_valid),
        .input_pixel_1(Pixel_00), .input_pixel_2(Pixel_01), .input_pixel_3(Pixel_02),
        .input_pixel_4(Pixel_10), .input_pixel_5(Pixel_11), .input_pixel_6(Pixel_12),
        .input_pixel_7(Pixel_20), .input_pixel_8(Pixel_21), .input_pixel_9(Pixel_22),
        
        .A_R(A_R), .A_G(A_G), .A_B(A_B),
        
        .Inv_A_R(Inv_AR), .Inv_A_G(Inv_AG), .Inv_A_B(Inv_AB),
        
        .ALE_done(ALE_done)
    );

    wire TE_SRSC_clk;
    wire TE_SRSC_enable = ALE_done;
    
    // Output Signals
    wire [7:0] J_R, J_G, J_B;
    wire output_valid;
    assign M_AXIS_TDATA = {8'd0, J_R, J_G, J_B};
    
    // Instance of Transmission Estimation, Scene Recovery and Saturation Correction
    TE_and_SRSC TE_SRSC (
        .clk(TE_SRSC_clk),
        .rst(~ARESETn),
        
        .input_valid(window_valid),
        .input_pixel_1(Pixel_00), .input_pixel_2(Pixel_01), .input_pixel_3(Pixel_02),
        .input_pixel_4(Pixel_10), .input_pixel_5(Pixel_11), .input_pixel_6(Pixel_12),
        .input_pixel_7(Pixel_20), .input_pixel_8(Pixel_21), .input_pixel_9(Pixel_22),
        
        .A_R(A_R), .A_G(A_G), .A_B(A_B),
        
        .Inv_AR(Inv_AR), .Inv_AG(Inv_AG), .Inv_AB(Inv_AB),
        
        .J_R(J_R), .J_G(J_G), .J_B(J_B),
        .output_valid(M_AXIS_TVALID)
    );

    ///////////////////////////////////////////////////////////////////////////////////////////////////
    // Clock Gating Cells
    ///////////////////////////////////////////////////////////////////////////////////////////////////

    // Image Haze Removal Core enable
    Clock_Gating_Cell Core_Enable (
        .clk(ACLK),
        .clk_enable(enable),
        .rst(~ARESETn),
        
        .clk_gated(IP_CLK)
    );

    // ALE module enable
    Clock_Gating_Cell ALE_CGC (
        .clk(IP_CLK),
        .clk_enable(ALE_enable),
        .rst(~ARESETn),
        
        .clk_gated(ALE_clk)
    );

    // TE and SRSC module enable
    Clock_Gating_Cell TE_SRSC_CGC (
        .clk(IP_CLK),
        .clk_enable(TE_SRSC_enable),
        .rst(~ARESETn),
        
        .clk_gated(TE_SRSC_clk)
    );

endmodule

///////////////////////////////////////////////////////////////////////////////////////////////////
// Clock Gating Module to reduce Power Consumption
///////////////////////////////////////////////////////////////////////////////////////////////////

module Clock_Gating_Cell (
    input  clk,
    input  clk_enable,
    input  rst,
    
    output clk_gated
);
    
    reg latch;
    
    always @(posedge clk) begin
        if (rst)
            latch <= 1'b0;
        else
            latch <= clk_enable;
    end

    assign clk_gated = latch & clk;

endmodule
