// Compute Ac^Î² * Jc^(1-Î²)
module Saturation_Correction_Multiplier (
    input clk, rst, 
    input   [9:0] Ac,       // Q3.7 format
    input   [9:0] Jc,       // Q6.4 format
    output  [7:0] Corrected_Pixel    // Unsigned 8-bit output
);
    
    reg [9:0] Ac_P, Jc_P;
    
    wire [19:0] product;
    
    always @(posedge clk) begin
            Ac_P <= Ac;
            Jc_P <= Jc;
    end
    
    assign product = Ac_P * Jc_P; // Q9.11

    // Scale down to 8 bit value
    assign Corrected_Pixel = product[18:11];
    
endmodule
