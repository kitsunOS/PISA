module Memory(
    input clk,
    input wire [31:0] memory_address,
    input wire [31:0] memory_in,
    input wire [1:0] memory_size,
    input wire memory_write_enable,
    output reg [31:0] memory_out
);

    (* ram_style = "block" *) reg [7:0] memory [0:255];

    reg [7:0] r0, r1, r2, r3;

    always_ff @(posedge clk) begin
        if (memory_write_enable) begin
            case (memory_size)
                2'b00: memory[memory_address] <= memory_in[7:0];
                2'b01: begin
                    memory[memory_address] <= memory_in[7:0];
                    memory[memory_address + 1] <= memory_in[15:8];
                end
                2'b10: begin
                    memory[memory_address] <= memory_in[7:0];
                    memory[memory_address + 1] <= memory_in[15:8];
                    memory[memory_address + 2] <= memory_in[23:16];
                    memory[memory_address + 3] <= memory_in[31:24];
                end
            endcase
        end else begin
            // one read per byte, sequential accesses (BRAM-friendly)
            r0 <= memory[memory_address];
            r1 <= memory[memory_address + 1];
            r2 <= memory[memory_address + 2];
            r3 <= memory[memory_address + 3];

            case (memory_size)
                2'b00: memory_out <= {24'b0, r0};
                2'b01: memory_out <= {16'b0, r1, r0};
                2'b10: memory_out <= {r3, r2, r1, r0};
                default: memory_out <= 32'b0;
            endcase
        end
    end

endmodule

