module workbench(
    input clk,
    input logic btnU,
    input logic RsRx,
    input logic [15:0] sw,
    output logic [15:0] led,
    output logic [3:0] vgaRed,
    output logic [3:0] vgaGreen,
    output logic [3:0] vgaBlue,
    output logic Hsync,
    output logic Vsync
);

    logic rst;
    logic p_ready;
    initial rst = 1'b1;

    logic m_clk = 1'b0;

    logic clk_pixel;
    clk_wiz_0 clk_gen (
        .clk_pixel(clk_pixel),
        .clk_in1(clk),
        .reset(rst)
    );

    logic [31:0] data_in;
    logic [31:0] data_out;
    logic [31:0] address;
    logic [1:0] data_size;
    logic write_enable;

    Core processor_core (
        .clk(clk),
        .rst(rst | ~p_ready),
        .enable_step(sw[15] | m_clk),
        .data_in(data_in),
        .data_out(data_out),
        .address(address),
        .data_size(data_size),
        .write_enable(write_enable),
        .debug_out(led[15:8])
    );

    (* ram_style = "distributed" *)
    logic [7:0] code [0:255];
    logic [31:0] code_address;
    logic [31:0] code_out;
    assign code_out = {code[code_address + 3], code[code_address + 2], code[code_address + 1], code[code_address]};

    logic code_byte_ready;
    logic [7:0] code_setup_addr;
    logic [7:0] code_setup_data;
    UART uart(
        .clk(clk),
        .bit_in(RsRx),
        .data_out(code_setup_data),
        .data_ready(code_byte_ready)
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            code_setup_addr <= 8'h00;
            p_ready <= 1'b0;
        end else begin
            if (code_byte_ready & p_ready) begin
                p_ready <= 1'b0;
            end
            if (code_byte_ready) begin
                code[code_setup_addr] <= code_setup_data;
                code_setup_addr <= code_setup_addr + 1;
            end
            if (code_setup_addr == 8'hFF) begin
                p_ready <= 1'b1;
                code_setup_addr <= 8'h00;
            end
        end
    end

    logic [31:0] memory_address;
    logic [31:0] memory_in;
    logic [1:0] memory_size;
    logic memory_write_enable;
    logic [31:0] memory_out;

    Memory memory(
        .clk(clk),
        .memory_address(memory_address),
        .memory_in(memory_in),
        .memory_size(memory_size),
        .memory_write_enable(memory_write_enable),
        .memory_out(memory_out)
    );

    logic [31:0] vram_address;
    logic [31:0] vram_in;
    logic [1:0] vram_size;
    logic vram_write_enable;
    logic [31:0] vram_out;
    logic [31:0] video_address;
    logic [15:0] video_out;

    VideoMemory vram(
        .clk(clk),
        .clk_pixel(clk_pixel),
        .memory_address(vram_address),
        .memory_in(vram_in),
        .memory_size(vram_size),
        .memory_write_enable(vram_write_enable),
        .memory_out(vram_out),
        .video_address(video_address),
        .video_out(video_out)
    );

    logic [31:0] input_in;
    assign input_in = {24'b0, sw};

    logic [31:0] output_in;
    logic [31:0] output_address;
    logic [31:0] output_out;
    logic [1:0] output_size;
    logic output_write_enable;

    OutputMap output_map(
        .clk(clk),
        .output_address(output_address),
        .output_in(output_in),
        .output_size(output_size),
        .output_write_enable(output_write_enable),
        .output_out(output_out),
        .led(led[7:0])
    );

    MemoryController mem_controller (
        .address(address),
        .write_enable(write_enable),
        .data_size(data_size),
        .data_in(data_out),
        .data_out(data_in),
        .memory_error(), // TODO: Handle memory error

        .code_in(code_out),
        .code_address(code_address),

        .memory_in(memory_out),
        .memory_address(memory_address),
        .memory_out(memory_in),
        .memory_size(memory_size),
        .memory_write_enable(memory_write_enable),

        .vram_in(vram_out),
        .vram_address(vram_address),
        .vram_out(vram_in),
        .vram_size(vram_size),
        .vram_write_enable(vram_write_enable),

        .input_in(input_in),

        .output_in(output_out),
        .output_address(output_address),
        .output_out(output_in),
        .output_size(output_size),
        .output_write_enable(output_write_enable)
    );

    VGA vga(
        .clk_pixel(clk_pixel),

        .active_char(video_out[7:0]),
        .active_foreground(video_out[11:8]),
        .active_background(video_out[15:12]),
        .video_address(video_address),

        .px_red(vgaRed),
        .px_green(vgaGreen),
        .px_blue(vgaBlue),
        .hsync(Hsync),
        .vsync(Vsync)
    );

    logic was_pressed;
    logic [26:0] debounce_counter;
    
    always_ff @(posedge clk) begin
        rst <= 1'b0;
    
        if (btnU == 1'b1) begin
            if (debounce_counter < 27'd2_000_000) begin
                debounce_counter <= debounce_counter + 1;
            end else if (!was_pressed) begin
                m_clk <= 1'b1;
                was_pressed <= 1'b1;
            end else begin
                m_clk <= 1'b0;
            end
        end else begin
            debounce_counter <= 27'd0;
            was_pressed <= 1'b0;
            m_clk <= 1'b0;
        end
    end

endmodule