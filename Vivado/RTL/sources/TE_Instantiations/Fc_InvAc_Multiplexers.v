// Multiplexer to choose minimum Filtered Pixel Value
module Fc_Multiplexer (
    input  [7:0] F_R, F_G, F_B,
    input  [1:0] sel,
    
    output [7:0] Fc
);
    
    assign Fc = (sel == 2'b00) ? F_R : 
                (sel == 2'b01) ? F_G : 
                (sel == 2'b10) ? F_B : 
                0;
    
endmodule

// Multiplexer to choose minimum Atmospheric Light Value
module Inv_Ac_Multiplexer (
    input  [9:0] Inv_AR, Inv_AG, Inv_AB,
    input  [1:0]  sel,
    
    output [9:0] Inv_Ac
);
    
    assign Inv_Ac = (sel == 2'b00) ? Inv_AR : 
                    (sel == 2'b01) ? Inv_AG : 
                    (sel == 2'b10) ? Inv_AB : 
                    0;
    
endmodule
