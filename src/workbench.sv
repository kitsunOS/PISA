module workbench(
    input clk,
    input btnU,
    input logic [15:0] sw,
    output logic [15:0] led
);

    logic rst = 1'b1;

    logic m_clk = 1'b0;

    logic a_clk;
    assign a_clk = sw[15] ? clk : m_clk;

    logic [31:0] data_in;
    logic [31:0] data_out;
    logic [31:0] address;
    logic write_enable;

    Core processor_core (
        .clk(a_clk),
        .rst(rst),
        .data_in(data_in),
        .data_out(data_out),
        .address(address),
        .write_enable(write_enable),
        .debug_out(led[15:8])
    );

    logic [7:0] code [0:255];
    logic [31:0] code_address;
    logic [31:0] code_out;
    assign code_out = {code[code_address + 3], code[code_address + 2], code[code_address + 1], code[code_address]};
    initial begin
        $readmemh("program.hex", code);
    end

    logic [31:0] memory_address;
    logic [31:0] memory_in;
    logic [1:0] memory_size;
    logic memory_write_enable;
    logic [31:0] memory_out;

    /*Memory memory(
        .clk(a_clk),
        .memory_address(memory_address),
        .memory_in(memory_in),
        .memory_size(memory_size),
        .memory_write_enable(memory_write_enable),
        .memory_out(memory_out)
    );*/

    logic [31:0] input_in = {24'b0, sw};

    logic [31:0] output_in;
    logic [31:0] output_address;
    logic [31:0] output_out;
    logic [1:0] output_size;
    logic output_write_enable;

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


    logic was_pressed = 1'b0;
    logic [26:0] debounce_counter = 27'd0;
    
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