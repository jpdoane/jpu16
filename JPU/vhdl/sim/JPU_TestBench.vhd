-- TestBench Template 

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all;
--use ieee.std_logic_arith.all;
use work.common_pkg.all;

library work;


ENTITY testbench IS
END testbench;

ARCHITECTURE arch OF testbench IS 

component JPUcontrol
    port (
    iClk                : in std_logic;
    iRst                : in std_logic;
	iRun				: in std_logic;										-- execution begins once this goes high
	oInt				: out std_logic;									-- interrupt
	oIntCode			: out STD_LOGIC_VECTOR (INTCODE_SIZE-1 downto 0));	-- interrupt code
end component;

constant clk_period : time := 10 ns;

signal clk				: std_logic := '0';
signal rst				: std_logic := '0';
signal sRun				: std_logic := '0';
signal sInt				: STD_LOGIC := '0';
signal sIntCode			: STD_LOGIC_VECTOR (6 downto 0) := "0000000";

begin



control1: JPUcontrol port map
	(
    iClk => clk,
    iRst => rst,
	 iRun => sRun,
	oInt => sInt,
	oIntCode  => sIntCode
    );

	-- Clock process definitions( clock with 50% duty cycle is generated here.
	clk_process :process
	begin
		  clk <= '0';
		  wait for clk_period/2;
		  clk <= '1';
		  wait for clk_period/2;
	end process;

  --  Test Bench Statements
     tb : PROCESS
     BEGIN
		  rst <= '1';
        wait for 40 ns; -- wait until global set/reset completes
		  rst <= '0';		  
			wait;
     END PROCESS tb;

--PC and Run Register
process(clk)
begin
    if (rising_edge (clk)) then
		if rst='1' then
			sRun <= '0';
		else
			sRun <= '1';
		end if;
	end if;
end process;

  --  End Test Bench 

  END;
