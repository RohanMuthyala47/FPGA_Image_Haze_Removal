module Multiplier_SRSC (
    input        clk,
    
    input  [7:0] Ic_minus_Ac, // 8-bit value
    input  [7:0] Inv_Trans,   // Fixed Point Q2.6
    
    output [7:0] result       // 8-bit result
);
    
    // Pipeline Registers
    reg [7:0] Ic_minus_Ac_P;
    reg [7:0] Inv_Trans_P;
    
    (* use_dsp = "yes" *)
    wire [15:0] product;
    
    always @(posedge clk) begin
        Ic_minus_Ac_P <= Ic_minus_Ac;
        Inv_Trans_P <= Inv_Trans; 
    end
    
    assign product = Ic_minus_Ac_P * Inv_Trans_P;  //Q10.6
    
    wire [9:0] scaled_product = product[15:6];
    // Scale down to 8-bit result
    assign result = (scaled_product[9:8]) ? 8'd255 : scaled_product[7:0];
    
endmodule
