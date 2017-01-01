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
constant INTCODE_SIZE           : integer := 7;

constant BRAM_ADDR_SIZE         : integer := 12;
constant BRAM_DATA_SIZE         : integer := REG_SIZE;
constant BRAM_LATENCY           : integer := 1;


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


constant BUS_DATA_SIZE          : integer := REG_SIZE;
constant BUS_ADDR_SIZE          : integer := 16;
constant BUS_READ               : std_logic := '0';
constant BUS_WRITE              : std_logic := '1';

-- signals for a synchronous bus
type bus_sync is
  record
     data       : std_logic_vector(BUS_DATA_SIZE-1 downto 0);
     addr       : std_logic_vector(BUS_ADDR_SIZE-1 downto 0);
     m_req      : std_logic; -- master request - stays high through transaction until s_valid raised
     m_cmd      : std_logic; -- BUS_READ or BUS_WRITE
     s_ack      : std_logic; -- slave ack valid command, must remain high until m_req drops else implies error
     s_valid    : std_logic; -- data valid on read or successful write
  end record;


end common_pkg;

package body common_pkg is


 
end common_pkg;
