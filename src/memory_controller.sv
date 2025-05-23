module MemoryController(
    input clk,
    input logic enable_step,

    input logic [31:0] address,
    input logic write_enable,
    input logic [1:0] data_size,
    input logic [31:0] data_in,
    output logic [31:0] data_out,
    output logic memory_error,

    input logic [31:0] code_in,
    output logic [31:0] code_address,

    input logic [31:0] memory_in,
    output logic [31:0] memory_address,
    output logic [31:0] memory_out,
    output logic [1:0] memory_size,
    output logic memory_write_enable,

    input logic [31:0] vram_in,
    output logic [31:0] vram_address,
    output logic [31:0] vram_out,
    output logic [1:0] vram_size,
    output logic vram_write_enable,

    input logic [31:0] input_in,

    input logic [31:0] output_in,
    output logic [31:0] output_address,
    output logic [31:0] output_out,
    output logic [1:0] output_size,
    output logic output_write_enable
);

    localparam CODE_START = 32'd0;
    localparam CODE_END = 32'd255;
    localparam MEMORY_START = 32'd256;
    localparam MEMORY_END = 32'd511;
    localparam VRAM_START = 32'd512;
    localparam VRAM_END = 32'd4511;
    localparam INPUT_START = 32'd4512;
    localparam INPUT_END = 32'd4515;
    localparam OUTPUT_START = 32'd4516;
    localparam OUTPUT_END = 32'd4519;

    logic [31:0] end_addr;
    logic is_code_range;
    logic is_memory_range;
    logic is_vram_range;
    logic is_input_range;
    logic is_output_range;
    assign end_addr = end_address(address, data_size);
    assign is_code_range = (address >= CODE_START && end_addr <= CODE_END);
    assign is_memory_range = (address >= MEMORY_START && end_addr <= MEMORY_END);
    assign is_vram_range = (address >= VRAM_START && end_addr <= VRAM_END);
    assign is_input_range = (address >= INPUT_START && end_addr <= INPUT_END);
    assign is_output_range = (address >= OUTPUT_START && end_addr <= OUTPUT_END);

    logic is_not_aligned;
    assign is_not_aligned =
        data_size == 2'b00 ? 1'b0 :
        (data_size == 2'b01) & address[0] ? 1'b1 :
        (data_size == 2'b10) & (|address[1:0]) ? 1'b1 :
        1'b0;

    logic bad_data_size;
    assign bad_data_size = data_size == 2'b11;
    assign memory_error_inst =
        (is_not_aligned && !is_code_range)
        | bad_data_size
        | (write_enable & !(is_memory_range | is_vram_range | is_output_range))
        | (!write_enable & !(is_code_range | is_memory_range | is_vram_range | is_input_range | is_output_range));

    logic [31:0] input_address;
    assign code_address = address - CODE_START;
    assign memory_address = address - MEMORY_START;
    assign vram_address = address - VRAM_START;
    assign input_address = address - INPUT_START;
    assign output_address = address - OUTPUT_START;

    assign memory_size = data_size;
    assign vram_size = data_size;
    assign output_size = data_size;

    assign write_ready = write_enable & !memory_error_inst;
    assign memory_write_enable = is_memory_range & write_ready;
    assign vram_write_enable = is_vram_range & write_ready;
    assign output_write_enable = is_output_range & write_ready;
    assign memory_out = data_in;
    assign vram_out = data_in;
    assign output_out = data_in;

    logic [31:0] data_out_raw;
    assign data_out_raw =
        memory_error_inst | write_enable ? 32'b0 :
        is_code_range ? code_in :
        is_memory_range ? memory_in :
        is_vram_range ? vram_in :
        is_input_range ? input_in :
        is_output_range ? output_in :
        32'b0;
    
    always_ff @(posedge clk) begin
        if (enable_step) begin
            data_out <= truncate_data(data_out_raw, data_size);
            memory_error <= memory_error_inst;
        end
    end

    function [31:0] end_address;
        input [31:0] address;
        input [1:0] size;
        begin
            case (size)
                2'b00: end_address = address;
                2'b01: end_address = address + 1;
                2'b10: end_address = address + 3;
                default: end_address = address;
            endcase
        end
    endfunction

    function [31:0] truncate_data;
        input [31:0] data;
        input [1:0] size;
        begin
            case (size)
                2'b00: truncate_data = {24'b0, data[7:0]};
                2'b01: truncate_data = {16'b0, data[15:0]};
                2'b10: truncate_data = data;
                default: truncate_data = data;
            endcase
        end
    endfunction

endmodule