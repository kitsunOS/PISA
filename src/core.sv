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

    logic [31:0] ip_inc;
    logic [2:0] opcode_type = data_in[7:5];
    logic imm_fetch = internal_data_size[1];
    always_comb begin
        unique case (opcode_type)
            3'b000: ip_inc = 1;
            3'b001: ip_inc = imm_fetch ? 1 : 2;
            3'b010: ip_inc = 1;
            3'b011: ip_inc = imm_fetch ? 1 : 2;
            3'b100: ip_inc = 2;
            3'b101: ip_inc = imm_fetch ? 2 : 3;
            3'b110: ip_inc = 2;
            default: ip_inc = 0; // Invalid state
        endcase
    end

    logic [31:0] ip_next, ip_p4;
    (* use_dsp = "yes" *) assign ip_next = special_registers[0] + ip_inc;
    (* use_dsp = "yes" *) assign ip_p4 = special_registers[0] + 4;

    always_ff @(posedge clk) begin
        case (state)
            // TODO: If at edge of memory, 4 bytes could wrongly result in error
            FETCH: begin
                opcode <= data_in[7:0];
                debug_out <= data_in[7:0];
                data_size <= internal_data_size;

                state <= DECODE;
                if (opcode_type != 3'b111) begin
                    if (opcode_type[2]) begin
                        rsrc1 <= data_in[15:12];
                        rsrc2 <= data_in[11:8];
                        // Let's assume that the first source is also the destination
                        rdest <= data_in[15:12];
                    end
                    if (opcode_type[1]) begin
                        data_size <= 2'b10;
                        state <= FETCH_IMEM;
                    end
                    if (opcode_type[0]) begin
                        if (internal_data_size[1]) begin
                            data_size <= 2'b10;
                            state <= FETCH_IMM;
                        end else begin
                            immediate <= enforce_constraints(internal_data_size[0] ?
                                opcode_type[2] ? {16'b0, data_in[31:16]} : {16'b0, data_in[23:8]} :
                                opcode_type[2] ? {24'b0, data_in[23:16]} : {24'b0, data_in[15:8]});
                        end
                    end
                end
                address <= ip_next;
                special_registers[0] <= ip_next;
            end
            FETCH_IMM: begin
                debug_out <= 8'b00000001;
                immediate <= enforce_constraints({24'b0, data_in[15:8]});
                data_size <= opcode_type[1] ? 2'b10 : internal_data_size;
                address <= ip_p4;
                special_registers[0] <= ip_p4;
                state <= opcode_type[1] ? FETCH_IMEM : DECODE;
            end
            FETCH_IMEM: begin
                debug_out <= 8'b00000010;
                imem <= data_in;
                data_size <= internal_data_size;
                address <= ip_p4;
                special_registers[0] <= ip_p4;
                state <= DECODE;
            end
            DECODE: begin
                debug_out <= 8'b00000011;
                rsrc1_value = lookup_gp_register(rsrc1);
                rsrc2_value = lookup_gp_register(rsrc2);
                state <= EXECUTE;
            end
            EXECUTE: begin
                debug_out <= 8'b00000100;
                if (control_signal.halt) begin
                    state <= HALT;
                end else begin
                    address <= imem;
                    state <= MEMORY;

                    if (enable_jump) begin
                        case (control_signal.jmp_src)
                            JS_NO_JUMP_SRC: begin end // No Jump
                            JS_JUMP_SRC_RSRC1: special_registers[0] <= rsrc1_value;
                            JS_JUMP_SRC_IMMEDIATE: (* use_dsp = "yes" *) special_registers[0] <= special_registers[0] + immediate;
                            JS_JUMP_SRC_ADDR: special_registers[0] <= imem;
                            default: state <= HALT; // Invalid state
                        endcase
                    end
                    
                    if (control_signal.set_mode) begin
                        internal_data_size <= control_signal.data_size;
                        extend_sign <= control_signal.extend_sign;
                    end
                end
            end
            MEMORY: begin
                debug_out <= 8'b00000101;
                case (control_signal.write_memory_src)
                    WM_WRITE_SRC_RSRC1: begin
                        data_out <= lookup_gp_register(rsrc1);
                        write_enable <= 1'b1;
                    end
                    WM_WRITE_SRC_IMMEDIATE: begin
                        data_out <= immediate;
                        write_enable <= 1'b1;
                    end
                endcase
                state <= WRITEBACK;
            end
            WRITEBACK: begin;
                debug_out <= 8'b00000110;
                write_enable <= 1'b0;

                case (control_signal.write_register_src)
                    WR_WRITE_SRC_ALU: write_gp_register(rdest, alu_result);
                    WR_WRITE_SRC_RSRC2: write_gp_register(rdest, rsrc2_value);
                    WR_WRITE_SRC_MEMORY: write_gp_register(rdest, data_in);
                    WR_WRITE_SRC_IMMEDIATE: write_gp_register(rdest, immediate);
                endcase

                state <= FETCH;
                data_size <= 2'b10;
                address <= special_registers[0];
            end
            HALT: begin
                debug_out <= 8'b11111111;
            end
        endcase

        if (rst) begin
            state <= FETCH;
            address <= 32'b0;
            data_out <= 32'b0;
            write_enable <= 1'b0;
            data_size <= 2'b10;
            internal_data_size <= 2'b00;
            extend_sign <= 1'b1;
            debug_out <= 8'b11111111;

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