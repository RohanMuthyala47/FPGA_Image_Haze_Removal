def to_fixed(val, int_bits, frac_bits):
    """Convert a float to unsigned fixed-point representation."""
    scale = 1 << frac_bits
    max_val = (1 << (int_bits + frac_bits)) - 1
    return min(max_val, max(0, int(round(val * scale))))

def generate_verilog_lut_module(power, int_bits, frac_bits, module_name, filename):
    """Generate a Verilog LUT module for x^power with fixed-point output."""
    width = int_bits + frac_bits
    with open(filename, 'w') as f:
        f.write(f"// LUT for x^{power} in Q{int_bits}.{frac_bits} format\n")
        f.write(f"module {module_name} (\n")
        f.write("    input  [7:0] in, // Q8.0 input\n")
        f.write(f"    output reg [{width-1}:0] out // Q{int_bits}.{frac_bits} output\n")
        f.write(");\n\n")
        f.write("    always @(*) begin\n")
        f.write("        case (in)\n")

        for xi in range(256):
            val = xi ** power if xi > 0 else 0.0
            fixed_val = to_fixed(val, int_bits, frac_bits)
            comment = f"{xi}^{power:.2f} ~= {val:.6f}"
            f.write(f"            8'd{xi:<3}: out = {width}'d{fixed_val};  // {comment}\n")

        f.write(f"            default: out = {width}'d0;\n")
        f.write("        endcase\n")
        f.write("    end\n")
        f.write("endmodule\n")
    print(f"✅ Generated {filename} for {module_name} (x^{power}, Q{int_bits}.{frac_bits})")

# Generate LUT for x^0.35 in Q3.9 (12 bits)
generate_verilog_lut_module(0.35, 3, 9, "LUT_035", "LUT_035_Q3_9.v")

# Generate LUT for x^0.65 in Q6.6 (12 bits)
generate_verilog_lut_module(0.65, 6, 6, "LUT_065", "LUT_065_Q6_6.v")
