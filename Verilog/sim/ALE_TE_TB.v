`timescale 1ns/1ps

module dehazing_tb;

    reg clk;
    reg rst;
    reg en;
    reg [23:0] input_pixel;
    reg input_is_valid;

    wire [7:0] transmission_out;
    wire transmission_valid;
    wire done_flag;

    // Instantiate the ALE_TE_Top module
    ALE_TE_Top dut (
        .clk(clk),
        .en(en),
        .rst(rst),
        .input_pixel(input_pixel),
        .input_is_valid(input_is_valid),
        .transmission_out(transmission_out),
        .transmission_valid(transmission_valid),
        .done_flag(done_flag)
    );

    // Clock generation
    initial clk = 1;
    always #5 clk = ~clk;

    // BMP Handling
    localparam array_length = 800 * 1024;
    reg [7:0] bmpdata[0:array_length - 1];
    reg [7:0] result[0:array_length - 1]; // Output BMP

    integer bmp_size, bmp_start_pos, bmp_width, bmp_height, bmp_count;
    integer i, j;

    // BMP reading
    task read_file;
        integer file1;
        begin 
            file1 = $fopen("canyon_512.bmp", "rb");
            if (file1 == 0) begin
                $display("Error: Cannot open BMP file.");
                $finish;
            end
            $fread(bmpdata, file1);
            $fclose(file1);

            bmp_size       = {bmpdata[5], bmpdata[4], bmpdata[3], bmpdata[2]};
            bmp_start_pos  = {bmpdata[13], bmpdata[12], bmpdata[11], bmpdata[10]};
            bmp_width      = {bmpdata[21], bmpdata[20], bmpdata[19], bmpdata[18]};
            bmp_height     = {bmpdata[25], bmpdata[24], bmpdata[23], bmpdata[22]};
            bmp_count      = {bmpdata[29], bmpdata[28]};

            $display("BMP size       : %d", bmp_size);
            $display("Start position : %d", bmp_start_pos);
            $display("Width x Height : %d x %d", bmp_width, bmp_height);
            $display("Bits/pixel     : %d", bmp_count);

            if (bmp_count != 24 || bmp_width % 4 != 0) begin
                $display("Invalid BMP format");
                $finish;
            end
        end
    endtask

    // BMP writing
    task write_file;
        integer file2;
        begin
            file2 = $fopen("output_file.bmp", "wb");
            for (i = 0; i < bmp_start_pos; i = i + 1)
                $fwrite(file2, "%c", bmpdata[i]);
            for (i = 0; i < bmp_size - bmp_start_pos; i = i + 1)
                $fwrite(file2, "%c", result[i]);
            $fclose(file2);
            $display("Write successful.");
        end
    endtask

    initial begin
        // Initialize
        clk = 0;
        rst = 1;
        en = 0; // Start in ALE mode
        input_pixel = 0;
        input_is_valid = 0;

        read_file;
        #20 rst = 0;

        // --------------------------
        // Pass 1: Feed image to ALE
        // --------------------------
        for (i = bmp_start_pos; i < bmp_size; i = i + 3) begin
            input_pixel[7:0]   = bmpdata[i];       // B
            input_pixel[15:8]  = bmpdata[i + 1];   // G
            input_pixel[23:16] = bmpdata[i + 2];   // R
            input_is_valid = 1;
            #10;
        end
        input_is_valid = 0;
        #10;

        // Wait for ALE to finish
        wait(done_flag == 1);
        #10;

        // ------------------------------
        // Pass 2: Feed image to TE
        // ------------------------------
        en = 1; // Switch to TE mode
        #10;
      
        read_file;
        #20;
      
        for (i = bmp_start_pos; i < bmp_size; i = i + 3) begin
            input_pixel[7:0]   = bmpdata[i];       // B
            input_pixel[15:8]  = bmpdata[i + 1];   // G
            input_pixel[23:16] = bmpdata[i + 2];   // R
            input_is_valid = 1;
            #10;
        end
        input_is_valid = 0;

        #100;

        write_file;
        $stop;
    end

    // Output Monitor
    always @(posedge clk) begin
        if (rst)
            j <= 0;
        else if (transmission_valid) begin
            result[j]     <= transmission_out; // B
            result[j + 1] <= transmission_out; // G
            result[j + 2] <= transmission_out; // R
            j <= j + 3;
        end
    end

endmodule
