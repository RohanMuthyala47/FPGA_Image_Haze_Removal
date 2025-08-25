module Multiplier_SRSC (
    input        clk, rst,
    
    input  [7:0] Ic_minus_Ac, // Q8.0
    input [15:0] Inv_Trans,   // Q2.14
    
    output [7:0] result       // Q8.0
);
    
    reg  [7:0] Ic_minus_Ac_P;
    reg [15:0] Inv_Trans_P;
    
    always @(posedge clk) begin
        if(rst) begin
            Ic_minus_Ac_P <= 0;
            Inv_Trans_P <= 0;
        end
        else begin
            Ic_minus_Ac_P <= Ic_minus_Ac;
            Inv_Trans_P <= Inv_Trans;
        end
    end
    
    // Q8.0 * Q2.14 = Q10.14
    wire [23:0] mult_result = Ic_minus_Ac_P * Inv_Trans_P;
    
    // Scale down to 8-bit range
    wire [9:0] scaled_result = mult_result[23:14];
    
    assign result = (scaled_result > 255) ? 8'd255 : scaled_result;

endmodule
