----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06/10/2021 02:33:27 PM
-- Design Name: 
-- Module Name: AD4003_Emulator - Behavioral
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

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

ENTITY AD4003_Emulator IS
    PORT (
        SCLK : IN STD_LOGIC;
        --SDI : IN STD_LOGIC;  --We don't really care about looking at input data.  Not going to emulate register writes
        SDO : OUT STD_LOGIC;
        CNV : IN STD_LOGIC);
END AD4003_Emulator;
ARCHITECTURE Behavioral OF AD4003_Emulator IS
    SIGNAL rx_data : STD_LOGIC_VECTOR(17 DOWNTO 0) := (OTHERS => '0');--Result of the emulated conversion
    SIGNAL counter : INTEGER range 0 to 17 := 0;

BEGIN

    PROCESS (CNV)
    BEGIN
        IF (rising_edge(CNV)) THEN
            rx_data <= STD_LOGIC_VECTOR(unsigned(rx_data) + 1);--Increment the emulated result
            --counter <= 0;
           end if;

    END PROCESS;

    PROCESS (sclk)
    BEGIN
        IF (rising_edge(sclk)) THEN
            SDO <= rx_data(counter);--new data clocked out on rising edge
            if(counter<17) then
            counter <= counter + 1;--Increment the counter position
            else
            counter<=0;
            end if;

        END IF;
    END PROCESS;

END Behavioral;