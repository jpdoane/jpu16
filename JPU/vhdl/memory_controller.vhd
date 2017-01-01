--------------------------------------------
-- memory_controller

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--use ieee.std_logic_unsigned.all;
--use ieee.std_logic_arith.all;
use work.common_pkg.all;
--
library work;

entity memory_controller is
    port (
    iClk						: in std_logic;
    iRst						: in std_logic;
    iBaseAddr           : in std_logic_vector(BUS_ADDR_SIZE-1 downto 0); --Global address of device
    iBus                : in bus_sync;  --bus_type record (data, addr, req, r_w, ready)
    oBus                : out bus_sync); --bus_type record (data, addr, req, r_w, ready)
end memory_controller;

architecture arch of memory_controller is

component bus_slave_controller is
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
end component;

component blockram_reg
  PORT (
    clka : IN STD_LOGIC;
    rsta : IN STD_LOGIC;
    ena : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(BRAM_ADDR_SIZE-1 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(BRAM_DATA_SIZE-1 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(BRAM_DATA_SIZE-1 DOWNTO 0)
  );
END component;

signal sMemAddr 	  : std_logic_vector (BRAM_ADDR_SIZE-1 downto 0);
signal sMemEn 	: std_logic;
signal sMemWriteEn 	: std_logic;
signal sMemReadEn 	: std_logic;
signal sDataToMem 	: std_logic_vector (BRAM_DATA_SIZE-1 downto 0);
signal sDataFromMem : std_logic_vector (BRAM_DATA_SIZE-1 downto 0);

signal sDataValid 	: std_logic;
signal sDataValid1 	: std_logic;
signal sDataValid2 	: std_logic;

begin

slave1 : bus_slave_controller
  GENERIC MAP (
    DEV_ADDR_SIZE => BRAM_ADDR_SIZE)
  PORT MAP (
    iClk => iClk,
    iRst => iRst,
    iBus => iBus,
    oBus => oBus,
    iBaseAddr => iBaseAddr,
    oDevEn => sMemEn,
    oDevReadEn => sMemReadEn,
    oDevWriteEn => sMemWriteEn,
    oDevAddr => sMemAddr,
    oDataToDev => sDataToMem,
    iDataFromDev => sDataFromMem,
    iDataValid => sDataValid
  );

bram1 : blockram_reg
  PORT MAP (
    clka => iClk,
    rsta => iRst,
    ena => sMemEn,
    wea(0) => sMemWriteEn,
    addra => sMemAddr,
    dina => sDataToMem,
    douta => sDataFromMem
  );

-- Read latency on BRAM is 3 cycles
process(iClk)
begin
    if (rising_edge (iClk)) then
		if iRst='1' then
          sDataValid <= '0';
          sDataValid1 <='0';
          sDataValid2 <='0';
      else
          sDataValid1 <= sMemReadEn; 
          sDataValid2 <= sDataValid1 and sMemReadEn; 
          sDataValid <= sDataValid2 and sMemReadEn; 
      end if;
    end if;
end process;

end arch;
