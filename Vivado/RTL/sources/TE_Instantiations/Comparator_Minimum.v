// Comparator module which determines the smallest value of the input pixels
module Comparator_Minimum (
    input  [7:0] red, green, blue,
    output [1:0] min_val
);
    
    parameter RED = 2'b00, GREEN = 2'b01, BLUE = 2'b10;
    
    assign min_val = (red <= green && red <= blue)   ? RED : 
                     (green <= red && green <= blue) ? GREEN : 
                                                       BLUE;

endmodule
