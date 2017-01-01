--------------------------------------------
-- Top block of JPU
-- instantiates control and memory, and routes bus
-------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--use ieee.std_logic_unsigned.all;
--use ieee.std_logic_arith.all;
use work.common_pkg.all;
--
library work;

entity top is
    port (
    iClk                : in std_logic;
    iRst                : in std_logic);
end top;

architecture arch of top is

component JPUcontrol is
    port (
    iClk                : in std_logic;
    iRst                : in std_logic;
    iBus                : in bus_type;
    iBusGrant           : in std_logic;
    oBus                : in bus_type;
    oBusGrant           : in std_logic);
end component;

component memory_controller is
    port (
    iClk                : in std_logic;
    iRst                : in std_logic;
    iBus                : in bus_type;
    iBusGrant           : in std_logic;
    oBus                : in bus_type;
    oBusGrant           : in std_logic);
end component;


signal sBus			    : bus_type;
signal sBusFromCPU		: bus_type;
signal sBusFromMem		: bus_type;
signal sBusGrantToCPU	: STD_LOGIC;
signal sBusGrantFromCPU	: STD_LOGIC;
signal sBusGrantToMem	: STD_LOGIC;
signal sBusGrantFromMem	: STD_LOGIC;

begin

sRun <= not iRst;

cpu : JPUcontrol
  PORT MAP (
    iClk <= iClk,
    iRst <= iRst,
    iBus <= sBus,
    iBusGrant <= sBusGrantToCPU,
    oBus <= sBusFromCPU,
    oBusGrant <= sBusGrantFromCPU
  );

mem1 : memory_controller
  PORT MAP (
    iClk <= iClk,
    iRst <= iRst,
    iBus <= sBus,
    iBusGrant <= sBusGrantToMem,
    oBus <= sBusFromMem,
    oBusGrant <= sBusGrantFromMem
  );

-- "or" the busses from each module together to form a common bus
-- modules are on the honor system: responsible to maintain zeros until granted control
sBus <= sBusFromCPU or sBusFromMem;  -- will this work??
-- sBus.data <= sBusFromCPU.data or sBusFromMem.data;
-- sBus.addr <= sBusFromCPU.addr or sBusFromMem.addr;
-- sBus.req <= sBusFromCPU.req or sBusFromMem.req;
-- sBus.r_w <= sBusFromCPU.r_w or sBusFromMem.r_w;
-- sBus.ready <= sBusFromCPU.ready or sBusFromMem.ready;

-- Daisychain grant permission. Bus access is strictly in order of priority (no "fairness arbitration)
-- CPU -> Mem -> other...
sBusGrantToCPU <= sBus.req;
sBusGrantToMem <= sBusGrantFromCPU;


end arch;
