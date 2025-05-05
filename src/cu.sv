typedef struct packed {
    logic halt;
    logic rsrc1_special;
    logic rdest_special;
    logic alu_b_use_immediate;
    logic [2:0] write_register_src;
    logic [1:0] write_memory_src;
    logic [1:0] jmp_src;
    logic [2:0] jump_condition;
} control_signal_t;

typedef enum logic [2:0] {
    WR_NO_WRITE_SRC = 3'd0,
    WR_WRITE_SRC_RDEST = 3'd1,
    WR_WRITE_SRC_RSRC2 = 3'd2,
    WR_WRITE_SRC_MEMORY = 3'd3,
    WR_WRITE_SRC_IMMEDIATE = 3'd4
} write_register_src_enum_t;

typedef enum logic [1:0] {
    WM_NO_WRITE_SRC = 2'd0,
    WM_WRITE_SRC_RSRC1 = 2'd1,
    WM_WRITE_SRC_IMMEDIATE = 2'd2
} write_memory_src_enum_t;

typedef enum logic [1:0] {
    JS_NO_JUMP_SRC = 2'd0,
    JS_JUMP_SRC_RDEST = 2'd1,
    JS_JUMP_SRC_IMMEDIATE = 2'd2,
    JS_JUMP_SRC_ADDR = 2'd3
} jump_src_enum_t;

typedef enum logic [2:0] {
    JC_ALWAYS = 3'b000,
    JC_IF_ZERO = 3'b010,
    JC_IF_NOT_ZERO = 3'b011,
    JC_IF_NEGATIVE = 3'b100,
    JC_IF_NOT_NEGATIVE = 3'b101
} jump_condition_enum_t;

module CU(
    input logic clk,
    input logic rst,
    input logic [7:0] opcode,
    output logic [3:0] alu_opcode,
    output control_signal_t control_signal
);

    control_signal_t control_signal_reg;
    assign control_signal = control_signal_reg;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            control_signal_reg <= '0;
            alu_opcode <= 4'b0;
        end else begin
            control_signal_reg <= '0;

            case (opcode)
                8'b00000000: begin // nop
                    control_signal_reg <= '{default:0};
                end
                8'b00000011: begin // hlt
                    control_signal_reg <= '{default:0, halt:1'b1};
                end

                8'b00100000: // jmpr
                    control_signal_reg.jmp_src <= JS_JUMP_SRC_IMMEDIATE;

                8'b01000000: // jmpa
                    control_signal_reg.jmp_src <= JS_JUMP_SRC_ADDR;

                8'b10000000, // add
                8'b10000001, // sub
                8'b10000010, // mul
                // 8'b10000011, // div
                8'b10000100, // and
                8'b10000110, // or
                8'b10000111, // xor
                8'b10001000, // shl
                8'b10001001, // shr
                8'b10001010: // shra
                // 8'b10001100: // mod
                begin
                    control_signal_reg.write_register_src <= WR_WRITE_SRC_RDEST;
                    alu_opcode <= opcode[3:0];
                end

                8'b10010000: // cpy
                    control_signal_reg.write_register_src <= WR_WRITE_SRC_RSRC2;

                8'b10100000, // addi
                8'b10100001: // subi
                begin
                    control_signal_reg.alu_b_use_immediate <= 1'b1;
                    control_signal_reg.write_register_src <= WR_WRITE_SRC_RDEST;
                    alu_opcode <= opcode[3:0];
                end

                8'b10110000: // cpyi
                    control_signal_reg.write_register_src <= WR_WRITE_SRC_IMMEDIATE;

                8'b10110010, // jer
                8'b10110011, // jner
                8'b10110100, // jlr
                8'b10110101: // jler
                begin
                    control_signal_reg.jmp_src <= JS_JUMP_SRC_IMMEDIATE;
                    control_signal_reg.jump_condition <= opcode[2:0];
                end

                8'b11010000: // stoa
                    control_signal_reg.write_memory_src <= WM_WRITE_SRC_RSRC1;

                8'b11010001: // loda
                    control_signal_reg.write_register_src <= WR_WRITE_SRC_MEMORY;

                default: control_signal_reg.halt <= 1'b1;
            endcase
        end
    end
endmodule