// Find the minimum of each color channel inputs
module ALE_Minimum_9 (
    input [7:0]  input_pixel_1, input_pixel_2, input_pixel_3,
                 input_pixel_4, input_pixel_5, input_pixel_6,
                 input_pixel_7, input_pixel_8, input_pixel_9, // 3x3 R/G/B color channel input
    
    output [7:0] minimum_pixel
);
    
    wire [7:0] min1, min2, min3;
    
    function [7:0] min;
        input [7:0] a, b, c;
        begin
            min = (a < b) ? ((a < c) ? a : c) : ((b < c) ? b : c);
        end
    endfunction
    
    assign min1 = min(input_pixel_1, input_pixel_2, input_pixel_3);
    assign min2 = min(input_pixel_4, input_pixel_5, input_pixel_6);
    assign min3 = min(input_pixel_7, input_pixel_8, input_pixel_9);

    assign minimum_pixel = min(min1, min2, min3);

endmodule
