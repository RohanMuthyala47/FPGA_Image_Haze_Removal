// Mean Filter applied when no edges are detected
module Block_P0 (
    input  [7:0] in1,
    input  [7:0] in2,
    input  [7:0] in3,
    input  [7:0] in4,
    input  [7:0] in5,
    input  [7:0] in6,
    input  [7:0] in7,
    input  [7:0] in8,
    input  [7:0] in9,
    
    output [7:0] p0_result
);
    
    reg [9:0] sum1, sum2, sum3;
    
    always @(*) begin
        sum1 <= in1 + in2 + in3;
        sum2 <= in4 + in5 + in6;
        sum3 <= in7 + in8 + in9;
    end
    
    assign p0_result = (sum1 + sum2 + sum3) / 9;
    
endmodule
