module FilterWeights_Estimation_Top (
    input [23:0] input_pixel_1, input_pixel_2, input_pixel_3,
                 input_pixel_4,                input_pixel_6,
                 input_pixel_7, input_pixel_8, input_pixel_9,
    
    output       corner_pixels_weight, edge_pixels_weight, center_pixel_weight
);
    
    wire red_w_corner,   red_w_edge,   red_w_center,
         green_w_corner, green_w_edge, green_w_center,
         blue_w_corner,  blue_w_edge,  blue_w_center;
    
    FilterWeights_Estimation FilterWeights_Estimation_Red (
        .input_pixel_1(input_pixel_1[23:16]), .input_pixel_2(input_pixel_2[23:16]), .input_pixel_3(input_pixel_3[23:16]),
        .input_pixel_4(input_pixel_4[23:16]),                                       .input_pixel_6(input_pixel_6[23:16]),
        .input_pixel_7(input_pixel_7[23:16]), .input_pixel_8(input_pixel_8[23:16]), .input_pixel_9(input_pixel_9[23:16]),
        
        .w_corner(red_w_corner), .w_edge(red_w_edge), .w_center(red_w_center)
    );
        
    FilterWeights_Estimation FilterWeights_Estimation_Green (
        .input_pixel_1(input_pixel_1[15:8]), .input_pixel_2(input_pixel_2[15:8]), .input_pixel_3(input_pixel_3[15:8]),
        .input_pixel_4(input_pixel_4[15:8]),                                      .input_pixel_6(input_pixel_6[15:8]),
        .input_pixel_7(input_pixel_7[15:8]), .input_pixel_8(input_pixel_8[15:8]), .input_pixel_9(input_pixel_9[15:8]),
        
        .w_corner(green_w_corner), .w_edge(green_w_edge), .w_center(green_w_center)
    );
        
    FilterWeights_Estimation FilterWeights_Estimation_Blue (
        .input_pixel_1(input_pixel_1[7:0]), .input_pixel_2(input_pixel_2[7:0]), .input_pixel_3(input_pixel_3[7:0]),
        .input_pixel_4(input_pixel_4[7:0]),                                     .input_pixel_6(input_pixel_6[7:0]),
        .input_pixel_7(input_pixel_7[7:0]), .input_pixel_8(input_pixel_8[7:0]), .input_pixel_9(input_pixel_9[7:0]),
        
        .w_corner(blue_w_corner), .w_edge(blue_w_edge), .w_center(blue_w_center)
    );
    
    assign corner_pixels_weight = (red_w_corner | green_w_corner | blue_w_corner);
    
    assign edge_pixels_weight = (red_w_edge | green_w_edge | blue_w_edge);
    
    assign center_pixel_weight = (red_w_center | green_w_center | blue_w_center);
    
endmodule
