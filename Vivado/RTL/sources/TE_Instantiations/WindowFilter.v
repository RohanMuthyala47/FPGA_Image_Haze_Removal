module WindowFilter (
    input  [1:0] window_edge,   // Window type: 
                                //   0 = No edge
                                //   1 = Vertical/Horizontal edge
                                //   2 = Diagonal edge

    // 3x3 input pixel window
    input  [7:0] input_pixel_1, input_pixel_2, input_pixel_3,
                 input_pixel_4, input_pixel_5, input_pixel_6,
                 input_pixel_7, input_pixel_8, input_pixel_9,

    // Filtered output pixel
    output [7:0] filtered_pixel
);

    //==================================================================
    // Internal wires for intermediate summations
    //==================================================================
    wire [11:0] sum1, sum2, sum3;  // Row-wise weighted sums (12 bits wide)
    wire [12:0] sum;               // Final accumulated sum (13 bits wide)

    //==================================================================
    // Weight assignment based on edge type
    //==================================================================
    // Shifting is used instead of multiplication for efficiency.
    //   w_corner: Weight applied to corner pixels
    //   w_edge  : Weight applied to edge pixels
    //   w_center: Weight applied to the center pixel
    //==================================================================
    wire [1:0] w_edge, w_corner, w_center;

    assign w_edge   = (window_edge == 2) ? 0 :    // No edge contribution for diagonal case
                      (window_edge == 1) ? 1 :    // Weight=1 for H/V edge
                      0;                          // Default=0

    assign w_corner = (window_edge == 2) ? 1 :    // Weight=1 for diagonal edge
                      (window_edge == 1) ? 0 :    // No contribution for H/V edge
                      0;                          // Default=0

    assign w_center = (window_edge != 0) ? 2 :    // Stronger weight (shift by 2) if edge is detected
                      0;                          // Default=0

    //==================================================================
    // Weighted pixel summation
    //==================================================================
    // Each input pixel is shifted left by its assigned weight, effectively
    // scaling its contribution in the accumulation process.
    // sum1: Top row
    // sum2: Middle row
    // sum3: Bottom row
    //==================================================================
    assign sum1 = (input_pixel_1 << w_corner) + 
                  (input_pixel_2 << w_edge)   + 
                  (input_pixel_3 << w_corner);

    assign sum2 = (input_pixel_4 << w_edge)   + 
                  (input_pixel_5 << w_center) + 
                  (input_pixel_6 << w_edge);

    assign sum3 = (input_pixel_7 << w_corner) + 
                  (input_pixel_8 << w_edge)   + 
                  (input_pixel_9 << w_corner);

    // Final weighted sum of all contributions
    assign sum = sum1 + sum2 + sum3;

    //==================================================================
    // Normalization
    //==================================================================
    // Normalization ensures the output pixel remains in the valid 8-bit
    // range after weighting. Different normalization is applied based 
    // on whether an edge is detected or not:
    //
    //   Case 1: Edge detected (window_edge != 0)
    //           -> Normalize by right-shifting sum by 4 (divide by 16).
    //
    //   Case 2: No edge (window_edge == 0, mean filter mode)
    //           -> Approximate division by 9 using shift-based formula:
    //              (sum >> 3) - (sum >> 6)
    //              This approximates sum / 9 without explicit division.
    //==================================================================
    assign filtered_pixel = (window_edge != 0) ? 
                            (sum >> 4) :                  // Edge case normalization
                            ((sum >> 3) - (sum >> 6));    // Mean filter approximation

endmodule
