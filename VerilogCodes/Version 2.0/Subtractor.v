module Subtractor(
    input [16:0] a,
    output [16:0] diff
);

    parameter ONE = 17'b00000000010000000;
    assign diff = ONE - a;

endmodule