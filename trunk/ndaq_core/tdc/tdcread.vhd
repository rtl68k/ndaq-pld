--
--

library ieee;
library work;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.tdc_pkg.all;

--
entity tdcread is
	port
	(
		-- General control signals
		signal rst			: in	std_logic;
		signal clk			: in	std_logic;	-- 40MHz clock
		signal dclk			: in	std_logic;
		
		-- TDC inputs/outputs
		signal itdc_data	: in	std_logic_vector(27 downto 0);
		signal otdc_data	: out	std_logic_vector(27 downto 0);
		signal otdc_csn	 	: out	std_logic;		-- TDC Chip Select
		signal otdc_rdn		: out	std_logic;		-- TDC Read strobe
		signal otdc_adr		: out	std_logic_vector(3 downto 0); -- TDC Address
		signal otdc_alutr	: out	std_logic;
		signal itdc_irflag	: in	std_logic;	-- TDC Interrupt flag (active high)
		signal itdc_ef1		: in	std_logic;	-- TDC FIFO-1 Empty flag (active high)
		signal itdc_ef2 	: in	std_logic;	-- TDC FIFO-2 Empty flag (active high)
		-- Readout FIFOs
		signal channel_ef	: out	CTDC_T;
		signal channel_rd	: in	CTDC_T;
		signal channel_out	: out	OTDC_A
	);
end tdcread;

--

architecture rtl of tdcread is
	
	-- Constants
	constant REG8  : std_logic_vector(3 downto 0) := "1000";		-- TDC FIFO 1 Address
	constant REG9  : std_logic_vector(3 downto 0) := "1001";		-- TDC FIFO 2 Address

	-- Components
	component tdcfifo
	port
	(
		aclr		: IN STD_LOGIC  := '0';
		data		: IN STD_LOGIC_VECTOR (25 DOWNTO 0);
		rdclk		: IN STD_LOGIC ;
		rdreq		: IN STD_LOGIC ;
		wrclk		: IN STD_LOGIC ;
		wrreq		: IN STD_LOGIC ;
		q			: OUT STD_LOGIC_VECTOR (25 DOWNTO 0);
		rdempty		: OUT STD_LOGIC ;
		wrfull		: OUT STD_LOGIC 
	);
	end component;
	

	-- Signals
	type sm_tdc is (sIdle, sTestEFs, sSelectFIFO, sCSN, sRDdown, sRDup, sReadDone);
	signal sm_TDCx : sm_tdc;
	attribute syn_encoding : string;
	attribute syn_encoding of sm_tdc : type is "safe";

	signal enable_read		: std_logic := '0';
	signal tdc_addr			: std_logic_vector(3 downto 0);	
	signal selected_fifo	: std_logic := '0';
	signal fifo2_issue		: std_logic := '0';
	signal i_data_valid		: std_logic := '0';
	signal TDC_Data			: std_logic_vector(27 downto 0);
	signal channel_sel		: std_logic_vector(2 downto 0) := "000";
	signal channel_wr		: CTDC_T := x"00";
	signal channel_ff		: CTDC_T := x"00";
	
	signal i_data_valid2	: std_logic := '0';
	
	signal stdc_ef1 		: std_logic := '1';
	signal stdc_ef2 		: std_logic := '1';
	signal stdc_irflag 		: std_logic := '0';
	
	signal rtdc_ef1 		: std_logic := '1';
	signal rtdc_ef2 		: std_logic := '1';
	signal rtdc_irflag 		: std_logic := '0';
	
--
--
begin	
	--------------------------------------------------
	-- Read Enable Based on Readout FIFOs Full Flag --
	--------------------------------------------------
	
	
	enable_read	<=	not(channel_ff(0) or channel_ff(1) or
						channel_ff(2) or channel_ff(3) or
						channel_ff(4) or channel_ff(5) or
						channel_ff(6) or channel_ff(7));


	----------------------------------------------
	-- Registering ef1, ef2 and irflag - 2 chains.
	----------------------------------------------
	process(rst, clk)
	begin
		if (rst = '1') then
			stdc_ef1	<= '1';
			stdc_ef2	<= '1';
			stdc_irflag	<= '0';
			--
			rtdc_ef1	<= '1';
			rtdc_ef2	<= '1';
			rtdc_irflag	<= '0';
		elsif (rising_edge(clk)) then
			stdc_ef1	<= itdc_ef1;
			stdc_ef2	<= itdc_ef2;
			stdc_irflag	<= itdc_irflag;
			--
			rtdc_ef1	<= stdc_ef1;
			rtdc_ef2	<= stdc_ef2;
			rtdc_irflag	<= stdc_irflag;
		end if;
	end process;
	
	
	----------------------
	-- TDC data readout --
	----------------------
	process (rst, clk, enable_read, fifo2_issue) begin
		if (rst = '1') then
			otdc_ADR <= "0000";
			otdc_CSN <= '1';
			otdc_RDN <= '1';
			i_data_valid <= '0';
			tdc_addr <= REG8;
			sm_TDCx <= sIdle;
			otdc_alutr <= '0';
			fifo2_issue	<= '0';
		elsif (clk'event and clk = '1') then
			case sm_TDCx is
				
				
				-- Idle
				when sIdle =>
					otdc_ADR <= "0000";
					otdc_CSN <= '1';
					otdc_RDN <= '1';
					i_data_valid <= '0';
					otdc_alutr <= '0';
					selected_fifo <= '0';

					-- Se a IRflag estiver em nivel baixo, espere nesse estado.
					if rtdc_irflag = '0' then
						sm_TDCx <= sIdle;
					-- Se a IRflag estiver em nivel alto, significa que a janela de tempo acabou e a medi��o pode ser lida.
					else
						sm_TDCx <= sSelectFIFO;
					end if;
								
				
				-- Testa EF1 e EF2
				when sSelectFIFO =>
					otdc_ADR <= "0000";
					otdc_CSN <= '1';
					otdc_RDN <= '1';
					--otdc_Data <= (others => 'Z');
					i_data_valid <= '0';
					otdc_alutr <= '0';
					
					--
					if (enable_read = '1') then	
						--both fifos have data: read fifo1 and issue a fifo2 read for the next cycle.
						if rtdc_ef1 = '0' and rtdc_ef2 = '0' and fifo2_issue = '0' then
							tdc_addr <= REG8;
							selected_fifo <= '0';
							fifo2_issue	<= '1';
							sm_TDCx <= sCSN;
						--fifo2 have data or fifo2 read issued: read fifo2.
						elsif rtdc_ef2 = '0' or fifo2_issue = '1' then
							tdc_addr <= REG9;
							selected_fifo <= '1';
							fifo2_issue	<= '0';
							sm_TDCx <= sCSN;
						--fifo1 have data: read fifo 1.
						elsif rtdc_ef1 = '0' then
							tdc_addr <= REG8;
							selected_fifo <= '0';
							fifo2_issue	<= '0';
							sm_TDCx <= sCSN;
						else
							sm_TDCx <= sSelectFIFO;
						end if;
					else
						sm_TDCx <= sSelectFIFO;
					end if;
			

				-- Come�a a Leitura
				when sCSN =>							
					otdc_ADR <= tdc_addr;				-- Address valid
					otdc_CSN <= '0';					-- CS falling edge
					oTDC_RDN <= '1';
					--
					i_data_valid <= '0';
					sm_TDCx <= sRDdown;
					otdc_alutr <= '0';
				
				-- Leitura
				when sRDdown =>						
					oTDC_ADR <= tdc_addr;				-- Address valid
					oTDC_CSN <= '0';					
					oTDC_RDN <= '0';					-- RD falling edge (25ns after CS falling-edge)
					--
					i_data_valid <= '0';
					sm_TDCx <= sRDup;
					otdc_alutr <= '0';
				
				-- Leitura
				when sRDup =>							-- CS and RD rising edge
					oTDC_ADR <= tdc_addr;
					oTDC_CSN <= '1';
					oTDC_RDN <= '1';
					--
					i_data_valid <= '1';
					sm_TDCx <= sReadDone;
					otdc_alutr <= '0';
				
				-- Leitura (final)
				when sReadDone =>						-- Remove Address and Data
					oTDC_ADR <= (others => 'Z');
					oTDC_CSN <= '1';
					oTDC_RDN <= '1';
					--
					i_data_valid <= '0';				-- Data strobe indicating valid data
					otdc_alutr <= '0';
					
					-- Se ainda h� dados nas FIFOs, o ciclo deve come�ar de novo sem Reset e
					-- sem passar pelo testa da IRflag.
					if ((rtdc_ef1 = '0') or (rtdc_ef2 = '0')) then
						sm_TDCx <= sSelectFIFO;
					-- Caso contr�rio, os resultados das duas FIFOs para uma janela de tempo j� foram lidos.
					-- Deve-se resetar e come�ar do 'sIdle'.
					else
						otdc_alutr <= '1'; 	-- TDC reset, keeping the contents of the configuration registers
						sm_TDCx <= sIdle;
					end if;
					
				when others =>
					oTDC_ADR <= (others => 'Z');
					oTDC_CSN <= '1';
					oTDC_RDN <= '1';
					i_data_valid <= '0';
					sm_TDCx <= sIdle;
					otdc_alutr <= '0';
			end case;
		end if;
	end process;
	
	-----------------------------------------------------------------------------------------
	-- TDC data input buffering  (1 Chain. Change to 2 chains if there is data instability --
	-----------------------------------------------------------------------------------------
	process(rst, clk)
	begin
		if (rst = '1') then
			TDC_Data <= (others => '0');
		elsif rising_edge(clk) then
			TDC_Data <= iTDC_Data;
		end if;
	end process;

	--------------------------------------------------
	-- TDC data channel selector and output buffers --
	--------------------------------------------------
	channel_sel	<= selected_fifo & TDC_Data(27 downto 26);
		
	-- Channel Selector Demux
	process(channel_sel, i_data_valid)
	begin
		channel_wr <= (others => '0');
		if (i_data_valid = '1') then
			channel_wr(conv_integer(channel_sel))	<= '1';
		end if;
	end process;
	
	-- otdc_Data Output Buffer
	process(rst, clk, i_data_valid)
	begin
		if (rst = '1') then
			otdc_Data <= (others => '0');
		elsif rising_edge(clk) then
			if (i_data_valid = '1') then
				otdc_Data <= TDC_Data;
			end if;
		end if;
	end process;

	-- Separated channel buffers
	channel_out_construct:
	for i in 0 to 7 generate
		readout_fifo:
		tdcfifo port map
		(
			aclr		=> rst,
			wrclk		=> clk,
			rdclk		=> dclk,
			data		=> TDC_Data(25 downto 0),
			wrreq		=> channel_wr(i),
			rdreq		=> channel_rd(i),
			wrfull		=> channel_ff(i),
			rdempty		=> channel_ef(i),
			q			=> channel_out(i)
		);
	end generate channel_out_construct;

--		

end rtl;