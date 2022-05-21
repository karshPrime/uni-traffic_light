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
type StateType is (GreenNS, GreenEW, AmberEW, AmberNS, WalkEW, WalkNS);
Signal State, NextState : StateType;

-- defining counter
CONSTANT COUNTER_MAX : INTEGER := 1535;
Signal Counter : NATURAL RANGE 0 to COUNTER_MAX := 0;

-- memory signals
Signal mCarEW, mCarNS, mPedEW, mPedNS     : STD_LOGIC := '0';
Signal cmCarEW, cmCarNS, cmPedEW, cmPedNS : STD_LOGIC := '0';

Signal PedWait, AmberWait, MinWait, WaitEnable : STD_LOGIC := '0';

begin
	debugLed <= Reset; 			-- Show reset status on FPGA LED
	LEDs     <= (mCarEW, mCarNS, mPedEW, mPedNS); -- Debug LEDs

	--[ ]--------------------------------------------------------------------------------------
	SyncProcess:
	Process(Reset, Clock)
	begin
		if (Reset = '1') then
			State <= GreenEW;
		elsif rising_edge(Clock) then
			State <= NextState;
		end if;
	end process SyncProcess;
	
	--[ Counter ]------------------------------------------------------------------------------
	Timer:
	Process(WaitEnable, Clock, Reset)
	begin
		if (Reset = '1') then
			Counter <= 0;
		elsif (WaitEnable = '1') then
			if rising_edge(Clock) then
				if (Counter = COUNTER_MAX) then
					Counter <= 0;
				else
					Counter <= Counter + 1;
				end if;
			end if;
		else
			Counter <= 0;
		end if;
	end Process Timer;
	
	MinWait   <= '1' when (Counter = 511)  else '0';
	AmberWait <= '1' when (Counter = 1023) else '0';
	PedWait   <= '1' when (Counter = 1535) else '0';

	--[ ]--------------------------------------------------------------------------------------
	CombinationalProcess:
	Process(State, MinWait, PedWait, AmberWait)
	begin
		LightsNS <= RED;
		LightsEW <= RED;
	
		case State is
			when GreenEW =>
			WaitEnable <= '1';
			if (MinWait = '1') then
				NextState  <= AmberEW;
				WaitEnable <= '0';
			else
				LightsEW   <= GREEN;
			end if;

			when AmberEW =>
				WaitEnable <= '1';
				if (AmberWait  = '1') then
					NextState  <= GreenNS;
					WaitEnable <= '0';
				else
					LightsEW   <= AMBER;
				end if;
			
			when WalkEW  =>
				WaitEnable <= '1';
				if (PedWait = '1') then
					NextState  <= GreenNS;
					WaitEnable <= '0';
				else
					LightsEW   <= WALK;
				end if;

			when GreenNS =>
				WaitEnable <= '1';
				if (MinWait = '1') then
					NextState  <= AmberNS;
					WaitEnable <= '0';
				else
					LightsNS   <= GREEN;
				end if;

			when AmberNS =>
				WaitEnable <= '1';
				if (AmberWait  = '1') then
					NextState  <= GreenEW;
					WaitEnable <= '0';
				else
					LightsNS   <= AMBER;
				end if;	

			when WalkNS  =>
				WaitEnable <= '1';
				if (PedWait = '1') then
					NextState  <= GreenEW;
					WaitEnable <= '0';
				else
					LightsNS   <= WALK;
				end if;

		end case State;
	end process CombinationalProcess;
	
	--[ ]--------------------------------------------------------------------------------------
	MemorySave:
	Process(CarEW, CarNS, PedEW, PedNS, cmCarEW, cmCarNS, cmPedEW, cmPedNS)
	begin
		cmCarEW  <= '0';
		cmCarNS  <= '0';
		cmPedEW  <= '0';
		cmPedNS  <= '0';

		if CarEW   = '1' then
			mCarEW <= '1';
		end if;
		
		if CarNS   = '1' then
			mCarNS <= '1';
		end if;
		
		if PedEW   = '1' then
			mPedEW <= '1';
		end if;
		
		if PedNS   = '1' then
			mPedNS <= '1';
		end if;
		
		if cmCarEW = '1' then
			mCarEW <= '0';
		end if;
		
		if cmCarNS = '1' then
			mCarNS <= '0';
		end if;
		
		if cmPedEW = '1' then
			mPedEW <= '0';
		end if;
		
		if cmPedNS = '1' then
			mPedNS <= '0';
		end if;
	end Process MemorySave;

end architecture;