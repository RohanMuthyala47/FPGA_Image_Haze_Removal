module Subtractor_SRSC (
    input [7:0]  Ic,
    input [7:0]  Ac, 
    
    output [7:0] Ic_minus_Ac,   // |Ic - Ac|
    output       add_or_sub     // Add with or subtract from Atmospheric Light in the Adder module
);
    
    localparam ADD = 1, SUB = 0;
    
    assign Ic_minus_Ac = (Ic > Ac) ? (Ic - Ac) : (Ac - Ic);
    
    assign add_or_sub = (Ic > Ac) ? ADD : SUB;
    
endmodule
