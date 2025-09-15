module WindowFilter (
    input  [1:0] window_edge,
    input  [7:0] input_pixel_1, input_pixel_2, input_pixel_3,
                 input_pixel_4, input_pixel_5, input_pixel_6,
                 input_pixel_7, input_pixel_8, input_pixel_9,
    output [7:0] filtered_pixel
);

    wire [11:0] sum1, sum2, sum3;
    wire [12:0] sum;

    // Weights based on edge type
    wire [1:0] w_edge, w_corner, w_center;
                             
    assign w_edge = (window_edge == 2) ? 0 :
                    (window_edge == 1) ? 1 :
                    0;
    assign w_corner = (window_edge == 2) ? 1 :
                      (window_edge == 1) ? 0 :
                      0;
    assign w_center = (window_edge != 0) ? 2 : 0;

    // Weighted sums
    assign sum1 = (input_pixel_1 << w_corner) + (input_pixel_2 << w_edge) + (input_pixel_3 << w_corner);
    assign sum2 = (input_pixel_4 << w_edge) + (input_pixel_5 << w_center) + (input_pixel_6 << w_edge);
    assign sum3 = (input_pixel_7 << w_corner) + (input_pixel_8 << w_edge) + (input_pixel_9 << w_corner);

    assign sum = sum1 + sum2 + sum3;

    // Normalization
    assign filtered_pixel = (window_edge != 0) ? (sum >> 4) : ((sum >> 3) - (sum >> 6));

endmodule
