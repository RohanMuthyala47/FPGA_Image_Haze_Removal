// Compute Ac^β * Jc^(1-β)
module Saturation_Correction_Multiplier (
    input clk, rst, 
    input  [15:0] x1,       // Q3.13 format
    input  [15:0] x2,       // Q6.10 format
    output  [7:0] result    // Unsigned 8-bit output
);
    
    reg [31:0] product;
    
    always @(posedge clk) begin
        if(rst)
            product <= 0;
        else
            product <= x1 * x2;
    end
    
    // Scale down to 8 bit value
    assign result = product[30:23];
    
endmodule
