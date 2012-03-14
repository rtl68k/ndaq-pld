-- $ Data Builder Package
-- v: svn controlled.
--
--

library ieee;
use ieee.std_logic_1164.all;		-- defines std_logic / std_logic_vector types and their functions.
use ieee.std_logic_arith.all;		-- defines basic arithmetic ops, CONV_STD_LOGIC_VECTOR() is here, 'signed' type too (will conflit with numeric_std if 'signed' is used in interfaces).
use ieee.std_logic_unsigned.all;	-- Synopsys extension to std_logic_arith to handle std_logic_vector as unsigned integers (used together with std_logic_signed is ambiguous).

--use work.functions_pkg.all;

--

package tdc_pkg is
	
	--
	--Constants
	--
			
--*******************************************************************************************************************************

	--
	--Data Types
	--
	
	subtype	OTDC_T	is std_logic_vector(25 downto 0);
	type	OTDC_A	is array (7 downto 0) of OTDC_T;

	
--*******************************************************************************************************************************
	
end package tdc_pkg;

--

package body tdc_pkg is
end package body tdc_pkg;