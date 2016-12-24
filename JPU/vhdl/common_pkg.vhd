library IEEE;
use IEEE.STD_LOGIC_1164.all;
library work;

package common_pkg is

--------------------------------------------------------
-- Constants
--------------------------------------------------------
constant REG_SIZE               : integer := 16;
constant REGADDR_SIZE        	: integer := 3;
constant OPCODE_SIZE            : integer := 3;
constant IMMSHORT_SIZE          : integer := 7;
constant IMMLONG_SIZE           : integer := 10;
constant MEMADDR_SIZE           : integer := 12;
constant INTCODE_SIZE           : integer := 7;

constant NUM_REGS               : integer := 8;

-- opcodes
constant OP_ADD 	    : STD_LOGIC_VECTOR (OPCODE_SIZE-1 downto 0) := "000";
constant OP_ADDI 	    : STD_LOGIC_VECTOR (OPCODE_SIZE-1 downto 0) := "001";
constant OP_NAND 	    : STD_LOGIC_VECTOR (OPCODE_SIZE-1 downto 0) := "010";
constant OP_LUI 	    : STD_LOGIC_VECTOR (OPCODE_SIZE-1 downto 0) := "011";
constant OP_SW 	      	: STD_LOGIC_VECTOR (OPCODE_SIZE-1 downto 0) := "101";
constant OP_LW 		   	: STD_LOGIC_VECTOR (OPCODE_SIZE-1 downto 0) := "100";
constant OP_BEQ 		: STD_LOGIC_VECTOR (OPCODE_SIZE-1 downto 0) := "110";
constant OP_JALR 	    : STD_LOGIC_VECTOR (OPCODE_SIZE-1 downto 0) := "111";


end common_pkg;

package body common_pkg is


 
end common_pkg;
