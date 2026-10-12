-- Contador de medio segundo.
-- Genera un pulso "tick" de un ciclo de reloj cada HALF_CYCLES ciclos.
-- Con CLOCK_50 (50 MHz): 0.5 s = 25_000_000 ciclos.
library ieee;
use ieee.std_logic_1164.all;

entity half_sec_counter is
  generic ( HALF_CYCLES : positive := 25_000_000 );
  port (
    clk, resetn : in  std_logic;
    clr         : in  std_logic;   -- '1' reinicia la cuenta (sincrono)
    tick        : out std_logic
  );
end half_sec_counter;

architecture rtl of half_sec_counter is
  signal count : integer range 0 to HALF_CYCLES - 1 := 0;
begin
  process (clk, resetn)
  begin
    if resetn = '0' then
      count <= 0;
    elsif rising_edge(clk) then
      if clr = '1' or count = HALF_CYCLES - 1 then
        count <= 0;
      else
        count <= count + 1;
      end if;
    end if;
  end process;

  tick <= '1' when (count = HALF_CYCLES - 1 and clr = '0') else '0';
end rtl;

library ieee;
use ieee.std_logic_1164.all;

entity letter_select is
  port (
    sw      : in  std_logic_vector(2 downto 0);
    pattern : out std_logic_vector(3 downto 0);
    length  : out std_logic_vector(2 downto 0)
  );
end letter_select;

architecture rtl of letter_select is
begin
  process (sw)
  begin
    case sw is
      when "000"  => pattern <= "0100"; length <= "010";  -- A  .-
      when "001"  => pattern <= "1000"; length <= "100";  -- B  -...
      when "010"  => pattern <= "1010"; length <= "100";  -- C  -.-.
      when "011"  => pattern <= "1000"; length <= "011";  -- D  -..
      when "100"  => pattern <= "0000"; length <= "001";  -- E  .
      when "101"  => pattern <= "0010"; length <= "100";  -- F  ..-.
      when "110"  => pattern <= "1100"; length <= "011";  -- G  --.
      when others => pattern <= "0000"; length <= "100";  -- H  ....
    end case;
  end process;
end rtl;
-- Registro de desplazamiento de 4 bits con carga paralela.
-- q(3) es el simbolo actual (0 = punto, 1 = raya).
library ieee;
use ieee.std_logic_1164.all;

entity morse_shift_reg is
  port (
    clk, resetn : in  std_logic;
    load        : in  std_logic;
    enable      : in  std_logic;
    data        : in  std_logic_vector(3 downto 0);
    q           : out std_logic_vector(3 downto 0)
  );
end morse_shift_reg;

architecture rtl of morse_shift_reg is
  signal r : std_logic_vector(3 downto 0);
begin
  process (clk, resetn)
  begin
    if resetn = '0' then
      r <= (others => '0');
    elsif rising_edge(clk) then
      if load = '1' then
        r <= data;
      elsif enable = '1' then
        r <= r(2 downto 0) & '0';
      end if;
    end if;
  end process;
  q <= r;
end rtl;
-- Contador descendente: simbolos que faltan por transmitir.
-- last = '1' cuando falta solo el simbolo actual.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity length_counter is
  port (
    clk, resetn : in  std_logic;
    load        : in  std_logic;
    enable      : in  std_logic;
    data        : in  std_logic_vector(2 downto 0);
    last        : out std_logic
  );
end length_counter;

architecture rtl of length_counter is
  signal c : unsigned(2 downto 0);
begin
  process (clk, resetn)
  begin
    if resetn = '0' then
      c <= (others => '0');
    elsif rising_edge(clk) then
      if load = '1' then
        c <= unsigned(data);
      elsif enable = '1' and c /= 0 then
        c <= c - 1;
      end if;
    end if;
  end process;
  last <= '1' when c = 1 else '0';
end rtl;
-- FSM de control del codificador Morse (Parte IV).
-- Temporizacion: punto = 1 tick (0.5 s) encendido, raya = 3 ticks (1.5 s),
-- y 1 tick (0.5 s) apagado entre simbolos.
--
--  IDLE --start--> LOAD --> ON1 --tick,punto--> GAP
--                           ON1 --tick,raya --> ON2 --tick--> ON3 --tick--> GAP
--  GAP --tick,ultimo--> IDLE        GAP --tick,no ultimo--> ON1
library ieee;
use ieee.std_logic_1164.all;

entity morse_fsm is
  port (
    clk, resetn : in  std_logic;
    start       : in  std_logic;  -- pulso de 1 ciclo (KEY1 presionado)
    tick        : in  std_logic;  -- pulso cada 0.5 s
    dash        : in  std_logic;  -- simbolo actual es raya
    last        : in  std_logic;  -- es el ultimo simbolo
    load        : out std_logic;  -- carga registro y contador de longitud
    shift_en    : out std_logic;  -- avanza al siguiente simbolo
    cnt_clr     : out std_logic;  -- reinicia contador de 0.5 s
    led         : out std_logic
  );
end morse_fsm;

architecture behavior of morse_fsm is
  type state_type is (S_IDLE, S_LOAD, S_ON1, S_ON2, S_ON3, S_GAP);
  signal y_Q, y_D : state_type;
begin
  -- Tabla de estados (logica de siguiente estado)
  state_table : process (y_Q, start, tick, dash, last)
  begin
    y_D <= y_Q;
    case y_Q is
      when S_IDLE =>
        if start = '1' then y_D <= S_LOAD; end if;
      when S_LOAD =>
        y_D <= S_ON1;
      when S_ON1 =>
        if tick = '1' then
          if dash = '1' then y_D <= S_ON2; else y_D <= S_GAP; end if;
        end if;
      when S_ON2 =>
        if tick = '1' then y_D <= S_ON3; end if;
      when S_ON3 =>
        if tick = '1' then y_D <= S_GAP; end if;
      when S_GAP =>
        if tick = '1' then
          if last = '1' then y_D <= S_IDLE; else y_D <= S_ON1; end if;
        end if;
    end case;
  end process;

  -- Flip-flops de estado, reset asincrono activo en bajo (KEY0)
  state_ffs : process (clk, resetn)
  begin
    if resetn = '0' then
      y_Q <= S_IDLE;
    elsif rising_edge(clk) then
      y_Q <= y_D;
    end if;
  end process;

  -- Salidas
  led      <= '1' when (y_Q = S_ON1 or y_Q = S_ON2 or y_Q = S_ON3) else '0';
  load     <= '1' when y_Q = S_LOAD else '0';
  cnt_clr  <= '1' when (y_Q = S_IDLE or y_Q = S_LOAD) else '0';
  shift_en <= '1' when (y_Q = S_GAP and tick = '1') else '0';
end behavior;
-- Top-level del codificador Morse (Parte IV, Figura 5).
--   SW(2..0) : letra (000=A ... 111=H)
--   KEY(1)   : inicio (activo en bajo)
--   KEY(0)   : reset asincrono (activo en bajo)
--   LEDR(0)  : salida Morse
library ieee;
use ieee.std_logic_1164.all;

entity morse_top is
  generic ( HALF_CYCLES : positive := 25_000_000 );  -- 0.5 s a 50 MHz
  port (
    CLOCK_50 : in  std_logic;
    KEY      : in  std_logic_vector(1 downto 0);
    SW       : in  std_logic_vector(2 downto 0);
    LEDR     : out std_logic_vector(0 downto 0)
  );
end morse_top;

architecture structure of morse_top is
  signal resetn, start_pulse            : std_logic;
  signal s1, s2, s3                     : std_logic;
  signal tick, dash, last               : std_logic;
  signal load, shift_en, cnt_clr, led   : std_logic;
  signal pattern                        : std_logic_vector(3 downto 0);
  signal length                         : std_logic_vector(2 downto 0);
  signal sreg                           : std_logic_vector(3 downto 0);
begin
  resetn <= KEY(0);

  -- Sincronizador + detector de flanco para KEY1 (evita metaestabilidad y
  -- que una pulsacion larga repita la letra)
  process (CLOCK_50, resetn)
  begin
    if resetn = '0' then
      s1 <= '1'; s2 <= '1'; s3 <= '1';
    elsif rising_edge(CLOCK_50) then
      s1 <= KEY(1); s2 <= s1; s3 <= s2;
    end if;
  end process;
  start_pulse <= (not s2) and s3;

  letters : entity work.letter_select
    port map (sw => SW, pattern => pattern, length => length);

  shreg : entity work.morse_shift_reg
    port map (clk => CLOCK_50, resetn => resetn, load => load,
              enable => shift_en, data => pattern, q => sreg);
  dash <= sreg(3);

  lencnt : entity work.length_counter
    port map (clk => CLOCK_50, resetn => resetn, load => load,
              enable => shift_en, data => length, last => last);

  halfsec : entity work.half_sec_counter
    generic map (HALF_CYCLES => HALF_CYCLES)
    port map (clk => CLOCK_50, resetn => resetn, clr => cnt_clr, tick => tick);

  fsm : entity work.morse_fsm
    port map (clk => CLOCK_50, resetn => resetn, start => start_pulse,
              tick => tick, dash => dash, last => last,
              load => load, shift_en => shift_en, cnt_clr => cnt_clr, led => led);

  LEDR(0) <= led;
end structure;