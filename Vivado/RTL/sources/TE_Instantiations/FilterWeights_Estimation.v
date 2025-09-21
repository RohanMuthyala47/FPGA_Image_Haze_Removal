module FilterWeights_Estimation (
    input  [7:0] input_pixel_1, input_pixel_2, input_pixel_3,
                 input_pixel_4,                input_pixel_6,
                 input_pixel_7, input_pixel_8, input_pixel_9,
    
    output       w_corner, w_edge, w_center
);
    
    parameter  THRESHOLD = 80; // Threshold Value for Edge Detection
    
    wire [7:0] diagonal1, diagonal2, horizontal, vertical;
    wire       d_edge_detected, h_v_edge_detected;
    
    // Calculate absolute differences for edge detection
    assign diagonal1  = (input_pixel_1 > input_pixel_9) ? (input_pixel_1 - input_pixel_9) : (input_pixel_9 - input_pixel_1);
    assign diagonal2  = (input_pixel_3 > input_pixel_7) ? (input_pixel_3 - input_pixel_7) : (input_pixel_7 - input_pixel_3);
    assign horizontal = (input_pixel_4 > input_pixel_6) ? (input_pixel_4 - input_pixel_6) : (input_pixel_6 - input_pixel_4);
    assign vertical   = (input_pixel_2 > input_pixel_8) ? (input_pixel_2 - input_pixel_8) : (input_pixel_8 - input_pixel_2);
    
    // Check if diagonal or vertical/horizontal edges exceed threshold
    assign d_edge_detected   = (diagonal1 >= THRESHOLD) || (diagonal2 >= THRESHOLD);
    assign h_v_edge_detected = (horizontal >= THRESHOLD) || (vertical >= THRESHOLD);
    
    assign w_corner = d_edge_detected;
                      
    assign w_edge = h_v_edge_detected;
                      
    assign w_center = (d_edge_detected | h_v_edge_detected);
    
endmodule
