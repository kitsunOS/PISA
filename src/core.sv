import mem_utils::enforce_constraints;

// Had to put Memory before Execute for performance reasons
typedef enum logic [2:0] {
    FETCH = 3'b000,
    DECODE = 3'b001,
    MEMORY = 3'b010,
    EXECUTE = 3'b011,
    WRITEBACK = 3'b100,
    HALT = 3'b101
} cpu_state_t;

(* use_dsp = "yes" *)
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
    logic refetch;

    control_signal_t control_signal;
    logic [3:0] alu_opcode;
    logic [31:0] alu_result;

    control_signal_t control_signal_inst;
    logic [3:0] alu_opcode_inst;

    logic [31:0] immediate_addr;
    logic [31:0] ref_addr_addr;
    logic [31:0] ref_addr;
    logic [2:0] rsrc1;
    logic [2:0] rsrc2;
    logic [2:0] rdest;

    logic [31:0] rsrc1_value;
    logic [31:0] rsrc2_value;
    logic [31:0] rsrc2_value_full;
    logic [31:0] immediate;
    logic [31:0] immediate_inst;

    logic [31:0] write_buffer;
    logic write_buffer_valid;

    logic [1:0] immediate_data_size;
    logic [1:0] register_data_size;
    logic extend_sign;

    logic [31:0] fetch_ip_next;

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
        .result(alu_result)
    );

    RegisterFile rf (
        .clk(clk),
        .rst(rst),
        .rsrc1(rsrc1),
        .rsrc2(rsrc2),
        .rdest(rdest),
        .data_size(register_data_size),
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
        .data_in(data_in),
        .ip_cur(special_registers[0]),
        .state(state),
        .opcode(opcode),
        .ip_next(fetch_ip_next),
        .refetch(refetch),
        .rsrc1(rsrc1),
        .rsrc2(rsrc2),
        .rdest(rdest),
        .immediate_addr(immediate_addr),
        .ref_addr_addr(ref_addr_addr),
        .immediate_data_size(immediate_data_size),
        .register_data_size(register_data_size),
        .extend_sign(extend_sign)
    );

    always_ff @(posedge clk) begin
        alu_opcode <= alu_opcode_inst;
        control_signal <= control_signal_inst;
    end

    assign immediate_inst = enforce_constraints(immediate_data_size, extend_sign, data_in);

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
            JS_JUMP_SRC_IMMEDIATE: jump_ip_next = special_registers[0] + immediate_inst;
            JS_JUMP_SRC_ADDR: jump_ip_next = ref_addr;
        endcase
    end

    logic [31:0] mem_addr;
    assign mem_addr = control_signal.memory_address_src == MA_RSRC2_SRC ? rsrc2_value_full : data_in;

    logic [31:0] mem_val;
    always_comb begin
        case (control_signal.write_register_src)
            WR_WRITE_SRC_ALU: write_buffer = alu_result;
            WR_WRITE_SRC_RSRC2: write_buffer = rsrc2_value;
            WR_WRITE_SRC_MEMORY: write_buffer = mem_val;
            WR_WRITE_SRC_IMMEDIATE: write_buffer = immediate;
        endcase
    end

    always_ff @(posedge clk) begin
        state <=
            rst ? FETCH :
            ~enable_step ? state :
            state == FETCH ? DECODE :
            state == DECODE ? (refetch ? FETCH : MEMORY) :
            state == MEMORY ? EXECUTE :
            state == EXECUTE ? (control_signal.halt ? HALT : WRITEBACK) :
            state == WRITEBACK ? FETCH :
            HALT;

         address <=
            rst || state == HALT ? 32'b0 :
            ~enable_step ? address :
            state == FETCH ? (refetch ? fetch_ip_next : ref_addr_addr) :
            state == DECODE ? immediate_addr :
            state == MEMORY ? mem_addr :
            jump_write_ip_next ? jump_ip_next :
            state == EXECUTE ? special_registers[0] :
            32'b0;
        
        special_registers[0] <=
            rst ? 32'b0 :
            ~enable_step ? special_registers[0] :
            state == FETCH ? fetch_ip_next :
            jump_write_ip_next ? jump_ip_next :
            special_registers[0];
        
        data_size <=
            rst ? 2'b10 :
            ~enable_step ? data_size :
            state == FETCH ? 2'b10 :
            state == DECODE ? immediate_data_size :
            state == MEMORY ? register_data_size :
            state == EXECUTE ? 2'b10 :
            2'b10;

        debug_out <=
            rst ? 8'b11111111 :
            ~enable_step ? debug_out :
            state == FETCH ? data_in[7:0] :
            state == DECODE ? 8'b00000001 :
            state == MEMORY ? 8'b00000010 :
            state == EXECUTE ? 8'b00000011 :
            state == WRITEBACK ? immediate[7:0] :
            8'b11111111;
        
        if (enable_step) write_enable <= (state == MEMORY) & (control_signal.write_memory_src != WM_NO_WRITE_SRC);
        data_out <= control_signal.write_memory_src == WM_WRITE_SRC_RSRC1 ? rsrc1_value : 32'b0;
        
        if (state == MEMORY && enable_step) ref_addr <= data_in;
        if (state == EXECUTE && enable_step) immediate <= immediate_inst;

        if (state == WRITEBACK && enable_step) mem_val <= data_in;
        if (state == WRITEBACK && enable_step && control_signal.write_register_src != WR_NO_WRITE_SRC)
            write_buffer_valid <= 1'b1;
        else if (enable_step)
            write_buffer_valid <= 1'b0;

        if (rst) begin
            for (int i = 1; i < 8; i++) begin
                special_registers[i] <= 32'b0;
            end
        end
    end

endmodule