module FilterWeights_Estimation (
    input [7:0] input_pixel_1, input_pixel_2, input_pixel_3,
                input_pixel_4,                input_pixel_6,
                input_pixel_7, input_pixel_8, input_pixel_9,
    
    output      w_corner, w_edge, w_center
);
    
    parameter THRESHOLD = 8'd80; // Threshold Value to detect edges
    
    assign w_corner = ((input_pixel_1 > input_pixel_9 ? input_pixel_1 - input_pixel_9 : input_pixel_9 - input_pixel_1) >= THRESHOLD) |
                      ((input_pixel_3 > input_pixel_7 ? input_pixel_3 - input_pixel_7 : input_pixel_7 - input_pixel_3) >= THRESHOLD);
    
    assign w_edge   = ((input_pixel_4 > input_pixel_6 ? input_pixel_4 - input_pixel_6 : input_pixel_6 - input_pixel_4) >= THRESHOLD) |
                      ((input_pixel_2 > input_pixel_8 ? input_pixel_2 - input_pixel_8 : input_pixel_8 - input_pixel_2) >= THRESHOLD);
    
    assign w_center = w_corner | w_edge;
    
endmodule
