defmodule Parentesis do
  @moduledoc """
  Secuencias de paréntesis balanceados con profundidad máxima (Problema 4 del Parcial 2).

  Para `n` pares de paréntesis genera todas las cadenas balanceadas con `n` caracteres `(` y `n` caracteres `)`
  en las que ningún prefijo tiene más de `p` paréntesis abiertos pendientes de cerrar. El generador es recursivo
  y perezoso: produce un `Stream` de soluciones que se escriben a medida que se consumen.

  ## Entradas

    * `parametros.csv` - registros `n;profundidad_max` (la primera línea es un comentario/encabezado).
    * `propuestas.txt` - cadenas por verificar, una por línea, con el formato `n;p;cadena`.

  ## Proceso

    1. Verifica cada propuesta con una función recursiva (`validar_propuestas/3` y `/11`).
    2. Stream infinito `n = 1, 2, 3...` con `p = n`: cuenta las soluciones sin guardarlas y se detiene en el
       primer `n` cuyo total es mayor o igual a 1000.
    3. Para cada par `(n, p)` de `parametros.csv` consume el Stream de soluciones, escribiéndolas y contándolas.
    4. Obtiene solo la primera solución de `n = 18`, `p = 18` con `Enum.take(1)` (sin calcular las demás).

  ## Salidas

    * `verificacion_parentesis.txt` - un mapa con el resultado de cada propuesta.
    * `secuencia_parentesis.csv` - encabezado `n;total` y una fila por cada `n` calculado.
    * `parentesis_n<N>_p<P>.txt` - una solución por línea y `Total: <cantidad>` al final.
    * `primera_n18_p18.txt` - la primera solución para `n = 18`, `p = 18`.
    * Por pantalla: cada solución, el total por par y mensajes de progreso.

  Todos los archivos se leen y se escriben junto al script (`__DIR__`).
  """
   @doc """
   Punto de entrada: ejecuta, en orden, la verificación de propuestas, el Stream infinito y la generación por parámetros.

   ## Entradas

     * Ninguna por argumento. Lee `propuestas.txt` y `parametros.csv` desde la carpeta del script.

   ## Proceso

     * Limpia `verificacion_parentesis.txt` y escribe en él el resultado de validar cada propuesta.
     * Ejecuta `stream_infinito/0`.
     * Por cada registro `n;p` de `parametros.csv` consume el Stream de soluciones, las imprime, las escribe y cuenta el total.
     * Obtiene únicamente la primera solución para `n = 18`, `p = 18`.

   ## Salida

     * Archivos de salida y mensajes por pantalla. El valor de retorno no se utiliza.
   """
   def main do

   # Rutas dinámicas
# Rutas de entrada y del archivo de verificación, relativas a la carpeta del script.
ruta = Path.join(__DIR__, "parametros.csv")
ruta_propuestas = Path.join(__DIR__, "propuestas.txt")
ruta_verificacion = Path.join(__DIR__, "verificacion_parentesis.txt")

# Archivos
# Streams perezosos de líneas: no se lee nada hasta que se consumen.
archivo = File.stream!(ruta)
archivo_propuestas = File.stream!(ruta_propuestas)

# Limpiar el archivo de verificación
# Crea o vacía el archivo de verificación antes de agregar resultados.
File.write!(ruta_verificacion, "")

# Procesar las propuestas
# Cada línea 'n;p;cadena' se convierte en la tupla {n, p, cadena}.
archivo_propuestas
|> Stream.map(fn linea ->
  [n, p, parentesis] =
    linea
    |> String.trim()
    |> String.split(";")

  {String.to_integer(n), String.to_integer(p), parentesis}
end)
# Valida cada propuesta y agrega su resultado al archivo (modo :append).
|> Enum.each(fn {n, p, parentesis} ->
  # Mapa con: valida, errores, primer_prefijo y max_profundidad.
  propuesta_validada = validar_propuestas(n, p, parentesis)

  File.write!(
    ruta_verificacion,
    "#{inspect(propuesta_validada)}\n",
    [:append]
  )
end)

# Final del procesamiento de propuestas
  # Stream infinito: total de soluciones para n = 1, 2, 3... hasta llegar a 1000 (se escribe en secuencia_parentesis.csv).
  IO.puts("ANTES DEL STREAM INFINITO")
  stream_infinito()
  IO.puts("DESPUÉS DEL STREAM INFINITO")

  # Procesa parametros.csv: se omite la primera línea (comentario/encabezado) y cada registro
  # 'n;p' se convierte en la tupla {n, p}.
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
    # Stream perezoso de soluciones: todavía no se genera ninguna.
    solucion = hacer_parentesis(n, p)

    # Un archivo de salida por cada par (n, p).
    ruta_salida = Path.join(__DIR__, "parentesis_n#{n}_p#{p}.txt")

    # Crear o limpiar el archivo
    File.write!(ruta_salida, "")

    # Al consumir el Stream, cada solución se imprime, se escribe en el archivo y se cuenta,
    # sin guardarlas en una lista.
    total =
      Enum.reduce(solucion, 0, fn s, contador ->
        IO.puts(s)
        File.write!(ruta_salida, s <> "\n", [:append])
        contador + 1
      end)

    # Muestra por pantalla el total del par.
    IO.puts("El total es: #{total}")

    # Escribir el total al final del archivo
    # Agrega el total al final del archivo.
    File.write!(ruta_salida, "Total: #{total}\n", [:append])
  end)

   # Obtener únicamente la primera solución para n=18 y p=18
  IO.puts("ANTES DE LA PRIMERA SOLUCIÓN")

  # Enum.take(1) pide solo el primer elemento: el Stream se detiene sin generar las demás soluciones.
  primera =
    hacer_parentesis(18, 18)
    |> Enum.take(1)

  IO.puts("DESPUÉS DE LA PRIMERA SOLUCIÓN")

  ruta_primera =
    Path.join(__DIR__, "primera_n18_p18.txt")

  # 'primera' es una lista con, a lo sumo, un elemento.
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
@doc """
Verifica una cadena propuesta de forma recursiva (punto de entrada de la validación).

## Entradas

  * `n`: cantidad de pares esperada.
  * `p`: profundidad máxima permitida.
  * `parentesis`: cadena propuesta (string).

## Proceso

  * Convierte la cadena en lista de caracteres y comprueba que su longitud sea `2n`.
  * Llama a `validar_propuestas/11` con los acumuladores en cero para revisar carácter por carácter.

## Salida

  * Mapa `%{valida, errores, primer_prefijo, max_profundidad}` (ver `validar_propuestas/11`).
"""
def validar_propuestas(n, p, parentesis) do

  # Separa la cadena en una lista de caracteres.
  caracteres = String.graphemes(parentesis)

  # Primera comprobación: la longitud debe ser 2n.
  errores =
    if length(caracteres) != 2 * n do
      [:longitud_incorrecta]
    else
      []
    end

  validar_propuestas(
    # Inicia la recursión con los contadores en cero: abiertos, cerrados, índice y abiertos actuales;
    # luego errores, profundidad máxima, prefijo vacío y primer prefijo problemático (nil).
    n, p, caracteres,
    0, 0, 0, 0,
    errores, 0, "", nil
  )

end


# Caso base
@doc """
Recorre recursivamente los caracteres de una propuesta acumulando contadores y errores (11 argumentos).

## Entradas

  * `n`, `p`: pares esperados y profundidad máxima.
  * lista de caracteres restantes (`[]` = caso base; `[cabeza | cola]` = caso recursivo).
  * `abiertos`, `cerrados`: cantidad de `(` y `)` leídos.
  * `indice`: posición actual.
  * `abiertos_actuales`: paréntesis abiertos sin cerrar (profundidad actual).
  * `errores`: motivos detectados (más reciente primero).
  * `max_profundidad`: mayor profundidad alcanzada.
  * `prefijo`: texto leído hasta ahora.
  * `primer_prefijo`: primer prefijo problemático o `nil`.

## Proceso

  * Apertura: aumenta la profundidad y marca `:profundidad_excedida` si supera `p`.
  * Cierre con apertura pendiente: disminuye la profundidad.
  * Cierre sin apertura pendiente: marca `:cierre_sin_apertura`.
  * Otro carácter: marca `:caracter_no_permitido`.
  * Caso base: si `abiertos` y `cerrados` difieren marca `:balance_incorrecto` y arma el resultado.

## Salida

  * Mapa con `:valida` (booleano), `:errores` (sin repetidos, en orden de detección), `:primer_prefijo` y `:max_profundidad`.
"""
def validar_propuestas(
      _n, _p, [],
      abiertos, cerrados, _indice, _abiertos_actuales,
      errores, max_profundidad, prefijo, primer_prefijo
    ) do

  errores =
    # Si las cantidades de ( y ) no coinciden, se agrega :balance_incorrecto.
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

  # Resultado de la validación.
  %{
    valida: errores == [],
    # Sin repetidos y en el orden en que se detectaron los motivos.
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

  # Prefijo leído hasta este carácter (incluido).
  nuevo_prefijo = prefijo <> cabeza

  cond do

    # Apertura de paréntesis
    cabeza == "(" ->

      # Al abrir, la profundidad actual aumenta en uno.
      nueva_profundidad = abiertos_actuales + 1

      nuevos_errores =
        # Si supera la profundidad máxima p se registra :profundidad_excedida.
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
        # Actualiza la mayor profundidad alcanzada.
        max(max_profundidad, nueva_profundidad),
        nuevo_prefijo, nuevo_primer_prefijo
      )


    # Cierre válido
    cabeza == ")" and abiertos_actuales > 0 ->

      validar_propuestas(
        n, p, cola,
        abiertos, cerrados + 1, indice + 1,
        # Al cerrar, la profundidad actual disminuye en uno.
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
        # Hay un ')' sin '(' pendiente.
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
        # Carácter distinto de '(' y ')'.
        [:caracter_no_permitido | errores],
        max_profundidad,
        nuevo_prefijo, nuevo_primer_prefijo
      )

  end
end


@doc """
Genera el Stream infinito `n = 1, 2, 3...` (con `p = n`) y escribe el total de soluciones hasta alcanzar 1000.

## Entradas

  * Ninguna por argumento.

## Proceso

  * Abre `secuencia_parentesis.csv` y escribe el encabezado `n;total`.
  * Crea un Stream infinito de enteros y lo transforma de forma perezosa en `{n, total}` contando las soluciones del generador sin guardarlas.
  * Con `Enum.reduce_while/3` escribe cada fila y se detiene en el primer `n` con `total >= 1000`, incluyéndolo.
  * El siguiente valor (`n = 9`) nunca se calcula porque el Stream es perezoso.

## Salida

  * Archivo `secuencia_parentesis.csv` (con el ejemplo del enunciado termina en `8;1430`).
"""
def stream_infinito() do
  # Archivo de salida del CSV.
  ruta = Path.join(__DIR__, "secuencia_parentesis.csv")

  # Se abre en modo escritura (reemplaza el contenido) y se escribe fila a fila.
  archivo = File.open!(ruta, [:write])
  # Encabezado del CSV.
  IO.write(archivo, "n;total\n")

  # Stream infinito de enteros 1, 2, 3, ... (nada se calcula hasta consumirlo).
  stream = Stream.iterate(1, fn x -> x + 1 end)

  stream
  # Para cada n (con p = n) cuenta las soluciones del generador sin guardarlas.
  |> Stream.map(fn s ->
    total = hacer_parentesis(s, s)
      |> Enum.count()

    {s, total}
  end)
  # Consume el Stream elemento a elemento; el acumulador es el archivo abierto.
  |> Enum.reduce_while(archivo, fn {n, total}, acumulador ->

    # Escribe la fila 'n;total' apenas se calcula.
    IO.write(acumulador, "#{n};#{total}\n")

    # Al alcanzar 1000 soluciones se detiene (n = 8 con 1430); n = 9 nunca se calcula.
    if total >= 1000 do
      {:halt, acumulador}
    else
      {:cont, acumulador}
    end

  end)

  # Cierra el archivo de salida.
  File.close(archivo)
end



  @doc """
  Crea el Stream perezoso con todas las cadenas balanceadas de `n` pares y profundidad máxima `p`.

  ## Entradas

    * `n`: cantidad de pares (>= 1).
    * `p`: profundidad máxima (1 <= p <= n).

  ## Proceso

    * Llama a `generar/5` con la cadena vacía y los contadores en cero.

  ## Salida

    * `Stream` de strings; no se genera ninguna solución hasta que se consume.
  """
  def hacer_parentesis(n, p) do
    generar(n, p, "", 0, 0)
  end

  @doc """
  Generador recursivo y perezoso de cadenas de paréntesis balanceados.

  ## Entradas

    * `n`, `p`: pares y profundidad máxima.
    * `string`: prefijo construido hasta ahora.
    * `abiertos`, `cerrados`: cantidad de `(` y `)` ya usados.

  ## Proceso

    * Caso base: con `n` abiertos y `n` cerrados el prefijo es una solución completa.
    * Rama 1: agrega `(` solo si `abiertos < n` y `abiertos - cerrados < p` (respeta pares y profundidad).
    * Rama 2: agrega `)` solo si `cerrados < abiertos` (nunca se cierra de más).
    * Las ramas se unen con `Stream.concat/1`: se prueba primero `(` y luego `)`. `Stream.flat_map/2` posterga la recursión hasta que se consume.

  ## Salida

    * `Stream` de strings con las soluciones, en el orden resultante de intentar primero `(` y luego `)`.
  """
  def generar(n, p, string, abiertos, cerrados) do
  cond do
    # Caso base: cadena completa; se emite como un Stream de un solo elemento.
    abiertos == n and cerrados == n ->
      Stream.map([string], fn x -> x end)

    true ->
      # Rama 1: agregar '(' si quedan por abrir y no se supera la profundidad p.
      abrir =
        if abiertos < n and abiertos - cerrados < p do
          # flat_map posterga la llamada recursiva hasta que se consume el Stream (evaluación perezosa).
          Stream.flat_map([:abrir], fn _ ->
            generar(n, p, string <> "(", abiertos + 1, cerrados)
          end)
        else
          []
        end

      # Rama 2: agregar ')' solo si hay algún '(' sin cerrar.
      cerrar =
        if cerrados < abiertos do
          Stream.flat_map([:cerrar], fn _ ->
            generar(n, p, string <> ")", abiertos, cerrados + 1)
          end)
        else
          []
        end

      # Orden de salida: primero las soluciones que abren, después las que cierran.
      Stream.concat([abrir, cerrar])
  end
end
end

# Punto de entrada: al ejecutar 'elixir parentesis.exs' se llama a main/0.
Parentesis.main()
