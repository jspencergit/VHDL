LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_arith.ALL;
USE ieee.std_logic_unsigned.ALL;

ENTITY ADAQ4003_data_capture IS
    GENERIC (d_width : INTEGER := 18);

    PORT (
        reset_n : IN STD_LOGIC;--active low reset
        clock : IN STD_LOGIC;--system clock.  100MHz to start
        enable : IN STD_LOGIC;--Initiate a transaction
        cpol : IN STD_LOGIC; --spi clock polarity
        cpha : IN STD_LOGIC; --spi clock phase
        clk_div : IN INTEGER;--system clock cycles per 1/2 period of sclk
        adc_config_data : IN STD_LOGIC_VECTOR(15 DOWNTO 0);--really only 16-bits, but there will be 18 clocks.  And SDO needs to be high when CNV goes high, so last two of 18 bits should be high
        SDO : IN STD_LOGIC;--MISO line connecting to ADC  pin.  We get our conversion result here.
        SDI : OUT STD_LOGIC;--MOSI line connecting to ADC pin.  We send our configuration data out here
        sclk : BUFFER STD_LOGIC;--serial clock to ADC
        CNV : BUFFER STD_LOGIC;--conversion pin.  Also used as CS#
        mux_setting : IN STD_LOGIC_VECTOR(3 DOWNTO 0);--Comes from the top module.  This is the mux setting for the next conversion
        mux_gpio : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);--mux GPIO, connects to the pins on the mux asic
        busy : OUT STD_LOGIC;--busy/ready# signal
        rx_data : OUT STD_LOGIC_VECTOR(d_width - 1 DOWNTO 0)--Conversion result
    );
END ADAQ4003_data_capture;

ARCHITECTURE logic OF ADAQ4003_data_capture IS
    TYPE machine IS(ready, convert, execute, end_delay);--state machine data type
    SIGNAL state : machine;--current state
    SIGNAL clk_ratio : INTEGER;--current clk div
    SIGNAL count : INTEGER;--counter to trigger sclk from system clock
    SIGNAL tquiet2_count : INTEGER; --delay after SPI transfer before next conversion can occur
    SIGNAL convert_count : INTEGER;--counter to wait for teh 320ns convert time
    SIGNAL mux_delay_count : INTEGER;--counter to wait after rising of CNV signal to switching of the mux
    SIGNAL clk_toggles : INTEGER RANGE 0 TO d_width * 2 + 1;--count spi toggles
    SIGNAL assert_data : STD_LOGIC;--'1' is tx sclk toggle, '0' is rx sclk toggle
    SIGNAL rx_buffer : STD_LOGIC_VECTOR(d_width - 1 DOWNTO 0);
    SIGNAL tx_buffer : STD_LOGIC_VECTOR(d_width - 1 DOWNTO 0);
    SIGNAL last_bit_rx : INTEGER RANGE 0 TO d_width * 2; --last rx data bit location

BEGIN
    PROCESS (clock, reset_n)
    BEGIN

        IF (reset_n = '0') THEN --reset the system
            busy <= '1'; --set busy signal
            CNV <= '0'; --set cnv pin low
            SDI <= '1'; --SDI needs to be high when CNV goes high to select CS# mode.
            sclk <= cpol; --set spi clock polarity
            rx_data <= (OTHERS => '0'); --clear receive data port
            state <= ready; --go to convert state when reset is exited
        ELSIF (rising_edge(clock)) THEN
            CASE state IS --state machine

                WHEN ready =>
                    busy <= '0';--clock out not busy signal
                    cnv <= '0';--CNV pin is low, ready to start the next conversion
                    SDI <= '1'; --SDI should be high when CNV goes high to choose CS# mode
                    convert_count <= 1; --initialize the conversion time count
                    mux_delay_count <= 1; --initialize the mux delay count
                    tquiet2_count <= 1;--initialize the tquiet2 count
                    --user input to initial transaction
                    IF (enable = '1') THEN
                        busy <= '1'; --set busy signal
                        cnv <= '1'; --initiate the conversion

                        IF (clk_div = 0) THEN --check for valid spi speed
                            clk_ratio <= 1; --set to maximum speed if zero
                            count <= 1; --initiate system-to-spi clock counter
                        ELSE
                            clk_ratio <= clk_div; --set to input selection if valid
                            count <= clk_div; --initiate system-to-spi clock counter
                        END IF;
                        sclk <= cpol; --set spi clock polarity
                        assert_data <= NOT cpha; --set spi clock phase
                        tx_buffer <= adc_config_data & "11"; --clock in data for transmit into buffer.  adc_config_data is 16 bits,  last two bits should be "11" so that SDI is high when CNV goes high
                        clk_toggles <= 0; --initiate clock toggle counter
                        last_bit_rx <= d_width * 2 + conv_integer(cpha) - 1; --set last rx data bit
                        state <= convert; --proceed to convert state
                    ELSE
                        state <= ready;--reamin in ready state
                    END IF;

                WHEN convert =>
                    --CNV already went high    
                    --busy is already high
                    --need to wait some time before we switch the mux
                    IF (mux_delay_count = 1) THEN
                        mux_gpio <= mux_setting;--Update the mux selection
                    ELSE
                        mux_delay_count <= mux_delay_count + 1;
                    END IF;
                    IF (convert_count = 32) THEN
                        --we're done waiting
                        state <= execute;
                    ELSE
                        convert_count <= convert_count + 1;
                        state <= convert;--stay in the convet state until the conversion can finish
                    END IF;

                WHEN execute =>
                    busy <= '1';--set busy signal
                    CNV <= '0';--drop the CNV signal  
                    --IF clk_toggles = 0 THEN
                     --   SDI <= tx_buffer(d_width - 1);--On falling edge of CNV, put data on SDI
                   --END IF;

                    --todo add a 13 ns Ten delay.  But we might just get this for free

                    --system clock to sclk ratio is met
                    IF (count = clk_ratio) THEN
                        count <= 1; --reset system-to-spi clock counter
                        assert_data <= NOT assert_data; --switch transmit/receive indicator
                        IF (clk_toggles = d_width * 2 + 1) THEN
                            clk_toggles <= 0; --reset spi clock toggles counter
                        ELSE
                            clk_toggles <= clk_toggles + 1; --increment spi clock toggles counter
                        END IF;

                        --spi clock toggle needed
                        IF (clk_toggles <= d_width * 2 AND CNV = '0') THEN
                            sclk <= NOT sclk; --toggle spi clock
                        END IF;

                        --receive spi clock toggle
                        IF (assert_data = '0' AND clk_toggles > 1 AND clk_toggles < last_bit_rx + 1 AND CNV = '0') THEN --need one clock before SDO is valid
                            rx_buffer <= rx_buffer(d_width - 2 DOWNTO 0) & SDO; --shift in received bit, channel 0

                        END IF;

                        --transmit spi clock toggle
                        IF (assert_data = '0' AND clk_toggles < last_bit_rx) THEN  --clock out data on falling edge so that it is valid on rising edge
                            SDI <= tx_buffer(d_width - 1); --clock out data bit
                            tx_buffer <= tx_buffer(d_width - 2 DOWNTO 0) & '0'; --shift data transmit buffer
                        END IF;

                        --end of transaction
                        IF ((clk_toggles = d_width * 2 + 1)) THEN
                            SDI <= '1'; --SDI needs to be high when CNV goes hign in order to select CS# mode.  This also starts the next conversion
                            rx_data <= rx_buffer; --clock out received data to output port, 
                            state <= end_delay; --return to ready state
                        ELSE --not end of transaction
                            state <= execute; --remain in execute state
                        END IF;

                    ELSE --system clock to sclk ratio not met
                        count <= count + 1; --increment counter
                        state <= execute; --remain in execute state
                    END IF;

                WHEN end_delay =>
                    --need to wait 60ns before next conversion can begin
                    IF (tquiet2_count = 6) THEN
                        busy <= '0'; --clock out not busy signal
                        state <= ready;
                    ELSE
                        tquiet2_count <= tquiet2_count + 1;
                        state <= ready;
                    END IF;

            END CASE;--end state machine case
        END IF; --end if(reset_n='0' ELSIF (rising_edge(clock)))
    END PROCESS;--end process(reset_n, clock)
END logic;--end architecture