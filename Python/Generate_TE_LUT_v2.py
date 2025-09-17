def q2_12(value):
    """Convert float to Q2.12 fixed-point format (14-bit unsigned)."""
    result = int(round(value * (1 << 12)))
    return min(result, (1 << 14) - 1)  # clamp to 14-bit (0x3FFF)


def generate_verilog_lut_q014_to_q212_limited(module_name="Transmission_Reciprocal_LUT",
                                              filename="Transmission_Reciprocal_LUT.v"):
    lines = []
    lines.append(f"module {module_name} (")
    lines.append("    input  [13:0] in,      // Q0.14 input (unsigned, 0 to 0.65 range only)")
    lines.append("    output reg [13:0] out  // Q2.12 reciprocal output (unsigned, 14-bit)")
    lines.append(");")
    lines.append("")
    lines.append("    always @(*) begin")
    lines.append("        case(in)")

    # max input index for 0.65 in Q0.14
    max_index = int(round(0.65 * (1 << 14)))  # ~10650

    for i in range(0, max_index + 1):
        if i == 0:
            value = q2_12(1.0)  # reciprocal(0) = 1
        else:
            val_float = i / (1 << 14)     # interpret as Q0.14
            recip = 1.0 / (1.0 - val_float)  # reciprocal(1-x)
            value = q2_12(recip)

        lines.append(f"            14'd{i:5}: out = 14'h{value:04X};")

    lines.append("            default: out = 14'h0000;")
    lines.append("        endcase")
    lines.append("    end")
    lines.append("endmodule")

    with open(filename, "w") as f:
        f.write("\n".join(lines))
    print(f"Verilog LUT module written to {filename} with {max_index+1} entries (14-bit output).")


# Generate the LUT file
generate_verilog_lut_q014_to_q212_limited()
