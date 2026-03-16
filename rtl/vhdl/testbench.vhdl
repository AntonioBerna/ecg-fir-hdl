library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use std.textio.all;
  use std.env.all;

entity tb_fir is
  generic (
    latency_cycles    : natural := 1;
    input_ref_path    : string  := "";
    input_hv_path     : string  := "";
    input_bs_path     : string  := "";
    expected_ref_path : string  := "";
    expected_hv_path  : string  := "";
    expected_bs_path  : string  := "";
    output_ref_path   : string  := "";
    output_hv_path    : string  := "";
    output_bs_path    : string  := ""
  );
end entity tb_fir;

architecture behavioral of tb_fir is

  constant dataset_count : integer := 3;

  subtype dataset_index_t is integer range 0 to dataset_count - 1;

  constant input_width       : integer := 8;
  constant output_width      : integer := 16;
  constant q_bits            : integer := 8;
  constant tap               : integer := 11;
  constant guard             : integer := 4;
  constant clk_period        : time    := 20 ns;
  constant reset_hold_cycles : integer := 10;

  signal input_sample    : std_logic_vector(input_width - 1 downto 0);
  signal clk             : std_logic;
  signal reset           : std_logic;
  signal filtered_sample : std_logic_vector(output_width - 1 downto 0);

  signal output_valid      : std_logic;
  signal current_dataset   : dataset_index_t;
  signal reset_cycles_left : integer range 0 to reset_hold_cycles;
  signal startup_done      : integer range 0 to 1;
  signal mismatch_count    : natural;

  type expected_delay_t is array (natural range <>) of integer;

  type valid_delay_t is array (natural range <>) of boolean;

  file input_ref : text;
  file input_hv  : text;
  file input_bs  : text;

  file expected_ref : text;
  file expected_hv  : text;
  file expected_bs  : text;

  file output_ref : text;
  file output_hv  : text;
  file output_bs  : text;

  procedure read_next_input_sample (
    constant dataset_idx : in integer;
    file input_ref_file  : text;
    file input_hv_file   : text;
    file input_bs_file   : text;
    variable input_line  : inout line;
    variable input_val   : out integer;
    variable has_sample  : out boolean
  ) is
  begin

    has_sample := false;

    case dataset_idx is

      when 0 =>

        if (not endfile(input_ref_file)) then
          readline(input_ref_file, input_line);
          read(input_line, input_val);
          has_sample := true;
        end if;

      when 1 =>

        if (not endfile(input_hv_file)) then
          readline(input_hv_file, input_line);
          read(input_line, input_val);
          has_sample := true;
        end if;

      when others =>

        if (not endfile(input_bs_file)) then
          readline(input_bs_file, input_line);
          read(input_line, input_val);
          has_sample := true;
        end if;

    end case;

  end procedure read_next_input_sample;

  procedure write_output_and_read_expected (
    constant dataset_idx   : in integer;
    file output_ref_file   : text;
    file output_hv_file    : text;
    file output_bs_file    : text;
    file expected_ref_file : text;
    file expected_hv_file  : text;
    file expected_bs_file  : text;
    variable output_line   : inout line;
    variable expected_line : inout line;
    variable expected_curr : out integer
  ) is
  begin

    expected_curr := 0;

    case dataset_idx is

      when 0 =>

        writeline(output_ref_file, output_line);

        if (not endfile(expected_ref_file)) then
          readline(expected_ref_file, expected_line);
          read(expected_line, expected_curr);
        end if;

      when 1 =>

        writeline(output_hv_file, output_line);

        if (not endfile(expected_hv_file)) then
          readline(expected_hv_file, expected_line);
          read(expected_line, expected_curr);
        end if;

      when others =>

        writeline(output_bs_file, output_line);

        if (not endfile(expected_bs_file)) then
          readline(expected_bs_file, expected_line);
          read(expected_line, expected_curr);
        end if;

    end case;

  end procedure write_output_and_read_expected;

  component fir_filter is
    generic (
      input_width  : integer := 8;
      output_width : integer := 16;
      q_bits       : integer := 8;
      tap          : integer := 11;
      guard        : integer := 4
    );
    port (
      input_sample    : in    std_logic_vector(input_width - 1 downto 0);
      clk             : in    std_logic;
      reset           : in    std_logic;
      filtered_sample : out   std_logic_vector(output_width - 1 downto 0)
    );
  end component fir_filter;

begin

  assert input_ref_path'length > 0 and input_hv_path'length > 0 and input_bs_path'length > 0
    report "Input path generics must be provided"
    severity failure;

  assert expected_ref_path'length > 0 and expected_hv_path'length > 0 and expected_bs_path'length > 0
    report "Expected output path generics must be provided"
    severity failure;

  assert output_ref_path'length > 0 and output_hv_path'length > 0 and output_bs_path'length > 0
    report "Simulation output path generics must be provided"
    severity failure;

  file_open_proc : process is

    variable file_status : file_open_status;

  begin

    file_open(file_status, input_ref, input_ref_path, read_mode);
    assert file_status = open_ok
      report "Cannot open input file: " & input_ref_path
      severity failure;

    file_open(file_status, input_hv, input_hv_path, read_mode);
    assert file_status = open_ok
      report "Cannot open input file: " & input_hv_path
      severity failure;

    file_open(file_status, input_bs, input_bs_path, read_mode);
    assert file_status = open_ok
      report "Cannot open input file: " & input_bs_path
      severity failure;

    file_open(file_status, expected_ref, expected_ref_path, read_mode);
    assert file_status = open_ok
      report "Cannot open expected file: " & expected_ref_path
      severity failure;

    file_open(file_status, expected_hv, expected_hv_path, read_mode);
    assert file_status = open_ok
      report "Cannot open expected file: " & expected_hv_path
      severity failure;

    file_open(file_status, expected_bs, expected_bs_path, read_mode);
    assert file_status = open_ok
      report "Cannot open expected file: " & expected_bs_path
      severity failure;

    file_open(file_status, output_ref, output_ref_path, write_mode);
    assert file_status = open_ok
      report "Cannot open output file: " & output_ref_path
      severity failure;

    file_open(file_status, output_hv, output_hv_path, write_mode);
    assert file_status = open_ok
      report "Cannot open output file: " & output_hv_path
      severity failure;

    file_open(file_status, output_bs, output_bs_path, write_mode);
    assert file_status = open_ok
      report "Cannot open output file: " & output_bs_path
      severity failure;

    wait;

  end process file_open_proc;

  dut : component fir_filter
    generic map (
      input_width  => input_width,
      output_width => output_width,
      q_bits       => q_bits,
      tap          => tap,
      guard        => guard
    )
    port map (
      input_sample    => input_sample,
      clk             => clk,
      reset           => reset,
      filtered_sample => filtered_sample
    );

  clock_gen : process is
  begin

    while true loop

      clk <= '0';
      wait for clk_period / 2;
      clk <= '1';
      wait for clk_period / 2;

    end loop;

  end process clock_gen;

  stim_proc : process (clk) is

    variable input_line : line;
    variable input_val  : integer;
    variable has_sample : boolean;

  begin

    if rising_edge(clk) then
      if (startup_done = 0) then
        startup_done      <= 1;
        reset             <= '1';
        reset_cycles_left <= reset_hold_cycles;
        current_dataset   <= 0;
        input_sample      <= (others => '0');
        output_valid      <= '0';
      elsif (reset_cycles_left > 0) then
        reset             <= '1';
        reset_cycles_left <= reset_cycles_left - 1;
        input_sample      <= (others => '0');
        output_valid      <= '0';
      else
        reset <= '0';

        read_next_input_sample(
                               current_dataset,
                               input_ref,
                               input_hv,
                               input_bs,
                               input_line,
                               input_val,
                               has_sample
                             );

        if (has_sample) then
          input_sample <= std_logic_vector(to_signed(input_val, input_width));
          output_valid <= '1';
        else
          if (current_dataset < dataset_count - 1) then
            current_dataset   <= current_dataset + 1;
            reset_cycles_left <= reset_hold_cycles;
            input_sample      <= (others => '0');
            output_valid      <= '0';
          else
            output_valid <= '0';
            if (mismatch_count = 0) then
              report "Simulation PASS: no mismatches found"
                severity note;
            else
              report "Simulation FAIL: mismatches=" & integer'image(mismatch_count)
                severity failure;
            end if;
            stop;
          end if;
        end if;
      end if;
    end if;

  end process stim_proc;

  write_proc : process (clk) is

    variable output_line    : line;
    variable expected_line  : line;
    variable expected_curr  : integer;
    variable expected_pipe  : expected_delay_t(0 to latency_cycles);
    variable expected_valid : valid_delay_t(0 to latency_cycles);
    variable dataset_prev   : dataset_index_t;
    variable dout_int       : integer;

  begin

    if rising_edge(clk) then
      if (reset = '1') then
        if (startup_done = 0) then
          mismatch_count <= 0;
        end if;
        expected_curr  := 0;
        expected_pipe  := (others => 0);
        expected_valid := (others => false);
        dataset_prev   := 0;
        dout_int       := 0;
      elsif (output_valid = '1') then
        dout_int := to_integer(signed(filtered_sample));
        write(output_line, dout_int);

        if (current_dataset /= dataset_prev) then
          expected_valid := (others => false);
          dataset_prev   := current_dataset;
        end if;

        write_output_and_read_expected(
                                       current_dataset,
                                       output_ref,
                                       output_hv,
                                       output_bs,
                                       expected_ref,
                                       expected_hv,
                                       expected_bs,
                                       output_line,
                                       expected_line,
                                       expected_curr
                                     );

        if (latency_cycles > 0) then

          for i in 0 to latency_cycles - 1 loop

            expected_pipe(i)  := expected_pipe(i + 1);
            expected_valid(i) := expected_valid(i + 1);

          end loop;

        end if;

        expected_pipe(latency_cycles)  := expected_curr;
        expected_valid(latency_cycles) := true;

        if expected_valid(0) then
          if (dout_int /= expected_pipe(0)) then
            mismatch_count <= mismatch_count + 1;
            assert false
              report "Mismatch dataset=" & integer'image(current_dataset) &
                     " rtl=" & integer'image(dout_int) &
                     " expected=" & integer'image(expected_pipe(0))
              severity error;
          end if;
        end if;
      end if;
    end if;

  end process write_proc;

end architecture behavioral;
