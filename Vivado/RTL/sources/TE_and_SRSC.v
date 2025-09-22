// Transmission Estimation, Scene Recovery and Saturation Correction Module
`define Image_Size (512 * 512)
module TE_and_SRSC (
    input        clk,
    input        rst,
    
    input        input_valid,                                 // Input data valid signal
    input [23:0] input_pixel_1, input_pixel_2, input_pixel_3,
                 input_pixel_4, input_pixel_5, input_pixel_6,
                 input_pixel_7, input_pixel_8, input_pixel_9, // 3x3 window input
    
    input  [7:0] A_R, A_G, A_B,                               // Atmospheric Light Values
    input [13:0] Inv_AR, Inv_AG, Inv_AB,                      // Inverse Atmospheric Light Values(Q0.14)

    output [7:0] J_R, J_G, J_B,                               // Output corrected pixels
    output       output_valid                                 // Output data valid signal
);

    // Pipeline the Center Pixel for SRSC
    reg [23:0] I_P, I_P1, I_P2, I_P3, I_P4;
    
    // Pipeline Atmospheric Light values for SRSC
    reg [7:0] A_R_P, A_G_P, A_B_P;
    reg [7:0] A_R_P1, A_G_P1, A_B_P1;
    reg [7:0] A_R_P2, A_G_P2, A_B_P2;
    reg [7:0] A_R_P3, A_G_P3, A_B_P3;
    reg [7:0] A_R_P4, A_G_P4, A_B_P4;
    
    //==================================================================================
    // STAGE 4 LOGIC
    //==================================================================================
    
    // Detect the type of edge in the 3x3 window
    wire       corner_pixels_weight, edge_pixels_weight, center_pixel_weight;
    
    // Pipeline Registers
    reg        corner_pixels_weight_P, edge_pixels_weight_P, center_pixel_weight_P;
    
    reg [13:0] Inv_AR_P, Inv_AG_P, Inv_AB_P;
    
    reg [23:0] I1_P, I2_P, I3_P,
               I4_P, I5_P, I6_P,
               I7_P, I8_P, I9_P;
               
    reg        stage_4_valid;
    
    //===========================================
    // Detect the type of edge in the 3x3 window
    FilterWeights_Estimation_Top Estimate_FilterWeights (
        .input_pixel_1(input_pixel_1), .input_pixel_2(input_pixel_2), .input_pixel_3(input_pixel_3),
        .input_pixel_4(input_pixel_4),                                .input_pixel_6(input_pixel_6), 
        .input_pixel_7(input_pixel_7), .input_pixel_8(input_pixel_8), .input_pixel_9(input_pixel_9),
        
        .corner_pixels_weight(corner_pixels_weight),
        .edge_pixels_weight(edge_pixels_weight),
        .center_pixel_weight(center_pixel_weight)
    );
    //===========================================
    
    // Update Stage 4 Pipeline Registers
    always @(posedge clk) begin
        if (rst) begin
            corner_pixels_weight_P <= 0;
            edge_pixels_weight_P   <= 0;
            center_pixel_weight_P  <= 0;
        
            I1_P <= 0; I2_P <= 0; I3_P <= 0;
            I4_P <= 0; I5_P <= 0; I6_P <= 0;
            I7_P <= 0; I8_P <= 0; I9_P <= 0;
                
            Inv_AR_P <= 0; Inv_AG_P <= 0; Inv_AB_P <= 0;
                    
            I_P <= 0;
            A_R_P <= 0; A_G_P <= 0; A_B_P <= 0;
                    
            stage_4_valid <= 0;
        end
        else begin
            corner_pixels_weight_P <= corner_pixels_weight;
            edge_pixels_weight_P   <= edge_pixels_weight;
            center_pixel_weight_P  <= center_pixel_weight;
        
            I1_P <= input_pixel_1; I2_P <= input_pixel_2; I3_P <= input_pixel_3;
            I4_P <= input_pixel_4; I5_P <= input_pixel_5; I6_P <= input_pixel_6;
            I7_P <= input_pixel_7; I8_P <= input_pixel_8; I9_P <= input_pixel_9;
                    
            Inv_AR_P <= Inv_AR; Inv_AG_P <= Inv_AG; Inv_AB_P <= Inv_AB;

            I_P <= input_pixel_5;
            A_R_P <= A_R; A_G_P <= A_G; A_B_P <= A_B;
                    
            stage_4_valid <= input_valid;
        end
    end
    
    //==================================================================================
    // STAGE 5 LOGIC
    //==================================================================================
    
    // ? = 15/16
    parameter OMEGA_D = 4;
    
    wire [7:0] filtered_pixel_red, filtered_pixel_green, filtered_pixel_blue;
    
    // Pipeline Registers
    reg [13:0] Inv_AR_P1, Inv_AG_P1, Inv_AB_P1;
    
    reg [7:0] filtered_pixel_red_P, filtered_pixel_green_P, filtered_pixel_blue_P;
    
    reg stage_5_valid;
    
    //===========================================
    // Filter blocks to apply Gaussian Filter or Mean Filter based on the edge detected
    WindowFilter Red_WindowFilter (
        .w_corner(corner_pixels_weight_P),
        .w_edge(edge_pixels_weight_P),
        .w_center(center_pixel_weight_P),
    
        .input_pixel_1(I1_P[23:16]), .input_pixel_2(I2_P[23:16]), .input_pixel_3(I3_P[23:16]),
        .input_pixel_4(I4_P[23:16]), .input_pixel_5(I5_P[23:16]), .input_pixel_6(I6_P[23:16]),
        .input_pixel_7(I7_P[23:16]), .input_pixel_8(I8_P[23:16]), .input_pixel_9(I9_P[23:16]),
        
        .filtered_pixel(filtered_pixel_red)
    );
                   
    WindowFilter Green_WindowFilter (
        .w_corner(corner_pixels_weight_P),
        .w_edge(edge_pixels_weight_P),
        .w_center(center_pixel_weight_P),

        .input_pixel_1(I1_P[15:8]), .input_pixel_2(I2_P[15:8]), .input_pixel_3(I3_P[15:8]),
        .input_pixel_4(I4_P[15:8]), .input_pixel_5(I5_P[15:8]), .input_pixel_6(I6_P[15:8]),
        .input_pixel_7(I7_P[15:8]), .input_pixel_8(I8_P[15:8]), .input_pixel_9(I9_P[15:8]),
        
        .filtered_pixel(filtered_pixel_green)
    );
                   
    WindowFilter Blue_WindowFilter (
        .w_corner(corner_pixels_weight_P),
        .w_edge(edge_pixels_weight_P),
        .w_center(center_pixel_weight_P),

        .input_pixel_1(I1_P[7:0]), .input_pixel_2(I2_P[7:0]), .input_pixel_3(I3_P[7:0]),
        .input_pixel_4(I4_P[7:0]), .input_pixel_5(I5_P[7:0]), .input_pixel_6(I6_P[7:0]),
        .input_pixel_7(I7_P[7:0]), .input_pixel_8(I8_P[7:0]), .input_pixel_9(I9_P[7:0]),
                       
        .filtered_pixel(filtered_pixel_blue)
    );
    //===========================================
    
    // Update Stage 5 Pipeline Registers 
    always @(posedge clk) begin
        if (rst) begin
            
            Inv_AR_P1 <= 0; Inv_AG_P1 <= 0; Inv_AB_P1 <= 0;
            
            filtered_pixel_red_P <= 0; filtered_pixel_green_P <= 0; filtered_pixel_blue_P <= 0;
            
            I_P1 <= 0;
            A_R_P1 <= 0; A_G_P1 <= 0; A_B_P1 <= 0;
            
            stage_5_valid <= 0;
        end
        else begin
            // Apply the scaling factor ? = 15/16 to the Inverse Atmospheric Light vValues
            Inv_AR_P1 <= Inv_AR_P - (Inv_AR_P >> OMEGA_D);
            Inv_AG_P1 <= Inv_AG_P - (Inv_AG_P >> OMEGA_D);
            Inv_AB_P1 <= Inv_AB_P - (Inv_AB_P >> OMEGA_D);
            
            filtered_pixel_red_P <= filtered_pixel_red;
            filtered_pixel_green_P <= filtered_pixel_green;
            filtered_pixel_blue_P <= filtered_pixel_blue;
                                
            I_P1 <= I_P;
                                
            A_R_P1 <= A_R_P; A_G_P1 <= A_G_P; A_B_P1 <= A_B_P;
                                
            stage_5_valid <= stage_4_valid;
        end
    end
    
    //==========================================================================
    // STAGE 6 LOGIC
    //==========================================================================
    
    // Select signal for minimum filter result
    wire  [1:0] min_val_sel;
    
    wire [7:0] min_Fc;
    
    wire [13:0] min_Ac;
        
    wire [9:0] product;
        
    // Compute (Ic - Ac)
    wire [7:0]  IR_minus_AR, IG_minus_AG, IB_minus_AB;
    wire        add_or_sub_R, add_or_sub_G, add_or_sub_B;
    wire [7:0]  I_R = I_P1[23:16], I_G = I_P1[15:8], I_B = I_P1[7:0];
        
    // Pipeline Registers for stage 6
    reg  [7:0]  IR_minus_AR_P, IG_minus_AG_P, IB_minus_AB_P;
    reg         add_or_sub_R_P, add_or_sub_G_P, add_or_sub_B_P;
    
    reg         stage_6_valid;
    
    //===========================================
    // Comparator to determine the minimum value of the filter results
    Comparator_Minimum Minimum_Filter_Select (
        .red(filtered_pixel_red_P), .green(filtered_pixel_green_P), .blue(filtered_pixel_blue_P),
        
        .min_val_sel(min_val_sel)
    );
    
    // Multiplexer to choose minimum of the filter results
    Fc_Multiplexer Minimum_Filtered_Pixel_Value (
        .F_R(filtered_pixel_red_P), .F_G(filtered_pixel_green_P), .F_B(filtered_pixel_blue_P),
        
        .sel(min_val_sel),
        
        .Fc(min_Fc)
    );
    
    // Multiplexer to choose minimum of Atmospheric Light values
    Inv_Ac_Multiplexer Minimum_Inv_ALE_Value (
        .Inv_AR(Inv_AR_P1), .Inv_AG(Inv_AG_P1), .Inv_AB(Inv_AB_P1),
        
        .sel(min_val_sel),
        
        .Inv_Ac(min_Ac)
    );
    
    // Multiplier modules to compute Fc * ?/Ac
    Multiplier_TE Fc_InvAc_Multiplier (
        .clk(clk), .rst(rst),
        
        .Fc(min_Fc),
        .Inv_Ac(min_Ac),
        
        .product(product)
    );
    
    // SUBTRACTOR MODULES TO COMPUTE (|Ic - Ac|)
    Subtractor_SRSC Sub_Red (
        .Ic(I_R),
        .Ac(A_R_P1),
            
        .Ic_minus_Ac(IR_minus_AR),
            
        .add_or_sub(add_or_sub_R)
    );
                    
    Subtractor_SRSC Sub_Green (
        .Ic(I_G),
        .Ac(A_G_P1),
            
        .Ic_minus_Ac(IG_minus_AG),
            
        .add_or_sub(add_or_sub_G)
    );
                
    Subtractor_SRSC Sub_Blue (
        .Ic(I_B),
        .Ac(A_B_P1),
            
        .Ic_minus_Ac(IB_minus_AB),
            
        .add_or_sub(add_or_sub_B)
    );
    //===========================================
    
    // Update Stage 6 Pipeline Registers
    always @(posedge clk) begin
        if (rst) begin
            I_P2 <= 0;
            
            A_R_P2 <= 0;
            A_G_P2 <= 0;
            A_B_P2 <= 0;
                        
            IR_minus_AR_P <= 0;
            IG_minus_AG_P <= 0;
            IB_minus_AB_P <= 0;
                        
            add_or_sub_R_P <= 0;
            add_or_sub_G_P <= 0;
            add_or_sub_B_P <= 0;

            stage_6_valid <= 0;
        end
        else begin
            I_P2 <= I_P1;
            
            A_R_P2 <= A_R_P1;
            A_G_P2 <= A_G_P1;
            A_B_P2 <= A_B_P1;
                        
            IR_minus_AR_P <= IR_minus_AR;
            IG_minus_AG_P <= IG_minus_AG;
            IB_minus_AB_P <= IB_minus_AB;
                       
            add_or_sub_R_P <= add_or_sub_R;
            add_or_sub_G_P <= add_or_sub_G;
            add_or_sub_B_P <= add_or_sub_B;
            
            stage_6_valid <= stage_5_valid;
        end
    end
    
    //==========================================================================
    // STAGE 7 LOGIC
    //==========================================================================
    
    wire [9:0] inverse_transmission;
    
    // Compute (|Ic-Ac|)*(1/T)
    wire [7:0]  IR_minus_AR_x_T, IG_minus_AG_x_T, IB_minus_AB_x_T;
    
    // Pipeline Registers for stage 7
    reg         add_or_sub_R_P1, add_or_sub_G_P1, add_or_sub_B_P1;
    
    reg         stage_7_valid;
    
    //===========================================
    // TRANSMISSION RECIPROCAL LOOKUP TABLE
    Transmission_Reciprocal_LUT Transmission_Reciprocal_LUT (
      .in(product),
                            
      .out(inverse_transmission)
    );
                    
    // MULTIPLIER MODULES TO COMPUTE (|Ic-Ac|)*(1/T)
    Multiplier_SRSC Multiplier_SRSC_Red (
      .clk(clk), .rst(rst),
            
      .Inv_Trans(inverse_transmission),
      .Ic_minus_Ac(IR_minus_AR_P),
            
      .result(IR_minus_AR_x_T)
    );
                            
    Multiplier_SRSC Multiplier_SRSC_Green (
      .clk(clk), .rst(rst),
            
      .Inv_Trans(inverse_transmission),
      .Ic_minus_Ac(IG_minus_AG_P),
            
      .result(IG_minus_AG_x_T)
    );
                        
    Multiplier_SRSC Multiplier_SRSC_Blue (
      .clk(clk), .rst(rst),
            
      .Inv_Trans(inverse_transmission),
      .Ic_minus_Ac(IB_minus_AB_P),
            
      .result(IB_minus_AB_x_T)
    );
    //===========================================
        
    // Update stage 7 pipeline registers
    always @(posedge clk) begin
        if (rst) begin
            I_P3 <= 0;
      
            A_R_P3 <= 0;
            A_G_P3 <= 0;
            A_B_P3 <= 0;

            add_or_sub_R_P1 <= 0;
            add_or_sub_G_P1 <= 0;
            add_or_sub_B_P1 <= 0;
        
            stage_7_valid <= 0;
        end
        else begin
            I_P3 <= I_P2;
      
            A_R_P3 <= A_R_P2;
            A_G_P3 <= A_G_P2;
            A_B_P3 <= A_B_P2;

            add_or_sub_R_P1 <= add_or_sub_R_P;
            add_or_sub_G_P1 <= add_or_sub_G_P;
            add_or_sub_B_P1 <= add_or_sub_B_P;
            
            stage_7_valid <= stage_6_valid;
        end
    end

    //==========================================================================
    // STAGE 8 LOGIC
    //==========================================================================
    
    // Pipeline Registers for stage 8
    reg [7:0]  Mult_Red_P, Mult_Green_P, Mult_Blue_P;
    
    reg        add_or_sub_R_P2, add_or_sub_G_P2, add_or_sub_B_P2;
    
    reg        stage_8_valid;
        
    // Update stage 8 pipeline registers
    always @(posedge clk) begin
      if (rst) begin
        A_R_P4 <= 0;
        A_G_P4 <= 0;
        A_B_P4 <= 0;
                
        I_P4 <= 0;
                
        add_or_sub_R_P2 <= 0;
        add_or_sub_G_P2 <= 0;
        add_or_sub_B_P2 <= 0;
                
        Mult_Red_P <= 0;
        Mult_Green_P <= 0;
        Mult_Blue_P <= 0;
                
        stage_8_valid <= 0;
      end
      else begin
        A_R_P4 <= A_R_P3;
        A_G_P4 <= A_G_P3;
        A_B_P4 <= A_B_P3;
                
        I_P4 <= I_P3;
                
        add_or_sub_R_P2 <= add_or_sub_R_P1;
        add_or_sub_G_P2 <= add_or_sub_G_P1;
        add_or_sub_B_P2 <= add_or_sub_B_P1;
                
        Mult_Red_P <= IR_minus_AR_x_T;
        Mult_Green_P <= IG_minus_AG_x_T;
        Mult_Blue_P <= IB_minus_AB_x_T;
                
        stage_8_valid <= stage_7_valid;
      end
    end
        
    //==========================================================================
    // STAGE 9 LOGIC
    //==========================================================================
        
    // Compute Ac +/- (|Ic-Ac|/T)
    wire [7:0] Sum_Red, Sum_Green, Sum_Blue;
        
    // Outputs of Look-Up Tables for Saturation Corection
    wire [9:0] J_R_Corrected, J_G_Corrected, J_B_Corrected;
    wire [9:0] A_R_Corrected, A_G_Corrected, A_B_Corrected;
    
    // Pipeline Registers for stage 9
    reg       stage_9_valid;
        
    //===========================================
    // ADDER BLOCKS TO COMPUTE Ac +/- (|Ic-Ac|/T)
    Adder_SRSC Add_Red (
      .Ac(A_R_P4),
      .Ic(I_P4[23:16]),
      .Multiplier_out(Mult_Red_P),
             
      .add_or_sub(add_or_sub_R_P2),
             
      .sum(Sum_Red)
    );
                             
    Adder_SRSC Add_Green (
      .Ac(A_G_P4),
      .Ic(I_P4[15:8]),
      .Multiplier_out(Mult_Green_P),
      
      .add_or_sub(add_or_sub_G_P2),
             
      .sum(Sum_Green)
    );
                             
    Adder_SRSC Add_Blue (
      .Ac(A_B_P4),
      .Ic(I_P4[7:0]),
      .Multiplier_out(Mult_Blue_P),
      
      .add_or_sub(add_or_sub_B_P2),
             
      .sum(Sum_Blue)
    );
        
    // LOOK-UP TABLES TO COMPUTE Ac ^ ? AND Jc ^ (1 - ?) (? = 0.3)
    LUT_03 A_R_Correction (
      .in(A_R_P4),
      .out(A_R_Corrected)
    );
        
    LUT_03 A_G_Correction (
      .in(A_G_P4),
      .out(A_G_Corrected)
    );
        
    LUT_03 A_B_Correction (
      .in(A_B_P4),
      .out(A_B_Corrected)
    );
    
    LUT_07 J_R_Correction (
      .in(Sum_Red),
      .out(J_R_Corrected)
    );
        
    LUT_07 J_G_Correction (
      .in(Sum_Green),
      .out(J_G_Corrected)
    );
        
    LUT_07 J_B_Correction (
      .in(Sum_Blue),
      .out(J_B_Corrected)
    );
    
    // MULTIPLIER MODULES TO COMPUTE Ac^? * Jc^(1-?)
    Saturation_Correction_Multiplier Saturation_Correction_Red (
      .clk(clk), .rst(rst),
      
      .Ac(A_R_Corrected), .Jc(J_R_Corrected),
      
      .Corrected_Pixel(J_R)
    );
    
    Saturation_Correction_Multiplier Saturation_Correction_Green (
      .clk(clk), .rst(rst),
            
      .Ac(A_G_Corrected), .Jc(J_G_Corrected),
            
      .Corrected_Pixel(J_G)
    );
    
    Saturation_Correction_Multiplier Saturation_Correction_Blue (
      .clk(clk), .rst(rst),
    
      .Ac(A_B_Corrected), .Jc(J_B_Corrected),
            
      .Corrected_Pixel(J_B)
    );
    //===========================================
        
    // Update stage 9 pipeline registers
    always @(posedge clk) begin
      if (rst) begin
        stage_9_valid <= 0;
      end
      else begin
        stage_9_valid <= stage_8_valid;
      end
    end
    
    // Stage 10 assignments
    assign output_valid = stage_9_valid;

endmodule
