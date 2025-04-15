module ALU(
    input wire [3:0] opcode,
    input wire [31:0] a,
    input wire [31:0] b,
    output reg [31:0] result
);

    (* use_dsp = "yes" *) wire [31:0] mul_result = a * b;

    always @ (*) begin
        case (opcode)
            4'b0000: result = a + b;
            4'b0001: result = a - b;
            4'b0010: result = mul_result;
            // 4'b0011: result = a / b;
            4'b0100: result = a & b;
            4'b0110: result = a | b;
            4'b0111: result = a ^ b;
            4'b1000: result = a << b;
            4'b1001: result = a >> b;
            4'b1010: result = a >>> b;
            // 4'b1100: result = a % b;
            default: result = 8'b0;
        endcase
    end

endmodule