# Parcial 2 - Programación III (G2D)
Integrantes 
Nicolas Santiago Guzman Chala
Juan Esteban Campos
Santiago Gomez Rave

Universidad del Quindío - Programa de Ingeniería de Sistemas y Computación
Docente: Julián Esteban Gutiérrez Posada

## Descripción del proyecto

Este proyecto fue realizado en Elixir como parte del segundo parcial de la asignatura de Programación III. Se resolvieron dos de los cuatro problemas propuestos: el **Problema 1** (robot de rescate con energía limitada y mapa SVG) y el **Problema 4** (secuencias de paréntesis balanceados con profundidad máxima).

Durante el desarrollo se trabajaron principalmente la recursividad, los Streams (perezosos e infinitos), los structs, el pattern matching, la lectura de archivos línea por línea con `File.stream!/1`, la validación previa de datos y la escritura de archivos de salida (TXT, CSV y SVG).

La idea principal es que cada programa lea sus archivos de entrada, verifique que los datos sean correctos antes de utilizarlos y, solo entonces, realice los cálculos y genere los resultados.

## Objetivos

El objetivo principal es aplicar los conceptos vistos en clase mediante dos problemas de programación funcional: un problema de búsqueda con retroceso sobre una matriz y un problema de generación perezosa de cadenas.

También se busca organizar los programas en funciones pequeñas, con una responsabilidad clara, de forma que el código sea más fácil de entender, modificar y mantener.

Otro objetivo es aprender a utilizar las estructuras y funciones propias de Elixir (listas, mapas, structs, `Stream`, `Enum`) para procesar la información sin construir listas innecesarias.

## Organización del proyecto

El proyecto está dividido en dos carpetas, una por problema. Cada una contiene el programa principal y sus archivos de entrada.

```
parcial2/
│
├── README.md
│
├── problema1_rescate/
│   ├── recorrido_rescate.exs
│   ├── edificio.txt
│   ├── terrenos.csv
│   ├── bateria.txt
│   └── pruebas/
│
├── problema4_parentesis/
│   ├── parentesis.exs
│   ├── parametros.csv
│   ├── propuestas.txt
│   └── pruebas/
│
└── informe/
    └── Informe_Parcial2_Programacion3.pdf
```

El archivo `recorrido_rescate.exs` contiene los módulos `Terreno`, `Recorrido` y `Recorrido_Rescate`. El archivo `parentesis.exs` contiene el módulo `Parentesis`.

Cada programa se ejecuta de forma independiente y escribe sus resultados en archivos de salida.

## Cómo ejecutar

Solo se necesita tener Elixir instalado. No se utilizan dependencias externas ni `mix`.

```bash
cd problema1_rescate
elixir recorrido_rescate.exs

cd ../problema4_parentesis
elixir parentesis.exs
```

El Problema 1 escribe sus salidas en el directorio desde el cual se ejecuta, por eso se debe ejecutar dentro de su carpeta.

---

# Problema 1: Robot de rescate

## Descripción

Un robot debe ir desde la casilla de inicio `S` hasta la meta `M` dentro de un edificio representado por una matriz. Cada movimiento es hacia arriba, derecha, abajo o izquierda, y entrar a una casilla consume energía según su tipo de terreno. El robot tiene una batería máxima `B` y no puede pasar dos veces por la misma casilla.

El programa encuentra todos los recorridos que llegan a la meta sin superar la batería, y determina cuáles tienen menos movimientos y cuáles consumen menos energía.

## Archivos de entrada

- `edificio.txt`: la matriz del edificio, con los símbolos separados por espacios.
- `terrenos.csv`: la definición de cada símbolo con el formato `simbolo,nombre,transitable,costo`.
- `bateria.txt`: un único entero positivo con la energía máxima.

Los símbolos y los costos se leen desde `terrenos.csv`; no están escritos dentro de las funciones de búsqueda.

## Structs

Se definieron dos structs:

```elixir
defmodule Terreno do
  defstruct simbolo: "", nombre: "", transitable: false, costo: 0
end

defmodule Recorrido do
  defstruct posiciones: [], energia: 0
end
```

`Terreno` representa cada fila de `terrenos.csv` y `Recorrido` representa cada ruta encontrada, con la lista de posiciones visitadas y la energía consumida.

## Flujo del programa

```
Leer edificio, terrenos y batería
   |
   v
Validar edificio
   |
   +--> hay errores --> escribir validacion_edificio.txt y terminar
   |
   v
Stream de relajación de energía
   |
   +--> la meta no es alcanzable --> sin recorrido (CSV vacío y SVG "sin recorrido")
   |
   v
Exploración recursiva de recorridos simples
   |
   v
Escribir CSV, resumen y SVG
```

## Validación previa

Antes de iniciar la búsqueda se comprueba que el edificio no esté vacío, que sea rectangular, que todos sus símbolos estén definidos en `terrenos.csv`, que el borde completo esté formado por `X`, que la tabla de terrenos no tenga símbolos repetidos y que la batería sea un único entero positivo.

Los recorridos de la matriz se hacen con funciones recursivas que avanzan fila por fila y columna por columna llevando los índices como acumuladores. De esta manera cada error informa su coordenada `{fila, columna}`, con origen en 0.

Todos los errores se guardan en `validacion_edificio.txt`. Si existe al menos uno, la búsqueda no se inicia.

## Stream infinito: relajación de energía

Antes de enumerar los recorridos se genera un Stream infinito con `Stream.iterate/2`. Cada elemento es un mapa que relaciona una posición con el menor costo conocido para llegar a ella.

```elixir
Stream.iterate(estado_inicial, fn estado ->
  relajar(estado, edificio, terrenos, bateria)
end)
```

En el paso 0 solamente la casilla `S` tiene costo 0. En cada paso siguiente se conservan los costos ya encontrados y cada casilla transitable se actualiza con el menor valor de `costo del vecino + costo de entrada`, descartando los valores mayores que la batería.

Como todos los costos son no negativos, el proceso termina estabilizándose. El Stream se consume hasta el primer par de estados consecutivos iguales y los pasos se escriben en `expansion_energia.txt`.

Si la meta no aparece en el estado final, no existe ningún recorrido posible y se omite la enumeración.

Esta relajación sirve como filtro porque el costo mínimo de una casilla es una cota inferior de cualquier ruta que llegue a ella. Pero no reemplaza la enumeración, porque el mapa guarda un solo número por casilla: no indica cuántos recorridos existen, cuáles son, cuántos movimientos tienen ni los empates.

## Exploración recursiva

La función `explorar/8` recibe la posición actual, la meta, la lista de posiciones visitadas y la energía acumulada. Si la posición actual es la meta, guarda el recorrido. Si no, `verificar_caminos/9` prueba las direcciones en el orden fijo:

```
arriba, derecha, abajo, izquierda
```

Para cada dirección se utiliza pattern matching sobre el struct `Terreno`:

```elixir
case obtener_terreno(x, y, edificio, terreno) do
  %Terreno{transitable: true, costo: costo} when energia + costo <= bateria ->
    explorar(...)

  _ ->
    recorridos
end
```

De esta forma se rechazan las paredes y las rutas que superan la batería. Como las listas en Elixir son inmutables, al pasar `visitadas ++ [siguiente]` a la llamada recursiva el retroceso se hace de forma natural, sin deshacer nada manualmente.

## Archivos de salida

| Archivo | Contenido |
|---|---|
| `validacion_edificio.txt` | Errores de validación, o el mensaje de edificio válido |
| `expansion_energia.txt` | Pasos distintos del Stream e índice de estabilización |
| `recorridos_rescate.csv` | Columnas `id;movimientos;energia;posiciones`, una fila por recorrido |
| `resumen_rescate.txt` | Total, recorridos con menos movimientos y con menor energía |
| `ruta_optima.svg` | Mapa con casillas de 40x40 px y el recorrido de menor energía |

El resumen también se muestra por pantalla.

## Mapa SVG

Cada casilla se dibuja con un color según su terreno (pared, pasillo, lodo, inicio y meta) y el recorrido de menor energía se marca con una línea roja. En caso de empate se dibuja el primero encontrado en el orden fijo de direcciones. El texto de cada casilla se escapa con `escapar_xml/1`. Si no existe ruta, el mapa se genera sin recorrido y con la leyenda `sin recorrido`.

## Ejemplo

Con el edificio del enunciado y una batería de 10:

```
X X X X X X
X S . L M X
X . X . . X
X . . . . X
X X X X X X
```

se obtienen 6 recorridos. El de menos movimientos (3) y el de menor energía (5) es el mismo:

```
(1,1) -> (1,2) -> (1,3) -> (1,4)
```

El Stream de relajación se estabiliza en el índice 6.

---

# Problema 4: Paréntesis balanceados con profundidad máxima

## Descripción

Dados `n` pares de paréntesis y una profundidad máxima `p`, el programa genera todas las cadenas balanceadas en las que, en ningún prefijo, hay más de `p` paréntesis abiertos pendientes de cerrar.

## Archivos de entrada

- `parametros.csv`: un registro `n;profundidad_max` por línea, con una primera línea de comentario.
- `propuestas.txt`: cadenas por verificar, con el formato `n;p;cadena`.

## Generador recursivo y perezoso

La función `generar/5` construye la cadena agregando un carácter a la vez y devuelve un Stream:

```elixir
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
```

Solo se agrega `(` cuando todavía quedan paréntesis por abrir y no se supera la profundidad `p`, y solo se agrega `)` cuando hay algún paréntesis abierto sin cerrar. Por eso nunca se construye un prefijo inválido.

Como se intenta primero `(` y después `)`, para `n = 3` y `p = 2` el orden de salida es:

```
(()())
(())()
()(())
()()()
Total: 4
```

## Evaluación perezosa

Las soluciones no se guardan en una lista. Cada una se escribe en su archivo `parentesis_n<N>_p<P>.txt` en el momento en que se consume, y al final se agrega el total.

Para `n = 18` y `p = 18` existen 477 638 700 cadenas. El programa obtiene solamente la primera con `Enum.take(1)` y la guarda en `primera_n18_p18.txt`. Gracias a la evaluación perezosa, el generador solo desarrolla la primera rama (haciendo 36 decisiones) y las demás quedan sin evaluar.

## Verificación de propuestas

`validar_propuestas/3` y `validar_propuestas/11` revisan cada propuesta recorriendo sus caracteres con una función recursiva y varios acumuladores: abiertos, cerrados, profundidad actual, profundidad máxima, prefijo recorrido, primer prefijo problemático y lista de errores.

Los motivos de rechazo que se pueden detectar son:

```
:longitud_incorrecta
:profundidad_excedida
:cierre_sin_apertura
:caracter_no_permitido
:balance_incorrecto
```

El resultado de cada propuesta se escribe en `verificacion_parentesis.txt` indicando si es válida, sus errores, el primer prefijo problemático y la profundidad máxima alcanzada.

## Stream infinito: crecimiento de soluciones

La función `stream_infinito/0` construye el Stream `n = 1, 2, 3, ...` con `p = n`, y cada valor se transforma de forma perezosa en `{n, total}` contando las soluciones con el generador, sin guardarlas:

```elixir
Stream.iterate(1, fn x -> x + 1 end)
|> Stream.map(fn s -> {s, hacer_parentesis(s, s) |> Enum.count()} end)
|> Enum.reduce_while(archivo, fn {n, total}, acc ->
  IO.write(acc, "#{n};#{total}\n")
  if total >= 1000, do: {:halt, acc}, else: {:cont, acc}
end)
```

Cada fila se escribe en `secuencia_parentesis.csv` conforme se calcula. El consumo se detiene en el primer `n` cuyo total es mayor o igual a 1000, incluyéndolo:

```
n;total
1;1
2;2
3;5
4;14
5;42
6;132
7;429
8;1430
```

El valor `n = 9` no se calcula porque los Streams son perezosos: el siguiente elemento solo se calcularía si `reduce_while` lo pidiera, y al llegar a `n = 8` el proceso se detiene con `{:halt, acc}`.

## Archivos de salida

| Archivo | Contenido |
|---|---|
| `parentesis_n<N>_p<P>.txt` | Una solución por línea y el total al final |
| `primera_n18_p18.txt` | Primera solución para n = 18 y p = 18 |
| `verificacion_parentesis.txt` | Resultado de cada propuesta |
| `secuencia_parentesis.csv` | Totales para n = 1 hasta el primer total >= 1000 |

---

## Pruebas realizadas

Para cada problema se definieron casos válidos, inválidos y límite. Los resultados detallados se encuentran en el informe PDF.

**Problema 1:**
- El edificio del enunciado con batería 10 (caso válido) y con batería 5 (presupuesto ajustado).
- Una batería de 4, con la que la meta no es alcanzable y no se enumeran recorridos.
- Un edificio donde `S` y `M` están contiguas y la batería es exactamente el costo.
- Un edificio con dos recorridos empatados.
- Edificios inválidos: símbolo no definido, borde que no es `X`, edificio no rectangular y batería negativa.

**Problema 4:**
- Los parámetros `3;2`, `4;2` y `5;3`, con 4, 8 y 34 soluciones.
- Casos límite: `1;1`, `3;1` y la primera solución de `18;18`.
- Propuestas inválidas: cierre sin apertura, profundidad excedida, longitud incorrecta y carácter no permitido.
- El Stream infinito, que se detiene en `n = 8` con 1430 soluciones.

## Conceptos de Elixir utilizados

### Módulos
Los módulos organizan las funciones y los structs de cada programa.

```elixir
defmodule Recorrido_Rescate do
```

### Funciones públicas y privadas
Las funciones públicas (`def`) pueden usarse desde otros módulos. Las privadas (`defp`) solo se usan dentro del módulo donde fueron definidas, como las de validación y lectura.

### Structs
`%Terreno{}` y `%Recorrido{}` agrupan los datos relacionados con nombres de campo claros.

### Pattern matching
Se usa para rechazar terrenos no transitables, para separar los registros de los archivos y para definir los casos base y recursivos de las funciones.

### Recursividad
La validación, la búsqueda de símbolos, la carga de terrenos, la exploración de recorridos y la verificación de propuestas se implementaron con funciones recursivas que llevan acumuladores.

### Streams
`File.stream!/1` lee los archivos línea por línea. `Stream.iterate/2`, `Stream.map/2`, `Stream.flat_map/2` y `Stream.concat/1` permiten generar datos de forma perezosa, y `Enum.reduce_while/3` consume un Stream infinito hasta que se cumple una condición.

### Enum
Se utiliza para recorrer, filtrar y transformar listas, por ejemplo con `Enum.min_by/2`, `Enum.filter/2` y `Enum.map_join/3`.

### Escritura de archivos
Los resultados se guardan con `File.write!/2` y `File.open!/2`, utilizando `;` como separador en los archivos CSV.