import mem_utils::enforce_constraints;

module RegisterFile(
    input logic clk,
    input logic rst,
    input logic [2:0] rsrc1,
    input logic [2:0] rsrc2,
    input logic [2:0] rdest,
    input logic [1:0] data_size,
    input logic extend_sign,
    input logic write_enable,
    input logic [31:0] write_data,
    output logic [31:0] rsrc1_value,
    output logic [31:0] rsrc2_value,
    output logic [31:0] rsrc2_value_full
);

    (* ram_style = "distributed" *) logic [31:0] gp_registers[0:7];

    logic [3:0] byte_enable;
    always_comb begin
        unique case (data_size)
            2'b00: byte_enable = 4'b0001;
            2'b01: byte_enable = 4'b0011;
            default: byte_enable = 4'b1111;
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 8; i++) begin
                gp_registers[i] <= 32'b0;
            end
        end else if (write_enable) begin
            for (int i = 0; i < 4; i++) begin
                if (byte_enable[i]) begin
                    gp_registers[rdest][i*8 +: 8] <= write_data[i*8 +: 8];
                end
            end
        end

        rsrc1_value <= enforce_constraints(data_size, extend_sign, gp_registers[rsrc1]);
        rsrc2_value <= enforce_constraints(data_size, extend_sign, gp_registers[rsrc2]);
        rsrc2_value_full <= gp_registers[rsrc2];
    end

endmodule