-- Testbench created online at:
--   https://www.doulos.com/knowhow/perl/vhdl-testbench-creation-using-perl/
-- Copyright Doulos Ltd

LIBRARY IEEE;
USE IEEE.Std_logic_1164.ALL;
USE IEEE.Numeric_Std.ALL;

ENTITY AD4003_Emulator_tb IS
END;

ARCHITECTURE bench OF AD4003_Emulator_tb IS

  COMPONENT AD4003_Emulator
    PORT (
      SCLK : IN STD_LOGIC;
      SDO : OUT STD_LOGIC;
      CNV : IN STD_LOGIC);
  END COMPONENT;

  SIGNAL SCLK : STD_LOGIC;
  SIGNAL SDO : STD_LOGIC;
  SIGNAL CNV : STD_LOGIC;

  CONSTANT clock_period : TIME := 10 ns;
  SIGNAL stop_the_clock : BOOLEAN;

BEGIN

  uut : AD4003_Emulator PORT MAP(
    SCLK => SCLK,
    SDO => SDO,
    CNV => CNV);

  stimulus : PROCESS
  BEGIN

    -- Put initialisation code here
    sclk <= '0';
    cnv <= '0';
    WAIT FOR clock_period * 2;

   -- Put test bench stimulus code here
    FOR j IN 1 TO 10 LOOP
      cnv <= '1';
      WAIT FOR clock_period * 35;
      cnv <= '0';
      FOR I IN 35 DOWNTO 0 LOOP
        IF (I = 35) THEN
          WAIT FOR clock_period * 2;
        END IF;
        sclk <= NOT sclk;
        WAIT FOR clock_period/2;
      END LOOP;
    END LOOP;
    stop_the_clock <= true;
    WAIT;
    
  END PROCESS;

END;