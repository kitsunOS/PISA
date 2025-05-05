module OutputMap(
    input clk,
    input logic [31:0] output_address,
    input logic [31:0] output_in,
    input logic [1:0] output_size,
    input logic output_write_enable,
    output logic [31:0] output_out,

    output logic [7:0] led
);

    always_ff @(posedge clk) begin
        if (output_write_enable && output_address == 0) begin
            led <= output_in[7:0];
        end
    end

    assign output_out = {24'b0, led};

endmodule