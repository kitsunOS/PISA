import mem_utils::enforce_constraints;

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
    logic [31:0] rsrc2_value_full;
    logic [31:0] alu_result;

    logic [1:0] global_immediate_data_size;
    logic [1:0] global_register_data_size;
    logic global_extend_sign;
    logic [1:0] immediate_data_size;
    logic [1:0] register_data_size;
    logic extend_sign;

    control_signal_t control_signal_inst;
    logic [3:0] alu_opcode_inst;
    logic [31:0] alu_result_inst;

    logic [31:0] write_buffer;
    logic write_buffer_valid;

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

    RegisterFile rf (
        .clk(clk),
        .rst(rst),
        .rsrc1(rsrc1),
        .rsrc2(rsrc2),
        .rdest(rdest),
        .data_size(data_size),
        .write_enable(write_buffer_valid),
        .write_data(write_buffer),
        .rsrc1_value(rsrc1_value),
        .rsrc2_value(rsrc2_value),
        .rsrc2_value_full(rsrc2_value_full)
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
            JC_IF_ZERO: enable_jump = rsrc1_value == 32'b0;
            JC_IF_NOT_ZERO: enable_jump = rsrc1_value != 32'b0;
            JC_IF_NEGATIVE: enable_jump = rsrc1_value[31];
            JC_IF_NOT_NEGATIVE: enable_jump = ~rsrc1_value[31];
            default: enable_jump = 1'b0; // Invalid state
        endcase
    end

    logic [2:0] opcode_type;
    assign opcode_type = data_in[7:5];

    logic is_prefix;
    assign is_prefix = opcode_type == 3'b111;

    logic [31:0] ip_inc;
    logic imm_fetch = immediate_data_size[1];
    assign ip_inc =
        data_in[7:0] == 8'b11100000 ? 2 :
        (1 + opcode_type[2]
            + ((~opcode_type[0] | imm_fetch) ? 0 : (immediate_data_size[0] ? 2 : 1)));

    logic [31:0] ip_next;
    assign ip_next = special_registers[0] + (state == FETCH ? ip_inc : 4);

    logic [31:0] mem_addr;
    assign mem_addr = control_signal.memory_address_src == MA_RSRC2_SRC ? rsrc2_value_full : imem;

    logic should_fetch_imm = opcode_type[0] & immediate_data_size[1];

    // TODO: Read smode data sizes
    always_ff @(posedge clk) begin
        address <=
            rst | state == HALT ? 32'b0 :
            ~enable_step ? address :
            (state == EXECUTE | state == MEMORY) ? mem_addr :
            state == WRITEBACK ? special_registers[0] :
            ip_next;

        write_enable <= enable_step & state == MEMORY & (control_signal.write_memory_src != WM_NO_WRITE_SRC);
        data_out <=
            control_signal.write_memory_src == WM_WRITE_SRC_RSRC1 ? rsrc1_value :
            control_signal.write_memory_src == WM_WRITE_SRC_IMMEDIATE ? immediate :
            32'b0;

        if (state == FETCH) begin
            opcode <= data_in[7:0];
            immediate <= enforce_constraints(immediate_data_size, extend_sign, immediate_data_size[0] ?
                opcode_type[2] ? {16'b0, data_in[31:16]} : {16'b0, data_in[23:8]} :
                opcode_type[2] ? {24'b0, data_in[23:16]} : {24'b0, data_in[15:8]});

            if (opcode_type[2]) begin
                rsrc1 <= data_in[15:12];
                rsrc2 <= data_in[11:8];
                // Let's assume that the first source is also the destination
                rdest <= data_in[15:12];
            end
        end

        if (state == FETCH & (data_in[7:0] == 8'b11100000)) begin
            immediate_data_size <= data_in[9:8];
            register_data_size <= data_in[11:10];
            extend_sign <= data_in[14];
            if (data_in[15]) begin
                global_immediate_data_size <= data_in[9:8];
                global_register_data_size <= data_in[11:10];
                global_extend_sign <= data_in[14];
            end
        end
        
        if (state == FETCH_IMM) begin
            immediate <= enforce_constraints(immediate_data_size, extend_sign, {24'b0, data_in[15:8]});
        end

        if (state == EXECUTE & enable_jump & enable_step) begin
            case (control_signal.jmp_src)
                JS_NO_JUMP_SRC: begin end // No Jump
                JS_JUMP_SRC_RSRC1: special_registers[0] <= rsrc1_value;
                JS_JUMP_SRC_IMMEDIATE: special_registers[0] <= special_registers[0] + immediate;
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
            immediate_data_size <= global_immediate_data_size;
            register_data_size <= global_register_data_size;
            extend_sign <= global_extend_sign;
        end
        if (write_buffer_valid) begin
            write_buffer_valid <= 1'b0;
        end

        state <=
            rst ? FETCH :
            ~enable_step ? state :
            state == FETCH ? (is_prefix ? FETCH : should_fetch_imm ? FETCH_IMM : opcode_type[1] ? FETCH_IMEM : DECODE) :
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
                data_size <=
                    is_prefix ? 2'b10 :
                    should_fetch_imm ? immediate_data_size :
                    opcode_type[1] ? 2'b10 :
                    register_data_size;
                special_registers[0] <= ip_next;
            end
            FETCH_IMM: begin
                data_size <= opcode[6] ? 2'b10 : register_data_size;
                special_registers[0] <= ip_next;
            end
            FETCH_IMEM: begin
                data_size <= register_data_size;
                special_registers[0] <= ip_next;
            end
            WRITEBACK: begin;
                data_size <= 2'b10;
            end
        endcase

        if (rst) begin
            data_size <= 2'b10;
            global_immediate_data_size <= 2'b00;
            global_register_data_size <= 2'b10;
            global_extend_sign <= 1'b1;
            immediate_data_size <= 2'b00;
            register_data_size <= 2'b10;
            extend_sign <= 1'b1;
            
            for (int i = 0; i < 8; i++) begin
                special_registers[i] <= 32'b0;
            end
        end
    end

endmodule