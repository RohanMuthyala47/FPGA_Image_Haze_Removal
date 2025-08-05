module Multiplier(
   input  [15:0] Ac_Inv, // Inverted Atmospheric Light value in Q0.16 format
   input  [7:0]  Pc,     // Edge Detection Filter result
   output [15:0] product // OMEGA * min(Pc / Ac) ; c ∈ {R, G, B} in Q0.16 format
);

   parameter [15:0] MAX_OUTPUT = 16'd47513;   // (1 - 0.275) = 0.725 in Q0.16

   // Unscaled result is in Q8.16 format
   wire [23:0] unscaled_product = Ac_Inv * Pc;

   // Scale the result with OMEGA
   wire [27:0] pre_scaled_product = (unscaled_product << 4) - unscaled_product;
   wire [23:0] scaled_product = pre_scaled_product >> 4;

   // Trim the product down to Q0.16 format
   wire [15:0] result = scaled_product[15:0];

   // Check if the unscaled product is greater than 1 to prevent roll around due to negative result in the Subtractor module
   wire is_gt_one = (unscaled_product[23:16] != 0);

   // Clamp output to 0.75 if overflow occurred
   assign product = is_gt_one ? MAX_OUTPUT : result;

endmodule
