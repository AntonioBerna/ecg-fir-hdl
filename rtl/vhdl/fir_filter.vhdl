library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity fir_filter is
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
end entity fir_filter;

architecture rtl of fir_filter is

  constant implemented_tap : integer := 11;
  constant acc_width : integer := input_width + q_bits + guard;

  type coefficients_type is array (0 to tap - 1) of signed(q_bits - 1 downto 0);

  constant coefficients : coefficients_type :=
  (
    to_signed(-1,
               q_bits),
    to_signed(-1,
               q_bits),
    to_signed(1,
               q_bits),
    to_signed(13,
               q_bits),
    to_signed(32,
               q_bits),
    to_signed(41,
               q_bits),
    to_signed(32,
               q_bits),
    to_signed(13,
               q_bits),
    to_signed(1,
               q_bits),
    to_signed(-1,
               q_bits),
    to_signed(-1,
               q_bits)
  );

  type stage_reg_type is array (0 to tap - 2) of signed(acc_width - 1 downto 0);

  signal stage_reg : stage_reg_type;
  signal acc       : signed(acc_width - 1 downto 0);

begin

  assert tap = implemented_tap
    report "This implementation expects tap=11 for the provided coefficient set"
    severity failure;

  mac_proc : process (clk, reset) is

    variable x_in    : signed(input_width - 1 downto 0);
    variable mul_v   : signed(input_width + q_bits - 1 downto 0);
    variable new_acc : signed(acc_width - 1 downto 0);

  begin

    if (reset = '1') then
      stage_reg <= (others => (others => '0'));
      acc       <= (others => '0');
    elsif rising_edge(clk) then
      x_in := signed(input_sample);

      mul_v   := x_in * coefficients(0);
      new_acc := resize(mul_v, acc_width) + stage_reg(0);
      acc     <= new_acc;

      for i in 0 to tap - 3 loop

        mul_v        := x_in * coefficients(i + 1);
        stage_reg(i) <= resize(mul_v, acc_width) + stage_reg(i + 1);

      end loop;

      mul_v              := x_in * coefficients(tap - 1);
      stage_reg(tap - 2) <= resize(mul_v, acc_width);
    end if;

  end process mac_proc;

  filtered_sample <= std_logic_vector(resize(acc, output_width));

end architecture rtl;

library ieee;
  use ieee.std_logic_1164.all;

entity n_bit_reg is
  generic (
    input_width : integer := 8
  );
  port (
    q     : out   std_logic_vector(input_width - 1 downto 0);
    clk   : in    std_logic;
    reset : in    std_logic;
    d     : in    std_logic_vector(input_width - 1 downto 0)
  );
end entity n_bit_reg;

architecture behavioral of n_bit_reg is

begin

  reg_proc : process (clk, reset) is
  begin

    if (reset = '1') then
      q <= (others => '0');
    elsif rising_edge(clk) then
      q <= d;
    end if;

  end process reg_proc;

end architecture behavioral;
