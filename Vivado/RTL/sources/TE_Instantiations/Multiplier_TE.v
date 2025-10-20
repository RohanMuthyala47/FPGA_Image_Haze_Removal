// Compute Pc * 1/Ac
(* use_dsp = "yes" *)
module Multiplier_TE (
    input        clk,
    
    input  [7:0] Fc,     // Filtered Pixel Value
    input  [9:0] Inv_Ac, // Scaled Inverted Atmospheric Light value in Fixed Point Q0.10
    
    output [9:0] product // min(Pc / Ac) ; c ∈ {R, G, B} in Fixed Point Q0.10
);

    reg [12:0] result_upper_P, result_lower_P;
    
    always @(posedge clk) begin
        result_lower_P  <= Fc * Inv_Ac[4:0];
        result_upper_P  <= Fc * Inv_Ac[9:5];
    end
    
    assign product = (result_upper_P[4:0] << 5) + result_lower_P;
            
endmodule
