module Saturation_Correction_Multiplier (
    input  [7:0] x1,       // Ac
    input  [7:0] x2,       // Jc
    output [7:0] result    // Final unsigned 8-bit result
);

    // Q8.8 * Q8.8 = Q16.16
    wire [31:0] mult_result = x1 * x2;

    // Convert Q16.16 to Q8.8
    wire [15:0] q8_8_result = mult_result[23:8];

    assign result = (q8_8_result[15:8] > 8'd255) ? 8'd255 : q8_8_result[15:8];

endmodule
