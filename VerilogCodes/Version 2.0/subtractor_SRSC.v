module sub(
    input [7:0]a,
    input[7:0] b, 
    
    output [8:0]out
    );

    assign out=(a>=b)?{1'b0,a-b}:{1'b1,b-a};
endmodule