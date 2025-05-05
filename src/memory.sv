module Memory(
    input clk,
    input wire [31:0] memory_address,
    input wire [31:0] memory_in,
    input wire [1:0] memory_size,
    input wire memory_write_enable,
    output reg [31:0] memory_out
);

    (* ram_style = "block" *) reg [32:0] memory [0:255];

endmodule

