--------------------------------------------
-- bus_slave_controller

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--use ieee.std_logic_unsigned.all;
--use ieee.std_logic_arith.all;
use work.common_pkg.all;
--
library work;

entity bus_slave_controller is
    generic (
    DEV_ADDR_SIZE       : integer);
    port (
    iClk                : in std_logic;
    iRst                : in std_logic;
    iBus                : in bus_sync;  --bus_type record (data, addr, req, r_w, ready)
    oBus                : out bus_sync; --bus_type record (data, addr, req, r_w, ready)
    iBaseAddr           : in std_logic_vector(BUS_ADDR_SIZE-1 downto 0); --Global address of device
    oDevEn              : out std_logic;
    oDevReadEn          : out std_logic;
    oDevWriteEn         : out std_logic;
    oDevAddr            : out std_logic_vector(DEV_ADDR_SIZE-1 downto 0); --Global address of device
    oDataToDev          : out std_logic_vector(BUS_DATA_SIZE-1 downto 0); --Data to write to device
    iDataFromDev        : in std_logic_vector(BUS_DATA_SIZE-1 downto 0); --Data read from device
    iDataValid          : in std_logic);                                 --Data Valid
end bus_slave_controller;

architecture arch of bus_slave_controller is

signal sDevEn 	    : std_logic;
signal sDevWriteEn 	: std_logic;
signal sDevReadEn 	: std_logic;

begin

 -- check if bus addr is match for device.  If so, set enable bits
sDevEn <= '1' when iBus.m_req='1' and
            iBus.addr(BUS_ADDR_SIZE-1 downto DEV_ADDR_SIZE)=iBaseAddr(BUS_ADDR_SIZE-1 downto DEV_ADDR_SIZE)
             else '0';
oBus.s_ack <= sDevEn;

sDevWriteEn <= '1' when iBus.m_cmd=BUS_WRITE and sDevEn='1' else '0';
sDevReadEn <= '1' when iBus.m_cmd=BUS_READ and sDevEn='1' else '0';

oDevEn <= sDevEn;
oDevReadEn <= sDevReadEn;
oDevWriteEn <= sDevWriteEn;

-- low bits of bus address are phyiscal address for device
oDevAddr <= iBus.addr(DEV_ADDR_SIZE-1 downto 0);
oDataToDev <= iBus.data;

-- All output bus signals are valid only while sDevEn is high.
-- If address changes or req is lowered, output bus must go to zero (else risk bus collision)

-- Put data from device on the bus once its valid if there is an active read req
oBus.data <= iDataFromDev when iDataValid='1' and sDevReadEn='1' else (others=>'0'); 

oBus.s_valid <= sDevWriteEn or (iDataValid and sDevReadEn); 

-- keep these low for slave
oBus.addr <= (others=>'0');
oBus.m_req <= '0';
oBus.m_cmd <= '0';


end arch;
