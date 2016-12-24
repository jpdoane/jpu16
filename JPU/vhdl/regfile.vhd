library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
--use ieee.std_logic_arith.all;
use work.common_pkg.all;
--
library work;

--------------
-- reg_file 
--------------
-- reads are combinatorial, writes are sequenctial and registered
-- read/write to same register returns iDataWrite

entity reg_file is
    port (
    iClk                        : in std_logic;
    iRst                        : in std_logic;
    iWriteEn	                : in std_logic;
    iWriteSel	                : in std_logic_vector(REGADDR_SIZE-1  downto 0);
    iDataWrite	                : in std_logic_vector(REG_SIZE-1  downto 0);
    iRegSelA	                : in std_logic_vector(REGADDR_SIZE-1  downto 0);
    oDataA	                : out std_logic_vector(REG_SIZE-1 downto 0);
    iRegSelB	                : in std_logic_vector(REGADDR_SIZE-1  downto 0);
    oDataB	                : out std_logic_vector(REG_SIZE-1 downto 0);
    iRegSelC	                : in std_logic_vector(REGADDR_SIZE-1  downto 0);
    oDataC	                : out std_logic_vector(REG_SIZE-1 downto 0)
    );
end reg_file;

architecture arch of reg_file is


--------------------------------------------------------
-- Signals
--------------------------------------------------------
type REG_ARRAY is array(NUM_REGS-1 downto 0) of std_logic_vector(REG_SIZE-1 downto 0);
signal sRegisters				: REG_ARRAY := (others=> (others=>'0'));

begin

-- Combinatorial Reads...
oDataA <= iDataWrite when iRegSelA=iWriteSel and iWriteEn='1' else sRegisters(to_integer(unsigned(iRegSelA)));
oDataB <= iDataWrite when iRegSelB=iWriteSel and iWriteEn='1' else sRegisters(to_integer(unsigned(iRegSelB)));
oDataC <= iDataWrite when iRegSelC=iWriteSel and iWriteEn='1' else sRegisters(to_integer(unsigned(iRegSelC)));

-- Seq writes
process(iClk)
begin
    if (rising_edge (iClk)) then
		if iRst='1' then
			 sRegisters <= (others=>(others=>'0')); 
		else
			for i in 1 to NUM_REGS-1 loop -- don't write to reg 0
				if (iWriteEn='1') and (iWriteSel=std_logic_vector(to_unsigned(i, REGADDR_SIZE))) then
					sRegisters(i) <= iDataWrite;
				else
					sRegisters(i) <= sRegisters(i);
				end if;
				sRegisters(0) <= (others=>'0');				
			end loop;
		end if;
  end if;
end process;

end;
