--------------------------------------------
-- control
-- Top block of JPU
-- instantiates other entities and manages pipeline flow
-------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--use ieee.std_logic_unsigned.all;
--use ieee.std_logic_arith.all;
use work.common_pkg.all;
--
library work;

entity control is
    port (
    iClk                : in std_logic;
    iRst                : in std_logic;
	iRun				: in std_logic;										-- execution begins once this goes high
	oInt				: out std_logic;									-- interrupt
	oIntCode			: out STD_LOGIC_VECTOR (INTCODE_SIZE-1 downto 0));	-- interrupt code
end control;

architecture arch of control is


--------------
-- decoder
--------------
-- parse instruction into components
-- fully combinatorial
-- not all outputs are valid, depends on opcode
component decoder
    Port (	iInstruction : in  STD_LOGIC_VECTOR (REG_SIZE-1 downto 0);	--16bit instruction
			iValid:		in STD_LOGIC;									--valid flag for instruction
			oOpCode : out  STD_LOGIC_VECTOR (OPCODE_SIZE-1 downto 0);	--3 bit opcode
			oRegSelA : out  STD_LOGIC_VECTOR (REGADDR_SIZE-1 downto 0); -- register select (0-7) for 1st register
			oRegSelB : out  STD_LOGIC_VECTOR (REGADDR_SIZE-1 downto 0); -- register select (0-7) for 2nd register
			oRegSelC : out  STD_LOGIC_VECTOR (REGADDR_SIZE-1 downto 0); -- register select (0-7) for 3rd register
			oReadAEn : out STD_LOGIC;									-- reg A is input (needed for hazard prediction)
			oReadBEn : out STD_LOGIC;									-- reg B is input (needed for hazard prediction)
			oReadCEn : out STD_LOGIC;									-- reg C is input (needed for hazard prediction)
			oImmShort : out  STD_LOGIC_VECTOR (IMMSHORT_SIZE-1 downto 0); -- 7 bit immedaite
			oImmLong : out  STD_LOGIC_VECTOR (IMMLONG_SIZE-1 downto 0);	-- 10 bit immediate	
			oValid:		out STD_LOGIC);									-- passes back iValid. Possible future error checking
  end component;

--------------
-- blockram
--------------
-- Xilinx BlockRAM Generator
-- Port A used for instruction fetching (read only)
-- Port B used for memory read/writes
component blockram
  PORT (
    clka : IN STD_LOGIC;
    ena : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(MEMADDR_SIZE-1 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0);
    clkb : IN STD_LOGIC;
    enb : IN STD_LOGIC;
    web : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addrb : IN STD_LOGIC_VECTOR(MEMADDR_SIZE-1 DOWNTO 0);
    dinb : IN STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(REG_SIZE-1 DOWNTO 0)
  );
  end component;
  
--------------
-- reg_file 
--------------
-- reads are combinatorial, writes are sequenctial and registered
-- read/write to same register returns iDataWrite
component reg_file
    port (
    iClk                        : in std_logic;
    iRst                        : in std_logic;
    iWriteEn	                : in std_logic;
    iWriteSel	                : in std_logic_vector(REGADDR_SIZE-1  downto 0);
    iDataWrite	                : in std_logic_vector(REG_SIZE-1  downto 0);
    iRegSelA	                : in std_logic_vector(REGADDR_SIZE-1  downto 0);
    oDataA	    	            : out std_logic_vector(REG_SIZE-1 downto 0);
    iRegSelB	                : in std_logic_vector(REGADDR_SIZE-1  downto 0);
    oDataB		                : out std_logic_vector(REG_SIZE-1 downto 0);
    iRegSelC	                : in std_logic_vector(REGADDR_SIZE-1  downto 0);
    oDataC		                : out std_logic_vector(REG_SIZE-1 downto 0));
  end component;

component alu
    Port ( iValid:		in STD_LOGIC;
           iOpCode : 	in  STD_LOGIC_VECTOR (2 downto 0);
           iDataA : 	in  STD_LOGIC_VECTOR (REG_SIZE-1 downto 0);
           iDataB : 	in  STD_LOGIC_VECTOR (REG_SIZE-1 downto 0);
           iDataC : 	in  STD_LOGIC_VECTOR (REG_SIZE-1 downto 0);
           iImmShort : 	in  STD_LOGIC_VECTOR (6 downto 0);
           iImmLong : 	in  STD_LOGIC_VECTOR (9 downto 0);
           iPC : 		in  STD_LOGIC_VECTOR (MEMADDR_SIZE-1 downto 0);	-- address of current instruction (needed for relative branches)
		   oValid: 		out STD_LOGIC;									-- ALU result is valid
           oResult : 	out  STD_LOGIC_VECTOR (REG_SIZE-1 downto 0);	-- ALU result
		   oResultWriteEn: 	out STD_LOGIC;								-- set if result is to be written to register
           oMemAddr : 	out  STD_LOGIC_VECTOR (MEMADDR_SIZE-1 downto 0); -- Address for memory ops
		   oMemReadEn: 	out STD_LOGIC;									-- set if mem to be read
		   oMemWriteEn: out STD_LOGIC;									-- set if mem to be written
		   oBranchEn: 	out STD_LOGIC;									-- set if branch/jump occurs
		   oBranchAddr: out STD_LOGIC_VECTOR (MEMADDR_SIZE-1 downto 0);	-- address to branch to
		   oInt:		out STD_LOGIC;									-- set if interrupt occurs
		   oIntCode:	out STD_LOGIC_VECTOR (IMMSHORT_SIZE-1 downto 0)); -- interrupt code
  end component;
  

-- CPU is fully pipelined, new instruction fetched and processed evey clock (except for branching and some hazards)
-- Pipeline is: Fetch -> Decode/Reg Read -> ALU -> Mem Read/Write -> Reg Write
-- All signals are registered between stages.
--

--signals for Fetch Stage
signal sRun			 		: STD_LOGIC := '0';							-- Start processing instructions
signal sPC 					: STD_LOGIC_VECTOR(MEMADDR_SIZE-1 downto 0);--Program counter (for op that has just been fetched)
signal sPCInc 				: STD_LOGIC_VECTOR(MEMADDR_SIZE-1 downto 0);--sPC+1
signal sPCNext 				: STD_LOGIC_VECTOR(MEMADDR_SIZE-1 downto 0);--PC for next op (to be fetched)
signal sBranchAddr 			: STD_LOGIC_VECTOR(MEMADDR_SIZE-1 downto 0);--Address to jump/branch
signal sBranchEn 			: STD_LOGIC := '0';							--Branch if true
signal sInstructionFetch    : STD_LOGIC_VECTOR(REG_SIZE-1 downto 0);	--Fetched instruction

-- Signals for Decode/Reg Read Stage
signal sInstructionDecode : STD_LOGIC_VECTOR(REG_SIZE-1 downto 0);
signal sOpCodeDecode 		: STD_LOGIC_VECTOR(OPCODE_SIZE-1 downto 0);
signal sRegSelADecode 		: STD_LOGIC_VECTOR(REGADDR_SIZE-1 downto 0);
signal sRegSelBDecode 		: STD_LOGIC_VECTOR(REGADDR_SIZE-1 downto 0);
signal sRegSelCDecode 		: STD_LOGIC_VECTOR(REGADDR_SIZE-1 downto 0);
signal sReadAEn 			: STD_LOGIC;
signal sReadBEn 			: STD_LOGIC;
signal sReadCEn 			: STD_LOGIC;
signal sImmShortDecode 		: STD_LOGIC_VECTOR(IMMSHORT_SIZE-1 downto 0);
signal sImmLongDecode	 	: STD_LOGIC_VECTOR(IMMLONG_SIZE-1 downto 0);
signal sPCDecode 			: STD_LOGIC_VECTOR(MEMADDR_SIZE-1 downto 0);
signal sRegWriteSelDecode	: STD_LOGIC_VECTOR(REGADDR_SIZE-1 downto 0);
signal sDataARegFile		: STD_LOGIC_VECTOR(REG_SIZE-1 downto 0);
signal sDataBRegFile		: STD_LOGIC_VECTOR(REG_SIZE-1 downto 0);
signal sDataCRegFile		: STD_LOGIC_VECTOR(REG_SIZE-1 downto 0);


-- signals for ALU stage
signal sOpCodeALU			: STD_LOGIC_VECTOR(OPCODE_SIZE-1 downto 0);
signal sDataAALU			: STD_LOGIC_VECTOR(REG_SIZE-1 downto 0);
signal sDataBALU			: STD_LOGIC_VECTOR(REG_SIZE-1 downto 0);
signal sDataCALU			: STD_LOGIC_VECTOR(REG_SIZE-1 downto 0);
signal sImmShortALU			: STD_LOGIC_VECTOR(IMMSHORT_SIZE-1 downto 0);
signal sImmLongALU			: STD_LOGIC_VECTOR(IMMLONG_SIZE-1 downto 0);
signal sPCALU				: STD_LOGIC_VECTOR(MEMADDR_SIZE-1 downto 0);
signal sResultALU			: STD_LOGIC_VECTOR(REG_SIZE-1 downto 0);
signal sResultWriteEnALU	: STD_LOGIC := '0';
signal sRegWriteSelALU		: STD_LOGIC_VECTOR(REGADDR_SIZE-1 downto 0);
signal sMemAddrALU			: STD_LOGIC_VECTOR(MEMADDR_SIZE-1 downto 0);
signal sMemReadEnALU		: STD_LOGIC := '0';
signal sMemWriteEnALU		: STD_LOGIC := '0';
signal sInt					: STD_LOGIC := '0';
signal sIntCode				: STD_LOGIC_VECTOR(INTCODE_SIZE-1 downto 0);

-- signals for Mem stage
signal sResultMem			: STD_LOGIC_VECTOR(REG_SIZE-1 downto 0);
signal sResultWriteEnMem	: STD_LOGIC := '0';
signal sMemAddrMem			: STD_LOGIC_VECTOR(MEMADDR_SIZE-1 downto 0);
signal sRegWriteSelMem		: STD_LOGIC_VECTOR(REGADDR_SIZE-1 downto 0);
signal sMemReadEnMem		: STD_LOGIC := '0';
signal sMemWriteEnMem		: STD_LOGIC := '0';
signal sDataFromMem			: STD_LOGIC_VECTOR(REG_SIZE-1 downto 0);
signal sMemEn				: STD_LOGIC := '0';
signal sMemWriteEn		: STD_LOGIC := '0';

-- because BlockRAM is synchronous, we must define its inputs combinatorially
signal sValidMem_C			: STD_LOGIC := '0';
signal sMemReadEnMem_C		: STD_LOGIC := '0';
signal sMemWriteEnMem_C		: STD_LOGIC := '0';
signal sMemAddrMem_C		: STD_LOGIC_VECTOR(MEMADDR_SIZE-1 downto 0);
signal sResultMem_C			: STD_LOGIC_VECTOR(REG_SIZE-1 downto 0);

signal sRegWriteEnRW		: STD_LOGIC := '0';
signal sRegWriteSelRW		: STD_LOGIC_VECTOR(REGADDR_SIZE-1 downto 0);
signal sRegWriteDataRW		: STD_LOGIC_VECTOR(REG_SIZE-1 downto 0);


-- Hazards flags
-- Read after Write (RAW) for each register 'slot'
-- Read after Memory Load (RAL) for each register 'slot'
-- "1" implies conflict with preceeding op
-- "2" implies conflict with 2 ops prior
signal sRAW1A				: STD_LOGIC := '0';
signal sRAW1B				: STD_LOGIC := '0';
signal sRAW1C				: STD_LOGIC := '0';
signal sRAW2A				: STD_LOGIC := '0';
signal sRAW2B				: STD_LOGIC := '0';
signal sRAW2C				: STD_LOGIC := '0';
signal sRAL1A				: STD_LOGIC := '0';
signal sRAL1B				: STD_LOGIC := '0';
signal sRAL1C				: STD_LOGIC := '0';
signal sRAL2A				: STD_LOGIC := '0';
signal sRAL2B				: STD_LOGIC := '0';
signal sRAL2C				: STD_LOGIC := '0';
signal sRALA				: STD_LOGIC := '0';-- RAL1 or RAL2
signal sRALB				: STD_LOGIC := '0';-- RAL1 or RAL2
signal sRALC				: STD_LOGIC := '0';-- RAL1 or RAL2
-- RAW/RAL is possible...
signal sRAW1Possible		: STD_LOGIC := '0';
signal sRAW2Possible		: STD_LOGIC := '0';
signal sRAL1Possible		: STD_LOGIC := '0';
signal sRAL2Possible		: STD_LOGIC := '0';


-- Valid flags indicate if instruction at that stage is valid
-- Allows for 'bubbles' to propagate when branches/hazards occur
signal sValidFetch	 		: STD_LOGIC := '0';
signal sValidDecodeIn 		: STD_LOGIC := '0';
signal sValidDecodeOut 		: STD_LOGIC := '0';
signal sValidALUIn	 		: STD_LOGIC := '0';
signal sValidALUOut	 		: STD_LOGIC := '0';
signal sValidMem			: STD_LOGIC := '0';
signal sValidRW				: STD_LOGIC := '0';

--Stall flags allow pipeline to stall
-- when high, all input signals for that stage are maintained through to next clock
signal sStallRAL			: STD_LOGIC := '0';
signal sStall_Fetch			: STD_LOGIC := '0';
signal sStall_Decode		: STD_LOGIC := '0';
signal sStall_ALU			: STD_LOGIC := '0';
signal sStall_Mem			: STD_LOGIC := '0';
signal sStall_RW			: STD_LOGIC := '0';

begin

--Run Register
process(iClk)
begin
    if (rising_edge (iClk)) then
		if iRst='1' then
			sRun <= '0';
		else
			sRun <= iRun;
		end if;
	end if;
end process;

--PC Register
process(iClk)
begin
    if (rising_edge (iClk)) then
		if iRst='1' then
			sPC <= (others=>'1');
			sValidFetch <= '0';	
		else
			if sRun='1' then
				sPC <= sPCNext;
				sValidFetch <= '1';	
			else
 				sPC <= sPC;
				sValidFetch <= '0';	
			end if;
		end if;
	end if;
end process;

sPCInc <= std_logic_vector(unsigned(sPC) + 1);
sPCNext <= sBranchAddr when sBranchEn = '1' else
			 sPC when sStall_Fetch = '1' else
			 sPCInc;

ram1 : blockram
  PORT MAP (
    clka => iClk,
    ena => sRun,
    wea(0) => '0',
    addra => sPCNext,
    dina => (others => '0'),
    douta => sInstructionFetch,
    clkb => iClk,
    enb => sMemEn,
    web(0) => sMemWriteEn,
    addrb => sMemAddrMem_C,
    dinb => sResultMem_C,
    doutb => sDataFromMem
  );
-- RAM inputs are registered on clock edge,
-- so they need to be valid on *previous* (ALU) pipeline stage.
sMemEn <= sValidMem_C and (sMemReadEnMem_C or sMemWriteEnMem_C);
sMemWriteEn <= sValidMem_C and sMemWriteEnMem_C;

--Fetch->Decode Registers
process(iClk)
begin
    if (rising_edge (iClk)) then
		if iRst='1' then
			sInstructionDecode <= (others=>'0');
			sValidDecodeIn <= '0';
			sPCDecode <= (others=>'0');
		else
			if sStall_Decode = '1' then
				sInstructionDecode <= sInstructionDecode;
				sValidDecodeIn <= sValidDecodeIn;
				sPCDecode <= sPCDecode;
			else
				sInstructionDecode <= sInstructionFetch;
				--if we are branching (as result of op currently in ALU)
				--then ops upstream of ALU are invalid
				--Also if Fetch stage is stalled, then output is invalid
				if sBranchEn = '1' or sStall_Fetch='1' or sInt='1' then
					sValidDecodeIn <= '0';
				else
					sValidDecodeIn <= sValidFetch;
				end if;
				sPCDecode <= sPC;
			end if;
		end if;
	end if;
end process;


decoder1: decoder port map
  ( iInstruction =>  sInstructionDecode,
	iValid => sValidDecodeIn,
	oOpCode => sOpCodeDecode,
	oRegSelA => sRegSelADecode,
	oRegSelB => sRegSelBDecode,
	oRegSelC => sRegSelCDecode,
	oReadAEn => sReadAEn,
	oReadBEn => sReadBEn,
	oReadCEn => sReadCEn,
	oImmShort => sImmShortDecode,
	oImmLong => sImmLongDecode,
	oValid => sValidDecodeOut
	);


reg_file1: reg_file port map
  ( iClk => iClk,
	iRst => iRst,
    iWriteEn => sRegWriteEnRW,
    iWriteSel => sRegWriteSelRW,
    iDataWrite	=> sRegWriteDataRW,
    iRegSelA => sRegSelADecode,
    oDataA => sDataARegFile,
    iRegSelB => sRegSelBDecode,
    oDataB => sDataBRegFile,
    iRegSelC => sRegSelCDecode,
    oDataC => sDataCRegFile);

sRegWriteSelDecode <= sRegSelADecode;  -- For our instruction set, all writes are to Reg A

--Decode->ALU Registers
process(iClk)
begin
    if (rising_edge (iClk)) then
		if iRst='1' then
			sValidALUIn <= '0';
			sOpCodeALU <= (others=>'0');
			sDataAALU <= (others=>'0');
			sDataBALU <= (others=>'0');
			sDataCALU <= (others=>'0');
			sImmShortALU <= (others=>'0');
			sImmLongALU <= (others=>'0');
			sPCALU <= (others=>'0');
			sRegWriteSelALU <= (others=>'0');
		else
		
			if sStall_ALU = '1' then
				sValidALUIn <= sValidALUIn;
				sOpCodeALU <= sOpCodeALU;
				sDataAALU <= sDataAALU;
				sDataBALU <= sDataBALU;
				sDataCALU <= sDataCALU;
				sImmShortALU <= sImmShortALU;
				sImmLongALU <= sImmLongALU;
				sPCALU <= sPCALU;
				sRegWriteSelALU <= sRegWriteSelALU;
			else
				--if we are branching (as result of op currently in ALU)
				--then ops upstream of ALU are invalid
				--Also if Decode stage is stalled, then output is invalid
				if sBranchEn = '1' or sStall_Decode='1' or sInt='1' then
					sValidALUIn <= '0';
				else
					sValidALUIn <= sValidDecodeOut;
				end if;
				sOpCodeALU <= sOpCodeDecode;
				sImmShortALU <= sImmShortDecode;
				sImmLongALU <= sImmLongDecode;
				sPCALU <= sPCDecode;
				sRegWriteSelALU <= sRegWriteSelDecode;				

				--Data into ALU depends on RAW/RAL hazards				
				--RAW1 means that ALU input data is the previous ALU result...
				--RAW2 means that ALU input data is ALU result from 2 ops ago, now in Mem stage
				--RAL means that ALU input is data from memory read.
				--	RAL1/RAL2 are differentiated in that RAL1 needs extra clock before memory read is valid.
				-- 	This stall is handled elsewhere, so we treat all RAL hazards equally at this point...
				if sRAW1A='1' then
					sDataAALU <= sResultALU;
				elsif sRALA='1' then
					sDataAALU <= sDataFromMem;
				elsif sRAW2A='1' then
					sDataAALU <= sResultMem;
				else
					sDataAALU <= sDataARegFile;
				end if;
				if sRAW1B='1' then
					sDataBALU <= sResultALU;
				elsif sRALB='1' then
					sDataBALU <= sDataFromMem;
				elsif sRAW2B='1' then
					sDataBALU <= sResultMem;
				else
					sDataBALU <= sDataBRegFile;
				end if;
				if sRAW1C='1' then
					sDataCALU <= sResultALU;
				elsif sRALC='1' then
					sDataCALU <= sDataFromMem;
				elsif sRAW2C='1' then
					sDataCALU <= sResultMem;
				else
					sDataCALU <= sDataCRegFile;
				end if;
			end if;
		end if;
	end if;
end process;


alu1: alu port map
  ( iValid => sValidALUIn,
	iOpCode => sOpCodeALU,
	iDataA => sDataAALU,
	iDataB => sDataBALU,
	iDataC => sDataCALU,
	iImmShort => sImmShortALU,
	iImmLong => sImmLongALU,
	iPC => sPCALU,
	oValid => sValidALUOut,
	oResult => sResultALU,
	oResultWriteEn => sResultWriteEnALU,
	oMemAddr => sMemAddrALU,
	oMemReadEn => sMemReadEnALU,
	oMemWriteEn => sMemWriteEnALU,
	oBranchAddr => sBranchAddr,
	oBranchEn => sBranchEn,
	oInt => sInt,
	oIntCode => sIntCode);

-- We don't really do anything with Ints yet other than stall the pipeline and return the intcode to the testbench
oInt <= sInt;
oIntCode <= sIntCode;

--inputs to BlockRAM IP are synchonrous, so they must be computed combinatorially rather than registered
sValidMem_C <= sValidMem when sStall_Mem='1' else
				'0' when sStall_ALU='1' else
				sValidALUOut; --If ALU stage is stalled, then output is invalid
sMemReadEnMem_C <= sMemReadEnMem when sStall_Mem='1' else sMemReadEnALU;
sMemWriteEnMem_C <= sMemWriteEnMem when sStall_Mem='1' else sMemWriteEnALU;
sMemAddrMem_C <= sMemAddrMem when sStall_Mem='1' else sMemAddrALU;
sResultMem_C <= sResultMem when sStall_Mem='1' else sResultALU;

--ALU->Memory Registers
process(iClk)
begin
    if (rising_edge (iClk)) then
		if iRst='1' then
			sValidMem <= '0';
			sResultMem <= (others=>'0');
			sResultWriteEnMem <= '0';
			sRegWriteSelMem <= (others=>'0');
			sMemAddrMem <= (others=>'0');
			sMemReadEnMem <= '0';
			sMemWriteEnMem <= '0';
		else
			if sStall_Mem = '1' then
				sValidMem <= sValidMem;
				sResultMem <= sResultMem;
				sResultWriteEnMem <= sResultWriteEnMem;
				sRegWriteSelMem <= sRegWriteSelMem;
				sMemAddrMem <= sMemAddrMem;
				sMemReadEnMem <= sMemReadEnMem;
				sMemWriteEnMem <= sMemWriteEnMem;
			else
				sValidMem <= sValidMem_C;
				sResultMem <= sResultMem_C;
				sMemAddrMem <= sMemAddrMem_C;
				sMemReadEnMem <= sMemReadEnMem_C;
				sMemWriteEnMem <= sMemWriteEnMem_C;
				sResultWriteEnMem <= sResultWriteEnALU;
				sRegWriteSelMem <= sRegWriteSelALU;
			end if;
		end if;
	end if;
end process;


--Memory->RegWrite Registers
process(iClk)
begin
    if (rising_edge (iClk)) then
		if iRst='1' then
			sValidRW <= '0';
			sRegWriteEnRW <= '0';
			sRegWriteSelRW <= (others=>'0');
			sRegWriteDataRW <= (others=>'0');
		else
			if sStall_RW = '1' then
				sValidRW <= sValidRW;
				sRegWriteEnRW <= sRegWriteEnRW;
				sRegWriteSelRW <= sRegWriteSelRW;
				sRegWriteDataRW <= sRegWriteDataRW;
			else
				--If Mem stage is stalled, then output is invalid
				if sStall_Mem = '1' then
					sValidRW <= '0';
				else
					sValidRW <= sValidMem;
				end if;
				sRegWriteSelRW <= sRegWriteSelMem;
				if sValidMem = '1' and sMemReadEnMem = '1' then
					-- Write Data from Memory to Register
					sRegWriteEnRW <= '1';
					sRegWriteDataRW <= sDataFromMem;
				elsif sValidMem = '1' and sResultWriteEnMem = '1' then
					-- Write Result from ALU to Register
					sRegWriteEnRW <= '1';
					sRegWriteDataRW <= sResultMem;
				else
					-- No Register Writes
					sRegWriteEnRW <= '0';
					sRegWriteDataRW <= (others=>'0');
				end if;
			end if;
		end if;
	end if;
end process;

-- Identify Hazards
--RAW flag is true if reg will be written by previous ALU result
--RAL flag is true if reg will be written by previous Memory load
--Stage 1 hazard indicate hazard from immediately preceding op
--Stage 2 hazard indicates hazard from 2 ops previous.
sRAW1Possible <= '1' when sValidDecodeOut='1' and sValidALUOut='1' and sResultWriteEnALU='1' and (sRegWriteSelALU /= "000") else '0';
sRAW2Possible <= '1' when sValidDecodeOut='1' and sValidMem='1' and sResultWriteEnMem='1' and (sRegWriteSelMem /= "000") else '0';
sRAL1Possible <= '1' when sValidDecodeOut='1' and sValidALUOut='1' and sMemReadEnALU='1' and (sRegWriteSelALU /= "000") else '0';
sRAL2Possible <= '1' when sValidDecodeOut='1' and sValidMem='1' and sMemReadEnMem='1' and (sRegWriteSelMem /= "000") else '0';
sRAW1A <= '1' when sReadAEn='1' and (sRegSelADecode=sRegWriteSelALU) and sRAW1Possible='1' else '0';
sRAW1B <= '1' when sReadBEn='1' and (sRegSelBDecode=sRegWriteSelALU) and sRAW1Possible='1' else '0';
sRAW1C <= '1' when sReadCEn='1' and (sRegSelCDecode=sRegWriteSelALU) and sRAW1Possible='1' else '0';
sRAW2A <= '1' when sReadAEn='1' and (sRegSelADecode=sRegWriteSelMem) and sRAW2Possible='1' else '0';
sRAW2B <= '1' when sReadBEn='1' and (sRegSelBDecode=sRegWriteSelMem) and sRAW2Possible='1' else '0';
sRAW2C <= '1' when sReadCEn='1' and (sRegSelCDecode=sRegWriteSelMem) and sRAW2Possible='1' else '0';
sRAL1A <= '1' when sReadAEn='1' and (sRegSelADecode=sRegWriteSelALU) and sRAL1Possible='1' else '0';
sRAL1B <= '1' when sReadBEn='1' and (sRegSelBDecode=sRegWriteSelALU) and sRAL1Possible='1' else '0';
sRAL1C <= '1' when sReadCEn='1' and (sRegSelCDecode=sRegWriteSelALU) and sRAL1Possible='1' else '0';
sRAL2A <= '1' when sReadAEn='1' and (sRegSelADecode=sRegWriteSelMem) and sRAL2Possible='1' else '0';
sRAL2B <= '1' when sReadBEn='1' and (sRegSelBDecode=sRegWriteSelMem) and sRAL2Possible='1' else '0';
sRAL2C <= '1' when sReadCEn='1' and (sRegSelCDecode=sRegWriteSelMem) and sRAL2Possible='1' else '0';

--RAL hazards at all stages are handled in the same way, (Mem out -> ALU data in)
--Difference is that stage 1 RAL hazards must first stall the pipeline to wait for memory load
sRALA <= sRAL1A or sRAL2A;
sRALB <= sRAL1B or sRAL2B;
sRALC <= sRAL1C or sRAL2C;
sStallRAL <= sRAL1A or sRAL1B or sRAL1C;

--Stall fetch and decode stages if we have a RAL or Interrupt
sStall_Fetch <= sStallRAL or sInt;
sStall_Decode <= sStallRAL or sInt;

end arch;
