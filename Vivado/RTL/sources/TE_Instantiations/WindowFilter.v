module WindowFilter (
    input        w_corner, w_edge, w_center,
    input  [7:0] input_pixel_1, input_pixel_2, input_pixel_3,
                 input_pixel_4, input_pixel_5, input_pixel_6,
                 input_pixel_7, input_pixel_8, input_pixel_9,
    output [7:0] filtered_pixel
);

    wire [11:0] sum1, sum2, sum3;
    wire [12:0] sum;
    wire [9:0]  mean_sum;

    // Weighted sums
    assign sum1 = (input_pixel_1 << w_corner) + (input_pixel_2 << w_edge) + (input_pixel_3 << w_corner);
    assign sum2 = (input_pixel_4 << w_edge) + (input_pixel_5 << (w_center << 1)) + (input_pixel_6 << w_edge);
    assign sum3 = (input_pixel_7 << w_corner) + (input_pixel_8 << w_edge) + (input_pixel_9 << w_corner);

    assign sum = sum1 + sum2 + sum3;
    
    assign mean_sum = sum >> 3;

    // Normalization
    assign filtered_pixel = (w_center) ? (sum >> 4) : ((mean_sum) - (mean_sum >> 3));

endmodule
