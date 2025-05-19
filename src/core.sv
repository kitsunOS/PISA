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

    logic [7:0] opcode;
    control_signal_t control_signal;
    logic [3:0] alu_opcode;

    logic [31:0] immediate;
    logic [31:0] ref_addr;
    logic [2:0] rsrc1;
    logic [2:0] rsrc2;
    logic [2:0] rdest;
    logic [31:0] rsrc1_value;
    logic [31:0] rsrc2_value;
    logic [31:0] rsrc2_value_full;
    logic [31:0] alu_result;

    control_signal_t control_signal_inst;
    logic [3:0] alu_opcode_inst;
    logic [31:0] alu_result_inst;

    logic [31:0] write_buffer;
    logic write_buffer_valid;

    logic fetch_is_active;
    cpu_state_t fetch_next_state;
    logic [31:0] fetch_ip_next;
    logic [1:0] fetch_data_size;

    logic [1:0] immediate_data_size;
    logic [1:0] register_data_size;
    logic extend_sign;

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

    IFU ifu (
        .clk(clk),
        .rst(rst),
        .enable_step(enable_step),
        .state(state),
        .data_in(data_in),
        .ip_cur(special_registers[0]),
        .opcode(opcode),
        .is_active(fetch_is_active),
        .next_state(fetch_next_state),
        .ip_next(fetch_ip_next),
        .data_size(fetch_data_size),
        .rsrc1(rsrc1),
        .rsrc2(rsrc2),
        .rdest(rdest),
        .immediate(immediate),
        .ref_addr(ref_addr),
        .immediate_data_size(immediate_data_size),
        .register_data_size(register_data_size),
        .extend_sign(extend_sign)
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

    logic jump_write_ip_next = (state == EXECUTE) & enable_jump & enable_step;
    logic [31:0] jump_ip_next;
    always_comb begin
        unique case (control_signal.jmp_src)
            JS_NO_JUMP_SRC: jump_ip_next = special_registers[0];
            JS_JUMP_SRC_RSRC1: jump_ip_next = rsrc1_value;
            JS_JUMP_SRC_IMMEDIATE: jump_ip_next = special_registers[0] + immediate;
            JS_JUMP_SRC_ADDR: jump_ip_next = ref_addr;
        endcase
    end

    logic [31:0] mem_addr;
    assign mem_addr = control_signal.memory_address_src == MA_RSRC2_SRC ? rsrc2_value_full : ref_addr;

    // TODO: Read smode data sizes
    always_ff @(posedge clk) begin
         address <=
            rst || state == HALT ? 32'b0 :
            ~enable_step ? address :
            fetch_is_active ? fetch_ip_next :
            (state == EXECUTE || state == MEMORY) ? mem_addr :
            state == WRITEBACK ? special_registers[0] :
            32'b0;

        write_enable <= enable_step & (state == MEMORY) & (control_signal.write_memory_src != WM_NO_WRITE_SRC);
        data_out <=
            control_signal.write_memory_src == WM_WRITE_SRC_RSRC1 ? rsrc1_value :
            control_signal.write_memory_src == WM_WRITE_SRC_IMMEDIATE ? immediate :
            32'b0;
        
        data_size <=
            rst ? 2'b10 :
            ~enable_step ? data_size :
            fetch_is_active ? fetch_data_size :
            state == WRITEBACK ? 2'b10 :
            register_data_size;

        if (state == WRITEBACK && enable_step) begin
            case (control_signal.write_register_src)
                WR_WRITE_SRC_ALU: write_buffer <= alu_result;
                WR_WRITE_SRC_RSRC2: write_buffer <= rsrc2_value;
                WR_WRITE_SRC_MEMORY: write_buffer <= data_in;
                WR_WRITE_SRC_IMMEDIATE: write_buffer <= immediate;
            endcase
            write_buffer_valid <= control_signal.write_register_src != WR_NO_WRITE_SRC;
        end
        if (write_buffer_valid) begin
            write_buffer_valid <= 1'b0;
        end

        special_registers[0] <=
            rst ? 32'b0 :
            ~enable_step ? special_registers[0] :
            fetch_is_active ? fetch_ip_next :
            jump_write_ip_next ? jump_ip_next :
            special_registers[0];

        state <=
            rst ? FETCH :
            ~enable_step ? state :
            fetch_is_active ? fetch_next_state :
            state == DECODE ? EXECUTE :
            state == EXECUTE ? (control_signal.halt ? HALT : MEMORY) :
            state == MEMORY ? WRITEBACK :
            state == WRITEBACK ? FETCH :
            HALT;
        
        debug_out <=
            rst ? 8'b11111111 :
            ~enable_step ? debug_out :
            fetch_is_active ? data_in[7:0] :
            state == FETCH_IMM ? 8'b10000001 :
            state == FETCH_IMEM ? 8'b00000010 :
            state == DECODE ? 8'b00000011 :
            state == EXECUTE ? 8'b00000100 :
            state == MEMORY ? 8'b00000101 :
            state == WRITEBACK ? 8'b00000110 :
            8'b11111111;

        if (rst) begin
            for (int i = 1; i < 8; i++) begin
                special_registers[i] <= 32'b0;
            end
        end
    end

endmodule