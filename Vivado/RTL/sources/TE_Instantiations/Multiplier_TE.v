// Compute ω * Pc / Ac
module Multiplier_TE (
    input         clk,
    input         rst,
    
    input  [7:0]  Fc,     // Filter result
    input  [15:0] Inv_Ac, // Scaled Inverted Atmospheric Light value in Q0.16 format (ω * 1/Ac) 
    
    output [13:0] product // ω * min(Pc / Ac) ; c ? {R, G, B} in Q0.14 format
);
    
    // Pipeline registers
    reg [21:0] result_P;
    
    // Pipeline inputs to reduce fan-out
    always @(posedge clk) begin
        if(rst) begin
            result_P <= 0;
        end
        else begin
            result_P <= Fc * Inv_Ac[15:2]; // Q8.14
        end
    end
    
    assign product = result_P[13:0]; // Scale down to Q0.14 and eliminate overflow
    
endmodule
