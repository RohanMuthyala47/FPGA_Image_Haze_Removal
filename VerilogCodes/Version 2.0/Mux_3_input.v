module Mux_1(
    input [7:0] a,b,c,
    input [1:0]sel,
    
    output [7:0] out
    );
    
    assign out = (sel == 2'b00) ? a : 
                          (sel == 2'b01) ? b : 
                          (sel == 2'b10) ? c : 
                          8'b0 ;
    
endmodule

module Mux_2(
    input [8:0] a,b,c,
    input [1:0]sel,
    
    output [8:0] out
    );
    
    assign out = (sel == 2'b00) ? a : 
                          (sel == 2'b01) ? b : 
                          (sel == 2'b10) ? c : 
                          9'b0 ;
    
endmodule