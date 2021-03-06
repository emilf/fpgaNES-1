/*
This file is part of fpgaNES.

fpgaNES is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

fpgaNES is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with fpgaNES.  If not, see <http://www.gnu.org/licenses/>.
*/

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity nes is
	port
	(
		CLOCK_125_p : in std_logic;
		CLOCK_50_B5B : in std_logic;
		CLOCK_50_B6A : in std_logic;
		CLOCK_50_B7A : in std_logic;
		CLOCK_50_B8A : in std_logic;
		CPU_RESET_n : in std_logic;
		KEY : in std_logic_vector(3 downto 0);
		SW: in std_logic_vector(9 downto 0);
		I2C_SCL : inout std_logic;
		I2C_SDA : inout std_logic;
		GPIO : inout std_logic_vector(21 downto 0);
		LEDG : out std_logic_vector(7 downto 0);
		LEDR : out std_logic_vector(9 downto 0);
		HEX0: out std_logic_vector(6 downto 0);
		HEX1: out std_logic_vector(6 downto 0);
		HEX2: out std_logic_vector(6 downto 0);
		HEX3: out std_logic_vector(6 downto 0);
		HDMI_TX_CLK : out std_logic;
		HDMI_TX_D : out std_logic_vector(23 downto 0);
		HDMI_TX_DE : out std_logic;
		HDMI_TX_HS : out std_logic;
		HDMI_TX_INT : in std_logic;
		HDMI_TX_VS : out std_logic;
		AUD_ADCDAT : in std_logic;
		AUD_ADCLRCK : inout std_logic;
		AUD_BCLK : inout std_logic;
		AUD_DACDAT : out std_logic;
		AUD_DACLRCK : inout std_logic;
		AUD_XCK : out std_logic;
		SD_CLK : out std_logic;
		SD_CMD : inout std_logic;
		SD_DAT : inout std_logic_vector(3 downto 0)
	);
end nes;

architecture behavioral of nes is
	component master_pll is
		port
		(
			refclk : in  std_logic := '0';
			rst : in  std_logic := '0';
			outclk_0 : out std_logic;
			locked : out std_logic
		);
	end component;
	component audio_pll is
		port
		(
			refclk : in  std_logic := '0';
			rst : in  std_logic := '0';
			outclk_0 : out std_logic;
			locked : out std_logic
		);
	end component;
	component vga_pll is
		port
		(
			refclk : in  std_logic := '0';
			rst : in  std_logic := '0';
			outclk_0 : out std_logic;
			locked : out std_logic
		);
	end component;
	component nescore is
		port
		(
			i_clk : in std_logic;
			i_reset_n : in std_logic := '1';
			i_ctrl_a_data : in std_logic := '1';
			i_ctrl_b_data : in std_logic := '1';
			o_ctrl_strobe : out std_logic;
			o_ctrl_a_clk : out std_logic;
			o_ctrl_b_clk : out std_logic;
			o_cpu_clk_enable : out std_logic;
			o_vga_addr : out std_logic_vector(15 downto 0);
			o_vga_data : out std_logic_vector(5 downto 0);
			o_vga_write_enable : out std_logic;
			o_vga_clk_enable : out std_logic;
			o_audio_q : out std_logic_vector(15 downto 0)
		);
	end component;
	component vga is
		generic
		(
			HFP : natural := 88;
			HSYNC : natural := 44;
			HBP : natural := 148;
			HRES : natural := 1920;
			VFP : natural := 4;
			VSYNC : natural := 5;
			VBP : natural := 36;
			VRES : natural := 1080
		);
		port
		(
			i_data_clk : in std_logic;
			i_data_clk_enable : in std_logic;
			i_vga_clk : in std_logic;
			i_vga_clk_enable : in std_logic;
			i_reset_n : in std_logic;
			i_addr : in std_logic_vector(15 downto 0);
			i_data : in std_logic_vector(5 downto 0);
			i_write_enable : in std_logic;
			o_data_enable : out std_logic;
			o_vsync : out std_logic;
			o_hsync : out std_logic;
			o_data : out std_logic_vector(23 downto 0)
		);
	end component;
	component i2s is
		generic
		(
			DIVIDER : natural := 4;
			WORD_WIDTH : natural := 16;
			CHANNEL_WIDTH : natural := 32
		);
		port
		(
			i_audio_clk : in std_logic;
			i_master_clk : in std_logic;
			i_clk_enable : in std_logic;
			i_audio_reset_n : in std_logic := '1';
			i_master_reset_n : in std_logic := '1';
			i_data : in std_logic_vector(WORD_WIDTH - 1 downto 0);
			o_lrclk : out std_logic;
			o_sclk : out std_logic;
			o_sdata : out std_logic
		);
	end component;
	component hex_digit is
		port
		(
			i_d : in std_logic_vector(3 downto 0);
			o_q : out std_logic_vector(6 downto 0)
		);
	end component;
	component periphery_ctrl is
		generic
		(
			CLK_SPEED : integer := 50_000_000
		);
		port
		(
			i_clk : in std_logic;
			i_reset_n : in std_logic := '1';
			i_int_n : in std_logic := '1';
			io_sda : inout std_logic;
			io_scl : inout std_logic;
			o_status : out std_logic_vector(7 downto 0);
			o_ack_error : out std_logic
		);
	end component;
	
	alias HDMI_AUDIO_SPDIF : std_logic is GPIO(0);
	alias HDMI_AUDIO_MCLK : std_logic is GPIO(1);
	alias HDMI_AUDIO_I2S0 : std_logic is GPIO(2);
	alias HDMI_AUDIO_I2S1 : std_logic is GPIO(3);
	alias HDMI_AUDIO_I2S2 : std_logic is GPIO(4);
	alias HDMI_AUDIO_I2S3 : std_logic is GPIO(5);
	alias HDMI_AUDIO_SCLK : std_logic is GPIO(6);
	alias HDMI_AUDIO_LRCLK : std_logic is GPIO(7);
	alias CTRL_A_DATA : std_logic is GPIO(8);
	alias CTRL_B_DATA : std_logic is GPIO(9);
	alias CTRL_A_CLOCK : std_logic is GPIO(10);
	alias CTRL_B_CLOCK : std_logic is GPIO(11);
	alias CTRL_STROBE : std_logic is GPIO(12);
	
	signal s_audio_clk : std_logic;
	signal s_master_clk : std_logic;
	signal s_vga_clk : std_logic;
	signal s_reset_n : std_logic;
	signal s_audio_reset_n : std_logic;
	signal s_vga_reset_n : std_logic;
	signal s_vga_addr : std_logic_vector(15 downto 0);
	signal s_vga_data : std_logic_vector(5 downto 0);
	signal s_vga_write_enable : std_logic;
	signal s_vga_clk_enable : std_logic;
	signal s_audio_q : std_logic_vector(15 downto 0);
	signal s_debug : std_logic_vector(7 downto 0);
	signal s_audio_counter : integer range 0 to 62499 := 0;
	signal s_ack_error : std_logic;
	signal s_audio_lrclk : std_logic;
	signal s_audio_sclk : std_logic;
	signal s_audio_dat : std_logic;
	signal s_sample_req : std_logic_vector(1 downto 0);
	signal s_cpu_clk_enable : std_logic;

begin
	master : master_pll port map
	(
		refclk => CLOCK_50_B5B,
		rst => not CPU_RESET_n,
		outclk_0 => s_master_clk,
		locked => s_reset_n
	);
	audio : audio_pll port map
	(
		refclk => CLOCK_50_B6A,
		rst => not CPU_RESET_n,
		outclk_0 => s_audio_clk,
		locked => s_audio_reset_n
	);
	vgapll : vga_pll port map
	(
		refclk => CLOCK_50_B7A,
		rst => not CPU_RESET_n,
		outclk_0 => s_vga_clk,
		locked => s_vga_reset_n
	);
	nes_core : nescore port map
	(
		i_clk => s_master_clk,
		i_reset_n  => s_reset_n,
		i_ctrl_a_data => CTRL_A_DATA,
		i_ctrl_b_data => CTRL_B_DATA,
		o_ctrl_strobe => CTRL_STROBE,
		o_ctrl_a_clk => CTRL_A_CLOCK,
		o_ctrl_b_clk => CTRL_B_CLOCK,
		o_cpu_clk_enable => s_cpu_clk_enable,
		o_vga_addr => s_vga_addr,
		o_vga_data => s_vga_data,
		o_vga_write_enable => s_vga_write_enable,
		o_vga_clk_enable => s_vga_clk_enable,
		o_audio_q => s_audio_q
	);
	vga_cmp : vga generic map
	(
		HFP => 16,
		HSYNC => 96,
		HBP => 48,
		HRES => 640,
		VFP => 10,
		VSYNC => 2,
		VBP => 33,
		VRES => 480
	)
	port map
	(
		i_data_clk => s_master_clk,
		i_data_clk_enable => s_vga_clk_enable,
		i_vga_clk => s_vga_clk,
		i_vga_clk_enable => '1',
		i_reset_n => s_vga_reset_n,
		i_addr => s_vga_addr,
		i_data => s_vga_data,
		i_write_enable => s_vga_write_enable,
		o_data_enable => HDMI_TX_DE,
		o_vsync => HDMI_TX_VS,
		o_hsync => HDMI_TX_HS,
		o_data => HDMI_TX_D
	);
	pc : periphery_ctrl port map
	(
		i_clk => CLOCK_50_B5B,
		i_reset_n => CPU_RESET_n,
		i_int_n => HDMI_TX_INT,
		io_sda => I2C_SDA,
		io_scl => I2C_SCL,
		o_status => s_debug,
		o_ack_error => s_ack_error
	);
	i2s_cmp : i2s port map
	(
		i_audio_clk => s_audio_clk,
		i_master_clk => s_master_clk,
		i_clk_enable => s_cpu_clk_enable,
		i_audio_reset_n => s_audio_reset_n,
		i_master_reset_n => CPU_RESET_n,
		i_data => s_audio_q,
		o_lrclk => s_audio_lrclk,
		o_sclk => s_audio_sclk,
		o_sdata => s_audio_dat
	);
	hd0 : hex_digit port map
	(
		i_d => s_debug(3 downto 0),
		o_q => HEX0
	);
	hd1 : hex_digit port map
	(
		i_d => s_debug(7 downto 4),
		o_q => HEX1
	);
	hd2 : hex_digit port map
	(
		i_d => s_debug(3 downto 0),
		o_q => HEX2
	);
	hd3 : hex_digit port map
	(
		i_d => s_debug(7 downto 4),
		o_q => HEX3
	);

	HDMI_AUDIO_MCLK <= s_audio_clk;
	HDMI_AUDIO_LRCLK <= s_audio_lrclk;
	HDMI_AUDIO_SCLK <= s_audio_sclk;
	HDMI_AUDIO_I2S0 <= s_audio_dat;
	HDMI_AUDIO_I2S1 <= '0';
	HDMI_AUDIO_I2S2 <= '0';
	HDMI_AUDIO_I2S3 <= '0';
	HDMI_AUDIO_SPDIF <= '0';
	AUD_DACDAT <= s_audio_dat;
	AUD_XCK <= s_audio_clk;
	AUD_DACLRCK <= s_audio_lrclk;
	AUD_BCLK <= s_audio_sclk;
	HDMI_TX_CLK <= s_vga_clk;
	LEDR(9) <= not HDMI_TX_INT;
	LEDR(8) <= s_ack_error;
	LEDR(7 downto 0) <= (others => '0');
	LEDG <= (others => '0');
	CTRL_A_DATA <= 'Z';
	CTRL_B_DATA <= 'Z';
	
end;


/********************************************************/

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.common.all;

entity nescore is
	port
	(
		i_clk : in std_logic;
		i_reset_n : in std_logic := '1';
		i_ctrl_a_data : in std_logic := '1';
		i_ctrl_b_data : in std_logic := '1';
		o_ctrl_strobe : out std_logic;
		o_ctrl_a_clk : out std_logic;
		o_ctrl_b_clk : out std_logic;
		o_cpu_clk_enable : out std_logic;
		o_vga_addr : out std_logic_vector(15 downto 0);
		o_vga_data : out std_logic_vector(5 downto 0);
		o_vga_write_enable : out std_logic;
		o_vga_clk_enable : out std_logic;
		o_audio_q : out std_logic_vector(15 downto 0)
	);
end nescore;

architecture behavioral of nescore is
	component cpu is
		port
		(
			i_clk : in std_logic;
			i_ready : in std_logic := '1';
			i_reset_n : in std_logic := '1';
			i_int_n : in std_logic := '1';
			i_nmi_n : in std_logic := '1';
			i_mem_q : in std_logic_vector(7 downto 0) := x"00";
			o_mem_addr : out std_logic_vector(15 downto 0);
			o_mem_data : out std_logic_vector(7 downto 0);
			o_mem_write_enable : out std_logic;
			o_phi0 : out std_logic;
			o_phi2 : out std_logic
		);
	end component;
	component ppu is
		port
		(
			i_clk: in std_logic;
			i_reset_n: in std_logic := '1';
			i_addr : in std_logic_vector(2 downto 0) := "000";
			i_data : in std_logic_vector(7 downto 0) := x"00";
			i_write_enable : in std_logic := '0';
			i_cs_n : in std_logic := '0';
			o_q : out std_logic_vector(7 downto 0);
			o_int_n : out std_logic;
			o_vga_addr: out std_logic_vector(15 downto 0);
			o_vga_data: out std_logic_vector(5 downto 0);
			o_vga_write_enable: out std_logic;
			o_phi0 : out std_logic
		);
	end component;
	component apu is
		port
		(
			i_clk : in std_logic;
			i_clk_enable : in std_logic;
			i_reset_n : in std_logic := '1';
			i_addr : in std_logic_vector(4 downto 0) := 5x"00";
			i_data : in std_logic_vector(7 downto 0) := x"00";
			i_write_enable : in std_logic := '0';
			i_cs_n : in std_logic := '1';
			i_dma_write_enable : in std_logic := '0';
			i_dma_q : in std_logic_vector(7 downto 0) := x"00";
			i_ctrl_a_data : in std_logic := '1';
			i_ctrl_b_data : in std_logic := '1';
			o_ctrl_strobe : out std_logic;
			o_ctrl_a_clk : out std_logic;
			o_ctrl_b_clk : out std_logic;
			o_int_n : out std_logic;
			o_audio : out std_logic_vector(15 downto 0);
			o_q : out std_logic_vector(7 downto 0);
			o_dma_addr : out std_logic_vector(15 downto 0);
			o_dma_data : out std_logic_vector(7 downto 0);
			o_dma_write_enable : out std_logic;
			o_dma_ready : out std_logic;
			o_dma_active : out std_logic
		);
	end component;
	component data_path is
		port
		(
			i_clk : in std_logic;
			i_clk_enable : in std_logic := '1';
			i_reset_n : in std_logic;
			i_sync : in std_logic;
			i_addr : in std_logic_vector(15 downto 0);
			i_data : in std_logic_vector(7 downto 0);
			i_write_enable : in std_logic;
			i_ppu_q : in std_logic_vector(7 downto 0);
			i_apu_q : in std_logic_vector(7 downto 0);
			o_ppu_addr : out std_logic_vector(2 downto 0);
			o_ppu_data : out std_logic_vector(7 downto 0);
			o_ppu_write_enable : out std_logic;
			o_ppu_cs_n : out std_logic;
			o_apu_addr : out std_logic_vector(4 downto 0);
			o_apu_data : out std_logic_vector(7 downto 0);
			o_apu_write_enable : out std_logic;
			o_apu_cs_n : out std_logic;
			o_q : out std_logic_vector(7 downto 0)
		);
	end component;
	
	signal s_cpu_clk_enable : std_logic;
	signal s_sync : std_logic;
	signal s_ppu_q : std_logic_vector(7 downto 0);
	signal s_ppu_addr : std_logic_vector(2 downto 0);
	signal s_ppu_data : std_logic_vector(7 downto 0);
	signal s_ppu_write_enable : std_logic;
	signal s_ppu_cs_n : std_logic;
	signal s_apu_addr : std_logic_vector(4 downto 0);
	signal s_apu_data : std_logic_vector(7 downto 0);
	signal s_apu_write_enable : std_logic;
	signal s_apu_cs_n : std_logic;
	signal s_apu_q : std_logic_vector(7 downto 0);
	signal s_nmi_n : std_logic;
	signal s_int_n : std_logic;
	signal s_mem_q : std_logic_vector(7 downto 0);
	signal s_mem_addr : std_logic_vector(15 downto 0);
	signal s_mem_data : std_logic_vector(7 downto 0);
	signal s_mem_write_enable : std_logic;
	signal s_eff_addr : std_logic_vector(15 downto 0);
	signal s_eff_data : std_logic_vector(7 downto 0);
	signal s_eff_write_enable : std_logic;
	signal s_dma_addr : std_logic_vector(15 downto 0);
	signal s_dma_data : std_logic_vector(7 downto 0);
	signal s_dma_write_enable : std_logic;
	signal s_dma_ready : std_logic;
	signal s_dma_active : std_logic;
	
begin

	cpu_core : cpu port map
	(
		i_clk => i_clk,
		i_ready => s_dma_ready,
		i_reset_n => i_reset_n,
		i_nmi_n => s_nmi_n,
		i_int_n => s_int_n,
		i_mem_q => s_mem_q,
		o_mem_addr => s_mem_addr,
		o_mem_data => s_mem_data,
		o_mem_write_enable => s_mem_write_enable,
		o_phi0 => s_cpu_clk_enable,
		o_phi2 => s_sync
	);
	ppu_cmp : ppu port map
	(
		i_clk => i_clk,
		i_reset_n => i_reset_n,
		i_addr => s_ppu_addr,
		i_data => s_ppu_data,
		i_write_enable => s_ppu_write_enable,
		i_cs_n => s_ppu_cs_n,
		o_q => s_ppu_q,
		o_int_n => s_nmi_n,
		o_vga_addr => o_vga_addr,
		o_vga_data => o_vga_data,
		o_vga_write_enable => o_vga_write_enable,
		o_phi0 => o_vga_clk_enable
	);
	apu_core : apu port map
	(
		i_clk => i_clk,
		i_clk_enable => s_cpu_clk_enable,
		i_reset_n => i_reset_n,
		i_addr => s_apu_addr,
		i_data => s_apu_data,
		i_write_enable => s_apu_write_enable,
		i_cs_n => s_apu_cs_n,
		i_ctrl_a_data => i_ctrl_a_data,
		i_ctrl_b_data => i_ctrl_b_data,
		i_dma_write_enable => s_mem_write_enable,
		i_dma_q => s_mem_q,
		o_ctrl_strobe => o_ctrl_strobe,
		o_ctrl_a_clk => o_ctrl_a_clk,
		o_ctrl_b_clk => o_ctrl_b_clk,
		o_int_n => s_int_n,
		o_audio => o_audio_q,
		o_q => s_apu_q,
		o_dma_addr => s_dma_addr,
		o_dma_data => s_dma_data,
		o_dma_write_enable => s_dma_write_enable,
		o_dma_ready => s_dma_ready,
		o_dma_active => s_dma_active
	);
	dpath : data_path port map
	(
		i_clk => i_clk,
		i_clk_enable => s_cpu_clk_enable,
		i_sync => s_sync,
		i_reset_n => i_reset_n,
		i_addr => s_eff_addr,
		i_data => s_eff_data,
		i_write_enable => s_eff_write_enable,
		i_ppu_q => s_ppu_q,
		i_apu_q => s_apu_q,
		o_ppu_addr => s_ppu_addr,
		o_ppu_data => s_ppu_data,
		o_ppu_write_enable => s_ppu_write_enable,
		o_ppu_cs_n => s_ppu_cs_n,
		o_apu_addr => s_apu_addr,
		o_apu_data => s_apu_data,
		o_apu_write_enable => s_apu_write_enable,
		o_apu_cs_n => s_apu_cs_n,
		o_q => s_mem_q
	);
	
	s_eff_write_enable <= s_dma_write_enable when s_dma_active = '1' else s_mem_write_enable;
	s_eff_addr <= s_dma_addr when s_dma_active = '1' else s_mem_addr;
	s_eff_data <= s_dma_data when s_dma_active = '1' else s_mem_data;
				  
	o_cpu_clk_enable <= s_cpu_clk_enable;

end;

