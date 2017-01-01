--------------------------------------------
-- bus_master_controller
--
-- 
-- after iReadyForResult and oResultValid are high, result is read by user and controller with then be ready to accept new commands

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--use ieee.std_logic_unsigned.all;
--use ieee.std_logic_arith.all;
use work.common_pkg.all;
--
library work;


entity bus_master_controller is
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
end bus_master_controller;

architecture arch of bus_master_controller is

signal sEn 	        : std_logic;
signal sCmd 	    : std_logic;
signal sBusActive 	: std_logic;

signal sAddr 	    : std_logic_vector (BUS_ADDR_SIZE-1 downto 0);

signal sWriteData 	: std_logic_vector (BUS_DATA_SIZE-1 downto 0);
signal sReadData 	: std_logic_vector (BUS_DATA_SIZE-1 downto 0);

signal sState 	    : std_logic_vector (2 downto 0);
signal sNextState   : std_logic_vector (2 downto 0);

constant RESET 	    : std_logic_vector (2 downto 0) := "000";
constant READY 	    : std_logic_vector (2 downto 0) := "001";
constant ACTIVE 	: std_logic_vector (2 downto 0) := "010";
constant COMPLETE 	: std_logic_vector (2 downto 0) := "011";
constant ERR 	    : std_logic_vector (2 downto 0) := "100";
constant BLOCKED 	: std_logic_vector (2 downto 0) := "101";

begin

-- Register inputs on Ready
process(iClk)
begin
    if (rising_edge (iClk)) then
		if iRst='1' then
            sEn <= '0';
            sCmd <= '0';
            sAddr <= (others=>'0');
            sWriteData <= (others=>'0');
            sReadData <= (others=>'0');
        else
            if sState=READY then
                sEn <= iEn;
                sCmd <= iCmd;
                sAddr <= iAddr;
                sWriteData <= iWriteData;
            else
                sEn <= sEn;
                sCmd <= sCmd;
                sAddr <= sAddr;
                sWriteData <= sWriteData;
            end if;
            if sState=ACTIVE then
                sReadData <= ibus.data;
            else
                sReadData <= sReadData;
            end if;
        end if;
    end if;
end process;


sBusActive <= '1' when sState=ACTIVE else '0';                              -- we are actively using the bus
oGrant <= '0' when iEn='1' or sState=BLOCKED or sBusActive='1' else iGrant; -- Block downstream grants if we are or want to be active

-- on active bus, raise bus req, addr and cmd lines
obus.m_req <= sBusActive;                               -- slave results will remain valid until this goes low
obus.addr <= sAddr when sBusActive='1' else (others=>'0');
obus.m_cmd <= sCmd when sBusActive='1' else '0';        -- BUS_READ or BUS_WRITE

obus.s_ack <= '0';
obus.s_valid <= '0';

--put data on bus if active write
obus.data <= sWriteData when sBusActive='1' and sCmd=BUS_WRITE else (others=>'0');

--output data upon complete read
oReadData <= sReadData when sState=COMPLETE and sCmd=BUS_READ else (others=>'0');
-- Read data valid or successful write
oResultValid <= '1' when sState=COMPLETE else '0';

--inform user of state of bus/controller
oBusBusy <= not iGrant; -- still accept/register inputs even if bus is busy.  We will wait...
oReady <= '1' when sState=READY else '0';
oErr <= '1' when sState=ERR else '0';

-- Update State Reg
process(iClk)
begin
    if (rising_edge (iClk)) then
		if iRst='1' then
            sState <= RESET;
        else
            sState <= sNextState;
        end if;
    end if;
end process;

-- compute next state (combinatorial)
process(sState, iEn, iGrant,ibus.s_valid, ibus.s_ack, iReadyForResult)
begin
case sState is
    when RESET =>
        sNextState <= READY;
    when READY =>   -- Controller is ready and available for new transaction command
        if iEn='1' then
            -- if we have auth to use the bus, go to active. Else to go blocked, where we wait for the bus
            if iGrant='1' then
                sNextState <= ACTIVE;
            else
                sNextState <= BLOCKED;
            end if;
        else
            sNextState <= READY;
        end if;
    when BLOCKED =>
        -- we could add a bus timeout here eventually...
            if iGrant='1' then
                sNextState <= ACTIVE;
            else
                sNextState <= BLOCKED;
            end if;
    when ACTIVE =>
        if ibus.s_ack='1' then
            -- we could add a slave timeout here eventually...
            if ibus.s_valid='1' then
                sNextState <= COMPLETE;
            else
                sNextState <= ACTIVE;
            end if;
        else
            -- something is wrong if we didn;t get an ack
            -- either no slave device at that address or other problem on slave end.
            sNextState <= ERR;
        end if;
    when COMPLETE =>
        --wait unit user is ready to read results before returning to ready
        if iReadyForResult='1' then
            sNextState <= READY;
        else
            sNextState <= COMPLETE;
        end if;
    when ERR =>
        --wait unit user is ready to read results before returning to ready
        if iReadyForResult='1' then
            sNextState <= READY;
        else
            sNextState <= ERR;
        end if;
    when others =>
        sNextState <= ERR;                              --shouldn't happen...
end case;
end process;


end arch;
