----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Jon Doane
-- 
-- Create Date:    16:18:25 11/20/2016 
-- Design Name: 
-- Module Name:  decoder
-- Project Name: JPU
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
--------------
-- decoder
--------------
-- parse instruction into components
-- combinatorial
--
-- inputs:
-- 	iInstruction: 16bit instruction
-- 	iValid: valid flag for instruction
-- outputs:  (not all returned signals are valid, depends on opcode)
-- 	oRegSel[A/B/C]: register select 0-7 for three possible register slots in instruction
-- 	oRead[A/B/C]En: set if instruction uses this register as input (needed for hazard prediction)
-- 	oImmShort/ImmLong: Immediate values (7 or 10bit)
-- 	oValid: passes back iValid. Possible future error checking
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.common_pkg.all;
--
library work;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity decoder is
    Port ( iInstruction : in  STD_LOGIC_VECTOR (REG_SIZE-1 downto 0);
			iValid:		in STD_LOGIC;
           oOpCode : out  STD_LOGIC_VECTOR (OPCODE_SIZE-1 downto 0);
           oRegSelA : out  STD_LOGIC_VECTOR (REGADDR_SIZE-1 downto 0);
           oRegSelB : out  STD_LOGIC_VECTOR (REGADDR_SIZE-1 downto 0);
           oRegSelC : out  STD_LOGIC_VECTOR (REGADDR_SIZE-1 downto 0);
			oReadAEn : out STD_LOGIC;
			oReadBEn : out STD_LOGIC;
			oReadCEn : out STD_LOGIC;
           oImmShort : out  STD_LOGIC_VECTOR (IMMSHORT_SIZE-1 downto 0);
           oImmLong : out  STD_LOGIC_VECTOR (IMMLONG_SIZE-1 downto 0);
			oValid:		out STD_LOGIC);
end decoder;

architecture arch of decoder is
signal sOpCode : STD_LOGIC_VECTOR (OPCODE_SIZE-1 downto 0);

begin

sOpCode <= iInstruction(15 downto 13);
oOpCode <= sOpCode;
oRegSelA <= iInstruction(12 downto 10);
oRegSelB <= iInstruction(9 downto 7);
oRegSelC <= iInstruction(2 downto 0);
oImmShort <= iInstruction(6 downto 0);
oImmLong <= iInstruction(9 downto 0);
oValid <= iValid;

with sOpCode select oReadAEn <=
	'1' when OP_SW,
	'1' when OP_BEQ,
	'0' when others;

with sOpCode select oReadBEn <=
	'0' when OP_LUI,
	'1' when others;

with sOpCode select oReadCEn <=
	'1' when OP_ADD,
	'1' when OP_NAND,
	'0' when others;
	
end arch;

