module IFU(
    input logic clk,
    input logic rst,
    input logic enable_step,
    input logic [31:0] data_in,
    input logic [31:0] ip_cur,
    input cpu_state_t state,
    output logic [7:0] opcode,
    output logic refetch,
    output logic [31:0] ip_next,
    output logic [2:0] rsrc1,
    output logic [2:0] rsrc2,
    output logic [2:0] rdest,
    output logic [31:0] immediate_addr,
    output logic [31:0] ref_addr_addr,
    output logic [1:0] immediate_data_size,
    output logic [1:0] register_data_size,
    output logic extend_sign
);

    logic [2:0] DATA_SIZE_EXPANDS [0:3];
    assign DATA_SIZE_EXPANDS = '{3'd1, 3'd2, 3'd4, 3'd4};

    logic [1:0] global_immediate_data_size;
    logic [1:0] global_register_data_size;
    logic global_extend_sign;

    logic [2:0] opcode_type;
    assign opcode_type = data_in[7:5];

    logic is_prefix;
    assign is_prefix = opcode_type == 3'b111;
    assign was_prefix = opcode[7:5] == 3'b111;
    assign refetch = (state == FETCH && is_prefix) || (state == DECODE && was_prefix);

    logic prefix_flag;

    logic [31:0] post_reg_ip;
    assign post_reg_ip = ip_cur + 1 + opcode_type[2];
    logic [31:0] post_immediate_ip;
    assign post_immediate_ip = post_reg_ip + (opcode_type[0] ? DATA_SIZE_EXPANDS[immediate_data_size] : 0);
    logic [31:0] post_imem_ip;
    assign post_imem_ip = post_immediate_ip + (opcode_type[1] ? 4 : 0);

    assign ip_next = is_prefix ? ip_cur + 2 : post_imem_ip;
    assign ref_addr_addr = post_immediate_ip;

    always_ff @(posedge clk) begin
        if (enable_step & (state == FETCH)) begin
            opcode <= data_in[7:0];
            immediate_addr <= post_reg_ip;

            // Don't care if a register actually exists, load anyways
            rsrc1 <= data_in[15:12];
            rsrc2 <= data_in[11:8];
            // Let's assume that the first source is also the destination
            rdest <= data_in[15:12];
        end
        
        if (enable_step && state == FETCH) begin
            if (data_in[7:0] == 8'b11100000) begin
                immediate_data_size <= data_in[9:8];
                register_data_size <= data_in[11:10];
                extend_sign <= data_in[14];
                if (data_in[15]) begin
                    global_immediate_data_size <= data_in[9:8];
                    global_register_data_size <= data_in[11:10];
                    global_extend_sign <= data_in[14];
                end
                prefix_flag <= 1'b1;
            end else if (prefix_flag) begin
                prefix_flag <= 1'b0;
            end else begin
                immediate_data_size <= global_immediate_data_size;
                register_data_size <= global_register_data_size;
                extend_sign <= global_extend_sign;
            end
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