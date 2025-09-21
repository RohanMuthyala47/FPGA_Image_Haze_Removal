// Compute ω * Pc / Ac
module Multiplier_TE (
    input         clk,
    input         rst,
    
    input  [7:0]  Fc,     // Filter result
    input  [13:0] Inv_Ac, // Scaled Inverted Atmospheric Light value in Q0.14 format (ω * 1/Ac) 
    
    output [9:0] product // ω * min(Pc / Ac) ; c ∈ {R, G, B} in Q0.10 format
);
    
    // Pipeline registers
    reg [21:0] result_P;

    // Pipeline STage
    always @(posedge clk) begin
        if(rst) begin
            result_P <= 0;
        end
        else begin
            result_P <= Fc * Inv_Ac; // Q8.14
        end
    end
    
    assign product = result_P[13:4]; // Scale down to Q0.10 and eliminate overflow
    
endmodule
