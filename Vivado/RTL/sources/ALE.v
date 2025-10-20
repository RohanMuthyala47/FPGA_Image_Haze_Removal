// Atmospheric Light Estimation Module
`define Image_Size (512 * 512)
module ALE (
    input            clk, rst,
    
    input            input_valid,                                 // Input data valid signal
    input     [23:0] input_pixel_1, input_pixel_2, input_pixel_3,
                     input_pixel_4, input_pixel_5, input_pixel_6,
                     input_pixel_7, input_pixel_8, input_pixel_9, // 3x3 window input
    
    output reg [7:0] A_R,
    output reg [7:0] A_G,
    output reg [7:0] A_B,      // Atmospheric Light Values
    
    output reg [9:0] Inv_A_R,
    output reg [9:0] Inv_A_G,
    output reg [9:0] Inv_A_B,  // Inverse Atmospheric Light Values (Q0.14)
    
    output reg       ALE_done  // Signal to indicate entire image has been processed
);

    reg [17:0] pixel_counter;
    
    // Keep track of the number of pixels processed through the module
    always @(posedge clk) begin
        if (rst)
            pixel_counter <= 0;
        if (input_valid)
            pixel_counter <= pixel_counter + 1;
    end
    
    always @(posedge clk) begin
        if (rst)
            ALE_done <= 0;
        if(pixel_counter == (`Image_Size - 1))
            ALE_done <= 1;    // All pixels have been processed through the ALE module
    end
    
    // Minimum of 9 - R/G/B channels
    wire [7:0] minimum_red, minimum_green, minimum_blue;
    
    // Pipeline Registers (Stage 1)
    reg [7:0]  minimum_red_P, minimum_green_P, minimum_blue_P;
    
    always @(posedge clk) begin
        minimum_red_P   <= minimum_red;
        minimum_green_P <= minimum_green;
        minimum_blue_P  <= minimum_blue;
    end

    // Dark channel pixel value
    wire [7:0] Dark_channel;
    
    // Pipeline Registers (Stage 2)
    reg [7:0]  Dark_channel_P;
    
    wire [7:0] Dark_channel_Red, Dark_channel_Green, Dark_channel_Blue;
    
    assign Dark_channel_Red   = (Dark_channel > Dark_channel_P) ? minimum_red_P   : A_R;
    assign Dark_channel_Green = (Dark_channel > Dark_channel_P) ? minimum_green_P : A_G;
    assign Dark_channel_Blue  = (Dark_channel > Dark_channel_P) ? minimum_blue_P  : A_B;
    
    // LUT outputs
    wire [9:0] LUT_Inv_AR, LUT_Inv_AG, LUT_Inv_AB;
    
    always @(posedge clk) begin
        if(rst)
            Dark_channel_P <= 0;
        else
            Dark_channel_P <= (Dark_channel > Dark_channel_P) ? Dark_channel : Dark_channel_P;
    end
    
    always @(posedge clk) begin
        A_R <= Dark_channel_Red;
        A_G <= Dark_channel_Green;
        A_B <= Dark_channel_Blue;
            
        Inv_A_R <= LUT_Inv_AR;
        Inv_A_G <= LUT_Inv_AG;
        Inv_A_B <= LUT_Inv_AB;
    end

    /////////////////////////////////////////////////////////////////////////////////
    // BLOCK INSTANCES
    /////////////////////////////////////////////////////////////////////////////////

    // Find the minimum of each of the color channel inputs
    ALE_Minimum_9 Min_Red (
        .input_pixel_1(input_pixel_1[23:16]), .input_pixel_2(input_pixel_2[23:16]), .input_pixel_3(input_pixel_3[23:16]),
        .input_pixel_4(input_pixel_4[23:16]), .input_pixel_5(input_pixel_5[23:16]), .input_pixel_6(input_pixel_6[23:16]),
        .input_pixel_7(input_pixel_7[23:16]), .input_pixel_8(input_pixel_8[23:16]), .input_pixel_9(input_pixel_9[23:16]),
        
        .minimum_pixel(minimum_red)
    );
    
    ALE_Minimum_9 Min_Green (
        .input_pixel_1(input_pixel_1[15:8]), .input_pixel_2(input_pixel_2[15:8]), .input_pixel_3(input_pixel_3[15:8]),
        .input_pixel_4(input_pixel_4[15:8]), .input_pixel_5(input_pixel_5[15:8]), .input_pixel_6(input_pixel_6[15:8]),
        .input_pixel_7(input_pixel_7[15:8]), .input_pixel_8(input_pixel_8[15:8]), .input_pixel_9(input_pixel_9[15:8]),
        
        .minimum_pixel(minimum_green)
    );
    
    ALE_Minimum_9 Min_Blue (
        .input_pixel_1(input_pixel_1[7:0]), .input_pixel_2(input_pixel_2[7:0]), .input_pixel_3(input_pixel_3[7:0]),
        .input_pixel_4(input_pixel_4[7:0]), .input_pixel_5(input_pixel_5[7:0]), .input_pixel_6(input_pixel_6[7:0]),
        .input_pixel_7(input_pixel_7[7:0]), .input_pixel_8(input_pixel_8[7:0]), .input_pixel_9(input_pixel_9[7:0]),
        
        .minimum_pixel(minimum_blue)
    );
    
    // Calculate minimum among the three channels to get Dark Channel
    ALE_Minimum_3 Dark_Channel_Pixel (
        .R(minimum_red_P),
        .G(minimum_green_P), 
        .B(minimum_blue_P),
        
        .minimum(Dark_channel)
    );
    
    // Look-Up Tables to output the reciprocal of the Atmospheric Light values in Q0.12 format
    Atmospheric_Light_Reciprocal_LUT Red_Atmospheric_Light_Reciprocal_LUT (
        .in(Dark_channel_Red),
        
        .out(LUT_Inv_AR)
    );
    
    Atmospheric_Light_Reciprocal_LUT Green_Atmospheric_Light_Reciprocal_LUT (
        .in(Dark_channel_Green),
        
        .out(LUT_Inv_AG)
    );
    
    Atmospheric_Light_Reciprocal_LUT Blue_Atmospheric_Light_Reciprocal_LUT (
        .in(Dark_channel_Blue),
        
        .out(LUT_Inv_AB)
    );
    
endmodule
