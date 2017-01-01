-- TestBench Template 

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all;
--use ieee.std_logic_arith.all;
use work.common_pkg.all;

library work;


ENTITY bus_testbench IS
END bus_testbench;

ARCHITECTURE arch OF bus_testbench IS 

component bus_master_controller is
    port (
    iClk                : in std_logic;
    iRst                : in std_logic;
    iEn                 : in std_logic;                                 -- Enable transaction
    iCmd                : in std_logic;                                 -- transaction type (BUS_READ, BUS_WRITE)
    iAddr               : in std_logic_vector(BUS_ADDR_SIZE-1 downto 0); --Global address of data
    iWriteData          : in std_logic_vector(BUS_DATA_SIZE-1 downto 0); -- Data to write to device
    iReadyForResult     : in std_logic;                                 -- User is Ready for transaction result
    oReadData           : out std_logic_vector(BUS_DATA_SIZE-1 downto 0);-- Data read from device
    oResultValid        : out std_logic;                                -- Write operation was success or ReadData is valid
    oBusBusy            : out std_logic;                                -- bus is busy
    oReady              : out std_logic;                                -- controller is ready for new transaction
    oErr                : out std_logic;                                -- transation error
    iGrant              : in std_logic;                                 -- Daisy chained bus auth input
    oGrant              : out std_logic;                                -- Daisy chained bus auth output
    iBus                : in bus_sync;
    oBus                : out bus_sync);
end component;


component memory_controller is
    port (
    iClk						: in std_logic;
    iRst						: in std_logic;
    iBaseAddr           : in std_logic_vector(BUS_ADDR_SIZE-1 downto 0); --Global address of device
    iBus                : in bus_sync;  --bus_type record (data, addr, req, r_w, ready)
    oBus                : out bus_sync); --bus_type record (data, addr, req, r_w, ready)
end component;

constant clk_period : time := 10 ns;

signal clk				: std_logic := '0';
signal rst				: std_logic := '0';

signal sEn 	        : std_logic;
signal sCmd 	    : std_logic;

signal sAddr 	    : std_logic_vector (BUS_ADDR_SIZE-1 downto 0);

signal sWriteData 	: std_logic_vector (BUS_DATA_SIZE-1 downto 0);
signal sReadData 	: std_logic_vector (BUS_DATA_SIZE-1 downto 0);

signal sReadyForResult 	: std_logic;
signal sResultValid 	: std_logic;
signal sBusBusy 	    : std_logic;
signal sMasterReady 	    : std_logic;
signal sBusErr 	        : std_logic;
signal sGrantIn 	    : std_logic;
signal sGrantOut 	    : std_logic;

signal sBus 	        : bus_sync;
signal sBusFromMaster 	: bus_sync;
signal sBusFromMem 	    : bus_sync;


begin

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

-- Clock process definitions( clock with 50% duty cycle is generated here.
process
begin
    wait until sMasterReady='1';

    --Perform a write
    sCmd <= BUS_WRITE;
    sAddr <= x"5000";
    sEn <= '1';
    sWriteData <= x"CCCC";
    sReadyForResult <= '1';

    wait until clk='1';
    sEn <= '0';

    wait until sResultValid='1';

    wait until sMasterReady='1';

    --Perform a read
    sEn <= '1';
    sCmd <= BUS_READ;
    sAddr <= x"5000";
    sReadyForResult <= '1';

    wait until clk='1';
    sEn <= '0';

    wait until sResultValid='1';

    assert sReadData=sWriteData;
    wait;

end process;



busmaster : bus_master_controller
  PORT MAP (
    iClk => clk,
    iRst => rst,
    iEn => sEn,
    iCmd => sCmd,
    iAddr => sAddr,
    iWriteData => sWriteData,
    iReadyForResult => sReadyForResult,
    oReadData => sReadData,
    oResultValid => sResultValid,
    oBusBusy => sBusBusy,
    oReady => sMasterReady,
    oErr => sBusErr,
    iGrant => sGrantIn,
    oGrant => sGrantOut,
    iBus => sBus,
    oBus => sBusFromMaster);

memctrl : memory_controller
    port map (
    iClk => clk,
    iRst => rst,
    iBaseAddr => x"5000",
    iBus => sBus,
    oBus => sBusFromMem);




-- "or" the busses from each module together to form a common bus
-- modules are on the honor system: responsible to maintain zeros until granted control
--could be written by slave or master
sBus.data <= sBusFromMaster.data or sBusFromMem.data;

-- writte by masters only
sBus.addr <= sBusFromMaster.addr;
sBus.m_req <= sBusFromMaster.m_req;
sBus.m_cmd <= sBusFromMaster.m_cmd;

-- writte by slaves only
sBus.s_ack <= sBusFromMem.s_ack;
sBus.s_valid <= sBusFromMem.s_valid;

sGrantIn <= '1';

  --  End Test Bench 

  END;
