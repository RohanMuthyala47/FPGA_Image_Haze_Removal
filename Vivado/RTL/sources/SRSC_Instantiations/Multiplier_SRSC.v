(* use_dsp = "yes" *)
module Multiplier_SRSC (
    input        clk,
    
    input  [7:0] Ic_minus_Ac, // 8-bit value
    input  [7:0] Inv_Trans,   // Q2.6 
    
    output reg [7:0] product  // Q8.0 
);
    
    // Pipeline registers
    reg [7:0]   Ic_minus_Ac_P;
    reg [7:0]   Inv_Trans_P;
    
    wire [15:0] result; // Q10.6
    
    always @(posedge clk) begin
        Ic_minus_Ac_P <= Ic_minus_Ac;
        Inv_Trans_P   <= Inv_Trans; 
    end
    
    assign result = Ic_minus_Ac_P * Inv_Trans_P; // Q10.6
    
    always @(posedge clk) begin
        // Check for overflow: if any bit above [13:6] is set 
        if (|result[15:14]) begin 
            product <= 8'd255;  // Saturate to max  
        end else begin  
            product <= result[13:6]; // Extract Q8.0 from Q10.6 
        end
    end
    
endmodule
