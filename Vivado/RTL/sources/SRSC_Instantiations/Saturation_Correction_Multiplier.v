// Compute Ac^β * Jc^(1-β)
module Saturation_Correction_Multiplier (
    input         clk, rst, 
    input  [11:0] x1,       // Q3.9 format
    input  [11:0] x2,       // Q6.6 format
    output [7:0]  result    // *-bit result
);
    
    reg [11:0] x1_P, x2_P;
    
    wire [23:0] product;
    
    always @(posedge clk) begin
            x1_P <= x1;
            x2_P <= x2;
    end
    
    assign product = x1_P * x2_P; // Q9.15
    
    // Scale down to 8 bit value
    assign result = (product[23:15] > 8'd255) ? 8'd255 : product[22:15];
    
endmodule
