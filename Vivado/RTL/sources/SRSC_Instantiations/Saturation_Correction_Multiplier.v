// Compute Ac^β * Jc^(1-β)
module Saturation_Correction_Multiplier (
    input        clk,
    input  [9:0] Ac,              // Fixed Point Q3.7 format
    input  [9:0] Jc,              // Fixed Point Q6.4 format
    output [7:0] Corrected_Pixel  // Unsigned 8-bit output
);

    // Pipeline Registers
    reg [9:0] Ac_P, Jc_P;
    
    (* use_dsp = "yes" *)
    wire [19:0] product;
    
    always @(posedge clk) begin
        Ac_P <= Ac;
        Jc_P <= Jc;
    end
    
    assign product = Ac_P * Jc_P;
    // Scale down to 8 bit value
    assign Corrected_Pixel = (product[19]) ? 8'd255 : product[18:11];
    
endmodule
