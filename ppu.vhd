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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.common.all;

entity parallel_serial_shifter is
	generic
	(
		width: integer := 8;
		size: integer := 8
	);
	port
	(
		i_clk: in std_logic;
		i_clk_enable : in std_logic := '1';
		i_load: in std_logic;
		i_enable: in std_logic;
		i_data: in std_logic_vector(size - 1 downto 0);
		o_q: out std_logic_vector(size - 1 downto 0)
	);
end parallel_serial_shifter;

architecture behavioral of parallel_serial_shifter is
	signal s_buffer: std_logic_vector(width - 1 downto 0);
begin
	process (i_clk, i_clk_enable)
	begin
		if rising_edge(i_clk) then
			if i_clk_enable = '1' then
				if i_enable = '1' and i_load = '1' then
					s_buffer <= s_buffer(width - 2 downto size) & i_data & '0';
				elsif i_enable = '1' then
					s_buffer <= s_buffer(width - 2 downto 0) & '0';
				elsif i_load = '1' then
					s_buffer(size - 1 downto 0) <= i_data;
				end if;
			end if;
		end if;
	end process;
	
	o_q <= reverse_vector(s_buffer(width - 1 downto width - size));
end architecture;

/*****************************************************************/

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity sprite_renderer is
	port
	(
		i_sprite_x : in std_logic_vector(7 downto 0);
		i_line_x : in std_logic_vector(7 downto 0);
		i_tile_low : in std_logic_vector(7 downto 0);
		i_tile_high : in std_logic_vector(7 downto 0);
		i_enable : in std_logic;
		i_first_col : in std_logic;
		o_pixel : out std_logic_vector(1 downto 0)
	);
end sprite_renderer;

architecture behavioral of sprite_renderer is
	signal s_offset : integer range 0 to 7;
	signal s_sprite_right : std_logic_vector(8 downto 0);
	signal s_draw_n : boolean;
begin

	s_offset <= to_integer(unsigned(i_sprite_x(2 downto 0) - i_line_x(2 downto 0) - "001"));
	s_sprite_right <= ('0' & i_sprite_x) + "000001000";
	s_draw_n <= (i_first_col = '0') and (i_line_x(7 downto 3) = "00000");

	o_pixel <= "00" when (i_enable = '0') or s_draw_n or (i_line_x < i_sprite_x) or (i_line_x >= s_sprite_right) else i_tile_high(s_offset) & i_tile_low(s_offset);
	
end architecture;

/*****************************************************************/

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity ppumem is
	port
	(
		i_clk : in std_logic;
		i_clk_enable : in std_logic := '1';
		i_addr : in std_logic_vector(15 downto 0);
		i_data : in std_logic_vector(7 downto 0);
		i_write_enable : in std_logic;
		o_q : out std_logic_vector(7 downto 0)
	);
end ppumem;

architecture behavioral of ppumem is
	component videorom is
		port
		(
			address : in std_logic_vector(12 downto 0);
			clken : in std_logic := '1';
			clock : in std_logic := '1';
			data : in std_logic_vector(7 downto 0);
			wren : in std_logic := '0';
			q : out std_logic_vector(7 downto 0)
		);
	end component;
	component videomem is
		port
		(
			address : in std_logic_vector(10 downto 0);
			clken : in std_logic := '1';
			clock : in std_logic := '1';
			data : in std_logic_vector(7 downto 0);
			wren : in std_logic := '0';
			q : out std_logic_vector(7 downto 0)
		);
	end component;
	
	type addr_type_t is (nop, ram, rom);
	
	signal s_ram_q : std_logic_vector(7 downto 0);
	signal s_rom_q : std_logic_vector(7 downto 0);
	signal s_ram_write_enable : std_logic := '0';
	signal s_rom_write_enable : std_logic := '0';
	signal s_addr_type : addr_type_t;
	signal s_addr_type_d : addr_type_t := nop;

begin
	vrom: videorom port map
	(
		address => i_addr(12 downto 0),
		clken => i_clk_enable,
		clock => i_clk,
		data => i_data,
		wren => s_rom_write_enable,
		q => s_rom_q
	);
	vram: videomem port map
	(
		address => i_addr(10 downto 0),
		clken => i_clk_enable,
		clock => i_clk,
		data => i_data,
		wren => s_ram_write_enable,
		q => s_ram_q
	);

	process (i_clk)
	begin
		if rising_edge(i_clk) then
			if i_clk_enable = '1' then
				s_addr_type_d <= s_addr_type;
			end if;
		end if;
	end process;
	
	s_ram_write_enable <= i_write_enable when s_addr_type = ram else '0';
	s_rom_write_enable <= i_write_enable when s_addr_type = rom else '0';

	s_addr_type <= rom when i_addr(15 downto 13) = "000"
					else ram when i_addr(15 downto 13) = "001"
					else nop;
	
	with s_addr_type_d select o_q <=
		s_rom_q when rom,
		s_ram_q when ram,
		x"--" when others;
	
end architecture;

/*****************************************************************/

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.common.all;

entity ppu is
	generic
	(
		DIVIDER : integer := 4
	);
	port
	(
		i_clk : in std_logic;
		i_reset_n : in std_logic := '1';
		i_addr : in std_logic_vector(2 downto 0) := "000";
		i_data : in std_logic_vector(7 downto 0) := x"00";
		i_write_enable : in std_logic := '0';
		i_cs_n : in std_logic := '0';
		o_q : out std_logic_vector(7 downto 0);
		o_int_n : out std_logic;
		o_vga_addr : out std_logic_vector(15 downto 0);
		o_vga_data : out std_logic_vector(5 downto 0);
		o_vga_write_enable : out std_logic;
		o_phi0 : out std_logic
	);
end ppu;

architecture behavioral of ppu is
	component parallel_serial_shifter is
		generic
		(
			width: integer := 8;
			size: integer := 8
		);
		port
		(
			i_clk : in std_logic;
			i_clk_enable : in std_logic := '1';
			i_load : in std_logic;
			i_enable : in std_logic;
			i_data : in std_logic_vector(7 downto 0);
			o_q : out std_logic_vector(7 downto 0)
		);
	end component;
	component ppumem is
		port
		(
			i_clk : in std_logic;
			i_clk_enable : in std_logic := '1';
			i_addr : in std_logic_vector(15 downto 0);
			i_data : in std_logic_vector(7 downto 0);
			i_write_enable : in std_logic;
			o_q : out std_logic_vector(7 downto 0)
		);
	end component;
	component spritemem is
		port
		(
			address : in std_logic_vector(7 downto 0);
			clken : in std_logic := '1';
			clock : in std_logic := '1';
			data : in std_logic_vector(7 downto 0);
			wren : in std_logic := '0';
			q : out std_logic_vector(7 downto 0)
		);
	end component;
	component soamem is
		port
		(
			address : in std_logic_vector(4 downto 0);
			clken : in std_logic := '1';
			clock : in std_logic := '1';
			data : in std_logic_vector(7 downto 0);
			wren : in std_logic;
			q : out std_logic_vector(7 downto 0)
		);
	end component;
	component sprite_renderer is
		port
		(
			i_sprite_x : in std_logic_vector(7 downto 0);
			i_line_x : in std_logic_vector(7 downto 0);
			i_tile_low : in std_logic_vector(7 downto 0);
			i_tile_high : in std_logic_vector(7 downto 0);
			i_enable : in std_logic;
			i_first_col : in std_logic;
			o_pixel : out std_logic_vector(1 downto 0)
		);
	end component;
	
	function to_pal_idx(addr: std_logic_vector(4 downto 0)) return integer is
	begin
		if (addr(4) = '1') and (addr(1 downto 0) = "00") then
			return to_integer(unsigned('0' & addr(3 downto 0)));
		else
			return to_integer(unsigned(addr));
		end if;
	end;

	type sprite_t is record
		x : std_logic_vector(7 downto 0);
		tile_low : std_logic_vector(7 downto 0);
		tile_high : std_logic_vector(7 downto 0);
		enabled : std_logic;
		priority : std_logic;
		palette : std_logic_vector(1 downto 0);
		pixel : std_logic_vector(1 downto 0);
	end record;
	
	type io_state_t is (idle, ppuctrl, ppumask, ppustatus, oamaddr, oamdata_read, oamdata_write, ppuscroll_x, ppuscroll_y, ppuaddr_hi, ppuaddr_lo, ppudata_read, ppudata_write);
	type sprite_state_t is (idle, clear1, clear2, ev_y, ev_tile, ev_attr, ev_x, test_overflow1, test_overflow2, wait1, wait2, gf1, gf2, gf3, gf4, ftl1, ftl2, fth1, fth2, disable_sprite);
	type background_state_t is (idle, nt1, nt2, at1, at2, tl1, tl2, th1, th2);
	type sprite_list_t is array (0 to 7) of sprite_t;
	type byte_array_t is array (0 to 31) of std_logic_vector(7 downto 0);
	
	constant NULL_SPRITE : sprite_t := (x => x"00", tile_low => x"00", tile_high => x"00", enabled => '0', priority => '0', palette => "00", pixel => "00");

	signal s_io_state : io_state_t := idle;
	signal s_io_data : std_logic_vector(7 downto 0) := x"00";
	signal s_io_mem : std_logic_vector(7 downto 0) := x"00";
	signal s_io_cycle : integer range 0 to 7 := 0;
	signal s_io_latch : boolean := true;
	signal s_sprites : sprite_list_t := (others => NULL_SPRITE);
	signal s_oam_addr : std_logic_vector(7 downto 0) := x"00";
	signal s_oam_write_enable : std_logic := '0';
	signal s_oam_q : std_logic_vector(7 downto 0);
	signal s_spr_addr : std_logic_vector(15 downto 0) := (others => '0');
	signal s_bkg_addr : std_logic_vector(15 downto 0) := (others => '0');
	signal s_video_addr : std_logic_vector(15 downto 0) := (others => '0');
	signal s_video_data : std_logic_vector(7 downto 0);
	signal s_video_write_enable : std_logic;
	signal s_xpos : std_logic_vector(7 downto 0);
	signal s_next_ypos : std_logic_vector(7 downto 0);
	signal s_cycle : integer range 0 to 340 := 0;
	signal s_line : integer range 0 to 261 := 261;
	signal s_tile_index : std_logic_vector(7 downto 0);
	signal s_background_half : std_logic;
	signal s_sprite_half : std_logic;
	signal s_nametable : std_logic_vector(1 downto 0);
	signal s_shifter_enable : std_logic := '0';
	signal s_shifter_load : std_logic := '0';
	signal s_render : boolean;
	signal s_tl_data : std_logic_vector(7 downto 0) := (others => '0');
	signal s_tl_q : std_logic_vector(7 downto 0);
	signal s_th_data : std_logic_vector(7 downto 0) := (others => '0');
	signal s_th_q : std_logic_vector(7 downto 0);
	signal s_bl_q : std_logic_vector(7 downto 0);
	signal s_bh_q : std_logic_vector(7 downto 0);
	signal s_background_palette_index: std_logic_vector(1 downto 0);
	signal s_new_background_palette_index : std_logic_vector(1 downto 0);
	signal s_color : std_logic_vector(5 downto 0);
	signal s_palette_color : std_logic_vector(5 downto 0);
	signal s_bkg_state : background_state_t := idle;
	signal s_spr_state : sprite_state_t := idle;
	signal s_out_addr : std_logic_vector(15 downto 0) := x"0000";
	signal s_out_data : std_logic_vector(5 downto 0) := "000000";
	signal s_out_write_enable : std_logic := '0';
	signal s_visible_line : boolean;
	signal s_visible_or_prescan_line : boolean;
	signal s_background_pixel : std_logic_vector(1 downto 0);
	signal s_winning_sprite : sprite_t;
	signal s_spr_cnt : integer range 0 to 8 := 0;
	signal s_next_spr_idx : integer range 0 to 8 := 0;
	signal s_spr_idx : integer range 0 to 7 := 0;
	signal s_soa_addr : std_logic_vector(4 downto 0) := (others => '0');
	signal s_soa_data : std_logic_vector(7 downto 0) := (others => '0');
	signal s_soa_q : std_logic_vector(7 downto 0) := (others => '0');
	signal s_soa_write_enable : std_logic := '0';
	signal s_soa_trigger_write : std_logic := '0';
	signal s_sprite_y : std_logic_vector(7 downto 0) := (others => '0');
	signal s_sprite_top : std_logic_vector(7 downto 0);
	signal s_sprite_tile : std_logic_vector(7 downto 0) := (others => '0');
	signal s_oam_soa_transfer : std_logic := '0';
	signal s_sprite_0_trigger : boolean := false;
	signal s_sprite_0_hit : std_logic := '0';
	signal s_sprite_0_visible : boolean := false;
	signal s_new_sprite_0_visible : boolean := false;
	signal s_sprite_overflow : std_logic := '0';
	signal s_sprite_flip_horizontal : std_logic := '0';
	signal s_tile_data : std_logic_vector(7 downto 0);
	signal s_enable_background : std_logic := '0';
	signal s_enable_sprites : std_logic := '0';
	signal s_render_first_bkg_col : std_logic := '0';
	signal s_render_first_spr_col : std_logic := '0';
	signal s_big_sprites : std_logic := '0';
	signal s_sprite_online : boolean;
	signal s_sprite_line_lower_test : boolean;
	signal s_sprite_line_upper_test : boolean;
	signal s_sprite_line_test_width : std_logic_vector(7 downto 0);
	signal s_inner_tile_pos : std_logic_vector(3 downto 0);
	signal s_next_tile_addr : std_logic_vector(12 downto 0);
	signal s_tile_addr : std_logic_vector(15 downto 0);
	signal s_attr_addr : std_logic_vector(15 downto 0);
	signal s_tile_lo_addr : std_logic_vector(15 downto 0);
	signal s_tile_hi_addr : std_logic_vector(15 downto 0);
	signal s_vassign : boolean;
	signal s_q : std_logic_vector(7 downto 0) := x"00";
	signal s_perform_oam_write_access : boolean;
	signal s_perform_oam_access : boolean;
	signal s_vblank : std_logic := '0';
	signal s_enable_nmi : std_logic := '0';
	signal s_vram_inc : std_logic := '0';
	signal s_vram_addr_t : std_logic_vector(14 downto 0) := 15x"0000";
	signal s_vram_addr_v : std_logic_vector(14 downto 0) := 15x"0000";
	signal s_fine_scroll_x : integer range 0 to 7 := 0;
	signal s_clk_enable : std_logic;
	signal s_palette_access : boolean;
	signal s_palette_index : std_logic_vector(4 downto 0);
	signal s_palette_quadrant : std_logic_vector(1 downto 0);
	signal s_palette_mem : byte_array_t := ( x"09", x"01", x"00", x"01", x"00", x"02", x"02", x"0D", x"08", x"10", x"08", x"24", x"00", x"00", x"04", x"2C", x"09", x"01", x"34", x"03", x"00", x"04", x"00", x"14", x"08", x"3A", x"00", x"02", x"00", x"20", x"2C", x"08" );
	signal s_hblank_cycle : boolean;
	signal s_first_col_n : boolean;
	signal s_clk_divider : integer range 0 to DIVIDER - 1 := 0;
	signal s_vram_bkg_inc : boolean;
	signal s_frame_latch : boolean := true;
	signal s_enable_rendering : boolean;
	signal s_shortcut_state : boolean;
	signal s_greyscale : std_logic := '0';

begin
	mem: ppumem port map
	(
		i_clk => i_clk,
		i_clk_enable => s_clk_enable,
		i_addr => s_video_addr,
		i_data => s_io_data,
		i_write_enable => s_video_write_enable,
		o_q => s_video_data
	);
	oamem: spritemem port map
	(
		clock => i_clk,
		clken => s_clk_enable,
		address => s_oam_addr,
		data => s_io_data,
		wren => s_oam_write_enable,
		q => s_oam_q
	);
	soam: soamem port map
	(
		clock => i_clk,
		clken => s_clk_enable,
		address => s_soa_addr,
		data => s_soa_data,
		wren => s_soa_write_enable,
		q => s_soa_q
	);
	tl_shifter: parallel_serial_shifter generic map (16, 8) port map
	(
		i_clk => i_clk,
		i_clk_enable => s_clk_enable,
		i_load => s_shifter_load,
		i_enable => s_shifter_enable,
		i_data => s_tl_data,
		o_q => s_tl_q
	);
	th_shifter: parallel_serial_shifter generic map (16, 8) port map
	(
		i_clk => i_clk,
		i_clk_enable => s_clk_enable,
		i_load => s_shifter_load,
		i_enable => s_shifter_enable,
		i_data => s_video_data,
		o_q => s_th_q
	);
	bl_shifter: parallel_serial_shifter generic map (16, 8) port map
	(
		i_clk => i_clk,
		i_clk_enable => s_clk_enable,
		i_load => s_shifter_load,
		i_enable => s_shifter_enable,
		i_data => s_new_background_palette_index(0) & s_new_background_palette_index(0) & s_new_background_palette_index(0) & s_new_background_palette_index(0) & s_new_background_palette_index(0) & s_new_background_palette_index(0) & s_new_background_palette_index(0) & s_new_background_palette_index(0),
		o_q => s_bl_q
	);
	bh_shifter: parallel_serial_shifter generic map (16, 8) port map
	(
		i_clk => i_clk,
		i_clk_enable => s_clk_enable,
		i_load => s_shifter_load,
		i_enable => s_shifter_enable,
		i_data => s_new_background_palette_index(1) & s_new_background_palette_index(1) & s_new_background_palette_index(1) & s_new_background_palette_index(1) & s_new_background_palette_index(1) & s_new_background_palette_index(1) & s_new_background_palette_index(1) & s_new_background_palette_index(1),
		o_q => s_bh_q
	);

	spr_gen: for i in 0 to 7 generate
		spr: sprite_renderer port map
		(
			i_sprite_x => s_sprites(i).x,
			i_line_x => s_xpos,
			i_tile_low => s_sprites(i).tile_low,
			i_tile_high => s_sprites(i).tile_high,
			i_enable => s_sprites(i).enabled and s_enable_sprites,
			i_first_col => s_render_first_spr_col,
			o_pixel => s_sprites(i).pixel
		);
	end generate;
	
	-- Clock Divider
	
	process (i_clk)
	begin
		if rising_edge(i_clk) then
			if i_reset_n = '0' then
				s_clk_divider <= 0;
			elsif s_clk_divider = DIVIDER - 1 then
				s_clk_divider <= 0;
			else
				s_clk_divider <= s_clk_divider + 1;
			end if;
		end if;
	end process;
	
	-- IO

	process (i_clk)
	begin
		if rising_edge(i_clk) then
			if s_clk_enable = '1' then
				if i_reset_n = '0' then
					s_q <= x"00";
					s_io_data <= x"00";
					s_io_state <= idle;
					s_io_latch <= true;
				else
					case s_io_state is
					
						when idle =>
							if i_cs_n = '0' then
								s_q <= x"00";
								s_io_data <= i_data;
								s_io_cycle <= 0;

								case i_addr is
									
									when "000" => -- PPUCTRL
										if i_write_enable = '1' then
											s_io_state <= ppuctrl;
										end if;
									
									when "001" => -- PPUMASK
										if i_write_enable = '1' then
											s_io_state <= ppumask;
										end if;
									
									when "010" => -- PPUSTATUS
										if i_write_enable = '0' then
											s_io_state <= ppustatus;
											s_io_latch <= true;
										end if;
									
									when "011" => -- OAMADDR
										if i_write_enable = '1' then
											s_io_state <= oamaddr;
											s_io_data <= i_data;
										end if;
									
									when "100" => -- OAMDATA
										if i_write_enable = '1' then
											s_io_state <= oamdata_write;
										else
											s_io_state <= oamdata_read;
										end if;
									
									when "101" => -- PPUSCROLL
										if i_write_enable = '1' then
											if s_io_latch then
												s_io_state <= ppuscroll_x;
											else
												s_io_state <= ppuscroll_y;
											end if;
											
											s_io_latch <= not s_io_latch;
										end if;
									
									when "110" => -- PPUADDR
										if i_write_enable = '1' then
											if s_io_latch then
												s_io_state <= ppuaddr_hi;
											else
												s_io_state <= ppuaddr_lo;
											end if;
											
											s_io_latch <= not s_io_latch;
										end if;
									
									when "111" => -- PPUDATA
										if i_write_enable = '1' then
											s_io_state <= ppudata_write;
										else
											s_io_state <= ppudata_read;
										end if;
									
									when others =>
								
								end case;
							end if;
						
						when oamdata_read =>
							if s_io_cycle = 1 then
								s_io_state <= idle;
								s_q <= s_oam_q;
							else
								s_io_cycle <= s_io_cycle + 1;
							end if;
							
						when ppustatus =>
							if s_io_cycle = 1 then
								s_io_state <= idle;
								s_q <= s_vblank & s_sprite_0_hit & s_sprite_overflow & "00000";
							else
								s_io_cycle <= s_io_cycle + 1;
							end if;
							
						when oamaddr | oamdata_write | ppuctrl | ppuscroll_x | ppuscroll_y | ppumask | ppuaddr_hi =>
							if s_io_cycle = 1 then
								s_io_state <= idle;
								s_q <= x"00";
							else
								s_io_cycle <= s_io_cycle + 1;
							end if;
							
						when ppudata_read =>
							if s_io_cycle = 5 then
								s_io_state <= idle;
								s_io_mem <= s_video_data;
							else
								if s_io_cycle = 1 then
									if s_palette_access then
										s_q <= s_palette_mem(to_pal_idx(s_vram_addr_v(4 downto 0)));
									else
										s_q <= s_io_mem;
									end if;
								end if;
							
								s_io_cycle <= s_io_cycle + 1;
							end if;
							
						when ppuaddr_lo =>
							if s_io_cycle = 2 then
								s_io_state <= idle;
							else
								s_io_cycle <= s_io_cycle + 1;
							end if;
							
						when ppudata_write =>
							if s_io_cycle = 7 then
								s_io_state <= idle;
							else
								s_io_cycle <= s_io_cycle + 1;
							end if;
					
					end case;
				end if;
			end if;
		end if;
	end process;

	-- Zeilen & Zyklen
	process (i_clk)
	begin
		if rising_edge(i_clk) then
			if s_clk_enable = '1' then
				if i_reset_n = '0' then
					s_line <= 261;
					s_cycle <= 0;
					s_frame_latch <= true;
				else
					if s_cycle = 340 then
						s_cycle <= 0;
						
						if s_line = 261 then
							s_line <= 0;
							s_frame_latch <= not s_frame_latch;
							
							if s_shortcut_state then
								s_cycle <= 1;
							end if;
						else
							s_line <= s_line + 1;
						end if;
					else
						s_cycle <= s_cycle + 1;
					end if;
				end if;
			end if;
		end if;
	end process;
	
	-- Enable Rendering
	
	process (i_clk)
	begin
		if rising_edge(i_clk) then
			if s_clk_enable = '1' then
				if i_reset_n = '0' then
					s_greyscale <= '0';
				elsif s_io_state = ppumask then
					s_greyscale <= s_io_data(0);
				end if;
			end if;
		end if;
	end process;

	process (i_clk)
	begin
		if rising_edge(i_clk) then
			if s_clk_enable = '1' then
				if i_reset_n = '0' then
					s_render_first_bkg_col <= '0';
				elsif s_io_state = ppumask then
					s_render_first_bkg_col <= s_io_data(1);
				end if;
			end if;
		end if;
	end process;
	
	process (i_clk)
	begin
		if rising_edge(i_clk) then
			if s_clk_enable = '1' then
				if i_reset_n = '0' then
					s_render_first_spr_col <= '0';
				elsif s_io_state = ppumask then
					s_render_first_spr_col <= s_io_data(2);
				end if;
			end if;
		end if;
	end process;
	
	process (i_clk)
	begin
		if rising_edge(i_clk) then
			if s_clk_enable = '1' then
				if i_reset_n = '0' then
					s_enable_background <= '0';
				elsif s_io_state = ppumask then
					s_enable_background <= s_io_data(3);
				end if;
			end if;
		end if;
	end process;
	
	process (i_clk)
	begin
		if rising_edge(i_clk) then
			if s_clk_enable = '1' then
				if i_reset_n = '0' then
					s_enable_sprites <= '0';
				elsif s_io_state = ppumask then
					s_enable_sprites <= s_io_data(4);
				end if;
			end if;
		end if;
	end process;
	
	-- Setup
	
	process (i_clk)
	begin
		if rising_edge(i_clk) then
			if s_clk_enable = '1' then
				if i_reset_n = '0' then
					s_vram_inc <= '0';
				elsif s_io_state = ppuctrl then
					s_vram_inc <= s_io_data(2);
				end if;
			end if;
		end if;
	end process;
	
	process (i_clk)
	begin
		if rising_edge(i_clk) then
			if s_clk_enable = '1' then
				if i_reset_n = '0' then
					s_sprite_half <= '0';
				elsif s_io_state = ppuctrl then
					s_sprite_half <= s_io_data(3);
				end if;
			end if;
		end if;
	end process;
	
	process (i_clk)
	begin
		if rising_edge(i_clk) then
			if s_clk_enable = '1' then
				if i_reset_n = '0' then
					s_background_half <= '0';
				elsif s_io_state = ppuctrl then
					s_background_half <= s_io_data(4);
				end if;
			end if;
		end if;
	end process;
	
	process (i_clk)
	begin
		if rising_edge(i_clk) then
			if s_clk_enable = '1' then
				if i_reset_n = '0' then
					s_big_sprites <= '0';
				elsif s_io_state = ppuctrl then
					s_big_sprites <= s_io_data(5);
				end if;
			end if;
		end if;
	end process;
	
	process (i_clk)
	begin
		if rising_edge(i_clk) then
			if s_clk_enable = '1' then
				if i_reset_n = '0' then
					s_enable_nmi <= '0';
				elsif (s_io_state = ppuctrl) and (s_io_cycle = 1) then
					s_enable_nmi <= s_io_data(7);
				end if;
			end if;
		end if;
	end process;
	
	-- VRAM Adressierung

	process (i_clk)
	begin
		if rising_edge(i_clk) then
			if s_clk_enable = '1' then
				if i_reset_n = '0' then
					s_vram_addr_t <= 15x"0000";
				elsif s_io_state = ppuaddr_hi then
					s_vram_addr_t(14) <= '0';
					s_vram_addr_t(13 downto 8) <= s_io_data(5 downto 0);
				elsif (s_io_state = ppuaddr_lo) and (s_io_cycle = 0) then
					s_vram_addr_t(7 downto 0) <= s_io_data;
				elsif s_io_state = ppuscroll_x then
					s_vram_addr_t(4 downto 0) <= s_io_data(7 downto 3);
				elsif s_io_state = ppuscroll_y then
					s_vram_addr_t(14 downto 12) <= s_io_data(2 downto 0);
					s_vram_addr_t(9 downto 5) <= s_io_data(7 downto 3);
				elsif s_io_state = ppuctrl then
					s_vram_addr_t(11 downto 10) <= s_io_data(1 downto 0);
				end if;
			end if;
		end if;
	end process;
	
	process (i_clk)
	begin
		if rising_edge(i_clk) then
			if s_clk_enable = '1' then
				if i_reset_n = '0' then
					s_fine_scroll_x <= 0;
				elsif s_io_state = ppuscroll_x then
					s_fine_scroll_x <= to_integer(unsigned(s_io_data(2 downto 0)));
				end if;
			end if;
		end if;
	end process;
	
	process (i_clk)
	begin
		if rising_edge(i_clk) then
			if s_clk_enable = '1' then
				if i_reset_n = '0' then
					s_vram_addr_v <= 15x"0000";
				elsif (s_io_state = ppuaddr_lo) and (s_io_cycle = 2) then
					s_vram_addr_v <= s_vram_addr_t;
				elsif ((s_io_state = ppudata_write) and (s_io_cycle = 7)) or ((s_io_state = ppudata_read) and (s_io_cycle = 5)) then
					if s_vram_inc = '0' then
						s_vram_addr_v <= s_vram_addr_v + 15x"0001";
					else
						s_vram_addr_v <= s_vram_addr_v + 15x"0020";
					end if;

					s_vram_addr_v(14) <= '0';
				elsif s_enable_rendering and s_visible_or_prescan_line and s_hblank_cycle then
					if s_cycle = 257 then -- Horizontal LoopyV <= Horizontal LoopyT
						s_vram_addr_v(10) <= s_vram_addr_t(10);
						s_vram_addr_v(4 downto 0) <= s_vram_addr_t(4 downto 0);
					elsif s_vassign then -- Vertical LoopyV <= Horizontal LoopyT
						s_vram_addr_v(9 downto 5) <= s_vram_addr_t(9 downto 5);
						s_vram_addr_v(14 downto 11) <= s_vram_addr_t(14 downto 11);
					end if;
				elsif s_enable_rendering and s_visible_or_prescan_line and s_vram_bkg_inc then
					-- Vertical LoopyV increment
					if s_cycle = 255 then
						if s_vram_addr_v(14 downto 12) = "111" then
							s_vram_addr_v(14 downto 12) <= "000";
							
							if s_vram_addr_v(9 downto 5) = "11101" then -- 29
								s_vram_addr_v(11) <= not s_vram_addr_v(11);
								s_vram_addr_v(9 downto 5) <= "00000";
							elsif s_vram_addr_v(9 downto 5) = "11111" then -- 31
								s_vram_addr_v(9 downto 5) <= "00000";
							else
								s_vram_addr_v(9 downto 5) <= s_vram_addr_v(9 downto 5) + "00001";
							end if;
						else
							s_vram_addr_v(14 downto 12) <= s_vram_addr_v(14 downto 12) + "001";
						end if;
					end if;
					
					-- Horizontal LoopyV increment
					if s_vram_addr_v(4 downto 0) = "11111" then
						s_vram_addr_v(4 downto 0) <= "00000";
						s_vram_addr_v(10) <= not s_vram_addr_v(10);
					else
						s_vram_addr_v(4 downto 0) <= s_vram_addr_v(4 downto 0) + "00001";
					end if;
				end if;
			end if;
		end if;
	end process;
	
	s_video_write_enable <= '1' when (s_io_state = ppudata_write) and (s_io_cycle = 7) and not s_palette_access else '0';
	
	-- Palette

	process (i_clk)
		variable index : integer range 0 to 31;
	begin
		if rising_edge(i_clk) then
			if s_clk_enable = '1' then
				if (s_io_state = ppudata_write) and s_palette_access and (s_io_cycle = 1) then
					index := to_pal_idx(s_vram_addr_v(4 downto 0));
					s_palette_mem(index) <= s_io_data;
				end if;
			end if;
		end if;
	end process;

	-- Hintergrund rendern
	
	process (i_clk)
		variable ypos : std_logic_vector(7 downto 0);
	begin
		if rising_edge(i_clk) then
			if s_clk_enable = '1' then
				s_shifter_load <= '0';
			
				if i_reset_n = '0' then
					s_bkg_state <= idle;
				else
					case s_bkg_state is
					
						when idle =>
							s_bkg_state <= nt1;
							s_bkg_addr <= s_tile_addr;
					
						when nt1 => -- Name Table
							s_bkg_state <= nt2;
							
						when nt2 =>
							s_tile_index <= s_video_data;
							s_bkg_addr <= s_attr_addr;
							s_bkg_state <= at1;
							
						when at1 => -- Attribute Table
							s_bkg_state <= at2;
							
						when at2 =>
							if s_cycle /= 340 then
								s_bkg_state <= tl1;
								s_bkg_addr <= s_tile_lo_addr;
									
								case s_palette_quadrant is
								
									when "00" =>
										s_new_background_palette_index <= s_video_data(1 downto 0);
										
									when "01" =>
										s_new_background_palette_index <= s_video_data(3 downto 2);
										
									when "10" =>
										s_new_background_palette_index <= s_video_data(5 downto 4);
										
									when "11" =>
										s_new_background_palette_index <= s_video_data(7 downto 6);
										
									when others =>
										s_new_background_palette_index <= "00";
										
								end case;
							elsif s_shortcut_state then
								s_bkg_state <= nt1;
								s_bkg_addr <= s_tile_addr;
							else
								s_bkg_state <= idle;
							end if;
							
						when tl1 => -- Tile low
							s_bkg_state <= tl2;
							
						when tl2 =>
							s_bkg_state <= th1;
							s_tl_data <= s_video_data;
							s_bkg_addr <= s_tile_hi_addr;
							
						when th1 => -- Tile high
							s_bkg_state <= th2;
							
						when th2 =>
							s_shifter_load <= '1';
							s_bkg_state <= nt1;
							s_bkg_addr <= s_tile_addr;

						when others =>
							s_bkg_state <= idle;
							
					end case;
				end if;
			end if;
		end if;
	end process;
	
	s_shifter_enable <= '0' when (s_cycle > 336) or (s_cycle = 0) else '1';
	
	-- Sprites rendern

	process (i_clk)
	begin
		if rising_edge(i_clk) then
			if s_clk_enable = '1' then
				if i_reset_n = '0' then
					s_spr_state <= idle;
					s_soa_addr <= "00000";
					s_soa_write_enable <= '0';
					s_oam_addr <= x"00";
				else
					s_soa_write_enable <= s_oam_soa_transfer;
					s_oam_soa_transfer <= '0';
					s_soa_data <= s_oam_q;
					
					if s_perform_oam_access then
						s_oam_addr <= s_oam_addr + x"01";
					end if;
					
					if (s_io_state = oamaddr) and (s_io_cycle = 1) then
						s_oam_addr <= s_io_data;
					end if;
					
					if s_oam_soa_transfer = '1' then
						s_soa_addr <= s_soa_addr + "00001";
					end if;
					
					-- Sprite Overflow zu Beginn eines neuen Frames zurücksetzen
					if (s_line = 261) and (s_cycle = 1) then
						s_sprite_overflow <= '0';
					end if;
					
					-- OAMADDR wird bei allen sichtbaren und der Prerender-Zeile von Zyklus 257 bis 320 bei jedem Tick auf 0 gesetzt
					if s_visible_or_prescan_line and s_hblank_cycle then
						s_oam_addr <= x"00";
					end if;
				
					case s_spr_state is

						when idle =>
							if s_visible_or_prescan_line and (s_enable_sprites = '1') then
								s_spr_state <= clear1;
								s_soa_addr <= "00000";
							else
								s_spr_state <= wait2;
							end if;
							
						when clear1 =>
							s_soa_data <= x"ff";
							s_soa_write_enable <= '1';
							s_spr_state <= clear2;

						when clear2 =>
							if s_soa_addr = "11111" then
								s_spr_state <= ev_y;
								s_spr_cnt <= 0;
								s_soa_addr <= "11111";
								s_new_sprite_0_visible <= false;
							else
								s_soa_addr <= s_soa_addr + "00001";
								s_spr_state <= clear1;
							end if;
							
						when ev_y =>
							s_oam_addr <= s_oam_addr + x"01"; -- Adresse für Tile Index
							s_spr_state <= ev_tile;
							
						when ev_tile =>
							if s_sprite_online then
								-- Sprite ist auf der kommenden Zeile
								s_oam_addr <= s_oam_addr + x"01"; -- Adresse für Attribute
								s_oam_soa_transfer <= '1'; -- Tile Index
								s_soa_data <= s_sprite_top; -- Y-Position
								s_soa_write_enable <= '1';
								s_soa_addr <= s_soa_addr + "00001";
								s_spr_state <= ev_attr;
								s_spr_cnt <= s_spr_cnt + 1;
								
								-- TODO: 1. Sprite und nicht Adresse x01 verwenden
								if s_oam_addr = x"01" then
									s_new_sprite_0_visible <= true;
								end if;
							else
								-- Sprite ist nicht auf der kommenden Zeile, überspringen
								if s_oam_addr >= x"fd" then
									-- Letzter zu testender Sprite erreicht
									s_spr_state <= wait1;
								else
									s_oam_addr <= s_oam_addr + x"03"; -- Adresse für Y-Position
									s_spr_state <= ev_y;
								end if;
							end if;
							
						when ev_attr =>
							s_oam_addr <= s_oam_addr + x"01"; -- Adresse für X-Position
							s_oam_soa_transfer <= '1'; -- Attributes
							s_spr_state <= ev_x;
						
						when ev_x =>
							s_oam_soa_transfer <= '1'; -- X-Position

							if s_oam_addr = x"ff" then
								-- Letzter zu testender Sprite erreicht, kein Overflow
								s_spr_state <= wait1;
							elsif s_spr_cnt = 8 then
								-- wir haben bereits 8 Sprites gefunden, jetzt noch auf Sprite Overflow testen
								s_spr_state <= test_overflow1;
								s_oam_addr <= s_oam_addr + x"01"; -- Adresse für Y-Position
							else
								s_spr_state <= ev_y;
								s_oam_addr <= s_oam_addr + x"01"; -- Adresse für Y-Position
							end if;
							
						when test_overflow1 =>
							s_spr_state <= test_overflow2;

						when test_overflow2 =>
							if (s_next_ypos >= s_oam_q) and (s_next_ypos < s_oam_q + x"08") then
								s_spr_state <= wait1;
								s_sprite_overflow <= '1';
							elsif s_oam_addr < x"fb" then
								s_oam_addr <= s_oam_addr + x"05"; -- Adresse für Y-Position, Overflow-Bug: korrekt währe x"04"
								s_spr_state <= test_overflow1;
							else
								s_spr_state <= wait1;
							end if;
		
						when wait1 =>
							if s_cycle = 256 then
								s_spr_idx <= 0;

								if s_spr_cnt = 0 then
									s_spr_state <= disable_sprite;
								else
									s_sprite_0_visible <= s_new_sprite_0_visible;
									s_spr_state <= gf1;
									s_soa_addr <= "00000"; -- Adresse für Y-Position
								end if;
							end if;
							
						when gf1 =>
							s_spr_state <= gf2;
							s_soa_addr <= s_soa_addr + "00001"; -- Adresse für Tile Index
						
						when gf2 =>
							s_sprite_y <= s_next_ypos - s_soa_q; -- Y-Position
							s_spr_state <= gf3;
							s_soa_addr <= s_soa_addr + "00001"; -- Adresse für Attribute
						
						when gf3 =>
							s_sprite_tile <= s_soa_q; -- Tile Index
							s_spr_state <= gf4;
							s_soa_addr <= s_soa_addr + "00001"; -- Adresse für X-Position
						
						when gf4 =>
							s_spr_addr <= "000" & s_next_tile_addr;
							s_spr_state <= ftl1;
							s_sprites(s_spr_idx).palette <= s_soa_q(1 downto 0); -- Attribute
							s_sprites(s_spr_idx).priority <= s_soa_q(5);
							s_sprite_flip_horizontal <= s_soa_q(6);
							
						when ftl1 =>
							s_spr_state <= ftl2;
							s_sprites(s_spr_idx).x <= s_soa_q; -- X-Position
							
						when ftl2 =>
							s_sprites(s_spr_idx).tile_low <= s_tile_data;
							s_spr_addr(3) <= '1'; -- +8 Bytes
							s_spr_state <= fth1;
							
						when fth1 =>
							s_oam_addr <= x"00";
							s_spr_state <= fth2;
							
						when fth2 =>
							s_sprites(s_spr_idx).tile_high <= s_tile_data;
							s_sprites(s_spr_idx).enabled <= '1';
						
							if s_next_spr_idx = 8 then
								s_spr_state <= wait2;
							else
								s_spr_idx <= s_next_spr_idx;
							
								if s_next_spr_idx = s_spr_cnt then
									s_spr_state <= disable_sprite;
								else
									s_spr_state <= gf1;
									s_soa_addr <= s_soa_addr + "00001"; -- Adresse für Y-Position
								end if;
							end if;
							
						when disable_sprite =>
							s_sprites(s_spr_idx).enabled <= '0';
						
							if s_next_spr_idx = 8 then
								s_spr_state <= wait2;
							else
								s_spr_idx <= s_next_spr_idx;
							end if;
							
						when wait2 =>
							if s_cycle = 340 then
								if s_shortcut_state then
									s_spr_state <= clear1;
									s_soa_addr <= "00000";
								else
									s_spr_state <= idle;
								end if;
							end if;

					end case;
				end if;
			end if;
		end if;
	end process;
	
	-- VBlank
	
	process (i_clk)
	begin
		if rising_edge(i_clk) then
			if s_clk_enable = '1' then
				if i_reset_n = '0' then
					s_vblank <= '0';
				elsif (s_line = 261) and (s_cycle = 1) then
					s_vblank <= '0';
				elsif (s_io_state = ppustatus) and (s_io_cycle = 1) then
					s_vblank <= '0'; -- VBlank zurücksetzen wenn PPUSTATUS gelesen wird
				elsif (s_line = 241) and (s_cycle = 1) then
					s_vblank <= '1';
				end if;
			end if;
		end if;
	end process;

	-- Sprite 0 Hit
	
	process (i_clk)
	begin
		if rising_edge(i_clk) then
			if s_clk_enable = '1' then
				s_sprite_0_trigger <= false;
			
				if i_reset_n = '0' then
					s_sprite_0_hit <= '0';
				else
					if s_sprite_0_trigger then
						s_sprite_0_hit <= '1';
					end if;
				
					if s_visible_line and (s_cycle >= 1) and (s_cycle < 256) then -- Es ist Absicht, dass hier nicht von 1 - 256 gegangen wird
						if s_sprite_0_visible and (s_sprites(0).pixel /= "00") and (s_background_pixel /= "00") then
							s_sprite_0_trigger <= true;
						end if;
					elsif (s_line = 261) and (s_cycle = 1) then
						s_sprite_0_hit <= '0';
					end if;
				end if;
			end if;
		end if;
	end process;
	
	-- Ausgabe an Framebuffer
	
	process (i_clk)
	begin
		if rising_edge(i_clk) then
			if s_clk_enable = '1' then
				if i_reset_n = '0' then
					s_out_addr <= x"0000";
				elsif not s_visible_line then
					s_out_addr <= x"0000";
				elsif s_render then
					s_out_addr <= s_out_addr + x"0001";
				end if;
			end if;
		end if;
	end process;
	
	s_winning_sprite <= s_sprites(0) when s_sprites(0).pixel /= "00"
	                    else s_sprites(1) when s_sprites(1).pixel /= "00"
						 	  else s_sprites(2) when s_sprites(2).pixel /= "00"
							  else s_sprites(3) when s_sprites(3).pixel /= "00"
							  else s_sprites(4) when s_sprites(4).pixel /= "00"
							  else s_sprites(5) when s_sprites(5).pixel /= "00"
							  else s_sprites(6) when s_sprites(6).pixel /= "00"
							  else s_sprites(7) when s_sprites(7).pixel /= "00"
							  else NULL_SPRITE;
	
	s_palette_index <= '1' & s_winning_sprite.palette & s_winning_sprite.pixel when (s_winning_sprite.pixel /= "00") and (s_winning_sprite.priority = '0')
	                   else '0' & s_background_palette_index & s_background_pixel when (s_background_pixel /= "00")
							 else '1' & s_winning_sprite.palette & s_winning_sprite.pixel when (s_winning_sprite.pixel /= "00")
							 else "00000";

	s_sprite_top <= x"ff" when s_oam_q = x"ff" else s_oam_q + x"01";
	s_sprite_line_test_width <= x"08" when s_big_sprites = '0' else x"10";
	s_sprite_line_lower_test <= s_next_ypos >= s_sprite_top;
	s_sprite_line_upper_test <= s_next_ypos < (s_sprite_top + s_sprite_line_test_width);
	s_sprite_online <= s_sprite_line_lower_test and s_sprite_line_upper_test;

	s_inner_tile_pos <= not s_sprite_y(3 downto 0) when s_soa_q(7) = '1' else s_sprite_y(3 downto 0); -- vertical flip
	s_next_tile_addr <= s_sprite_half & s_sprite_tile & '0' & s_inner_tile_pos(2 downto 0) when s_big_sprites = '0'
	                    else s_sprite_tile(0) & s_sprite_tile(7 downto 1) & s_inner_tile_pos(3) & '0' & s_inner_tile_pos(2 downto 0);
							 
	s_tile_data <= reverse_vector(s_video_data) when s_sprite_flip_horizontal = '1' else s_video_data;
	s_next_spr_idx <= s_spr_idx + 1;
						 
	s_video_addr <= s_spr_addr when s_visible_or_prescan_line and s_hblank_cycle and s_enable_rendering
	                else s_bkg_addr when s_visible_or_prescan_line and not s_hblank_cycle and s_enable_rendering
						 else '0' & s_vram_addr_v;
						 
	s_xpos <= std_logic_vector(to_unsigned(s_cycle - 1, 8)) when s_render else x"ff";
	s_next_ypos <= x"00" when s_line >= 239 else std_logic_vector(to_unsigned(s_line, 8)) + x"01";
	s_out_write_enable <= '1' when s_visible_line and s_render else '0';
	s_render <= (s_cycle >= 1) and (s_cycle < 257);
	s_visible_line <= s_line < 240;
	s_visible_or_prescan_line <= s_visible_line or (s_line = 261);
	s_hblank_cycle <= (s_cycle > 256) and (s_cycle < 321);
	s_vram_bkg_inc <= std_logic_vector(to_unsigned(s_cycle - 1, 3)) = "110";
	s_out_data <= s_palette_color and 6x"30" when s_greyscale = '1' else s_palette_color;
	s_oam_write_enable <= '1' when s_perform_oam_write_access else '0';
	s_perform_oam_write_access <= (s_io_state = oamdata_write) and (s_io_cycle = 1);
	s_perform_oam_access <= s_perform_oam_write_access;
	s_enable_rendering <= (s_enable_background = '1') or (s_enable_sprites = '1');
	s_shortcut_state <= s_frame_latch and (s_line = 261) and s_enable_rendering;
	
	s_palette_quadrant <= s_vram_addr_v(6) & s_vram_addr_v(1);
	s_tile_addr <= "0010" & s_vram_addr_v(11 downto 0);
	s_attr_addr <= "0010" & s_vram_addr_v(11 downto 10) & "1111" & s_vram_addr_v(9 downto 7) & s_vram_addr_v(4 downto 2);
	s_tile_lo_addr <= "000" & s_background_half & s_tile_index & '0' & s_vram_addr_v(14 downto 12);
	s_tile_hi_addr <= "000" & s_background_half & s_tile_index & '1' & s_vram_addr_v(14 downto 12);
	s_vassign <= (s_cycle >= 280) and (s_cycle <= 304) and (s_line = 261);
	s_background_pixel <= s_th_q(s_fine_scroll_x) & s_tl_q(s_fine_scroll_x) when (s_enable_background = '1') and ((s_render_first_bkg_col = '1') or (s_xpos(7 downto 3) /= "00000")) else "00";
	s_background_palette_index <= s_bh_q(s_fine_scroll_x) & s_bl_q(s_fine_scroll_x);
	s_palette_color <= s_palette_mem(to_pal_idx(s_palette_index))(5 downto 0);
	s_palette_access <= s_vram_addr_v(14 downto 8) = 7x"3f";
	s_clk_enable <= '1' when s_clk_divider = 0 else '0';
	
	o_phi0 <= s_clk_enable;
	o_q <= s_q;
	o_int_n <= s_vblank nand s_enable_nmi;
	o_vga_addr <= s_out_addr;
	o_vga_data <= s_out_data;
	o_vga_write_enable <= s_out_write_enable;

end architecture;
