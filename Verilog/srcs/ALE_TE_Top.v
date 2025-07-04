module ALE_TE_Top(
    input clk,
    input rst,
    input [23:0] input_pixel,
    input input_is_valid,
    
    output [7:0] transmission_out,
    output transmission_valid,
    output done_flag
);

// Wires for 3x3 window
wire [23:0] w1, w2, w3, w4, w5, w6, w7, w8, w9;
wire window_valid;

// Connect WindowGeneratorTop
WindowGeneratorTop win_gen (
    .clk(clk),
    .rst(rst),
    .input_pixel(input_pixel),
    .input_is_valid(input_is_valid),

    .output_pixel_1(w1),
    .output_pixel_2(w2),
    .output_pixel_3(w3),
    .output_pixel_4(w4),
    .output_pixel_5(w5),
    .output_pixel_6(w6),
    .output_pixel_7(w7),
    .output_pixel_8(w8),
    .output_pixel_9(w9),
    .output_is_valid(window_valid)
);

// Done signal from ALE
wire ALE_done;

// === Clock Gating (Using Enables instead of actual gating) ===
wire clk_ale_enable = ~ALE_done;
wire clk_te_enable  = ALE_done;

// Gated clock (simulation-only) -- not recommended for FPGA synthesis
wire clk_ale = clk & clk_ale_enable;
wire clk_te  = clk & clk_te_enable;

// Wires from ALE
wire [7:0] A_R, A_G, A_B;
wire [15:0] inv_A_R, inv_A_G, inv_A_B;
wire ALE_valid;

// Connect ALE
ALE ale (
    .clk(clk_ale),     // Gated clock
    .rst(rst),
    
    .input_is_valid(window_valid),
    
    .input_pixel_1(w1),
    .input_pixel_2(w2),
    .input_pixel_3(w3),
    .input_pixel_4(w4),
    .input_pixel_5(w5),
    .input_pixel_6(w6),
    .input_pixel_7(w7),
    .input_pixel_8(w8),
    .input_pixel_9(w9),
    
    .A_R(A_R),
    .A_G(A_G),
    .A_B(A_B),
    
    .Inv_A_R(inv_A_R),
    .Inv_A_G(inv_A_G),
    .Inv_A_B(inv_A_B),
    
    .output_is_valid(ALE_valid),
    .done(ALE_done)
);

// Wires for TE
wire [7:0] transmission;
wire TE_valid;

// Connect TE (starts after ALE done)
TE te (
    .clk(clk_te),       // Gated clock
    .rst(rst),
    
    .input_is_valid(window_valid),
    .in1(w1), .in2(w2), .in3(w3),
    .in4(w4), .in5(w5), .in6(w6),
    .in7(w7), .in8(w8), .in9(w9),
    
    .inv_ar(inv_A_R),
    .inv_ag(inv_A_G),
    .inv_ab(inv_A_B),
    .atm_valid(ALE_valid),
    
    .transmission(transmission),
    .output_is_valid(TE_valid)
);

// Outputs
assign transmission_out   = transmission;
assign transmission_valid = TE_valid;
assign done_flag          = ALE_done;

endmodule
