//module top (
//    input clk,
//    input rst,
//    input [23:0] input_pixel,
//    input input_is_valid,

//    output wire [23:0] out_pixel,
//    output wire output_is_valid
//);

//    // Wires for 3x3 window pixels from WindowGeneratorTop
//    wire [23:0] output_pixel_1;
//    wire [23:0] output_pixel_2;
//    wire [23:0] output_pixel_3;
//    wire [23:0] output_pixel_4;
//    wire [23:0] output_pixel_5;
//    wire [23:0] output_pixel_6;
//    wire [23:0] output_pixel_7;
//    wire [23:0] output_pixel_8;
//    wire [23:0] output_pixel_9;

//    wire window_valid;

//    // Instance of 3x3 Window Generator
//    WindowGeneratorTop dut (
//        .clk(clk),
//        .rst(rst),
//        .input_pixel(input_pixel),
//        .input_is_valid(input_is_valid),

//        .output_pixel_1(output_pixel_1),
//        .output_pixel_2(output_pixel_2),
//        .output_pixel_3(output_pixel_3),
//        .output_pixel_4(output_pixel_4),
//        .output_pixel_5(output_pixel_5),
//        .output_pixel_6(output_pixel_6),
//        .output_pixel_7(output_pixel_7),
//        .output_pixel_8(output_pixel_8),
//        .output_pixel_9(output_pixel_9),
//        .output_is_valid(window_valid)
//    );

//    // Instance of test module (your processing block)
//    test T (
//        .clk(clk),
//        .rst(rst),
//        .input_is_valid(window_valid),

//        .output_pixel_1(output_pixel_1),
//        .output_pixel_2(output_pixel_2),
//        .output_pixel_3(output_pixel_3),
//        .output_pixel_4(output_pixel_4),
//        .output_pixel_5(output_pixel_5),
//        .output_pixel_6(output_pixel_6),
//        .output_pixel_7(output_pixel_7),
//        .output_pixel_8(output_pixel_8),
//        .output_pixel_9(output_pixel_9),

//        .out_pixel(out_pixel),
//        .output_is_valid(output_is_valid)
//    );

//endmodule
