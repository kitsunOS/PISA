module IFU(
    input logic clk,
    input logic rst,
    input logic enable_step,
    input cpu_state_t state,
    input logic [31:0] data_in,
    input logic [31:0] ip_cur,
    output logic [7:0] opcode,
    output logic is_active,
    output cpu_state_t next_state,
    output logic [31:0] ip_next,
    output logic [1:0] data_size,
    output logic [2:0] rsrc1,
    output logic [2:0] rsrc2,
    output logic [2:0] rdest,
    output logic [31:0] immediate,
    output logic [31:0] ref_addr,
    output logic [1:0] immediate_data_size,
    output logic [1:0] register_data_size,
    output logic extend_sign
);

    logic [1:0] global_immediate_data_size;
    logic [1:0] global_register_data_size;
    logic global_extend_sign;

    logic [2:0] opcode_type;
    assign opcode_type = data_in[7:5];

    logic should_fetch_imm = opcode_type[0] & immediate_data_size[1];

    logic is_prefix;
    assign is_prefix = opcode_type == 3'b111;

    logic [31:0] ip_inc;
    logic imm_fetch = immediate_data_size[1];
    assign ip_inc =
        data_in[7:0] == 8'b11100000 ? 2 :
        (1 + opcode_type[2]
            + ((~opcode_type[0] | imm_fetch) ? 0 : (immediate_data_size[0] ? 2 : 1)));

    assign ip_next = ip_cur + (state == FETCH ? ip_inc : 4);
    assign is_active = state == FETCH || state == FETCH_IMM || state == FETCH_IMEM;

    assign next_state =
        state == FETCH ? (is_prefix ? FETCH : should_fetch_imm ? FETCH_IMM : opcode_type[1] ? FETCH_IMEM : DECODE) :
        state == FETCH_IMM ? (opcode[6] ? FETCH_IMEM : DECODE) :
        state == FETCH_IMEM ? DECODE :
        HALT;

    always_comb begin
        if (enable_step) case (state)
            // TODO: If at edge of memory, 4 bytes could wrongly result in error
            FETCH: data_size =
                is_prefix ? 2'b10 :
                should_fetch_imm ? immediate_data_size :
                opcode_type[1] ? 2'b10 :
                register_data_size;
            FETCH_IMM: data_size = opcode[6] ? 2'b10 : register_data_size;
            FETCH_IMEM: data_size = register_data_size;
        endcase
    end

    always_ff @(posedge clk) begin
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

        if (state == FETCH_IMM) begin
            immediate <= enforce_constraints(immediate_data_size, extend_sign, {24'b0, data_in[15:8]});
        end

        if (state == FETCH_IMEM) begin
            ref_addr <= data_in;
        end

        if (data_in[7:0] == 8'b11100000 && state == FETCH) begin
            immediate_data_size <= data_in[9:8];
            register_data_size <= data_in[11:10];
            extend_sign <= data_in[14];
            if (data_in[15]) begin
                global_immediate_data_size <= data_in[9:8];
                global_register_data_size <= data_in[11:10];
                global_extend_sign <= data_in[14];
            end
        end

        if (state == WRITEBACK && enable_step) begin
            immediate_data_size <= global_immediate_data_size;
            register_data_size <= global_register_data_size;
            extend_sign <= global_extend_sign;
        end
        
        if (rst) begin
            global_immediate_data_size <= 2'b00;
            global_register_data_size <= 2'b10;
            global_extend_sign <= 1'b1;
            immediate_data_size <= 2'b00;
            register_data_size <= 2'b10;
            extend_sign <= 1'b1;
        end
    end

endmodule