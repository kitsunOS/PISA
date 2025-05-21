module VideoMemory(
    input clk,
    input clk_pixel,
    input logic [31:0] memory_address,
    input logic [31:0] memory_in,
    input logic [1:0] memory_size,
    input logic memory_write_enable,
    output logic [31:0] memory_out,

    input logic [11:0] video_address,
    output logic [15:0] video_out
);

    logic [29:0] base;
    logic [1:0] offset;
    assign base = memory_address[31:2];
    assign offset = memory_address[1:0];

    logic [29:0] address_part[0:3];
    logic [29:0] base_plus1 = base + 1;
    
    logic [0:3] enable;
    logic [0:3] enable_p;
    always_comb begin
        unique case ({memory_size[0], offset})
            3'b000: enable_p = 4'b1000;
            3'b001: enable_p = 4'b0100;
            3'b010: enable_p = 4'b0010;
            3'b011: enable_p = 4'b0001;
            3'b100: enable_p = 4'b1100;
            3'b101: enable_p = 4'b0110;
            3'b110: enable_p = 4'b0011;
            3'b111: enable_p = 4'b1001;
        endcase
    end

    assign enable = memory_size[1] ? 4'b1111 : enable_p;

    for (genvar i = 0; i < 4; ++i) begin : gen_addr
        assign address_part[i] = (i < offset) ? base_plus1 : base;
    end

    logic [31:0] reordered_memory_in;
    logic [7:0] memory_out_part [0:3];
    always_comb begin
        unique case (offset)
            2'b00: reordered_memory_in = {memory_in[31:24], memory_in[23:16], memory_in[15:8], memory_in[7:0]};
            2'b01: reordered_memory_in = {memory_in[23:16], memory_in[15:8], memory_in[7:0], memory_in[31:24]};
            2'b10: reordered_memory_in = {memory_in[15:8], memory_in[7:0], memory_in[31:24], memory_in[23:16]};
            2'b11: reordered_memory_in = {memory_in[7:0], memory_in[31:24], memory_in[23:16], memory_in[15:8]};
        endcase
    end

    logic video_alignment_buf;
    logic video_alignment;
    always_ff @(posedge clk_pixel) begin
        video_alignment_buf <= video_address[0];
        video_alignment <= video_alignment_buf;
    end

    logic [7:0] video_out_part [0:3];

    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : gen_bram
            BRAM_TDP_MACRO #(
                .BRAM_SIZE("18Kb"),
                .DEVICE("7SERIES"),
                .WRITE_WIDTH_A(8),
                .READ_WIDTH_A(8),
                .WRITE_WIDTH_B(8),
                .READ_WIDTH_B(8),
                .DOB_REG(1)
            ) BRAM_TDP_MACRO_inst (
                .DOA(memory_out_part[i]),
                .DIA(reordered_memory_in[(8*i)+7 -: 8]),
                .ADDRA(address_part[i]),
                .WEA(memory_write_enable),
                .ENA(enable[i]),
                .CLKA(clk),

                .DOB(video_out_part[i]),
                .DIB(8'b0),
                .ADDRB(video_address[11:1]),
                .ENB(1'b1),
                .REGCEB(1'b1),
                .CLKB(clk_pixel)
            );
        end
    endgenerate

    always_comb begin
        unique case (offset)
            2'b00: memory_out = {memory_out_part[3], memory_out_part[2], memory_out_part[1], memory_out_part[0]};
            2'b01: memory_out = {memory_out_part[0], memory_out_part[3], memory_out_part[2], memory_out_part[1]};
            2'b10: memory_out = {memory_out_part[1], memory_out_part[0], memory_out_part[3], memory_out_part[2]};
            2'b11: memory_out = {memory_out_part[2], memory_out_part[1], memory_out_part[0], memory_out_part[3]};
        endcase
    end

    always_comb begin
        unique case (video_alignment)
            1'b0: video_out = {video_out_part[1], video_out_part[0]};
            1'b1: video_out = {video_out_part[3], video_out_part[2]};
        endcase
    end

endmodule