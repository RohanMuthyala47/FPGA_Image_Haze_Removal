// Mean Filter applied when no edges are detected
module Block_P0 (
    input        clk, rst, 
    
    input  [7:0] in1, in2, in3,
                 in4, in5, in6,
                 in7, in8, in9,
    
    output [7:0] p0_result
);
    
    // Pipeline Registers
    reg   [7:0] in1_P, in2_P, in3_P, 
                in4_P, in5_P, in6_P, 
                in7_P, in8_P, in9_P;
    
    wire  [9:0] sum1, sum2, sum3;
    wire [11:0] sum;
    
    always @(posedge clk) begin
        if(rst) begin
            in1_P <= 0; in2_P <= 0; in3_P <= 0;
            in4_P <= 0; in5_P <= 0; in6_P <= 0;
            in7_P <= 0; in8_P <= 0; in9_P <= 0;
        end
        else begin
            in1_P <= in1; in2_P <= in2; in3_P <= in3;
            in4_P <= in4; in5_P <= in5; in6_P <= in6;
            in7_P <= in7; in8_P <= in8; in9_P <= in9;
        end
    end

    assign sum1 = in1_P + in2_P + in3_P;
    assign sum2 = in4_P + in5_P + in6_P;
    assign sum3 = in7_P + in8_P + in9_P;
    
    assign sum = sum1 + sum2 + sum3;
    
    assign p0_result = (sum >> 3) - (sum >> 6); // x/8 - x/64 = 7x/64 ~= x/9
    
endmodule
