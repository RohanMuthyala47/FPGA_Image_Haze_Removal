def generate_reciprocal_lut():
    scale = 0.9375  # scaling factor (15/16)

    print("module Atmospheric_Light_Reciprocal_LUT (")
    print("    input  [7:0] in,")
    print("    output reg [9:0] out")
    print(");")
    print()
    print("    always @(*) begin")
    print("        casez (in)")

    for i in range(1, 256):
        reciprocal = scale / i
        fixed_point = int(round(reciprocal * (1 << 10)))  # Q0.10 format
        fixed_point = min(fixed_point, 1023)  # clamp to 10-bit max
        print(f"            8'd{i:3}: out = 10'd{fixed_point:4};  // 0.9375/{i} ≈ {reciprocal:.8f}")

    print("            default: out = 10'd1023; // undefined for 0")
    print("        endcase")
    print("    end")
    print()
    print("endmodule")


generate_reciprocal_lut_q0()
