-- $ Circular Priority Arbiter - 8 channels
-- v: svn controlled.
--
-- 0.0	First Version
--
-- 0.1	Changed the coding style.
--		Added an explicit priority encoder
--
--


library ieee;
use ieee.std_logic_1164.all;

--

entity priarb8 is
	port
	(	
		signal clk				: in 	std_logic; -- sync if
		signal rst				: in 	std_logic; -- async if

		signal enable			: in	std_logic; -- arbiter if
		signal isidle			: out	std_logic; -- arbiter if

		signal en	 			: out	std_logic_vector(7 downto 0) := x"00";

		signal ii				: in	std_logic_vector(7 downto 0);

		signal control        	: in	std_logic_vector(7 downto 0)
	);
end priarb8;

--

architecture rtl of priarb8 is
		
	-- Build an enumerated type for the state machine
	type state_type is (idle,	d0enable, d0notidle, d0disable,
								d1enable, d1notidle, d1disable,
								d2enable, d2notidle, d2disable,
								d3enable, d3notidle, d3disable,
								d4enable, d4notidle, d4disable,
								d5enable, d5notidle, d5disable,
								d6enable, d6notidle, d6disable,
								d7enable, d7notidle, d7disable
	);

	-- Register to hold the current state
	signal state		: state_type := idle;
	
	-- Attribute "safe" implements a safe state machine.
	-- This is a state machine that can recover from an
	-- illegal state (by returning to the reset state).
	attribute syn_encoding : string;
	attribute syn_encoding of state_type : type is "safe";

	-- Priority encoder result signals
	signal s0,s1,s2,s3	: state_type;
	signal s4,s5,s6,s7	: state_type;
	
	-- FSM outputs
	signal i_en			: std_logic_vector(7 downto 0) := x"00";
	signal i_isidle		: std_logic := '1';
	
--

begin

	-- Priority Encoder
	s0	 	<=	d0enable when control(0) = '1' else
				d1enable when control(1) = '1' else
				d2enable when control(2) = '1' else
				d3enable when control(3) = '1' else
				d4enable when control(4) = '1' else
				d5enable when control(5) = '1' else
				d6enable when control(6) = '1' else
				d7enable when control(7) = '1' else
				idle;

	s1	 	<=	d1enable when control(1) = '1' else
				d2enable when control(2) = '1' else
				d3enable when control(3) = '1' else
				d4enable when control(4) = '1' else
				d5enable when control(5) = '1' else
				d6enable when control(6) = '1' else
				d7enable when control(7) = '1' else
				idle;

	s2		<=	d2enable when control(2) = '1' else
				d3enable when control(3) = '1' else
				d4enable when control(4) = '1' else
				d5enable when control(5) = '1' else
				d6enable when control(6) = '1' else
				d7enable when control(7) = '1' else
				idle;

	s3		<=	d3enable when control(3) = '1' else
				d4enable when control(4) = '1' else
				d5enable when control(5) = '1' else
				d6enable when control(6) = '1' else
				d7enable when control(7) = '1' else
				idle;

	s4		<=	d4enable when control(4) = '1' else
				d5enable when control(5) = '1' else
				d6enable when control(6) = '1' else
				d7enable when control(7) = '1' else
				idle;

	s5		<=	d5enable when control(5) = '1' else
				d6enable when control(6) = '1' else
				d7enable when control(7) = '1' else
				idle;

	s6		<=	d6enable when control(6) = '1' else
				d7enable when control(7) = '1' else
				idle;

	s7		<=	d7enable when control(7) = '1' else
				idle;


	-- Circular FSM
	circular_fsm:
	process (clk, rst, enable)
	begin
		if (rst = '1') then
			state <= idle;
			
		elsif (rising_edge(clk) and (enable = '1')) then
			case state is
			--IDLE
				when idle =>					
					state <= s0;

			--#0										
				when d0enable =>
					-- if it is not idle anymore...
					if (ii(0) = '0') then
						state <= d0notidle;
					else
						state <= d0enable;
					end if;

				when d0notidle =>
					-- if it is idle back again, we shall finish...
					if (ii(0) = '1') then
						state <= d0disable;
					else
						state <= d0notidle;
					end if;
				
				when d0disable =>
					state <= s1;

			--#1				
				when d1enable =>
					-- if it is not idle anymore...
					if (ii(1) = '0') then
						state <= d1notidle;
					else
						state <= d1enable;
					end if;
				
				when d1notidle =>
					-- if it is idle back again, we shall finish...
					if (ii(1) = '1') then
						state <= d1disable;
					else
						state <= d1notidle;
					end if;
				
				when d1disable =>
					state <= s2;

			--#2
				when d2enable =>
					-- if it is not idle anymore...
					if (ii(2) = '0') then
						state <= d2notidle;
					else
						state <= d2enable;
					end if;
				
				when d2notidle =>
					-- if it is idle back again, we shall finish...
					if (ii(2) = '1') then
						state <= d2disable;
					else
						state <= d2notidle;
					end if;
				
				when d2disable =>
					state <= s3;

			--#3
				when d3enable =>
					-- if it is not idle anymore...
					if (ii(3) = '0') then
						state <= d3notidle;
					else
						state <= d3enable;
					end if;
				
				when d3notidle =>
					-- if it is idle back again, we shall finish...
					if (ii(3) = '1') then
						state <= d3disable;
					else
						state <= d3notidle;
					end if;
				
				when d3disable =>
					state <= s4;

--***************************************************************************
			--#4										
				when d4enable =>
					-- if it is not idle anymore...
					if (ii(4) = '0') then
						state <= d4notidle;
					else
						state <= d4enable;
					end if;

				when d4notidle =>
					-- if it is idle back again, we shall finish...
					if (ii(4) = '1') then
						state <= d4disable;
					else
						state <= d4notidle;
					end if;
				
				when d4disable =>
					state <= s5;

			--#5				
				when d5enable =>
					-- if it is not idle anymore...
					if (ii(5) = '0') then
						state <= d5notidle;
					else
						state <= d5enable;
					end if;
				
				when d5notidle =>
					-- if it is idle back again, we shall finish...
					if (ii(5) = '1') then
						state <= d5disable;
					else
						state <= d5notidle;
					end if;
				
				when d5disable =>
					state <= s6;

			--#6
				when d6enable =>
					-- if it is not idle anymore...
					if (ii(6) = '0') then
						state <= d6notidle;
					else
						state <= d6enable;
					end if;
				
				when d6notidle =>
					-- if it is idle back again, we shall finish...
					if (ii(6) = '1') then
						state <= d6disable;
					else
						state <= d6notidle;
					end if;
				
				when d6disable =>
					state <= s7;

			--#7
				when d7enable =>
					-- if it is not idle anymore...
					if (ii(7) = '0') then
						state <= d7notidle;
					else
						state <= d7enable;
					end if;
				
				when d7notidle =>
					-- if it is idle back again, we shall finish...
					if (ii(7) = '1') then
						state <= d7disable;
					else
						state <= d7notidle;
					end if;
				
				when d7disable =>
					state <= idle;

			end case;
		end if;
	end process;

	fsm_outputs:
	process(state)
	begin
		case (state) is
			when idle		=>
				i_en		<= x"00";
				--
				i_isidle	<= '1';
				
		--*********************--

			when d0enable	=>
				i_en		<= x"01";
				--
				i_isidle	<= '0';

			when d0notidle	=>
				i_en		<= x"01";
				--
				i_isidle	<= '0';

			when d0disable	=>
				i_en		<= x"00";
				--
				i_isidle	<= '0';
		
		--*********************--
		
			when d1enable	=>
				i_en		<= x"02";
				--
				i_isidle	<= '0';

			when d1notidle	=>
				i_en		<= x"02";
				--
				i_isidle	<= '0';

			when d1disable	=>
				i_en		<= x"00";
				--
				i_isidle	<= '0';
		
		--*********************--

			when d2enable	=>
				i_en		<= x"04";
				--
				i_isidle	<= '0';

			when d2notidle	=>
				i_en		<= x"04";
				--
				i_isidle	<= '0';

			when d2disable	=>
				i_en		<= x"00";
				--
				i_isidle	<= '0';
		
		--*********************--

			when d3enable	=>
				i_en		<= x"08";
				--
				i_isidle	<= '0';

			when d3notidle	=>
				i_en		<= x"08";
				--
				i_isidle	<= '0';

			when d3disable	=>
				i_en		<= x"00";
				--
				i_isidle	<= '0';
		
--**************************************************--

			when d4enable	=>
				i_en		<= x"10";
				--
				i_isidle	<= '0';

			when d4notidle	=>
				i_en		<= x"10";
				--
				i_isidle	<= '0';

			when d4disable	=>
				i_en		<= x"00";
				--
				i_isidle	<= '0';
		
		--*********************--
		
			when d5enable	=>
				i_en		<= x"20";
				--
				i_isidle	<= '0';

			when d5notidle	=>
				i_en		<= x"20";
				--
				i_isidle	<= '0';

			when d5disable	=>
				i_en		<= x"00";
				--
				i_isidle	<= '0';
		
		--*********************--

			when d6enable	=>
				i_en		<= x"40";
				--
				i_isidle	<= '0';

			when d6notidle	=>
				i_en		<= x"40";
				--
				i_isidle	<= '0';

			when d6disable	=>
				i_en		<= x"00";
				--
				i_isidle	<= '0';
		
		--*********************--

			when d7enable	=>
				i_en		<= x"80";
				--
				i_isidle	<= '0';

			when d7notidle	=>
				i_en		<= x"80";
				--
				i_isidle	<= '0';

			when d7disable	=>
				i_en		<= x"00";
				--
				i_isidle	<= '0';

		--*********************--

			when others 	=>
				i_en		<= x"00";
				--
				i_isidle	<= '1';
		end case;
	end process;
	
	output_registers:
	process(clk, rst)
	begin
		if (rst = '1') then
			en		<= x"00";
			isidle	<= '1';
		elsif (rising_edge(clk)) then
			en		<= i_en;
			isidle	<= i_isidle;
		end if;
	end process;
end rtl;