----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06/04/2021 01:23:13 PM
-- Design Name: 
-- Module Name: ADC_Top - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.Numeric_Std.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

ENTITY ADC_Top IS
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
END ADC_Top;

ARCHITECTURE Behavioral OF ADC_Top IS

    TYPE machine IS(InitADC, InitNewConv, WaitForResult, DelayUntilNext);--state machine types

    TYPE ROM_Array IS ARRAY (0 TO 31)
    OF STD_LOGIC_VECTOR(3 DOWNTO 0);
    --ROM to hold the mux values
    CONSTANT sequencer : ROM_Array := (
        0 => "0000",
        1 => "0001",
        2 => "0010",
        3 => "0011",
        4 => "0100",
        5 => "0101",
        6 => "0110",
        7 => "0111",
        8 => "1000",
        9 => "1001",
        10 => "1010",
        11 => "1011",
        12 => "1100",
        13 => "1101",
        14 => "1110",
        15 => "1111",
        16 => "0000",
        17 => "0001",
        18 => "0010",
        19 => "0011",
        20 => "0100",
        21 => "0101",
        22 => "0110",
        23 => "0111",
        24 => "1000",
        25 => "1001",
        26 => "1010",
        27 => "1011",
        28 => "1100",
        29 => "1101",
        30 => "1110",
        31 => "1111",
        OTHERS => "0000"

    );

    SIGNAL state : machine; --current state
    SIGNAL mux_index : INTEGER RANGE 0 TO 31;--32 channel mux sequencer
    SIGNAL clocks_per_sample : INTEGER := 100; --How many system clocks per sample.  100MHz, 100 clocks = 1Msps
    SIGNAL clock_count : INTEGER;
    SIGNAL one_shot_counter : INTEGER := 0;--Counter for short pulses
    SIGNAL adc_is_initialized : INTEGER;
    SIGNAL sample_counter : STD_LOGIC_VECTOR (9 DOWNTO 0) := "0000000000";--Counts the sample number.  we have room for 10 bits
    SIGNAL sequencer_index : INTEGER := 0;

BEGIN

    PROCESS (clock, reset_n)
    BEGIN
        IF (reset_n = '0') THEN

            adc_is_initialized <= 0;--flag to indicate that the ADC is not setup.
            start_conversion <= '0';
            cpol <= '0';
            cpha <= '1';
            clk_div <= '1';
            clock_count <= 0;--Reset the clock count
            one_shot_counter <= 0;--reset our one shot timer
            --adc config data
            --Write EN# = 0
            --R/W# = 0
            --0101 pattern, followed by 00 address
            --111 for reserved bits.  This is the reset value
            --En 6 bits status = 0
            --Span compression = 0
            --Hi-Z mode = 0
            --Turbo Mode = 0
            --OV# clemp = 1
            adc_config_data <= "0001010011100001";
            sequencer_index <= 0;
            mux_setting <= sequencer(sequencer_index);
            data_out <= (OTHERS => '0');
            new_data_ready <= '0';
            state <= InitADC;--Goto initADC state when reset is exited
        ELSIF (rising_edge(clock)) THEN
            CASE state IS -- state machine

                WHEN InitADC =>
                    cpol <= '0';
                    cpha <= '1';
                    clk_div <= '1';
                    clock_count <= 0;--Reset the clock count
                    adc_config_data <= "0001010011100001";
                    mux_setting <= sequencer(0);
                    data_out <= (OTHERS => '0');
                    new_data_ready <= '0';
                    state <= InitNewConv;

                WHEN InitNewConv => --assert start_conversion, wait for a few clocks and then de-assert start_conversion
                    clock_count <= clock_count + 1;--increment the clock counter
                    one_shot_counter <= 0;--reset one shot counter
                    IF (clock_count < 10) THEN
                        start_conversion <= '1';--assert start_conversion, keep it high for 10 clocks
                        state <= InitNewConv;--stay in this state
                    ELSE
                        start_conversion <= '0';--de-assert start_conversion
                        sequencer_index <= sequencer_index+1;--update the mux channel
                        mux_setting <= sequencer(sequencer_index);
                        state <= WaitForResult;--go and wait for the result to be ready
                    
                    END IF;

                WHEN WaitForResult => --just waiting for a result
                    clock_count <= clock_count + 1;--increment the clock counter
                    IF (busy = '1') THEN
                        state <= WaitForResult;--stay in this state
                    ELSE
                        state <= DelayUntilNext;--go delay until want to to init the next sample
                    END IF;

                WHEN DelayUntilNext => --Put data out to the master axi streamer.  Assert short 'ready' pulse.  Delay until next sample shoudl start
                    clock_count <= clock_count + 1;--increment clock counter
                    one_shot_counter <= one_shot_counter + 1; --increment the one shot counter
                    --When we first enter this state, put data out to the AXI streamer and pulse new_data_ready. But only after the ADC is init
                    IF ((one_shot_counter < 1) AND (adc_is_initialized = 1)) THEN
                        new_data_ready <= '1';
                        data_out <= sample_counter & sequencer(sequencer_index - 1) & rx_data;--Send sample number & prev mux setting & ADC result.  32 bit vector
                    ELSE
                        new_data_ready <= '0';
                        --data_out <= (OTHERS => '0');--don't reset the data out.  Fine to leave the avlue.
                    END IF;

                    IF (clock_count < clocks_per_sample - 1) THEN--we haven't waited enough to init the next sample
                        state <= DelayUntilNext;--just sit here and wait
                    ELSE --we're done waiting
                        --sequencer_index <= sequencer_index + 1;--Increment the mux to the next state
                        state <= InitNewConv;--next thing to do is a new conversion
                        adc_is_initialized <= 1;--If ADC wasn't initialized, it is now
                        clock_count <=0;--reset the clock counter
                        sample_counter <= std_logic_vector(unsigned(sample_counter)+1);
                    END IF;

            END CASE;
        END IF;
    END PROCESS;

END Behavioral;