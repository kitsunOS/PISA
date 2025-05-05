module ALU(
    input clk,
    input logic [3:0] opcode,
    input logic [31:0] a,
    input logic [31:0] b,
    output logic [31:0] result
);

    (* use_dsp = "yes" *) wire [31:0] add_res = a + b;
    (* use_dsp = "yes" *) wire [31:0] sub_res = a - b;
    (* use_dsp = "yes" *) wire [31:0] mul_res = a * b;
    // (* use_dsp = "yes" *) wire [31:0] div_res = a / b;

    wire [31:0] and_res = a & b;
    wire [31:0] or_res  = a | b;
    wire [31:0] xor_res = a ^ b;

    wire [31:0] sll_res = a << b[4:0];
    wire [31:0] srl_res = a >> b[4:0];
    wire [31:0] sra_res = a >>> b[4:0];

    always_ff @(posedge clk) begin
        unique case (opcode)
            4'b0000: result <= add_res;
            4'b0001: result <= sub_res;
            4'b0010: result <= mul_res;
            // 4'b0011: result <= div_res;
            4'b0100: result <= and_res;
            4'b0110: result <= or_res;
            4'b0111: result <= xor_res;
            4'b1000: result <= sll_res;
            4'b1001: result <= srl_res;
            4'b1010: result <= sra_res;
            // 4'b1100: result <= a % b;
            default: result <= 32'b0;
        endcase
    end

endmodule