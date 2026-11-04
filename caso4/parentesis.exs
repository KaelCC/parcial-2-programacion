defmodule Parentesis do
   def main do

   # Rutas dinámicas
ruta = Path.join(__DIR__, "parametros.csv")
ruta_propuestas = Path.join(__DIR__, "propuestas.txt")
ruta_verificacion = Path.join(__DIR__, "verificacion_parentesis.txt")

# Archivos
archivo = File.stream!(ruta)
archivo_propuestas = File.stream!(ruta_propuestas)

# Limpiar el archivo de verificación
File.write!(ruta_verificacion, "")

# Procesar las propuestas
archivo_propuestas
|> Stream.map(fn linea ->
  [n, p, parentesis] =
    linea
    |> String.trim()
    |> String.split(";")

  {String.to_integer(n), String.to_integer(p), parentesis}
end)
|> Enum.each(fn {n, p, parentesis} ->
  propuesta_validada = validar_propuestas(n, p, parentesis)

  File.write!(
    ruta_verificacion,
    "#{inspect(propuesta_validada)}\n",
    [:append]
  )
end)

# Final del procesamiento de propuestas
  IO.puts("ANTES DEL STREAM INFINITO")
  stream_infinito()
  IO.puts("DESPUÉS DEL STREAM INFINITO")

  archivo
  |> Stream.drop(1)
  |> Stream.map(fn linea ->
    [n, p] =
      linea
      |> String.trim()
      |> String.split(";")

    {String.to_integer(n), String.to_integer(p)}
  end)
  |> Enum.each(fn {n, p} ->
    solucion = hacer_parentesis(n, p)

    ruta_salida = Path.join(__DIR__, "parentesis_n#{n}_p#{p}.txt")

    # Crear o limpiar el archivo
    File.write!(ruta_salida, "")

    total =
      Enum.reduce(solucion, 0, fn s, contador ->
        IO.puts(s)
        File.write!(ruta_salida, s <> "\n", [:append])
        contador + 1
      end)

    IO.puts("El total es: #{total}")

    # Escribir el total al final del archivo
    File.write!(ruta_salida, "Total: #{total}\n", [:append])
  end)

   # Obtener únicamente la primera solución para n=18 y p=18
  IO.puts("ANTES DE LA PRIMERA SOLUCIÓN")

  primera =
    hacer_parentesis(18, 18)
    |> Enum.take(1)

  IO.puts("DESPUÉS DE LA PRIMERA SOLUCIÓN")

  ruta_primera =
    Path.join(__DIR__, "primera_n18_p18.txt")

  case primera do
    [solucion] ->
      File.write!(ruta_primera, solucion <> "\n")
      IO.puts("Primera solución para n=18, p=18: #{solucion}")

    [] ->
      IO.puts("No se encontraron soluciones.")
  end


#final main

end


# Función inicial
def validar_propuestas(n, p, parentesis) do

  caracteres = String.graphemes(parentesis)

  errores =
    if length(caracteres) != 2 * n do
      [:longitud_incorrecta]
    else
      []
    end

  validar_propuestas(
    n, p, caracteres,
    0, 0, 0, 0,
    errores, 0, "", nil
  )

end


# Caso base
def validar_propuestas(
      _n, _p, [],
      abiertos, cerrados, _indice, _abiertos_actuales,
      errores, max_profundidad, prefijo, primer_prefijo
    ) do

  errores =
    if abiertos != cerrados do
      [:balance_incorrecto | errores]
    else
      errores
    end

  primer_prefijo =
    if abiertos != cerrados and primer_prefijo == nil do
      prefijo
    else
      primer_prefijo
    end

  %{
    valida: errores == [],
    errores: Enum.reverse(Enum.uniq(errores)),
    primer_prefijo: primer_prefijo,
    max_profundidad: max_profundidad
  }

end


# Caso recursivo
def validar_propuestas(
      n, p, [cabeza | cola],
      abiertos, cerrados, indice, abiertos_actuales,
      errores, max_profundidad, prefijo, primer_prefijo
    ) do

  nuevo_prefijo = prefijo <> cabeza

  cond do

    # Apertura de paréntesis
    cabeza == "(" ->

      nueva_profundidad = abiertos_actuales + 1

      nuevos_errores =
        if nueva_profundidad > p do
          [:profundidad_excedida | errores]
        else
          errores
        end

      nuevo_primer_prefijo =
        if nueva_profundidad > p and primer_prefijo == nil do
          nuevo_prefijo
        else
          primer_prefijo
        end

      validar_propuestas(
        n, p, cola,
        abiertos + 1, cerrados, indice + 1,
        nueva_profundidad,
        nuevos_errores,
        max(max_profundidad, nueva_profundidad),
        nuevo_prefijo, nuevo_primer_prefijo
      )


    # Cierre válido
    cabeza == ")" and abiertos_actuales > 0 ->

      validar_propuestas(
        n, p, cola,
        abiertos, cerrados + 1, indice + 1,
        abiertos_actuales - 1,
        errores, max_profundidad,
        nuevo_prefijo, primer_prefijo
      )


    # Cierre sin apertura
    cabeza == ")" ->

      nuevo_primer_prefijo =
        if primer_prefijo == nil do
          nuevo_prefijo
        else
          primer_prefijo
        end

      validar_propuestas(
        n, p, cola,
        abiertos, cerrados + 1, indice + 1,
        abiertos_actuales,
        [:cierre_sin_apertura | errores],
        max_profundidad,
        nuevo_prefijo, nuevo_primer_prefijo
      )


    # Caracteres diferentes de ( y )
    true ->

      nuevo_primer_prefijo =
        if primer_prefijo == nil do
          nuevo_prefijo
        else
          primer_prefijo
        end

      validar_propuestas(
        n, p, cola,
        abiertos, cerrados, indice + 1,
        abiertos_actuales,
        [:caracter_no_permitido | errores],
        max_profundidad,
        nuevo_prefijo, nuevo_primer_prefijo
      )

  end
end


def stream_infinito() do
  ruta = Path.join(__DIR__, "secuencia_parentesis.csv")

  archivo = File.open!(ruta, [:write])
  IO.write(archivo, "n;total\n")

  stream = Stream.iterate(1, fn x -> x + 1 end)

  stream
  |> Stream.map(fn s ->
    total = hacer_parentesis(s, s)
      |> Enum.count()

    {s, total}
  end)
  |> Enum.reduce_while(archivo, fn {n, total}, acumulador ->

    IO.write(acumulador, "#{n};#{total}\n")

    if total >= 1000 do
      {:halt, acumulador}
    else
      {:cont, acumulador}
    end

  end)

  File.close(archivo)
end



  def hacer_parentesis(n, p) do
    generar(n, p, "", 0, 0)
  end

  def generar(n, p, string, abiertos, cerrados) do
  cond do
    abiertos == n and cerrados == n ->
      Stream.map([string], fn x -> x end)

    true ->
      abrir =
        if abiertos < n and abiertos - cerrados < p do
          Stream.flat_map([:abrir], fn _ ->
            generar(n, p, string <> "(", abiertos + 1, cerrados)
          end)
        else
          []
        end

      cerrar =
        if cerrados < abiertos do
          Stream.flat_map([:cerrar], fn _ ->
            generar(n, p, string <> ")", abiertos, cerrados + 1)
          end)
        else
          []
        end

      Stream.concat([abrir, cerrar])
  end
end
end

Parentesis.main()
