module ED (
    input input_valid,
    input  [7:0] input_pixel_1, input_pixel_2, input_pixel_3,
                 input_pixel_4,                input_pixel_6,
                 input_pixel_7, input_pixel_8, input_pixel_9,
    
    output [1:0] ED_out
);
    parameter DIAGONAL_EDGE = 2'b10, 
              VERTICAL_HORIZONTAL_EDGE = 2'b01, 
              NO_EDGE = 2'b00;
    
    parameter THRESHOLD = 80; // Threshold Value for Edge Detection
    
    wire [7:0] diagonal1, diagonal2, horizontal, vertical;
    wire       cond1, cond2;
    
    // Calculate absolute differences for edge detection
    assign diagonal1  = (input_pixel_1 > input_pixel_9) ? (input_pixel_1 - input_pixel_9) : (input_pixel_9 - input_pixel_1);
    assign diagonal2  = (input_pixel_3 > input_pixel_7) ? (input_pixel_3 - input_pixel_7) : (input_pixel_7 - input_pixel_3);
    assign horizontal = (input_pixel_4 > input_pixel_6) ? (input_pixel_4 - input_pixel_6) : (input_pixel_6 - input_pixel_4);
    assign vertical   = (input_pixel_2 > input_pixel_8) ? (input_pixel_2 - input_pixel_8) : (input_pixel_8 - input_pixel_2);
    
    // Check if diagonal or vertical/horizontal edges exceed threshold
    assign cond1 = (diagonal1 >= THRESHOLD) || (diagonal2 >= THRESHOLD);
    assign cond2 = (horizontal >= THRESHOLD) || (vertical >= THRESHOLD);
    
    assign ED_out = cond1 ? DIAGONAL_EDGE : 
                    cond2 ? VERTICAL_HORIZONTAL_EDGE : 
                            NO_EDGE;
    
endmodule
