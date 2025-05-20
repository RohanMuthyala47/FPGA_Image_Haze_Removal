module Multiplier(
    input [8:0] a,
    input [7:0] b,
    
    output [20:0] product
    );
    
    assign product = (a * b *15) >> 8;
    
endmodule