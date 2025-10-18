// Compute ω * Pc / Ac
module Multiplier_TE (
    input        clk,
    
    input  [7:0] Fc,     // Filter result
    input  [9:0] Inv_Ac, // Scaled Inverted Atmospheric Light value in Q0.10 format (ω * 1/Ac) 
    
    output [9:0] product // ω * min(Pc / Ac) ; c ∈ {R, G, B} in Q0.10 format
);
    
    // Pipeline registers
    reg [7:0] Fc_P;
    reg [9:0] Inv_Ac_P;
    
    (* use_dsp = "yes" *)
    wire [17:0] result;
    
    always @(posedge clk) begin
        Fc_P <= Fc;
        Inv_Ac_P <= Inv_Ac;
    end
    
    assign result = Fc_P * Inv_Ac_P;    //Q8.10
    // Scale down to Fixed Point Q0.10
    assign product = result[9:0];
            
endmodule
