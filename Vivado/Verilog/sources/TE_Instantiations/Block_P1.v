// Edge Preserving Filter applied when Vertical and Horizontal edges are detected
module Block_P1 (
    input  [7:0] in1,
    input  [7:0] in2,
    input  [7:0] in3,
    input  [7:0] in4,
    input  [7:0] in5,
    input  [7:0] in6,
    input  [7:0] in7,
    input  [7:0] in8,
    input  [7:0] in9,
    
    output [7:0] p1_result
);
    
    reg [10:0] sum1, sum2, sum3;
    
    always @(*) begin
        sum1 <= (in1) + (in2 << 1) + (in3);
        sum2 <= (in4 << 1) + (in5 << 2) + (in6 << 1);
        sum3 <= (in7) + (in8 << 1) + (in9);
    end
    
    assign p1_result = (sum1 + sum2 + sum3) >> 4;
    
endmodule
