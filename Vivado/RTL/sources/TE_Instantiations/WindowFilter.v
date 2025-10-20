module WindowFilter (
    input        w_corner, w_edge, w_center,
    
    input  [7:0] input_pixel_1, input_pixel_2, input_pixel_3,
                 input_pixel_4, input_pixel_5, input_pixel_6,
                 input_pixel_7, input_pixel_8, input_pixel_9,
    
    output [7:0] filtered_pixel
);

    wire [8:0] sum1, sum2, sum3, sum4;
    
    wire [10:0] corner_pixels_sum, edge_pixels_sum;
    
    wire [12:0] sum;

    // Weighted sums
    assign sum1 = input_pixel_1 + input_pixel_3;
    assign sum2 = input_pixel_7 + input_pixel_9;
    
    assign corner_pixels_sum = (sum1 + sum2) << w_corner;
    
    assign sum3 = input_pixel_2 + input_pixel_4;
    assign sum4 = input_pixel_6 + input_pixel_8;
    
    assign edge_pixels_sum = (sum3 + sum4) << w_edge;
    
    assign sum = corner_pixels_sum + edge_pixels_sum + (input_pixel_5 << (w_center << 1));

    // Normalization
    assign filtered_pixel = (w_center) ? (sum >> 4) : ((sum[12:3]) - (sum[12:6]));

endmodule
