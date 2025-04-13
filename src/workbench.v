`timescale 1ns / 1ps

module workbench(
    input clk,
    input wire [15:0] sw,
    output wire [7:0] led
);

wire [7:0] bt1 = sw[7:0];
wire [15:8] bt2 = sw[15:8];

assign led = bt1 + bt2;

endmodule;