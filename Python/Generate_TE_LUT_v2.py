def float_to_q28(value):
    """
    Convert float to Q2.8 fixed-point (10-bit unsigned).
    Range: 0 to ~3.996
    """
    scaled = int(round(value * (1 << 8)))  # multiply by 256
    return min(scaled, (1 << 10) - 1)      # clamp to 10 bits (0..1023)


def generate_verilog_lut_q010_to_q28(module_name="Transmission_Reciprocal_LUT",
                                     filename="Transmission_Reciprocal_LUT.v"):
    lines = []
    lines.append(f"module {module_name} (")
    lines.append("    input  [9:0] in,      // Q0.10 input (unsigned, 0 to 0.75 max)")
    lines.append("    output reg [9:0] out  // Q2.8 reciprocal output (unsigned, 10-bit)")
    lines.append(");")
    lines.append("")
    lines.append("    always @(*) begin")
    lines.append("        case(in)")

    # max input index for 0.75 in Q0.10
    max_index = int(round(0.75 * (1 << 10)))  # 0.75 * 1024 ≈ 768

    for i in range(0, max_index + 1):
        if i == 0:
            value = float_to_q28(1.0)  # reciprocal(0) = 1
        else:
            val_float = i / (1 << 10)      # interpret as Q0.10
            recip = 1.0 / (1.0 - val_float)  # reciprocal(1-x)
            value = float_to_q28(recip)

        lines.append(f"            10'd{i:4}: out = 10'h{value:03X};")

    lines.append("            default: out = 10'h000;")
    lines.append("        endcase")
    lines.append("    end")
    lines.append("endmodule")

    with open(filename, "w") as f:
        f.write("\n".join(lines))
    print(f"Verilog LUT module written to {filename} with {max_index+1} entries (10-bit output).")


# Generate the LUT file
generate_verilog_lut_q010_to_q28()
