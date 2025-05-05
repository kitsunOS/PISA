module Memory(
    input clk,
    input logic [31:0] memory_address,
    input logic [31:0] memory_in,
    input logic [1:0] memory_size,
    input logic memory_write_enable,
    output logic [31:0] memory_out
);

    (* ram_style = "block" *) logic [32:0] memory [0:255];

endmodule

