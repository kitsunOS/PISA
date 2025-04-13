module workbench(
    input clk,
    input wire [15:0] sw,
    output wire [7:0] led
);

wire [7:0] bt1 = sw[7:0];
wire [3:0] bt2p = sw[11:8];
wire [3:0] opcode = sw[15:12];

wire [7:0] bt2 = {4'b0000, bt2p};

ALU alu(
    .opcode(opcode),
    .a(bt1),
    .b(bt2),
    .result(led)
);

endmodule;