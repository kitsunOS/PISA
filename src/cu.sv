typedef struct packed {
    logic halt;
    logic rsrc1_special;
    logic rdest_special;
    logic alu_b_use_immediate;
    logic [2:0] write_register_src;
    logic [1:0] write_memory_src;
    logic [1:0] jmp_src;
    logic [2:0] jump_condition;
    logic set_mode;
    logic [1:0] data_size;
    logic extend_sign;
} control_signal_t;

typedef enum logic [2:0] {
    WR_NO_WRITE_SRC = 3'd0,
    WR_WRITE_SRC_ALU = 3'd1,
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
    JS_JUMP_SRC_RSRC1 = 2'd1,
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

    logic op_nop = opcode == 8'b00000000;
    logic op_hlt = opcode == 8'b00000011;
    logic op_jmpr = opcode == 8'b00100000;
    logic op_jmpa = opcode == 8'b01000000;
    logic op_add = opcode == 8'b10000000;
    logic op_sub = opcode == 8'b10000001;
    logic op_mul = opcode == 8'b10000010;
    // logic op_div = opcode == 8'b10000011;
    logic op_and = opcode == 8'b10000100;
    logic op_or = opcode == 8'b10000110;
    logic op_xor = opcode == 8'b10000111;
    logic op_shl = opcode == 8'b10001000;
    logic op_shr = opcode == 8'b10001001;
    logic op_shra = opcode == 8'b10001010;
    // logic op_mod = opcode == 8'b10001100;
    logic op_cpy = opcode == 8'b10010000;
    logic op_jmpto = opcode == 8'b10011000;
    logic op_addi = opcode == 8'b10100000;
    logic op_subi = opcode == 8'b10100001;
    logic op_cpyi = opcode == 8'b10110000;
    logic op_jer = opcode == 8'b10110010;
    logic op_jner = opcode == 8'b10110011;
    logic op_jlr = opcode == 8'b10110100;
    logic op_jler = opcode == 8'b10110101;
    logic op_stoa = opcode == 8'b11010000;
    logic op_loda = opcode == 8'b11010001;
    logic op_smode = opcode[7:5] == 3'b111;

    logic has_immediate = opcode[5];
    logic is_plain_arithmatic =
        (opcode >= 8'b10000000 && opcode < 8'b10010000)
        || (opcode >= 8'b10100000 && opcode < 8'b10110000);
    logic is_valid_opcode =
        op_nop | op_hlt | op_jmpr | op_jmpa |
        op_add | op_sub | op_mul | op_and | op_or | op_xor |
        op_shl | op_shr | op_shra | op_cpy | op_jmpto |
        op_addi | op_subi | op_cpyi |
        op_jer | op_jner | op_jlr | op_jler |
        op_stoa | op_loda |
        op_smode;

    assign control_signal.halt = !rst & (op_hlt | !is_valid_opcode);
    assign control_signal.rsrc1_special = 0;
    assign control_signal.rdest_special = 0;
    assign control_signal.alu_b_use_immediate = !rst & has_immediate;
    assign control_signal.write_register_src = rst ? WR_NO_WRITE_SRC :
        is_plain_arithmatic ? WR_WRITE_SRC_ALU :
        op_cpy ? WR_WRITE_SRC_RSRC2 :
        op_cpyi ? WR_WRITE_SRC_IMMEDIATE :
        op_loda ? WR_WRITE_SRC_MEMORY : WR_NO_WRITE_SRC;
    assign control_signal.write_memory_src = !rst & op_stoa ? WM_WRITE_SRC_RSRC1 : WM_NO_WRITE_SRC;
    assign control_signal.jmp_src = rst ? JS_NO_JUMP_SRC :
        op_jmpr ? JS_JUMP_SRC_IMMEDIATE :
        op_jmpa ? JS_JUMP_SRC_ADDR :
        op_jer ? JS_JUMP_SRC_IMMEDIATE :
        op_jner ? JS_JUMP_SRC_IMMEDIATE :
        op_jlr ? JS_JUMP_SRC_IMMEDIATE :
        op_jler ? JS_JUMP_SRC_IMMEDIATE :
        op_jmpto ? JS_JUMP_SRC_RSRC1 :
        JS_NO_JUMP_SRC;
    assign control_signal.jump_condition = rst ? JC_ALWAYS : opcode[2:0];
    assign control_signal.set_mode = rst ? 1'b0 : op_smode;
    assign control_signal.data_size = rst ? 2'b00 : opcode[1:0];
    assign control_signal.extend_sign = rst ? 1'b0 : opcode[4];

    assign alu_opcode = opcode[3:0];
    
endmodule