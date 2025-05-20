module adder(
    input [24:0]x,
    input [15:0]y,

    output [24:0]out_add
    );
    
    assign out_add=x+{9'b000000000,y};
endmodule