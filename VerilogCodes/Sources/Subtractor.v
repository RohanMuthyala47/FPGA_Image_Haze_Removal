//module Subtractor(
//    input [15:0] a,
//    output [15:0] diff
//);
//    parameter [16:0] One = 17'd65536;
//    parameter [15:0] T0 = 16'd16383;
    
//    assign diff = (a < 16'd49152) ? One - a : T0;
//endmodule

module Subtractor(
    input [15:0] a,      // Q0.16 format input
    output [15:0] diff   // Q0.16 format output
);
    parameter signed [16:0] One = 17'd65535;        // 1.0 in Q0.16 (use 17-bit to prevent overflow)
    parameter [15:0] T0_min = 16'd16384;            // 0.25 in Q0.16 (minimum clamp)
    
    // Use signed arithmetic to handle negative results properly
    wire signed [16:0] temp_diff = One - {1'b0, a}; // Extend 'a' to 17-bit unsigned
    
    assign diff = (temp_diff <= $signed({1'b0, T0_min})) ? T0_min :    // If result <= 0.25, clamp to 0.25
                  temp_diff[15:0];                                     // Otherwise, take lower 16 bits
    
endmodule
