----------------------------------------------------------------------------------
--  Traffic.vhd
--
-- Traffic light system to control an intersection
--
-- Accepts inputs from two car sensors and two pedestrian call buttons
-- Controls two sets of lights consisting of Red, Amber and Green traffic lights and
-- a pedestrian walk light.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity Traffic is
    Port (	Reset      : in   STD_LOGIC;
				Clock      : in   STD_LOGIC;

				-- for debug
				debugLED   : out  std_logic;
				LEDs       : out  std_logic_vector(2 downto 0);

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
----------------------------------------------------------------------------------

architecture Behavioral of Traffic is
-- Encoding for lights
constant RED   : std_logic_vector(1 downto 0) := "00";
constant AMBER : std_logic_vector(1 downto 0) := "01";
constant GREEN : std_logic_vector(1 downto 0) := "10";
constant WALK  : std_logic_vector(1 downto 0) := "11";

-- defining states
type StateType is (GreenNS, GreenEW, AmberEW, AmberNS);
signal State, NextState : StateType;

-- defining counter
constant COUNTER_MAX : INTEGER := 511;
signal Counter : NATURAL RANGE 0 to COUNTER_MAX := 0;

begin
	debugLed <= Reset; 		-- Show reset status on FPGA LED
	LEDs     <= "000";		-- Threee LEDs for debug 


	-- Chance state on clock edge, and reset state if requested
	SyncProcess:
	Process(Reset, Clock)
	begin
		if (Reset = '1') then
			State <= GreenEW;
		elsif rising_edge(clock) then
			State <= NextState;

			if (Counter = COUNTER_MAX) then
				Counter <= 0;
			else
				Counter <= Counter + 1;
			end if;

		end if;
	end Process SyncProcess;


	-- 
	CombinationalProcess:
	Process(State, Counter)
	begin
		-- default values for signals; prevents latches
		LightsEW  <= RED;
		LightsNS  <= RED;

		-- Next state and lights condition defined based upon current state
		case State is
			when GreenNS =>
				if (Counter = COUNTER_MAX) then
					NextState <= AmberNS;
				else
					LightsNS  <= GREEN;
				end if;

			when AmberNS =>
				if (Counter = COUNTER_MAX) then
					NextState <= GreenEW;
				else
					LightsNS  <= AMBER;
				end if;

			when GreenEW =>
				if (Counter = COUNTER_MAX) then
					NextState <= AmberEW;
				else
					LightsEW  <= GREEN;
				end if;

			when AmberEW =>
				if (Counter = COUNTER_MAX) then
					NextState <= GreenNS;
				else
					LightsEW  <= AMBER;
				end if;
		end case;

	end Process CombinationalProcess;


	-- button states save in memory
--	ButtonState:
--	Process(
end;