module ALU(
    input wire [3:0] opcode,
    input wire [7:0] a,
    input wire [7:0] b,
    output reg [7:0] result
);

(* use_dsp48 = "yes" *) wire [7:0] mul_result = a * b;

always @ (*) begin
    result = 8'b0;
    case (opcode)
        4'b0000: result = a + b;
        4'b0001: result = a - b;
        4'b0010: result = mul_result;
        4'b0011: result = a / b;
        4'b0100: result = a & b;
        4'b0110: result = a | b;
        4'b0111: result = a ^ b;
        4'b1000: result = a << b;
        4'b1001: result = a >> b;
        4'b1010: result = a >>> b;
        4'b1100: result = a % b;
    endcase
end

endmodule;