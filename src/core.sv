(* use_dsp = "yes" *)
typedef enum logic [2:0] {
    FETCH = 3'b000,
    FETCH_IMM = 3'b001,
    FETCH_IMEM = 3'b010,
    DECODE = 3'b011,
    EXECUTE = 3'b100,
    MEMORY = 3'b101,
    WRITEBACK = 3'b110,
    HALT = 3'b111
} cpu_state_t;

module Core(
    input clk,
    input rst,
    input enable_step,
    input [31:0] data_in,
    output logic [31:0] data_out,
    output logic [31:0] address,
    output logic write_enable,
    output logic [1:0] data_size,
    output logic [7:0] debug_out
);

    cpu_state_t state;

    (* ram_style = "distributed" *) logic [31:0] gp_registers[0:7];
    (* ram_style = "distributed" *) logic [31:0] special_registers[0:7];

    logic [2:0] rsrc1;
    logic [2:0] rsrc2;
    logic [2:0] rdest;

    logic [31:0] immediate;
    logic [31:0] imem;

    logic [7:0] opcode;
    control_signal_t control_signal;
    logic [3:0] alu_opcode;

    logic [31:0] rsrc1_value;
    logic [31:0] rsrc2_value;
    logic [31:0] alu_result;

    logic [1:0] internal_data_size;
    logic extend_sign;

    control_signal_t control_signal_inst;
    logic [3:0] alu_opcode_inst;
    logic [31:0] alu_result_inst;

    CU cu (
        .opcode(opcode),
        .control_signal(control_signal_inst),
        .alu_opcode(alu_opcode_inst)
    );

    ALU alu (
        .clk(clk),
        .opcode(alu_opcode),
        .a(rsrc1_value),
        .b(control_signal.alu_b_use_immediate ? immediate : rsrc2_value),
        .result(alu_result_inst)
    );

    always_ff @(posedge clk) begin
        alu_opcode <= alu_opcode_inst;
        alu_result <= alu_result_inst;
        control_signal <= control_signal_inst;
    end

    logic enable_jump;
    always_comb begin
        unique case (control_signal.jump_condition)
            JC_ALWAYS: enable_jump = 1'b1;
            JC_IF_ZERO: enable_jump = (rsrc1_value == 32'b0);
            JC_IF_NOT_ZERO: enable_jump = (rsrc1_value != 32'b0);
            JC_IF_NEGATIVE: enable_jump = rsrc1_value[31];
            JC_IF_NOT_NEGATIVE: enable_jump = ~rsrc1_value[31];
            default: enable_jump = 1'b0; // Invalid state
        endcase
    end

    logic [2:0] opcode_type;
    assign opcode_type = data_in[7:5];

    logic [31:0] ip_inc;
    logic imm_fetch = internal_data_size[1];
    assign ip_inc =
        opcode_type == 3'b111 ? 1 :
        1 + opcode_type[2]
            + ((~opcode_type[0] | imm_fetch) ? 0 : 1);

    logic [31:0] ip_next, ip_p4;
    assign ip_next = special_registers[0] + ip_inc;
    assign ip_p4 = special_registers[0] + 4;

    logic [31:0] write_buffer;
    logic write_buffer_valid;

    always_ff @(posedge clk) begin
        address <=
            rst | state == HALT ? 32'b0 :
            ~enable_step ? address :
            state == FETCH ? ip_next :
            state == EXECUTE ? imem :
            state == MEMORY ? imem :
            state == WRITEBACK ? special_registers[0] :
            ip_p4;

        if (state == FETCH) opcode <= data_in[7:0];
        write_enable <= enable_step & state == MEMORY & control_signal.write_memory_src != WM_NO_WRITE_SRC;
        data_out <=
            control_signal.write_memory_src == WM_WRITE_SRC_RSRC1 ? rsrc1_value :
            control_signal.write_memory_src == WM_WRITE_SRC_IMMEDIATE ? immediate :
            32'b0;

        rsrc1_value <= lookup_gp_register(rsrc1);
        rsrc2_value <= lookup_gp_register(rsrc2);

        if (state == FETCH) begin
            immediate <= enforce_constraints(internal_data_size[0] ?
                opcode_type[2] ? {16'b0, data_in[31:16]} : {16'b0, data_in[23:8]} :
                opcode_type[2] ? {24'b0, data_in[23:16]} : {24'b0, data_in[15:8]});

            if (opcode_type[2] & opcode_type != 3'b111) begin
                rsrc1 <= data_in[15:12];
                rsrc2 <= data_in[11:8];
                // Let's assume that the first source is also the destination
                rdest <= data_in[15:12];
            end
        end else if (state == FETCH_IMM) begin
            immediate <= enforce_constraints({24'b0, data_in[15:8]});
        end

        if (state == EXECUTE & enable_jump & enable_step) begin
            case (control_signal.jmp_src)
                JS_NO_JUMP_SRC: begin end // No Jump
                JS_JUMP_SRC_RSRC1: special_registers[0] <= rsrc1_value;
                JS_JUMP_SRC_IMMEDIATE: (* use_dsp = "yes" *) special_registers[0] <= special_registers[0] + immediate;
                JS_JUMP_SRC_ADDR: special_registers[0] <= imem;
            endcase
        end

        if (state == FETCH_IMEM) imem <= data_in;

        if (state == WRITEBACK & enable_step) begin
            case (control_signal.write_register_src)
                WR_WRITE_SRC_ALU: write_buffer <= alu_result;
                WR_WRITE_SRC_RSRC2: write_buffer <= rsrc2_value;
                WR_WRITE_SRC_MEMORY: write_buffer <= data_in;
                WR_WRITE_SRC_IMMEDIATE: write_buffer <= immediate;
            endcase
            write_buffer_valid <= control_signal.write_register_src != WR_NO_WRITE_SRC;
        end
        if (write_buffer_valid) begin
            write_gp_register(rdest, write_buffer);
        end
        
        if (control_signal.set_mode) begin
            internal_data_size <= control_signal.data_size;
            extend_sign <= control_signal.extend_sign;
        end

        state <=
            rst ? FETCH :
            ~enable_step ? state :
            state == FETCH ? (opcode_type[0] & internal_data_size[1] ? FETCH_IMM : opcode_type[1] ? FETCH_IMEM : DECODE) :
            state == FETCH_IMM ? (opcode[6] ? FETCH_IMEM : DECODE) : // opcode_type updates too early
            state == FETCH_IMEM ? DECODE :
            state == DECODE ? EXECUTE :
            state == EXECUTE ? (control_signal.halt ? HALT : MEMORY) :
            state == MEMORY ? WRITEBACK :
            state == WRITEBACK ? FETCH :
            HALT;
        
        debug_out <=
            rst ? 8'b11111111 :
            ~enable_step ? debug_out :
            state == FETCH ? data_in[7:0] :
            state == FETCH_IMM ? 8'b00000001 :
            state == FETCH_IMEM ? 8'b00000010 :
            state == DECODE ? 8'b00000011 :
            state == EXECUTE ? 8'b00000100 :
            state == MEMORY ? imem[14:8] :
            state == WRITEBACK ? immediate[7:0] :
            8'b11111111;

        if (enable_step) case (state)
            // TODO: If at edge of memory, 4 bytes could wrongly result in error
            FETCH: begin
                data_size <= opcode_type[1] ? 2'b10 : internal_data_size;
                special_registers[0] <= ip_next;
            end
            FETCH_IMM: begin
                data_size <= opcode[6] ? 2'b10 : internal_data_size;
                special_registers[0] <= ip_p4;
            end
            FETCH_IMEM: begin
                data_size <= internal_data_size;
                special_registers[0] <= ip_p4;
            end
            WRITEBACK: begin;
                data_size <= 2'b10;
            end
        endcase

        if (rst) begin
            data_size <= 2'b10;
            internal_data_size <= 2'b00;
            extend_sign <= 1'b1;

            for (integer i = 0; i < 8; i = i + 1) begin
                gp_registers[i] <= 32'b0;
                special_registers[i] <= 32'b0;
            end
        end
    end

    task automatic write_gp_register;
        input [2:0] index;
        input [31:0] value;
        begin
            case (data_size)
                2'b00: gp_registers[index][7:0] <= value[7:0];
                2'b01: gp_registers[index][15:0] <= value[15:0];
                2'b10, 2'b11: gp_registers[index] <= value;
            endcase
        end
    endtask

    function [31:0] lookup_gp_register;
        input [2:0] index;
        begin
            lookup_gp_register = enforce_constraints(gp_registers[index]);
        end
    endfunction


    function [31:0] enforce_constraints;
        input [31:0] value;
        begin
            unique case (internal_data_size)
                2'b00: enforce_constraints = extend_sign ? {{24{value[7]}}, value[7:0]} : {24'b0, value[7:0]};
                2'b01: enforce_constraints = extend_sign ? {{16{value[15]}}, value[15:0]} : {16'b0, value[15:0]};
                2'b10, 2'b11: enforce_constraints = value;
            endcase
        end
    endfunction

endmodule