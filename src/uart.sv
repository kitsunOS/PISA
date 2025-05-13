typedef enum logic [1:0] {
    IDLE = 2'b00,
    DATA = 2'b01,
    STOP = 2'b10
} state_t;

module UART(
    input logic clk,
    input logic bit_in,
    output logic [7:0] data_out,
    output logic data_ready
);
  
  localparam integer BAUD_RATE = 9600;
  localparam integer CLOCK_FREQ = 100000000;
  localparam integer BIT_PERIOD = CLOCK_FREQ / BAUD_RATE;

  logic bit_ready;
  logic bit_cur;
  logic [13:0] period_counter;
  always @(posedge clk) begin
    period_counter <= period_counter + 1;
    if (period_counter + 1 == BIT_PERIOD) begin
      period_counter <= 0;
      bit_cur <= bit_in;
      bit_ready <= 1;
    end else begin
      bit_ready <= 0;
    end
  end

  logic [3:0] bit_count;
  logic [7:0] data_reg;
  state_t state;
  initial state = IDLE;
  always @(posedge clk) begin
    if (bit_ready) begin
      case (state)
        IDLE: begin
          data_ready <= 0;
          if (bit_cur == 0) begin
            state <= DATA;
            bit_count <= 0;
          end
        end
        DATA: begin
          data_reg[bit_count] <= bit_cur;
          bit_count <= bit_count + 1;
          if (bit_count == 7) begin
            state <= STOP;
          end
        end
        STOP: begin
          if (bit_cur) begin
            data_out <= data_reg;
            data_ready <= 1;
            state <= IDLE;
          end
        end
      endcase
    end else begin
      data_ready <= 0;
    end
  end

endmodule