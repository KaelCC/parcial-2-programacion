defmodule Parentesis do
  def main do
    pares=
      "ingrese el numero de pares de parentesis"
      |> preguntar()

    parentesis =
    "numero de abiertos. (debe ser menor a la cantidad de pares totales)"
    |> preguntar(pares)

   solucion =  hacer_parentesis(pares, parentesis)
   Enum.each(solucion, fn s -> IO.puts(s) end )
  end


  def hacer_parentesis(n, p) do
   generar( n, p,"", 0, 0)
  end
def generar(n, p, string, abiertos, cerrados) do
cond do
  abiertos == n and cerrados == n ->
    Stream.map([string], fn x -> x end)

    true ->
      abiertos =
       if abiertos < n and abiertos - cerrados < p do
        generar(n,p, string <> "(", abiertos + 1, cerrados)
       else
         Stream.map([], fn x -> x end)
        end

      cerrados =
        if cerrados < abiertos do
          generar(n, p, string <> ")", abiertos, cerrados + 1)
        else
          Stream.map([], fn x -> x end)

        end
end

Stream.concat(abiertos, cerrados)


end
def preguntar(mensaje) do
n =
  IO.gets(mensaje)
  |>String.trim()
  |>String.to_integer()

 if n <= 0 do
  IO.puts("los pares no pueden ser 0 o negativo")
  preguntar(mensaje)
 else
  n
 end
end
def preguntar(mensaje, pares) do
  n =
    IO.gets(mensaje)
    |> String.trim()
    |> String.to_integer()

 cond do
  n < 1 ->
    IO.puts(" debe haber almenos un abierto ")
    preguntar(mensaje, pares)

  n > pares ->
    IO.puts("Los abiertos  no pueden superar los pares")
    preguntar(mensaje, pares)

  true ->
    n
end

end
end

Parentesis.main()
