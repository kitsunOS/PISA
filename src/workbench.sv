module workbench(
    input clk,
    input btnU,
    input wire [15:0] sw,
    output wire [15:0] led
);

    reg rst = 1'b1;

    reg m_clk = 1'b0;

    wire a_clk;
    assign a_clk = clk;

    wire [31:0] data_in;
    wire [31:0] data_out;
    wire [31:0] address;
    wire write_enable;

    Core processor_core (
        .clk(a_clk),
        .rst(rst),
        .data_in(data_in),
        .data_out(data_out),
        .address(address),
        .write_enable(write_enable),
        .debug_out(led[15:8])
    );

    reg [7:0] code [0:255];
    reg [31:0] code_address;
    wire [31:0] code_out;
    assign code_out = {code[code_address + 3], code[code_address + 2], code[code_address + 1], code[code_address]};
    initial begin
        $readmemh("program.hex", code);
    end

    wire [31:0] memory_address;
    wire [31:0] memory_in;
    wire [1:0] memory_size;
    wire memory_write_enable;
    wire [31:0] memory_out;

    /*Memory memory(
        .clk(a_clk),
        .memory_address(memory_address),
        .memory_in(memory_in),
        .memory_size(memory_size),
        .memory_write_enable(memory_write_enable),
        .memory_out(memory_out)
    );*/

    wire [31:0] input_in = {sw, 16'b0};

    wire [31:0] output_in;
    wire [31:0] output_address;
    wire [31:0] output_out;
    wire [1:0] output_size;
    wire output_write_enable;

    OutputMap output_map(
        .clk(a_clk),
        .output_address(output_address),
        .output_in(output_in),
        .output_size(output_size),
        .output_write_enable(output_write_enable),
        .output_out(output_out),
        .led(led[7:0])
    );

    MemoryController mem_controller (
        .clk(a_clk),
        .address(address),
        .write_enable(write_enable),
        .data_in_size(2'b10), // TODO: Use proper data sizes
        .data_out_size(2'b10), // TODO: Use proper data sizes
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
        .input_in(input_in),
        .output_in(output_out),
        .output_address(output_address),
        .output_out(output_in),
        .output_size(output_size),
        .output_write_enable(output_write_enable)
    );


    reg was_pressed = 1'b0;
    reg [26:0] debounce_counter = 27'd0;
    
    always_ff @(posedge clk) begin
        rst <= 1'b0;
    
        if (btnU == 1'b1) begin
            if (debounce_counter < 27'd50_000_000) begin
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