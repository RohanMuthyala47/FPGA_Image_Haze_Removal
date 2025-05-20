module scene_recovery_with_saturation_correction (
    input  wire        clk,
    input  wire        rst,
    
    input  wire [7:0]  i_r,
    input  wire [7:0]  i_g, 
    input  wire [7:0]  i_b,
    input wire window_valid,
    
    input  wire [7:0]  i_a_r,
    input  wire [7:0]  i_a_g,
    input  wire [7:0]  i_a_b,
    input wire ale_in_valid,
   
    input  wire [16:0] i_transmission,
    input  wire        i_trans_valid,
    
    output reg [7:0]   o_r,
    output reg [7:0]   o_g,
    output reg [7:0]   o_b,
    output reg         o_valid
);

    parameter MIN_TRANSMISSION = 17'd32768;
    //stage 7
    reg [7:0]A_R,A_G,A_B;
    reg [8:0]SUB_r,SUB_g,SUB_b;
    wire [8:0]  stage7_1_r_minus_atm;
    wire [8:0]  stage7_1_g_minus_atm;
    wire [8:0]  stage7_1_b_minus_atm;
    wire [7:0]  stage7_1_a_r, stage7_1_a_g, stage7_a_b;
    wire [7:0]  stage7_5_r, stage7_5_g, stage7_5_b;
    reg        stage7_valid;
    sub S1(.a(stage7_5_r), .b(stage7_1_a_r), .out(stage7_1_r_minus_atm));
    sub S2(.a(stage7_5_g), .b(stage7_1_a_g), .out(stage7_1_g_minus_atm));
    sub S3(.a(stage7_5_b), .b(stage7_1_a_b), .out(stage7_1_b_minus_atm));
    always @(posedge clk)
    begin
    if(rst)
    begin
          A_R<=0;
          A_G<=0;
          A_B<=0;
          SUB_r<=0;
          SUB_g<=0;
          SUB_b<=0;
          stage7_valid<=0;
     end
     else begin
          A_R<=stage7_1_a_r;
          A_G<=stage7_1_a_g;
          A_B<=stage7_1_a_b;
          SUB_r<=stage7_1_r_minus_atm;
          SUB_g<=stage7_1_g_minus_atm;
          SUB_b<=stage7_1_b_minus_atm;
          stage7_valid<=(window_valid&ale_in_valid);
       end
    end
    //stage 8
    reg [7:0]A_R_1,A_G_1,A_B_1;
    reg [15:0] left_r_reg,left_g_reg,left_b_reg;
    wire [15:0] left_shift_r,left_shift_g,left_shift_b;
    reg  [16:0] t_max;
    reg  [15:0] inv_t;
    reg        stage8_valid;
    assign left_shift_r=A_R<<8;
    assign left_shift_g=A_G<<8;
    assign left_shift_b=A_B<<8; 
    always @(posedge clk)
    begin
    if (rst)
    begin
        A_R_1<=0;
        A_G_1<=0;
        A_B_1<=0;
        left_r_reg<=0;
        left_g_reg<=0;
        left_b_reg<=0;
        t_max<=0;
        inv_t<=0;
        stage8_valid<=0;
    end
    else begin
       A_R_1<=A_R;
        A_G_1<=A_G;
        A_B_1<=A_B;
        left_r_reg<=left_shift_r;
        left_g_reg<=left_shift_g;
        left_b_reg<=left_shift_b;
        t_max<=(i_transmission>MIN_TRANSMISSION)?i_transmission:MIN_TRANSMISSION;
        inv_t<= calc_inverse_t(t_max);
        stage8_valid<=(stage7_valid&i_trans_valid);
     end
   end
    // For 1/t calculation with 17-bit input, we'll use a hardware divider
    // or a more sophisticated approximation approach
    function [15:0] calc_inverse_t;
        input [16:0]t_value;
        reg [31:0] numerator;
        begin
            // Fixed point division approximation for 1/t
            // Using 2^24 as numerator for good precision
            numerator = 32'h1000000; // 2^24
            
            // Avoid division by zero
            if (t_value == 0)
                calc_inverse_t = 16'hFFFF; // Maximum value
            else
                calc_inverse_t = numerator / t_value; // Hardware would implement this differently
        end
    endfunction
    //stage 9
     reg [7:0]A_R_2,A_G_2,A_B_2;
     reg [15:0] left_r_reg1,left_g_reg2,left_b_reg3;
     reg [24:0] mul_reg_r,mul_reg_g,mul_reg_b;
     wire [24:0] mul_r,mul_g,mul_b;
     reg        stage9_valid;
     multiplier_SRSC m1(
     .p(SUB_r),
     .q(inv_t),
     .out_mul(mul_r)
     );
     multiplier_SRSC m2(
     .p(SUB_g),
     .q(inv_t),
     .out_mul(mul_g)
     );
     multiplier_SRSC m3(
     .p(SUB_b),
     .q(inv_t),
     .out_mul(mul_b)
     );
     always @(posedge clk)
     begin
     if(rst)
     begin
          A_R_2<=0;
          A_G_2<=0;
          A_B_2<=0;
          left_r_reg1<=0;
          left_g_reg2<=0;
          left_b_reg3<=0;
          mul_reg_r<=0;
          mul_reg_g<=0;
          mul_reg_b<=0;
          stage9_valid<=0;
      end
      else begin
          A_R_2<=A_R_1;
          A_G_2<=A_G_1;
          A_B_2<=A_B_1;
          left_r_reg1<= left_r_reg;
          left_g_reg2<= left_g_reg;
          left_b_reg3<= left_b_reg;
          mul_reg_r<=mul_r;
          mul_reg_g<=mul_g;
          mul_reg_b<=mul_b;
          stage9_valid<=stage8_valid;
     end
   end
   
  // stage 10
  wire [24:0] add_r,add_g,add_b;
  wire [16:0]right_shift_r,right_shift_g,right_shift_b;
  
   adder a1(
     .x(mul_reg_r),
     .y(left_r_reg1),
     .out_add(add_r)
     );
     adder a2(
     .x(mul_reg_g),
     .y(left_g_reg1),
     .out_add(add_g)
     );
     adder a3(
     .x(mul_reg_b),
     .y(left_b_reg1),
     .out_add(add_b)
     );
    assign right_shift_r=add_r>>8;
    assign right_shift_g=add_g>>8;
    assign right_shift_b=add_b>>8;
    
    
    wire [15:0]corrected_a_r,corrected_a_g,corrected_a_b;
    wire [15:0]corrected_j_r,corrected_j_g,corrected_j_b;
    
    power_luts SRSC_BETA_LUT_1(
        .x(A_R_2),
        .y(right_shift_r),
        
        .x_pow_03(corrected_a_r),
        .y_pow_07(corrected_j_r)
    );
    
        power_luts SRSC_BETA_LUT_2(
        .x(A_G_2),
        .y(right_shift_g),
        
        .x_pow_03(corrected_a_g),
        .y_pow_07(corrected_j_g)
    );
    
        power_luts SRSC_BETA_LUT_3(
        .x(A_B_2),
        .y(right_shift_b),
        
        .x_pow_03(corrected_a_b),
        .y_pow_07(corrected_j_b)
    );
    
    always @(posedge clk)
    begin
        if(rst)
        begin
            o_r <= 0;
            o_g <= 0;
            o_b <= 0;
            o_valid <= 0;
        end
        else if(stage9_valid)
        begin
            o_r <= corrected_a_r * corrected_j_r;
            o_g <= corrected_a_g * corrected_j_g;
            o_b <= corrected_a_b * corrected_j_b;
            o_valid <= stage9_valid;
        end
    end
    
    
 endmodule