typedef enum reg [2:0] {
    FETCH = 3'b000,
    FETCH_IMEM = 3'b001,
    DECODE = 3'b010,
    EXECUTE = 3'b011,
    MEMORY = 3'b100,
    WRITEBACK = 3'b101,
    HALT = 3'b110
} cpu_state_t;

module Core(
    input clk,
    input rst,
    input [31:0] data_in,
    output reg [31:0] data_out,
    output reg [31:0] address,
    output reg write_enable,
    output reg [7:0] debug_out
);

    cpu_state_t state;

    reg [31:0] gp_registers[0:7];
    reg [31:0] special_registers[0:7];

    reg [3:0] rsrc1;
    reg [3:0] rsrc2;
    reg [3:0] rdest;

    reg [31:0] immediate;
    reg [31:0] imem;

    reg [7:0] opcode;
    control_signal_t control_signal;
    wire [3:0] alu_opcode;

    wire [31:0] alu_result;

    CU cu (
        .clk(clk),
        .rst(rst),
        .opcode(opcode),
        .control_signal(control_signal),
        .alu_opcode(alu_opcode)
    );

    ALU alu (
        .opcode(alu_opcode),
        .a(lookup_gp_register(rsrc1)),
        .b(lookup_gp_register(rsrc2)),
        .result(alu_result)
    );

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= FETCH;
            address <= 32'b0;
            data_out <= 32'b0;
            debug_out <= 8'b11111111;

            for (integer i = 0; i < 8; i = i + 1) begin
                gp_registers[i] <= 32'b0;
                special_registers[i] <= 32'b0;
            end
        end else begin
            case (state)
                FETCH: begin
                    opcode <= data_in[7:0];
                    debug_out <= data_in[7:0];
                    case (data_in[7:5])
                        3'b000: begin // No extra values
                            special_registers[0] <= special_registers[0] + 1;
                            state <= DECODE;
                        end
                        3'b001: begin // Immediate
                            // For now, assume 8 bits. This may change in the future
                            immediate <= data_in[15:8];
                            special_registers[0] <= special_registers[0] + 2;
                            state <= DECODE;
                        end
                        3'b010: begin // Address
                            special_registers[0] <= special_registers[0] + 1;
                            address <= special_registers[0] + 1;
                            state <= FETCH_IMEM;
                        end
                        3'b011: begin // Immediate + Address
                            immediate <= data_in[15:8];
                            special_registers[0] <= special_registers[0] + 2;
                            address <= special_registers[0] + 2;
                            state <= FETCH_IMEM;
                        end
                        3'b100: begin // Register
                            rsrc1 <= data_in[11:8];
                            rsrc2 <= data_in[15:12];
                            // Let's assume that the first source is also the destination
                            rdest <= data_in[11:8];
                            special_registers[0] <= special_registers[0] + 2;
                            state <= DECODE;
                        end
                        3'b101: begin // Register + Immediate
                            rsrc1 <= data_in[11:8];
                            rsrc2 <= data_in[15:12];
                            rdest <= data_in[11:8];
                            immediate <= data_in[23:16];
                            special_registers[0] <= special_registers[0] + 3;
                            debug_out <= 8'b01010101;
                            state <= DECODE;
                        end
                        3'b110: begin // Register + Address
                            rsrc1 <= data_in[11:8];
                            rsrc2 <= data_in[15:12];
                            rdest <= data_in[11:8];
                            address <= special_registers[0] + 2;
                            special_registers[0] <= special_registers[0] + 2;
                            state <= FETCH_IMEM;
                        end
                        3'b111: begin // Invalid state
                            state <= HALT;
                        end
                    endcase
                end
                FETCH_IMEM: begin
                    debug_out <= 8'b00000010;
                    imem <= data_in;
                    special_registers[0] <= special_registers[0] + 4;
                    state <= DECODE;
                end
                DECODE: begin
                    debug_out <= 8'b00000011;
                    // TODO: What to do?
                    state <= EXECUTE;
                end
                EXECUTE: begin
                    debug_out <= 8'b00000100;
                    if (control_signal.halt) begin
                        state <= HALT;
                    end else begin
                        address <= imem;
                        state <= MEMORY;
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
                        WR_WRITE_SRC_RDEST: write_gp_register(rdest, alu_result);
                        WR_WRITE_SRC_RSRC2: write_gp_register(rsrc2, alu_result);
                        WR_WRITE_SRC_MEMORY: write_gp_register(rdest, data_in);
                        WR_WRITE_SRC_IMMEDIATE: write_gp_register(rdest, immediate);
                    endcase

                    state <= FETCH;
                    address <= special_registers[0];
                end
                HALT: begin
                    debug_out <= 8'b11111111;
                end
            endcase
        end
    end


    task automatic write_gp_register;
        input [2:0] index;
        input [31:0] value;
        begin
            case (index)
                3'd0: gp_registers[0] <= value;
                3'd1: gp_registers[1] <= value;
                3'd2: gp_registers[2] <= value;
                3'd3: gp_registers[3] <= value;
                3'd4: gp_registers[4] <= value;
                3'd5: gp_registers[5] <= value;
                3'd6: gp_registers[6] <= value;
                3'd7: gp_registers[7] <= value;
            endcase
        end
    endtask

    function [31:0] lookup_gp_register;
        input [2:0] index;
        begin
            case (index)
                3'd0: lookup_gp_register = gp_registers[0];
                3'd1: lookup_gp_register = gp_registers[1];
                3'd2: lookup_gp_register = gp_registers[2];
                3'd3: lookup_gp_register = gp_registers[3];
                3'd4: lookup_gp_register = gp_registers[4];
                3'd5: lookup_gp_register = gp_registers[5];
                3'd6: lookup_gp_register = gp_registers[6];
                3'd7: lookup_gp_register = gp_registers[7];
            endcase
        end
    endfunction

endmodule