module Memory(
    input clk,
    input logic [31:0] memory_address,
    input logic [31:0] memory_in,
    input logic [1:0] memory_size,
    input logic memory_write_enable,
    output logic [31:0] memory_out
);

    (* ram_style = "block" *) logic [7:0] memory_a [0:255];
    (* ram_style = "block" *) logic [7:0] memory_b [0:255];
    (* ram_style = "block" *) logic [7:0] memory_c [0:255];
    (* ram_style = "block" *) logic [7:0] memory_d [0:255];

    logic [29:0] base = memory_address[31:2];
    logic [1:0] offset = memory_address[1:0];

    logic [29:0] address_a;
    logic [29:0] address_b;
    logic [29:0] address_c;
    logic [29:0] address_d;

    logic enable_a;
    logic enable_b;
    logic enable_c;
    logic enable_d;
    
    logic enable_2 = memory_size != 2'b00;
    logic enable_34 = memory_size != 2'b01 & enable_2;

    logic [29:0] base_plus1 = base + 1;

    always_comb begin
        unique case (offset)
            2'b00: begin
                enable_a = 1'b1;
                enable_b = enable_2;
                enable_c = enable_34;
                enable_d = enable_34;

                address_a = base;
                address_b = base;
                address_c = base;
                address_d = base;
            end
            2'b01: begin
                enable_a = enable_34;
                enable_b = 1'b1;
                enable_c = enable_2;
                enable_d = enable_34;

                address_a = base_plus1;
                address_b = base;
                address_c = base;
                address_d = base;
            end
            2'b10: begin
                enable_a = enable_34;
                enable_b = enable_34;
                enable_c = 1'b1;
                enable_d = enable_2;

                address_a = base_plus1;
                address_b = base_plus1;
                address_c = base;
                address_d = base;
            end
            2'b11: begin
                enable_a = enable_2;
                enable_b = enable_34;
                enable_c = enable_34;
                enable_d = 1'b1;

                address_a = base_plus1;
                address_b = base_plus1;
                address_c = base_plus1;
                address_d = base;
            end
        endcase
    end

    logic [31:0] reordered_memory_in;
    always_comb begin
        unique case (offset)
            2'b00: reordered_memory_in = {memory_in[31:24], memory_in[23:16], memory_in[15:8], memory_in[7:0]};
            2'b01: reordered_memory_in = {memory_in[23:16], memory_in[15:8], memory_in[7:0], memory_in[31:24]};
            2'b10: reordered_memory_in = {memory_in[15:8], memory_in[7:0], memory_in[31:24], memory_in[23:16]};
            2'b11: reordered_memory_in = {memory_in[7:0], memory_in[31:24], memory_in[23:16], memory_in[15:8]};
        endcase
    end
    always_ff @(posedge clk) begin
        if (memory_write_enable) begin
            if (enable_a) memory_a[address_a] <= reordered_memory_in[7:0];
            if (enable_b) memory_b[address_b] <= reordered_memory_in[15:8];
            if (enable_c) memory_c[address_c] <= reordered_memory_in[23:16];
            if (enable_d) memory_d[address_d] <= reordered_memory_in[31:24];
        end
    end

    logic [7:0] memory_out_a;
    logic [7:0] memory_out_b;
    logic [7:0] memory_out_c;
    logic [7:0] memory_out_d;
    always_comb begin
        memory_out_a = enable_a ? memory_a[address_a] : 8'b0;
        memory_out_b = enable_b ? memory_b[address_b] : 8'b0;
        memory_out_c = enable_c ? memory_c[address_c] : 8'b0;
        memory_out_d = enable_d ? memory_d[address_d] : 8'b0;
        unique case (offset)
            2'b00: memory_out = {memory_out_d, memory_out_c, memory_out_b, memory_out_a};
            2'b01: memory_out = {memory_out_a, memory_out_d, memory_out_c, memory_out_b};
            2'b10: memory_out = {memory_out_b, memory_out_a, memory_out_d, memory_out_c};
            2'b11: memory_out = {memory_out_c, memory_out_b, memory_out_a, memory_out_d};
        endcase
    end

endmodule