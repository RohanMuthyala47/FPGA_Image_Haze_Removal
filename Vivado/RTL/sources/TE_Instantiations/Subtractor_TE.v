// Compute T(x) = 1 - ω * min(Pc / Ac)
module Subtractor_TE (
    input  [13:0] in, // ω * min(Pc / Ac) : c ∈ {R, G, B}
    
    output [13:0] out // Transmission value in Q0.14
);
    
    parameter [13:0] ONE = 16'd16383; // 0.999.... = 1.0 in Q0.14 format
    parameter [13:0] T0  = 16'd5734; // Lower bound for transmission = 0.325 in Q0.14 format
    parameter [13:0] MAX_T  = ONE - T0; // ONE - T0 = 0.675 in Q0.14 format
    
    assign out = (in > MAX_T) ?  T0 : ONE - in;
    
endmodule
