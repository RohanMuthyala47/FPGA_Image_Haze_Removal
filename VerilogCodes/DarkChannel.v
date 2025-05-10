`timescale 1ns / 1ps
module DarkChannel(
input        i_clk,
input [215:0]i_pixel_data,
input        i_pixel_data_valid,
output reg [7:0] o_dcp_data,
output reg   o_dcp_data_valid
    );
integer i;
reg [7:0] red [8:0];
reg [7:0] green [8:0];
reg [7:0] blue [8:0];
reg pixel_data_valid_pipe1;
reg pixel_data_valid_pipe2;

// Registers for minimum values of each color
reg [7:0] min_red;
reg [7:0] min_green;
reg [7:0] min_blue;

//first pipeline stage to separate colors
always @(posedge i_clk)
begin
    if(i_pixel_data_valid) begin
        for(i = 0; i < 9; i = i + 1) begin
            blue[i] <= i_pixel_data[(i*24)+:8];
            green[i] <= i_pixel_data[(i*24)+8+:8];
            red[i] <= i_pixel_data[(i*24)+16+:8];
        end
        pixel_data_valid_pipe1 <= i_pixel_data_valid;
    end
    else begin
        pixel_data_valid_pipe1 <= 1'b0;
    end
end

// Second pipeline stage to find minimum value of each color component
always @(posedge i_clk)
begin
    if(pixel_data_valid_pipe1) begin
        // Initialize min values with first pixel
        min_red <= red[0];
        min_green <= green[0];
        min_blue <= blue[0];
        
        // Find minimum values
        for(i = 1; i < 9; i = i + 1) begin
            if(red[i] < min_red)
                min_red <= red[i];
                
            if(green[i] < min_green)
                min_green <= green[i];
                
            if(blue[i] < min_blue)
                min_blue <= blue[i];
        end
        
        pixel_data_valid_pipe2 <= pixel_data_valid_pipe1;
    end
    else begin
        pixel_data_valid_pipe2 <= 1'b0;
    end
end

// Third pipeline stage to find minimum among the three color minimums
always @(posedge i_clk)
begin
    if(pixel_data_valid_pipe2) begin
        // Default to min_red
        o_dcp_data <= min_red;
        
        // Check if min_green is smaller
        if(min_green < o_dcp_data)
            o_dcp_data <= min_green;
            
        // Check if min_blue is smaller
        if(min_blue < o_dcp_data)
            o_dcp_data <= min_blue;
            
        o_dcp_data_valid <= pixel_data_valid_pipe2;
    end
    else begin
        o_dcp_data_valid <= 1'b0;
    end
end
    
endmodule
