// Compute ω * Pc / Ac
module Multiplier_TE (
    input         clk, rst,
    
    input  [15:0] Ac_Inv, // Scaled Inverted Atmospheric Light value in Q0.16 format (ω * 1/Ac) 
    input  [7:0]  Pc,     // Edge Detection Filter result
    
    output [13:0] product // ω * min(Pc / Ac) ; c ∈ {R, G, B} in Q0.16 format
);
    
    // Pipeline register
    reg [21:0] result_P;
    
    always @(posedge clk) begin
        if(rst) begin
            result_P <= 0;
        end
        else begin
            result_P <= Pc * Ac_Inv[15:2]; // Q8.14
        end
    end
    
    assign product = result_P[13:0]; // Scale down to Q0.14 and eliminate overflow
    
endmodule
