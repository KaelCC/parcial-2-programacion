defmodule Parentesis do
  @moduledoc """
  Versión interactiva (borrador) del generador de paréntesis balanceados con profundidad máxima.

  Pide por teclado la cantidad de pares `n` y un segundo valor `p` (entre 1 y `n`), y genera como `Stream` las
  cadenas balanceadas de `n` pares en las que nunca hay más de `p` paréntesis abiertos pendientes de cerrar.

  ## Entradas

    * Teclado: `n`, la cantidad de pares (entero mayor que 0).
    * Teclado: `p`, el número de abiertos permitido (entero entre 1 y `n`).

  ## Proceso

    1. `preguntar/1` y `preguntar/2` leen y validan los dos números, repitiendo la pregunta si no son válidos.
    2. `hacer_parentesis/2` llama al generador recursivo `generar/5`, que construye un `Stream` perezoso.
    3. `Enum.each/2` consume el `Stream` e imprime cada cadena.

  ## Salida

    * Por pantalla: una cadena balanceada por línea. No escribe archivos.

  ## Observaciones sobre generar/5

  En `generar/5` las variables `abiertos` y `cerrados` se vuelven a asignar dentro de la cláusula `true` del `cond`.
  Esas variables no existen fuera del `cond`, así que `Stream.concat(abiertos, cerrados)` recibe los enteros
  originales y no las ramas. Además, la segunda comparación (`cerrados < abiertos`) usa el `abiertos` ya
  reasignado. La versión final (`parentesis.exs`) corrige esto con las variables `abrir` y `cerrar` y
  `Stream.flat_map/2`. Este archivo es solo un borrador y no forma parte de la entrega.
  """
  @doc """
  Punto de entrada: pide los datos, crea el Stream de soluciones y las imprime.

  ## Entradas

    * Teclado: `n` (pares) y `p` (abiertos permitidos).

  ## Proceso

    * Pregunta `n` con `preguntar/1` y `p` con `preguntar/2` (que exige `p <= n`).
    * Obtiene el `Stream` con `hacer_parentesis/2` y lo consume con `Enum.each/2`.

  ## Salida

    * Imprime una cadena por línea. El valor de retorno no se utiliza.
  """
  def main do
    # Pide por teclado la cantidad de pares n (entero positivo).
    pares=
      "ingrese el numero de pares de parentesis"
      |> preguntar()

    # Pide el segundo dato p; debe estar entre 1 y n.
    parentesis =
    "numero de abiertos. (debe ser menor a la cantidad de pares totales)"
    |> preguntar(pares)

   # Stream perezoso de soluciones: todavía no se genera ninguna.
   solucion =  hacer_parentesis(pares, parentesis)
   # Al consumir el Stream se genera e imprime cada cadena.
   Enum.each(solucion, fn s -> IO.puts(s) end )
  end


  @doc """
  Crea el Stream de cadenas balanceadas de `n` pares con profundidad máxima `p`.

  ## Entradas

    * `n`: cantidad de pares.
    * `p`: profundidad máxima permitida.

  ## Proceso

    * Llama a `generar/5` con la cadena vacía y los contadores en cero.

  ## Salida

    * `Stream` de strings (perezoso).
  """
  def hacer_parentesis(n, p) do
   # Inicia con la cadena vacía, 0 abiertos y 0 cerrados.
   generar( n, p,"", 0, 0)
  end
@doc """
Generador recursivo de cadenas de paréntesis balanceados.

## Entradas

  * `n`, `p`: pares y profundidad máxima.
  * `string`: prefijo construido hasta ahora.
  * `abiertos`, `cerrados`: cantidad de `(` y `)` usados.

## Proceso

  * Caso base: con `n` abiertos y `n` cerrados el prefijo es una solución.
  * Caso recursivo: intenta agregar `(` (si `abiertos < n` y `abiertos - cerrados < p`) y `)` (si `cerrados < abiertos`).
  * Une las ramas con `Stream.concat/2`.

## Salida

  * `Stream` de strings. Ver las observaciones del módulo sobre el uso de `abiertos` y `cerrados`.
"""
def generar(n, p, string, abiertos, cerrados) do
cond do
  # Caso base: cadena completa; se emite como Stream de un solo elemento.
  abiertos == n and cerrados == n ->
    Stream.map([string], fn x -> x end)

    # Caso recursivo: se prueban las ramas '(' y ')'.
    true ->
      # Rama de '(': se reasigna 'abiertos' con el Stream de esa rama.
      abiertos =
       # Solo se abre si quedan por abrir y no se supera la profundidad p.
       if abiertos < n and abiertos - cerrados < p do
        # Agrega '(' y continúa recursivamente.
        generar(n,p, string <> "(", abiertos + 1, cerrados)
       else
         # Rama sin soluciones: Stream vacío.
         Stream.map([], fn x -> x end)
        end

      # Rama de ')': se reasigna 'cerrados' con el Stream de esa rama.
      cerrados =
        # Solo se cierra si hay algún '(' sin cerrar (ver observaciones del módulo).
        if cerrados < abiertos do
          # Agrega ')' y continúa recursivamente.
          generar(n, p, string <> ")", abiertos, cerrados + 1)
        else
          # Rama sin soluciones: Stream vacío.
          Stream.map([], fn x -> x end)

        end
end

# Une las dos ramas: primero '(' y luego ')'.
Stream.concat(abiertos, cerrados)


end
@doc """
Pide por teclado la cantidad de pares y repite la pregunta hasta recibir un entero positivo.

## Entradas

  * `mensaje`: texto que se muestra al pedir el dato.

## Proceso

  * Lee una línea, quita espacios y la convierte a entero (`String.to_integer/1` falla si no es numérica).
  * Si el valor es 0 o negativo, avisa y vuelve a preguntar (recursión).

## Salida

  * Entero mayor que 0.
"""
def preguntar(mensaje) do
# Lee una línea del teclado, quita espacios y la convierte a entero.
n =
  IO.gets(mensaje)
  |>String.trim()
  |>String.to_integer()

 # Rechaza 0 o negativos y vuelve a preguntar.
 if n <= 0 do
  IO.puts("los pares no pueden ser 0 o negativo")
  preguntar(mensaje)
 else
  # Valor válido: se devuelve.
  n
 end
end
@doc """
Pide el número de abiertos y repite la pregunta hasta que esté entre 1 y la cantidad de pares.

## Entradas

  * `mensaje`: texto que se muestra al pedir el dato.
  * `pares`: cantidad de pares ya ingresada (límite superior).

## Proceso

  * Lee y convierte el entero; si es menor que 1 o mayor que `pares` avisa y vuelve a preguntar (recursión).

## Salida

  * Entero entre 1 y `pares`.
"""
def preguntar(mensaje, pares) do
  # Lee una línea del teclado, quita espacios y la convierte a entero.
  n =
    IO.gets(mensaje)
    |> String.trim()
    |> String.to_integer()

 cond do
  # Menos de un abierto: se vuelve a preguntar.
  n < 1 ->
    IO.puts(" debe haber almenos un abierto ")
    preguntar(mensaje, pares)

  # Más abiertos que pares: se vuelve a preguntar.
  n > pares ->
    IO.puts("Los abiertos  no pueden superar los pares")
    preguntar(mensaje, pares)

  # Valor válido: se devuelve.
  true ->
    n
end

end
end

# Punto de entrada: al ejecutar el script se llama a main/0.
Parentesis.main()
