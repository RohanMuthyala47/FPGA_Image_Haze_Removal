def generate_reciprocal_lut_q0_10():
    print("module ReciprocalLUT_Q0_10 (")
    print("    input  [7:0] in,")
    print("    output reg [9:0] out")
    print(");")
    print()
    print("    always @(*) begin")
    print("        casez (in)")

    for i in range(1, 256):
        reciprocal = 1 / i
        fixed_point = int(round(reciprocal * (1 << 10)))  # Q0.10 format
        print(f"            8'd{i:3}: out = 10'd{fixed_point:4};  // 1/{i} ≈ {reciprocal:.8f}")

    print("            default: out = 10'd0;  // undefined for 0")
    print("        endcase")
    print("    end")
    print()
    print("endmodule")

# Run the function
generate_reciprocal_lut_q0_10()
