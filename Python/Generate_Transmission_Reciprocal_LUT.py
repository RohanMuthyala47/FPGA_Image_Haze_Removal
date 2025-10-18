def float_to_q26(value):
    """
    Convert float to Q2.6 fixed-point (8-bit unsigned).
    Range: 0 to ~3.984 (max representable value = 255/64)
    """
    scaled = int(round(value * (1 << 6)))  # multiply by 64
    return min(scaled, (1 << 8) - 1)       # clamp to 8 bits (0..255)


def generate_verilog_lut_q010_to_q26(module_name="Transmission_Reciprocal_LUT",
                                     filename="Transmission_Reciprocal_LUT.v"):
    lines = []
    lines.append(f"module {module_name} (")
    lines.append("    input  [9:0] in,      // Q0.10 input (unsigned, 0 to 0.65 max)")
    lines.append("    output reg [7:0] out  // Q2.6 reciprocal output (unsigned, 8-bit)")
    lines.append(");")
    lines.append("")
    lines.append("    always @(*) begin")
    lines.append("        case(in)")

    # max input index for 0.65 in Q0.10
    max_index = int(round(0.65 * (1 << 10)))  # 0.65 * 1024 ≈ 666

    for i in range(0, max_index + 1):
        if i == 0:
            value = float_to_q26(1.0)  # reciprocal(0) = 1
        else:
            val_float = i / (1 << 10)          # interpret as Q0.10
            recip = 1.0 / (1.0 - val_float)    # reciprocal(1-x)
            value = float_to_q26(recip)

        lines.append(f"            10'd{i:4}: out = 8'h{value:02X};")

    lines.append("            default: out = 8'h00;")
    lines.append("        endcase")
    lines.append("    end")
    lines.append("endmodule")

    with open(filename, "w") as f:
        f.write("\n".join(lines))


# Generate the LUT file
generate_verilog_lut_q010_to_q26()
