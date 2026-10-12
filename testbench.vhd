
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity testbench is
end testbench;

architecture sim of testbench is
  constant T : time := 20 ns;          -- 50 MHz
  constant N : integer := 8;           -- ciclos por "medio segundo" simulado
  signal clk  : std_logic := '0';
  signal key  : std_logic_vector(1 downto 0) := "11";
  signal sw   : std_logic_vector(2 downto 0) := "000";
  signal ledr : std_logic_vector(0 downto 0);
  signal done : boolean := false;

  function expected(idx : integer) return string is
  begin
    case idx is
      when 0 => return "101110";        -- A  .-
      when 1 => return "1110101010";    -- B  -...
      when 2 => return "111010111010";  -- C  -.-.
      when 3 => return "11101010";      -- D  -..
      when 4 => return "10";            -- E  .
      when 5 => return "1010111010";    -- F  ..-.
      when 6 => return "1110111010";    -- G  --.
      when others => return "10101010"; -- H  ....
    end case;
  end function;
begin
  clk <= not clk after T/2 when not done;

  dut : entity work.morse_top
    generic map (HALF_CYCLES => N)
    port map (CLOCK_50 => clk, KEY => key, SW => sw, LEDR => ledr);

  stimulus : process
    procedure test_letter(idx : integer) is
      constant exp : string := expected(idx);
    begin
      sw <= std_logic_vector(to_unsigned(idx, 3));
      wait for 3*T;
      key(1) <= '0';                            -- presionar KEY1
      wait until ledr(0) = '1' for 20*T;        -- esperar flanco con la tecla pulsada
      key(1) <= '1';
      assert ledr(0) = '1' report "Letra " & integer'image(idx) & ": el LED nunca se encendio" severity failure;
      wait for (N/2)*T;                         -- muestrear a mitad de cada ranura
      for i in exp'range loop
        if exp(i) = '1' then
          assert ledr(0) = '1' report "Letra " & integer'image(idx) & ": ranura " & integer'image(i) & " debia ser 1" severity failure;
        else
          assert ledr(0) = '0' report "Letra " & integer'image(idx) & ": ranura " & integer'image(i) & " debia ser 0" severity failure;
        end if;
        wait for N*T;
      end loop;
      wait for 3*N*T;
      assert ledr(0) = '0' report "Letra " & integer'image(idx) & ": el LED debia quedar apagado" severity failure;
      report "Letra " & integer'image(idx) & " OK (" & exp & ")";
    end procedure;
  begin
    -- Reset inicial
    key(0) <= '0'; wait for 4*T; key(0) <= '1'; wait for 4*T;
    assert ledr(0) = '0' report "LED debe estar apagado tras reset" severity failure;

    -- 1) Las 8 letras
    for k in 0 to 7 loop
      test_letter(k);
    end loop;

    -- 2) Reset asincrono a mitad de una letra (D)
    sw <= "011"; wait for 3*T;
    key(1) <= '0';
    wait until ledr(0) = '1' for 20*T;
    key(1) <= '1';
    wait for 2*N*T;
    key(0) <= '0'; wait for T/4;            -- reset asincrono (entre flancos)
    assert ledr(0) = '0' report "Reset asincrono no apago el LED" severity failure;
    wait for 3*T; key(0) <= '1';
    wait for 4*N*T;
    assert ledr(0) = '0' report "El LED debe seguir apagado tras el reset" severity failure;
    report "Reset asincrono OK";

    -- 3) Recuperacion: letra E despues del reset
    test_letter(4);

    -- 4) KEY1 mantenido: no debe repetir la letra
    sw <= "100"; wait for 3*T;
    key(1) <= '0';
    wait until ledr(0) = '1' for 20*T;
    wait for 6*N*T;
    assert ledr(0) = '0' report "Pulsacion larga repitio la letra" severity failure;
    key(1) <= '1';
    report "Pulsacion larga OK";

    report "=== TODAS LAS PRUEBAS PASARON ===";
    done <= true;
    wait;
  end process;
end sim;
