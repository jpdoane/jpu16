----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Jon Doane
-- 
-- Create Date:    16:18:25 11/20/2016 
-- Design Name: 
-- Module Name:    alu
-- Project Name: 	JPU
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use ieee.numeric_bit.all;
use IEEE.NUMERIC_STD.ALL;
use work.common_pkg.all;
--
library work;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity alu is
    Port ( iValid:		in STD_LOGIC;
           iOpCode : 	in  STD_LOGIC_VECTOR (2 downto 0);
           iDataA : 	in  STD_LOGIC_VECTOR (REG_SIZE-1 downto 0);
           iDataB : 	in  STD_LOGIC_VECTOR (REG_SIZE-1 downto 0);
           iDataC : 	in  STD_LOGIC_VECTOR (REG_SIZE-1 downto 0);
           iImmShort : 	in  STD_LOGIC_VECTOR (6 downto 0);
           iImmLong : 	in  STD_LOGIC_VECTOR (9 downto 0);
           iPC : 		in  STD_LOGIC_VECTOR (MEMADDR_SIZE-1 downto 0);
		   oValid: 		out STD_LOGIC;
           oResult : 	out  STD_LOGIC_VECTOR (REG_SIZE-1 downto 0);
		   oResultWriteEn: 	out STD_LOGIC;
           oMemAddr : 	out  STD_LOGIC_VECTOR (MEMADDR_SIZE-1 downto 0);
		   oMemReadEn: 	out STD_LOGIC;
		   oMemWriteEn: out STD_LOGIC;
		   oBranchEn: 	out STD_LOGIC;
		   oBranchAddr: out STD_LOGIC_VECTOR (MEMADDR_SIZE-1 downto 0);
		   oInt:		out STD_LOGIC;
		   oIntCode:	out STD_LOGIC_VECTOR (IMMSHORT_SIZE-1 downto 0));
end alu;

architecture arch of alu is


signal sDataB_s 		: SIGNED (REG_SIZE downto 0);
signal sDataC_s 		: SIGNED (REG_SIZE downto 0);
signal sImmShort_s 		: SIGNED (REG_SIZE downto 0);
signal sResult_s 		: SIGNED (REG_SIZE downto 0);

signal sSum 		: STD_LOGIC_VECTOR (REG_SIZE-1 downto 0);
signal sSumi 		: STD_LOGIC_VECTOR (REG_SIZE-1 downto 0);
signal sNand 		: STD_LOGIC_VECTOR (REG_SIZE-1 downto 0);
signal sLui 		: STD_LOGIC_VECTOR (REG_SIZE-1 downto 0);
signal sBranchAddrRel : STD_LOGIC_VECTOR (MEMADDR_SIZE-1 downto 0);
signal sBranchAddrAbs : STD_LOGIC_VECTOR (MEMADDR_SIZE-1 downto 0);
signal sPCInc 		: STD_LOGIC_VECTOR (MEMADDR_SIZE-1 downto 0);
--signal sPCInc_Reg 		: STD_LOGIC_VECTOR (REG_SIZE-1 downto 0);
signal sABEq 		: STD_LOGIC;

begin

sDataB_s <= resize(signed(iDataB), sDataB_s'length);
sDataC_s <= resize(signed(iDataC), sDataC_s'length);
sImmShort_s <= resize(signed(iImmShort), sImmShort_s'length);

sSum <= std_logic_vector(resize((sDataB_s + sDataC_s),sSum'length));
sSumi <= std_logic_vector(resize((sDataB_s + sImmShort_s),sSumi'length));
sNand <= iDataB nand iDataC;
sLui(15 downto 6) <= iImmLong;
sLui(5 downto 0) <= (others => '0');
sBranchAddrRel <= std_logic_vector(resize(signed('0' & sPCInc) + resize(signed(iImmShort), MEMADDR_SIZE+1),MEMADDR_SIZE));
sBranchAddrAbs <= std_logic_vector(resize(signed('0' & iDataB(MEMADDR_SIZE-1 downto 0)) + resize(signed(iImmShort), MEMADDR_SIZE+1),MEMADDR_SIZE));
sPCInc <= std_logic_vector(resize(('0' & unsigned(iPC) + 1),MEMADDR_SIZE));
--sPCInc_Reg <= std_logic_vector(resize(('0' & unsigned(iPC) + 1),MEMADDR_SIZE));
sABEq <= '1' when iDataA=iDataB else '0';

oValid <= iValid;

with iOpCode select oResult <=
	sSum when OP_ADD,
	sSumi when OP_ADDI,
	sNand when OP_NAND,
	sLui when OP_LUI,
	iDataA when OP_SW,
	std_logic_vector(resize(unsigned(sPCInc),REG_SIZE)) when OP_JALR,
	(others=>'0') when others;
	
with iOpCode select oResultWriteEn <=
	'1' when OP_ADD,
	'1' when OP_ADDI,
	'1' when OP_NAND,
	'1' when OP_LUI,
	'1' when OP_JALR,
	'0' when others;	

oMemAddr <= std_logic_vector(resize(signed('0' & iDataB) + resize(signed(iImmShort), REG_SIZE+1),MEMADDR_SIZE));
--oMemAddr <= std_logic_vector(resize(signed('0' & iDataB) + resize(signed(iImmShort), REG_SIZE+1),REG_SIZE));
oMemReadEn <= '1' when iValid='1' and iOpCode=OP_LW else '0';
oMemWriteEn <= '1' when iValid='1' and iOpCode=OP_SW else '0';

oBranchEn <= '1' when iValid='1' and ((iOpCode=OP_BEQ and sABEq='1') or iOpCode=OP_JALR) else '0';
oBranchAddr <= sBranchAddrRel when iOpCode=OP_BEQ else iDataB(MEMADDR_SIZE-1 downto 0);

oInt <= '1' when iValid='1' and iOpCode=OP_JALR and iDataA = (iDataA'range => '0') and sABEq='1' and not (iImmShort=(iImmShort'range => '0')) else '0';
oIntCode <= iImmShort;
	
end arch;

