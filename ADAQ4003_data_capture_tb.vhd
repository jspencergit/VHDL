-- Joseph Spencer
--Testbench created online at:
--   https://www.doulos.com/knowhow/perl/vhdl-testbench-creation-using-perl/
-- Copyright Doulos Ltd

LIBRARY IEEE;
USE IEEE.Std_logic_1164.ALL;
USE IEEE.Numeric_Std.ALL;

ENTITY ADAQ4003_data_capture_tb IS
END;

ARCHITECTURE bench OF ADAQ4003_data_capture_tb IS

  COMPONENT ADAQ4003_data_capture

    PORT (
      reset_n : IN STD_LOGIC;
      clock : IN STD_LOGIC;
      enable : IN STD_LOGIC;
      cpol : IN STD_LOGIC;
      cpha : IN STD_LOGIC;
      clk_div : IN INTEGER;
      adc_config_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      SDO : IN STD_LOGIC;
      SDI : OUT STD_LOGIC;
      sclk : BUFFER STD_LOGIC;
      CNV : BUFFER STD_LOGIC;
      mux_setting : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      mux_gpio : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      busy : OUT STD_LOGIC;
      rx_data : OUT STD_LOGIC_VECTOR(17 DOWNTO 0)
    );
  END COMPONENT;

  SIGNAL reset_n : STD_LOGIC;
  SIGNAL clock : STD_LOGIC;
  SIGNAL enable : STD_LOGIC;
  SIGNAL cpol : STD_LOGIC;
  SIGNAL cpha : STD_LOGIC;
  SIGNAL clk_div : INTEGER;
  SIGNAL adc_config_data : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL SDO : STD_LOGIC;
  SIGNAL SDI : STD_LOGIC;
  SIGNAL sclk : STD_LOGIC;
  SIGNAL CNV : STD_LOGIC;
  SIGNAL mux_setting : STD_LOGIC_VECTOR(3 DOWNTO 0);
  SIGNAL mux_gpio : STD_LOGIC_VECTOR(3 DOWNTO 0);
  SIGNAL busy : STD_LOGIC;
  SIGNAL rx_data : STD_LOGIC_VECTOR(17 DOWNTO 0);

  SIGNAL AD4003_result : STD_LOGIC_VECTOR(17 DOWNTO 0);

  CONSTANT clock_period : TIME := 10 ns;
  SIGNAL stop_the_clock : BOOLEAN;

BEGIN

  -- Insert values for generic parameters !!
  uut : ADAQ4003_data_capture
  PORT MAP(
    reset_n => reset_n,
    clock => clock,
    enable => enable,
    cpol => cpol,
    cpha => cpha,
    clk_div => clk_div,
    adc_config_data => adc_config_data,
    SDO => SDO,
    SDI => SDI,
    sclk => sclk,
    CNV => CNV,
    mux_setting => mux_setting,
    mux_gpio => mux_gpio,
    busy => busy,
    rx_data => rx_data);

  stimulus : PROCESS
  BEGIN

    -- Put initialisation code here
    reset_n <= '0';
    enable <= '0';
    cpol <= '0';
    cpha <= '1';
    clk_div <= 1;
    adc_config_data <= "0001010111100000";
    mux_setting <= "0001";
    AD4003_result <= "111111111100000001";

    -- Put test bench stimulus code here
    WAIT FOR clock_period * 2;
    reset_n <= '1';
    WAIT FOR clock_period * 2;
    enable <= '1';
    WAIT UNTIL falling_edge (CNV);
    enable <= '0';

    FOR I IN  17 DOWNTO 0 LOOP
      WAIT UNTIL rising_edge(sclk);
      SDO <= AD4003_result(I);
    END LOOP;

for j in 1 to 10 loop
    WAIT FOR 200 ns;
    enable <= '1';
    wait until rising_edge(cnv);
    AD4003_result <=STD_LOGIC_VECTOR(unsigned(AD4003_result)+1);--increment the ADC_Conversion_Register
    mux_setting <= STD_LOGIC_VECTOR(unsigned(mux_setting) + 1);--update the mux setting
    WAIT UNTIL falling_edge (CNV);
    enable <= '0';

    FOR I IN  17 DOWNTO 0 LOOP
      WAIT UNTIL rising_edge(sclk);
      SDO <= AD4003_result(I);
    END LOOP;
    end loop;
    
   

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