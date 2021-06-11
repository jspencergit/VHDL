-- Testbench created online at:
--   https://www.doulos.com/knowhow/perl/vhdl-testbench-creation-using-perl/
-- Copyright Doulos Ltd

LIBRARY IEEE;
USE IEEE.Std_logic_1164.ALL;
USE IEEE.Numeric_Std.ALL;

ENTITY ADC_Top_tb IS
END;

ARCHITECTURE bench OF ADC_Top_tb IS

  COMPONENT ADC_Top
    PORT (
      reset_n : IN STD_LOGIC;
      clock : IN STD_LOGIC;
      start_conversion : OUT STD_LOGIC;
      cpol : OUT STD_LOGIC;
      cpha : OUT STD_LOGIC;
      clk_div : OUT STD_LOGIC;
      adc_config_data : OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
      mux_setting : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
      busy : IN STD_LOGIC;
      rx_data : IN STD_LOGIC_VECTOR (17 DOWNTO 0);
      data_out : OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
      new_data_ready : OUT STD_LOGIC);
  END COMPONENT;

  SIGNAL reset_n : STD_LOGIC;
  SIGNAL clock : STD_LOGIC;
  SIGNAL start_conversion : STD_LOGIC;
  SIGNAL cpol : STD_LOGIC;
  SIGNAL cpha : STD_LOGIC;
  SIGNAL clk_div : STD_LOGIC;
  SIGNAL adc_config_data : STD_LOGIC_VECTOR (15 DOWNTO 0);
  SIGNAL mux_setting : STD_LOGIC_VECTOR (3 DOWNTO 0);
  SIGNAL busy : STD_LOGIC;
  SIGNAL rx_data : STD_LOGIC_VECTOR (17 DOWNTO 0);
  SIGNAL data_out : STD_LOGIC_VECTOR (31 DOWNTO 0);
  SIGNAL new_data_ready : STD_LOGIC;

  CONSTANT clock_period : TIME := 10 ns;
  SIGNAL stop_the_clock : BOOLEAN;

BEGIN

  uut : ADC_Top PORT MAP(
    reset_n => reset_n,
    clock => clock,
    start_conversion => start_conversion,
    cpol => cpol,
    cpha => cpha,
    clk_div => clk_div,
    adc_config_data => adc_config_data,
    mux_setting => mux_setting,
    busy => busy,
    rx_data => rx_data,
    data_out => data_out,
    new_data_ready => new_data_ready);

  stimulus : PROCESS
  BEGIN

    -- Put initialisation code here
    reset_n <= '0';
    rx_data <= (OTHERS => '0');
    busy <= '1';

    -- Put test bench stimulus code here
    WAIT FOR clock_period * 2;
    reset_n <= '1';--take out of reset
    busy <= '0';
    --WAIT FOR clock_period * 2;

    FOR i IN 1 TO 10 LOOP
      WAIT UNTIL rising_edge(start_conversion);
      busy <= '1';--we're busy for awhile
      WAIT FOR clock_period * 80;--takes about this long for the data to be ready
      rx_data <= STD_LOGIC_VECTOR(unsigned(rx_data) + 1);--just increment rx_data
      WAIT FOR clock_period * 2;
      busy <= '0';--Not busy any more 
    END LOOP;

    stop_the_clock <= true;
    WAIT;
  END PROCESS;

  clocking : PROCESS
  BEGIN
    WHILE NOT stop_the_clock LOOP
      clock <= '0', '1' AFTER clock_period / 2;
      WAIT FOR clock_period;
    END LOOP;
    WAIT;
  END PROCESS;

END;