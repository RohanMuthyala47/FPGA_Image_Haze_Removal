module LineBuffer (
    input         clk, rst,
    
    input [23:0]  input_pixel,
    input         input_is_valid,

    output [23:0] output_pixel,
    output        output_is_valid
);

localparam BUFFER_SIZE = 512;

reg [$clog2(BUFFER_SIZE):0] wr_counter;
reg [$clog2(BUFFER_SIZE):0] rd_counter;

reg [23:0] line_buffer_mem [0:BUFFER_SIZE - 1];

reg [$clog2(BUFFER_SIZE):0] PixelCounter;

always @(posedge clk)
begin
    if(rst)
        PixelCounter <= 0;
    else begin
        if(input_is_valid)
            PixelCounter <= (PixelCounter == BUFFER_SIZE) ? PixelCounter : PixelCounter + 1; 
    end
end

always @(posedge clk)
begin
    if(rst)
        wr_counter <= 0;
    else
    begin
        if(input_is_valid)
        begin
            line_buffer_mem[wr_counter] <= input_pixel;
            wr_counter <= (wr_counter == BUFFER_SIZE - 1) ? 0 : wr_counter + 1; 
        end
    end
end

always @(posedge clk)
begin
    if(rst)
        rd_counter <= 0;
    else
    begin
        if(input_is_valid)
        begin
            if(PixelCounter == BUFFER_SIZE)
                rd_counter <= (rd_counter == BUFFER_SIZE - 1) ? 0 : rd_counter + 1;
        end
    end
end

assign output_is_valid = (PixelCounter == BUFFER_SIZE);
assign output_pixel = line_buffer_mem[rd_counter];

endmodule
