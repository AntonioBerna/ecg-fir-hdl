module fir_filter #(
    parameter integer input_width  = 8,
    parameter integer output_width = 16,
    parameter integer q_bits       = 8,
    parameter integer tap          = 11,
    parameter integer guard        = 4
) (
    input  wire [ input_width - 1:0] input_sample,
    input  wire                      clk,
    input  wire                      reset,
    output wire [output_width - 1:0] filtered_sample
);
  localparam integer acc_width = input_width + q_bits + guard;
  localparam integer implemented_tap = 11;

  function automatic signed [q_bits - 1:0] base_coefficient;
    input integer idx;
    begin
      case (idx)
        0: base_coefficient = -1;
        1: base_coefficient = -1;
        2: base_coefficient = 1;
        3: base_coefficient = 13;
        4: base_coefficient = 32;
        5: base_coefficient = 41;
        6: base_coefficient = 32;
        7: base_coefficient = 13;
        8: base_coefficient = 1;
        9: base_coefficient = -1;
        10: base_coefficient = -1;
        default: base_coefficient = '0;
      endcase
    end
  endfunction

  reg signed [q_bits - 1:0] coefficients[tap];
  reg signed [acc_width - 1:0] stage_reg[tap - 1];
  reg signed [acc_width - 1:0] acc;
  reg signed [acc_width - 1:0] new_acc;

  integer i;
  reg signed [input_width - 1:0] x_in;
  reg signed [input_width + q_bits - 1:0] mul_v;

  initial begin
    if (tap != implemented_tap) begin
      $fatal(1, "This implementation expects tap=11 for the provided coefficient set");
    end

    for (i = 0; i < tap; i = i + 1) begin
      coefficients[i] = base_coefficient(i);
    end

    acc = '0;
    new_acc = '0;
    for (i = 0; i < tap - 1; i = i + 1) begin
      stage_reg[i] = '0;
    end
  end

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      acc <= '0;
      new_acc <= '0;
      for (i = 0; i < tap - 1; i = i + 1) begin
        stage_reg[i] <= '0;
      end
    end else begin
      x_in = $signed(input_sample);
      mul_v = x_in * coefficients[0];
      new_acc = $signed(mul_v) + stage_reg[0];
      acc <= new_acc;

      for (i = 0; i < tap - 2; i = i + 1) begin
        mul_v = x_in * coefficients[i+1];
        stage_reg[i] <= $signed(mul_v) + stage_reg[i+1];
      end

      mul_v = x_in * coefficients[tap-1];
      stage_reg[tap-2] <= $signed(mul_v);
    end
  end

  assign filtered_sample = acc[output_width-1:0];
endmodule
