module OutputMap(
    input clk,
    input reg [31:0] output_address,
    input reg [31:0] output_in,
    input reg [1:0] output_size,
    input reg output_write_enable,
    output wire [31:0] output_out,

    output reg [7:0] led
);

    always_ff @(posedge clk) begin
        if (output_write_enable && output_address == 0) begin
            led <= output_in[7:0];
        end
    end

    assign output_out = {24'b0, led};

endmodule