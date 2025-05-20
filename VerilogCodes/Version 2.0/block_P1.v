module block_P1(
    input  wire [7:0] in1,
    input  wire [7:0] in2,
    input  wire [7:0] in3,
    input  wire [7:0] in4,
    input  wire [7:0] in5,
    input  wire [7:0] in6,
    input  wire [7:0] in7,
    input  wire [7:0] in8,
    input  wire [7:0] in9,
    
    output wire [7:0] p1_result
    );
    
    wire [15:0] sum;
    assign sum = in1 + (in2 * 2) + in3 + (in4 * 2) + (in5 * 4) + (in6 * 2) + in7 + (in8 * 2) + in9;
    
    assign p1_result = sum/16;
    
    endmodule