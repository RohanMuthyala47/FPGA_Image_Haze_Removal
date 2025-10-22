// Compute Ac^0.3 * Jc^0.7
(* use_dsp = "yes" *)
module Saturation_Correction_Multiplier (
    input         clk,
    input   [9:0] Ac,       // Q3.7 format
    input   [9:0] Jc,       // Q6.4 format
    output  [7:0] Corrected_Pixel    // Unsigned 8-bit output
);
    
    reg [7:0] Ac_P;
    reg [9:0] Jc_P;
    
    wire [17:0] product;
    
    always @(posedge clk) begin
        Ac_P <= Ac[9:2];
        Jc_P <= Jc;
    end
    
    assign product = Ac_P * Jc_P; //Q9.9
    // Scale down to 8 bit value
    assign Corrected_Pixel = product[16:9];
    
endmodule
