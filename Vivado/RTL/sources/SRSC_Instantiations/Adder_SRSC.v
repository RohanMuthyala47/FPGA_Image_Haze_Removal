module Adder_SRSC (
    input  [7:0] Ac,
    input  [7:0] Ic,
    input  [7:0] Multiplier_out,
    
    input        add_or_sub,
    
    output [7:0] sum
);

    wire ic_gt_ac  = (Ic > Ac);
    wire ac_gt_mul = (Ac > Multiplier_out);

    wire [7:0] add_res = Ac + Multiplier_out;
    wire [7:0] sub_res = Ac - Multiplier_out;

    assign sum = add_or_sub ? 
                 (ic_gt_ac ? sub_res : add_res) :
                 (ac_gt_mul ? sub_res : 8'd0);
    
endmodule
