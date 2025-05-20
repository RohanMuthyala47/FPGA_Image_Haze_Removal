module multiplier_SRSC(
    input [8:0]p,
    input[15:0]q,
    
    output [24:0]out_mul
    );
    assign out_mul=p*q;
endmodule