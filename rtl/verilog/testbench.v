`timescale 1ns / 1ps

module testbench;
  localparam integer dataset_count = 3;
  localparam integer input_width = 8;
  localparam integer output_width = 16;
  localparam integer q_bits = 8;
  localparam integer tap = 11;
  localparam integer guard = 4;
  localparam integer latency_cycles = 1;
  localparam integer clk_period_ns = 20;
  localparam integer reset_hold_cycles = 10;

  reg     [ input_width - 1:0] input_sample;
  reg                          clk;
  reg                          reset;
  wire    [output_width - 1:0] filtered_sample;

  reg                          output_valid;

  integer                      fd_in             [     dataset_count];
  integer                      fd_expected       [     dataset_count];
  integer                      fd_out            [     dataset_count];

  integer                      expected_pipe     [latency_cycles + 1];
  reg                          expected_valid    [latency_cycles + 1];

  integer                      mismatch_count;

  reg     [            1023:0] input_ref_path;
  reg     [            1023:0] input_hv_path;
  reg     [            1023:0] input_bs_path;
  reg     [            1023:0] expected_ref_path;
  reg     [            1023:0] expected_hv_path;
  reg     [            1023:0] expected_bs_path;
  reg     [            1023:0] output_ref_path;
  reg     [            1023:0] output_hv_path;
  reg     [            1023:0] output_bs_path;
  reg     [            1023:0] input_paths       [     dataset_count];
  reg     [            1023:0] expected_paths    [     dataset_count];
  reg     [            1023:0] output_paths      [     dataset_count];

  fir_filter #(
      .input_width(input_width),
      .output_width(output_width),
      .q_bits(q_bits),
      .tap(tap),
      .guard(guard)
  ) dut (
      .input_sample   (input_sample),
      .clk            (clk),
      .reset          (reset),
      .filtered_sample(filtered_sample)
  );

  initial begin
    clk = 1'b0;
    forever #(clk_period_ns / 2) clk = ~clk;
  end

  task automatic clear_expected_pipe;
    integer i;
    begin
      for (i = 0; i <= latency_cycles; i = i + 1) begin
        expected_pipe[i]  = 0;
        expected_valid[i] = 1'b0;
      end
    end
  endtask

  task automatic apply_reset;
    integer i;
    begin
      for (i = 0; i < reset_hold_cycles; i = i + 1) begin
        @(negedge clk);
        reset = 1'b1;
        input_sample = '0;
        output_valid = 1'b0;
      end
      @(negedge clk);
      reset = 1'b0;
    end
  endtask

  task automatic process_output;
    input integer dataset_idx;
    integer dout_int;
    integer expected_curr;
    integer scan_expected;
    integer i;
    begin
      dout_int = $signed(filtered_sample);
      $fwrite(fd_out[dataset_idx], "%0d\n", dout_int);

      expected_curr = 0;
      scan_expected = $fscanf(fd_expected[dataset_idx], "%d\n", expected_curr);
      if (scan_expected != 1) begin
        expected_curr = 0;
      end

      for (i = 0; i < latency_cycles; i = i + 1) begin
        expected_pipe[i]  = expected_pipe[i+1];
        expected_valid[i] = expected_valid[i+1];
      end

      expected_pipe[latency_cycles]  = expected_curr;
      expected_valid[latency_cycles] = 1'b1;

      if (expected_valid[0] && (dout_int !== expected_pipe[0])) begin
        mismatch_count = mismatch_count + 1;
        $display("Mismatch dataset=%0d rtl=%0d expected=%0d", dataset_idx, dout_int,
                 expected_pipe[0]);
      end
    end
  endtask

  task automatic run_dataset;
    input integer dataset_idx;
    integer scan_input;
    integer input_val;
    begin
      clear_expected_pipe();
      apply_reset();

      while (!$feof(
          fd_in[dataset_idx]
      )) begin
        scan_input = $fscanf(fd_in[dataset_idx], "%d\n", input_val);
        if (scan_input == 1) begin
          @(negedge clk);
          input_sample = input_val[input_width-1:0];
          output_valid = 1'b1;

          @(posedge clk);
          if (output_valid) begin
            process_output(dataset_idx);
          end
        end
      end

      @(negedge clk);
      output_valid = 1'b0;
      input_sample = '0;
    end
  endtask

  initial begin
    integer dataset_idx;

    mismatch_count = 0;
    input_sample = '0;
    reset = 1'b1;
    output_valid = 1'b0;

    if (!$value$plusargs(
            "INPUT_REF_PATH=%s", input_ref_path
        ) || !$value$plusargs(
            "INPUT_HV_PATH=%s", input_hv_path
        ) || !$value$plusargs(
            "INPUT_BS_PATH=%s", input_bs_path
        )) begin
      $fatal(1, "Input path plusargs must be provided");
    end

    if (!$value$plusargs(
            "EXPECTED_REF_PATH=%s", expected_ref_path
        ) || !$value$plusargs(
            "EXPECTED_HV_PATH=%s", expected_hv_path
        ) || !$value$plusargs(
            "EXPECTED_BS_PATH=%s", expected_bs_path
        )) begin
      $fatal(1, "Expected output plusargs must be provided");
    end

    if (!$value$plusargs(
            "OUTPUT_REF_PATH=%s", output_ref_path
        ) || !$value$plusargs(
            "OUTPUT_HV_PATH=%s", output_hv_path
        ) || !$value$plusargs(
            "OUTPUT_BS_PATH=%s", output_bs_path
        )) begin
      $fatal(1, "Simulation output plusargs must be provided");
    end

    input_paths[0] = input_ref_path;
    input_paths[1] = input_hv_path;
    input_paths[2] = input_bs_path;

    expected_paths[0] = expected_ref_path;
    expected_paths[1] = expected_hv_path;
    expected_paths[2] = expected_bs_path;

    output_paths[0] = output_ref_path;
    output_paths[1] = output_hv_path;
    output_paths[2] = output_bs_path;

    for (dataset_idx = 0; dataset_idx < dataset_count; dataset_idx = dataset_idx + 1) begin
      fd_in[dataset_idx] = $fopen(input_paths[dataset_idx], "r");
      fd_expected[dataset_idx] = $fopen(expected_paths[dataset_idx], "r");
      fd_out[dataset_idx] = $fopen(output_paths[dataset_idx], "w");
    end

    for (dataset_idx = 0; dataset_idx < dataset_count; dataset_idx = dataset_idx + 1) begin
      if (fd_in[dataset_idx] == 0) begin
        $fatal(1, "Cannot open input file: %0s", input_paths[dataset_idx]);
      end
      if (fd_expected[dataset_idx] == 0) begin
        $fatal(1, "Cannot open expected file: %0s", expected_paths[dataset_idx]);
      end
      if (fd_out[dataset_idx] == 0) begin
        $fatal(1, "Cannot open output file: %0s", output_paths[dataset_idx]);
      end
    end

    $dumpfile("fir.vcd");
    $dumpvars(0, testbench);

    for (dataset_idx = 0; dataset_idx < dataset_count; dataset_idx = dataset_idx + 1) begin
      run_dataset(dataset_idx);
    end

    for (dataset_idx = 0; dataset_idx < dataset_count; dataset_idx = dataset_idx + 1) begin
      $fclose(fd_in[dataset_idx]);
      $fclose(fd_expected[dataset_idx]);
      $fclose(fd_out[dataset_idx]);
    end

    if (mismatch_count != 0) begin
      $fatal(1, "Simulation failed with %0d mismatches", mismatch_count);
    end

    $display("Simulation PASS: no mismatches found");
    $finish;
  end
endmodule
