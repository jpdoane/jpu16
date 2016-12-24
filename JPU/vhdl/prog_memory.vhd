library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
--use ieee.std_logic_arith.all;
use work.common_pkg.all;
--
library work;


entity prog_mem is
    port (
    iClk                        : in std_logic;
    iRst                        : in std_logic;
	iPC						: in std_logic_vector(REG_SIZE-1  downto 0);
    oInstruction	            : out std_logic_vector(REG_SIZE-1 downto 0)
    );
end prog_mem;

architecture arch of prog_mem is

type INSTR_LIST is array(integer range <>) of std_logic_vector(15 downto 0);
signal sProgram	: INSTR_LIST(9 downto 0) := (others=> (others=>'0'));
signal sInstruction : std_logic_vector(15 downto 0);

begin

-- sProgram(0) <= OP_ADDI & "001" & "000" & "0000001"; 		-- addi $1, $0, 1
-- sProgram(1) <= OP_ADDI & "010" & "000" & "0000010"; 		-- addi $2, $0, 2
-- sProgram(2) <= OP_ADD  & "011" & "001" & "0000" & "010"; -- add $3, $1, $2
-- sProgram(3) <= x"0000"; 									-- nop
-- sProgram(4) <= OP_JALR & "000" & "000" & "0000001"; 		-- halt

sProgram(0) <= OP_ADD & "001" & "000" & "0000" & "000"; 	-- add $1, $0, $0 	($1=0)
sProgram(1) <= OP_ADDI & "010" & "000" & "0001000"; 		-- addi $2, $0, 16 	($2=8)
sProgram(2) <= OP_ADDI & "011" & "000" & "0000011"; 		-- addi $3, $0, 3 	($3=3)
sProgram(3) <= OP_ADDI & "001" & "001" & "0000001"; 		-- addi $1, $1, 1  	($i++)
sProgram(4) <= OP_BEQ  & "001" & "010" & "0000001"; 		-- beq $1, $2, 1 	(if $1=$2 jump to line 6)
sProgram(5) <= OP_JALR & "000" & "011" & "0000000"; 		-- jalr $0, $3, 0 	(jump to line 3)
sProgram(6) <= x"0000"; 									-- nop
sProgram(7) <= OP_JALR & "000" & "000" & "0000001"; 		-- halt


process(iClk)
begin
    if (rising_edge (iClk)) then
		if iRst='1' then
		  sInstruction <= (others=>'0');
		else
		  sInstruction <= sProgram(to_integer(unsigned(iPC)));
		end if;
  end if;
end process;

oInstruction <= sInstruction;

end;
