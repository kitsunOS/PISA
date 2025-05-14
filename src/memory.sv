module Memory(
    input clk,
    input logic [31:0] memory_address,
    input logic [31:0] memory_in,
    input logic [1:0] memory_size,
    input logic memory_write_enable,
    output logic [31:0] memory_out
);

    logic [29:0] base;
    logic [1:0] offset;
    assign base = memory_address[31:2];
    assign offset = memory_address[1:0];

    logic [29:0] address_part[0:3];
    logic enable[0:3];
    
    logic enable_2 = memory_size != 2'b00;
    logic enable_34 = memory_size != 2'b01 & enable_2;

    logic [29:0] base_plus1 = base + 1;

    always_comb begin
        unique case (offset)
            2'b00: begin
                enable[0] = 1'b1;
                enable[1] = enable_2;
                enable[2] = enable_34;
                enable[3] = enable_34;

                address_part[0] = base;
                address_part[1] = base;
                address_part[2] = base;
                address_part[3] = base;
            end
            2'b01: begin
                enable[0] = enable_34;
                enable[1] = 1'b1;
                enable[2] = enable_2;
                enable[3] = enable_34;

                address_part[0] = base_plus1;
                address_part[1] = base;
                address_part[2] = base;
                address_part[3] = base;
            end
            2'b10: begin
                enable[0] = enable_34;
                enable[1] = enable_34;
                enable[2] = 1'b1;
                enable[3] = enable_2;

                address_part[0] = base_plus1;
                address_part[1] = base_plus1;
                address_part[2] = base;
                address_part[3] = base;
            end
            2'b11: begin
                enable[0] = enable_2;
                enable[1] = enable_34;
                enable[2] = enable_34;
                enable[3] = 1'b1;

                address_part[0] = base_plus1;
                address_part[1] = base_plus1;
                address_part[2] = base_plus1;
                address_part[3] = base;
            end
        endcase
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

    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : gen_bram
            BRAM_SDP_MACRO #(
                .BRAM_SIZE("18Kb"),
                .DEVICE("7SERIES"),
                .WRITE_WIDTH(8),
                .READ_WIDTH(8),
                .DO_REG(0),
                .WRITE_MODE("READ_FIRST")
            ) BRAM_SDP_MACRO_inst (
                .DO(memory_out_part[i]),
                .DI(reordered_memory_in[(8*i)+7 -: 8]),
                .RDADDR(address_part[i]),
                .RDCLK(clk),
                .RDEN(enable[i]),
                .REGCE(1'b0),
                .RST(1'b0),
                .WE(7'b1111111),
                .WRADDR(address_part[i]),
                .WRCLK(clk),
                .WREN(memory_write_enable & enable[i])
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

endmodule