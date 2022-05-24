----------------------------------------------------------------------------------------------
-- Traffic.vhd
--
-- Traffic light system to control an intersection
--
-- Accepts inputs from two car sensors and two pedestrian call buttons Controls two sets of 
-- lights consisting of Red, Amber and Green traffic lights and a pedestrian walk light.
----------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity Traffic is
    Port (	Reset      : in   STD_LOGIC;
				Clock      : in   STD_LOGIC;

				-- for debug
				debugLED   : out  STD_LOGIC;
				LEDs       : out  STD_LOGIC_VECTOR(3 downto 0);

				-- Car and pedestrian buttons
				CarEW      : in   STD_LOGIC; -- Car on EW road
				CarNS      : in   STD_LOGIC; -- Car on NS road
				PedEW      : in   STD_LOGIC; -- Pedestrian moving EW (crossing NS road)
				PedNS      : in   STD_LOGIC; -- Pedestrian moving NS (crossing EW road)

           -- Light control
				LightsEW   : out STD_LOGIC_VECTOR (1 downto 0); -- controls EW lights
				LightsNS   : out STD_LOGIC_VECTOR (1 downto 0)  -- controls NS lights
           
           );
end Traffic;

----------------------------------------------------------------------------------------------

architecture Behavioral of Traffic is
-- Encoding for lights
CONSTANT RED   : STD_LOGIC_VECTOR(1 downto 0) := "00";
CONSTANT AMBER : STD_LOGIC_VECTOR(1 downto 0) := "01";
CONSTANT GREEN : STD_LOGIC_VECTOR(1 downto 0) := "10";
CONSTANT WALK  : STD_LOGIC_VECTOR(1 downto 0) := "11";

-- defining states
type StateType is (GreenNS, GreenEW, AmberEW, AmberNS);
Signal State, NextState : StateType;

-- defining counter
CONSTANT COUNTER_MAX : INTEGER := 1535;
Signal Counter : NATURAL RANGE 0 to COUNTER_MAX := 0;

-- memory signals
Signal mCarEW, mCarNS, mPedEW, mPedNS : STD_LOGIC := '0';
Signal cCarEW, cCarNS, cPedEW, cPedNS : STD_LOGIC := '0';

-- for individual light delays
Signal PedWait, AmberWait, MinWait, WaitEnable : STD_LOGIC := '0';

begin
	debugLed <= Reset;                              -- Show reset status on FPGA LED
	LEDs     <= (mCarEW, mCarNS, mPedEW, mPedNS);   -- display stored values in Debug LEDs

	--[ Async reset and synchronised state change ]--------------------------------------------
	SyncProcess:
	Process(Reset, Clock)
	begin
		if (Reset = '1') then  -- async reset
			State  <= GreenEW;  -- defalut state
		elsif rising_edge(Clock) then
			State <= NextState; -- at clock edge, change state
		end if;
	end process SyncProcess;
	
	--[ Counter for delays ]-------------------------------------------------------------------
	Timer:
	Process(WaitEnable, Clock, Reset)
	begin
		if (Reset = '1') then                 -- async reset
			Counter <= 0;                      -- clear counter
		elsif (WaitEnable = '1') then         -- if counter requested to run
			if rising_edge(Clock) then         -- at clock edge
				if (Counter = COUNTER_MAX) then -- if counter is already the max it could be
					Counter <= 0;                -- clear counter
				else
					Counter <= Counter + 1;      -- increment counter
				end if;
			end if;
		else
			Counter <= 0;                      -- clear counter when not needed
		end if;
	end Process Timer;
	
	-- change wait status depending on counter count
	MinWait   <= '1' when (Counter = 511)  else '0';
	AmberWait <= '1' when (Counter = 1023) else '0';
	PedWait   <= '1' when (Counter = 1535) else '0';

	--[ State change conditions and processes ]------------------------------------------------
	CombinationalProcess:
	Process(State, MinWait, PedWait, AmberWait)
	begin
		-- default values; helps prevent latches
		LightsNS   <= RED;
		LightsEW   <= RED;
		cCarEW     <= '0';
		cCarNS     <= '0';
		cPedEW     <= '0';
		cPedNS     <= '0';
		WaitEnable <= '1';

		case State is
			when GreenEW =>
				LightsEW   <= GREEN;          -- change lights for this state

				-- change state only when a car is ditected on other road or ped wants to cross 
				-- the current road, and the current light has been on for minimum time.
				if (MinWait = '1' and (mCarNS = '1' or mPedNS = '1')) then
					WaitEnable <= '0';			-- turn off counter once its at minWait
					NextState  <= AmberNS;		-- define next state

				-- if ped wishes to cross the other road
				elsif (mPedEW = '1') then
					if (PedWait  = '1') then	-- clear cross light after allocated crossing time
						WaitEnable <= '0';		-- turn off counter once its at pedWait
						cPedEW     <= '1';		-- clear ped crossing request
					else
						LightsEW   <= WALK;     -- while counter < max allowed; show crossing sign
					end if;
				end if;


			when GreenNS =>                  -- same process as above, but for different Lights
				LightsNS   <= GREEN;
				if (MinWait = '1' and (mCarEW = '1' or mPedEW = '1')) then
					WaitEnable <= '0';
					NextState  <= AmberEW;
				elsif (mPedNS = '1') then
					if (PedWait  = '1') then
						WaitEnable <= '0';
						cPedNS     <= '1';
					else
						LightsNS   <= WALK;
					end if;
				end if;


			when AmberNS =>
				LightsNS   <= AMBER;          -- change lights for this state
				cCarNS     <= '1';            -- clear car requests (not required anymore)

				-- change state only when the current light has been ON for min time
				if (AmberWait = '1') then
					WaitEnable <= '0';         -- disable counter
					NextState  <= GreenNS;     -- define next state
				end if;


			when AmberEW =>                  -- same process as above, but for different Lights
				LightsEW   <= AMBER;
				cCarEW     <= '1';
				if (AmberWait = '1') then
					WaitEnable <= '0';
					NextState <= GreenEW;
				end if;

		end case State;

	end process CombinationalProcess;
	
	--[ save button value in signals until asked to clear ]------------------------------------
	MemorySave:
	Process(Reset, CarEW, CarNS, cCarEW, cCarNS, clock)
	begin
		if Reset = '1' then
			mCarEW <= '0';
			mCarNS <= '0';
		elsif rising_edge(clock) then
			if    cCarEW = '1' then mCarEW <= '0';
			elsif cCarNS = '1' then mCarNS <= '0';
			elsif (CarEW = '1' and State /= GreenEW) then mCarEW <= '1';
			elsif (CarNS = '1' and State /= GreenNS) then mCarNS <= '1';
			end if;
		end if;
	end Process MemorySave;

	PedSave:
	Process(Reset, cPedNS, cPedEW, PedEW, PedNS)
	begin
		if Reset = '1' then
			mPedEW <= '0';
			mPedNS <= '0';
		elsif cPedEW = '1' then mPedEW <= '0';
		elsif cPedNS = '1' then mPedNS <= '0';
		elsif PedEW = '1'  then mPedEW <= '1';
		elsif PedNS = '1'  then mPedNS <= '1';
		end if;
	end Process PedSave;


end architecture;
