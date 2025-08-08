// Edge Preserving Filter applied when Diagonal Edges are detected
module Block_P2 (
    input  [7:0] in1,
    input  [7:0] in2,
    input  [7:0] in3,
    input  [7:0] in4,
    input  [7:0] in5,
    input  [7:0] in6,
    input  [7:0] in7,
    input  [7:0] in8,
    input  [7:0] in9,
    
    output [7:0] p2_result
);
    
    reg [10:0] sum1, sum2, sum3;
    
    always @(*) begin
        sum1 <= (in1 << 1) + (in2) + (in3 << 1);
        sum2 <= (in4) + (in5 << 2) + (in6);
        sum3 <= (in7 << 1) + (in8) + (in9 << 1);
    end
    
    assign p2_result = (sum1 + sum2 + sum3) >> 4;
    
endmodule
