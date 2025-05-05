module ALU(
    input clk,
    input logic [3:0] opcode,
    input logic [31:0] a,
    input logic [31:0] b,
    output logic [31:0] result
);

    always_ff @(posedge clk) begin
        case (opcode)
            4'b0000: result <= a + b;
            4'b0001: result <= a - b;
            4'b0010: (* use_dsp = "yes" *) result <= a * b;
            // 4'b0011: result <= a / b;
            4'b0100: result <= a & b;
            4'b0110: result <= a | b;
            4'b0111: result <= a ^ b;
            4'b1000: result <= a << b[4:0];
            4'b1001: result <= a >> b[4:0];
            4'b1010: result <= a >>> b[4:0];
            // 4'b1100: result <= a % b;
            default: result <= 32'b0;
        endcase
    end

endmodule