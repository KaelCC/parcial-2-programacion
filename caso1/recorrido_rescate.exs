defmodule Terreno do
  @moduledoc """
  Estructura que representa un tipo de terreno del edificio.

  Cada registro de `terrenos.csv` (`simbolo,nombre,transitable,costo`) se convierte en un `%Terreno{}`.

  ## Campos

    * `:simbolo` - carácter que aparece en la matriz (por ejemplo `X`, `.`, `L`, `S`, `M`).
    * `:nombre` - nombre legible del terreno (pared, pasillo, lodo...); se usa para rotular el SVG.
    * `:transitable` - `true` si el robot puede entrar a la casilla, `false` si no (paredes).
    * `:costo` - energía (entero no negativo) que consume entrar a una casilla de este tipo.
  """
  defstruct simbolo: "", nombre: "", transitable: false, costo: 0
end

defmodule Recorrido do
  @moduledoc """
  Estructura que representa un recorrido encontrado por el robot.

  ## Campos

    * `:posiciones` - lista de posiciones `[fila, columna]` en orden, desde `S` hasta `M` (origen en 0).
    * `:energia` - energía total consumida (la casilla inicial no consume).
  """
  defstruct posiciones: [], energia: 0
end

defmodule Recorrido_Rescate do
  @moduledoc """
  Robot de rescate con energía limitada (Problema 1 del Parcial 2).

  Un robot debe ir desde la casilla `S` hasta la meta `M` de un edificio representado por una matriz,
  moviéndose arriba, derecha, abajo o izquierda. Entrar a una casilla consume energía según su terreno
  (la casilla inicial no consume) y el robot tiene una batería máxima `B`. No puede repetir casillas
  dentro de un mismo recorrido.

  ## Entradas

    * `edificio.txt` - matriz con los símbolos separados por espacios.
    * `terrenos.csv` - un registro `simbolo,nombre,transitable,costo` por línea.
    * `bateria.txt` - una línea con el entero positivo `B`.

  ## Proceso

    1. Lectura de los tres archivos con `File.stream!/1`.
    2. Validación previa con funciones recursivas. Si hay errores se escribe `validacion_edificio.txt` y no se busca.
    3. Stream infinito de relajación de energía mínima (`Stream.iterate/2`), consumido hasta estabilizarse.
       Si la meta no queda con costo alcanzable, se omite la enumeración.
    4. Enumeración recursiva (con retroceso) de todos los recorridos simples `S` -> `M` con energía menor o
       igual a `B`, probando las direcciones en el orden fijo: arriba, derecha, abajo, izquierda.
    5. Cálculo de los recorridos con menos movimientos y con menor energía (se conservan los empates).
    6. Escritura de los resultados y del mapa SVG.

  ## Salidas

    * `validacion_edificio.txt` - errores de validación o mensaje de edificio válido.
    * `expansion_energia.txt` - pasos distintos de la relajación e índice de estabilización.
    * `recorridos_rescate.csv` - columnas `id;movimientos;energia;posiciones`.
    * `resumen_rescate.txt` - total, recorridos con menos movimientos y con menor energía.
    * `ruta_optima.svg` - mapa con casillas de 40 x 40 píxeles y el recorrido de menor energía.
    * Por pantalla: estado de la validación, resumen y recorrido de menor energía.

  Los archivos de entrada se leen junto al script (`__DIR__`); los de salida se escriben en el
  directorio de trabajo actual, por eso se debe ejecutar desde la carpeta del problema.
  """
  # Orden fijo para explorar y desempatar
  @direcciones ["arriba", "derecha", "abajo", "izquierda"]

  @doc """
  Punto de entrada del programa: lee, valida y, si todo es correcto, resuelve el problema.

  ## Entradas

    * Ninguna por argumento. Lee `edificio.txt`, `terrenos.csv` y `bateria.txt` desde la carpeta del script.

  ## Proceso

    * Lee cada archivo línea por línea (`File.stream!/1`).
    * Convierte las líneas en la matriz, en structs `%Terreno{}` y en el entero de batería.
    * Reúne los errores de validación y escribe `validacion_edificio.txt`.
    * Si no hay errores, llama a `encontrar_recorridos/3`; si los hay, los muestra y termina.

  ## Salida

    * Archivos de salida y mensajes por pantalla. El valor de retorno no se utiliza.
  """
  def main() do
    # Rutas de los tres archivos de entrada, relativas a la carpeta del script.
    ruta_edificio = Path.join(__DIR__, "edificio.txt")
    ruta_terreno = Path.join(__DIR__, "terrenos.csv")
    ruta_bateria = Path.join(__DIR__, "bateria.txt")

    # Matriz del edificio: cada línea se limpia y se separa por espacios,
    # ejemplo: "X S . L" -> ["X", "S", ".", "L"]. El resultado es una lista de listas.
    edificio =
      ruta_edificio
      |> File.stream!()
      |> Stream.map(fn linea ->
        linea |> String.trim() |> String.split()
      end)
      |> Enum.to_list()

    # Líneas de terrenos.csv, sin espacios sobrantes y sin líneas vacías.
    lineas_terreno =
      ruta_terreno
      |> File.stream!()
      |> Stream.map(&String.trim/1)
      |> Enum.to_list()
      |> Enum.reject(&(&1 == ""))

    # Líneas de bateria.txt con el mismo tratamiento (debe quedar una sola).
    lineas_bateria =
      ruta_bateria
      |> File.stream!()
      |> Stream.map(&String.trim/1)
      |> Enum.to_list()
      |> Enum.reject(&(&1 == ""))

    # Convierte las líneas en structs %Terreno{} y recoge los errores de formato.
    {terreno, errores_terreno} = cargar_terrenos(lineas_terreno)
    # Convierte la línea en un entero positivo (0 si es inválida) y recoge su error.
    {bateria, errores_bateria} = cargar_bateria(lineas_bateria)

    # Reúne todos los errores de validación: edificio, terrenos y batería.
    errores =
      validar_edificio(edificio, terreno) ++
        errores_terreno ++ errores_bateria

    # Siempre se escribe validacion_edificio.txt: mensaje de éxito o un error por línea.
    File.write!(
      "validacion_edificio.txt",
      if errores == [] do
        "Edificio válido. No se encontraron errores.\n"
      else
        Enum.join(errores, "\n")
      end
    )

    # Solo si no hay errores se inicia la búsqueda; si los hay, se muestran y se termina.
    if errores != [] do
      IO.puts("Se encontraron errores en la validación:")
      Enum.each(errores, &IO.puts/1)
    else
      IO.puts("Validación correcta.")

      # Validación correcta: relajación de energía y enumeración de recorridos.
      encontrar_recorridos(terreno, bateria, edificio)
    end
  end

  # --------------------------------------------------
  # LECTURA DE TERRENOS
  # --------------------------------------------------

  # cargar_terrenos/1 (privada)
  # Convierte las líneas de terrenos.csv en structs %Terreno{}.
  #
  # Entradas:
  #   - lineas: lista de strings, una por registro (sin líneas vacías).
  # Proceso:
  #   - Llama a cargar_terrenos/4 con el número de registro inicial (1) y acumuladores vacíos.
  # Salida:
  #   - Tupla {terrenos, errores}: lista de %Terreno{} y lista de mensajes de error.
  defp cargar_terrenos(lineas) do
    cargar_terrenos(lineas, 1, [], [])
  end

  # cargar_terrenos/4 - caso base: no quedan líneas; se devuelven los acumuladores en su orden original.
  defp cargar_terrenos([], _linea, terrenos, errores) do
    {Enum.reverse(terrenos), Enum.reverse(errores)}
  end

  # cargar_terrenos/4 - caso recursivo (privada)
  # Procesa un registro y continúa con el resto.
  #
  # Entradas:
  #   - linea | cola: registro actual y los que faltan.
  #   - numero: posición del registro (cuenta solo líneas no vacías).
  #   - terrenos, errores: acumuladores.
  # Proceso:
  #   - Separa por comas y exige exactamente 4 columnas (pattern matching).
  #   - Valida que 'transitable' sea si/no y que el costo sea un entero >= 0.
  #   - Agrega el struct o el error y llama a sí misma con numero + 1.
  # Salida:
  #   - Llamada recursiva; al final devuelve {terrenos, errores}.
  defp cargar_terrenos([linea | cola], numero, terrenos, errores) do
    # Separa el registro por comas: simbolo, nombre, transitable, costo.
    partes = String.split(String.trim(linea), ",")

    # Pattern matching: solo se acepta un registro de exactamente 4 columnas.
    case partes do
      [simbolo, nombre, transitable, costo] ->
        # Se evalúan a la vez el texto de 'transitable' y el costo convertido a entero.
        case {transitable, Integer.parse(costo)} do
          # Terreno transitable con costo entero no negativo.
          {"si", {valor, ""}} when valor >= 0 ->
            # Construye el struct del terreno (transitable: true).
            nuevo = %Terreno{
              simbolo: simbolo,
              nombre: nombre,
              transitable: true,
              costo: valor
            }

            cargar_terrenos(
              cola,
              numero + 1,
              [nuevo | terrenos],
              errores
            )

          # Terreno no transitable (por ejemplo una pared) con costo entero no negativo.
          {"no", {valor, ""}} when valor >= 0 ->
            # Construye el struct del terreno (transitable: false).
            nuevo = %Terreno{
              simbolo: simbolo,
              nombre: nombre,
              transitable: false,
              costo: valor
            }

            cargar_terrenos(
              cola,
              numero + 1,
              [nuevo | terrenos],
              errores
            )

          _ ->
            cargar_terrenos(
              cola,
              numero + 1,
              terrenos,
              # Registro inválido: no se agrega el terreno, se acumula el error con su número.
              ["Línea #{numero}: registro de terreno inválido." | errores]
            )
        end

      _ ->
        cargar_terrenos(
          cola,
          numero + 1,
          terrenos,
          # Cantidad de columnas distinta de 4: se acumula el error.
          ["Línea #{numero}: cantidad incorrecta de columnas." | errores]
        )
    end
  end

  # --------------------------------------------------
  # LECTURA DE BATERÍA
  # --------------------------------------------------

  # cargar_bateria/1 (privada)
  # Lee el presupuesto de energía B.
  #
  # Entradas:
  #   - lineas: lista de strings no vacíos de bateria.txt.
  # Proceso:
  #   - Exige una sola línea y que sea un entero positivo (Integer.parse sin resto).
  # Salida:
  #   - {valor, []} si es válida; {0, [mensaje]} si no lo es.
  defp cargar_bateria(lineas) do
    case lineas do
      # Debe existir exactamente una línea de datos.
      [linea] ->
        # Integer.parse devuelve {entero, resto}; el resto debe ser "" (sin caracteres extra).
        case Integer.parse(String.trim(linea)) do
          # Entero positivo: batería válida y sin errores.
          {valor, ""} when valor > 0 ->
            {valor, []}

          _ ->
            # Valor no numérico, cero o negativo.
            {0, ["Batería: debe ser un entero positivo."]}
        end

      _ ->
        # Ninguna línea o más de una: error.
        {0, ["Batería: debe existir una sola línea con el presupuesto."]}
    end
  end

  # --------------------------------------------------
  # VALIDACIÓN DEL EDIFICIO
  # --------------------------------------------------

  # validar_edificio/2 (privada)
  # Validación previa de la consistencia del edificio.
  #
  # Entradas:
  #   - edificio: matriz (lista de listas de símbolos).
  #   - terrenos: lista de %Terreno{}.
  # Proceso:
  #   - Verifica: edificio no vacío, rectangular, símbolos de terrenos.csv sin repetir, S y M definidos una vez en la
  #   - tabla, símbolos de la matriz definidos (validar_simbolos/4) y borde formado solo por X (validar_borde/2).
  #   - Los errores se acumulan al inicio de la lista y se invierten al final.
  # Salida:
  #   - Lista de mensajes de error en el orden en que se detectaron (vacía si todo es válido).
  defp validar_edificio(edificio, terrenos) do
    # Lista de errores acumulados (se agregan al inicio y al final se invierte).
    errores = []

    errores =
      # 1. Edificio vacío: sin filas o con todas las filas vacías.
      if edificio == [] or Enum.all?(edificio, &(&1 == [])) do
        ["El edificio está vacío." | errores]
      else
        errores
      end

    # 2. Rectangularidad: todas las filas deben tener el mismo ancho.
    anchos = Enum.map(edificio, &length/1)

    errores =
      if length(Enum.uniq(anchos)) > 1 do
        ["El edificio no es rectangular." | errores]
      else
        errores
      end

    simbolos = Enum.map(terrenos, & &1.simbolo)

    errores =
      # 3. La tabla de terrenos no debe tener símbolos repetidos.
      if length(simbolos) != length(Enum.uniq(simbolos)) do
        ["Existen símbolos repetidos en terrenos.csv." | errores]
      else
        errores
      end

    errores =
      # 4. terrenos.csv debe definir S exactamente una vez.
      if Enum.count(simbolos, &(&1 == "S")) != 1 do
        ["terrenos.csv debe definir S exactamente una vez." | errores]
      else
        errores
      end

    errores =
      # 5. terrenos.csv debe definir M exactamente una vez.
      if Enum.count(simbolos, &(&1 == "M")) != 1 do
        ["terrenos.csv debe definir M exactamente una vez." | errores]
      else
        errores
      end

    # 6. Recorre la matriz (recursivamente) buscando símbolos no definidos.
    errores = validar_simbolos(edificio, simbolos, 0, errores)
    # 7. Recorre la matriz (recursivamente) verificando que el borde sea X.
    errores = validar_borde(edificio, errores)

    # Se acumularon al inicio; se invierten para dejarlos en orden de detección.
    Enum.reverse(errores)
  end

  # validar_simbolos/4 (privada, recursiva)
  # Verifica fila por fila que cada símbolo de la matriz esté definido en terrenos.csv.
  #
  # Entradas:
  #   - edificio (filas restantes), simbolos (definidos), numero_fila (origen 0), errores (acumulador).
  # Proceso:
  #   - Caso base: sin filas devuelve los errores. Caso recursivo: valida la primera fila y sigue con el resto.
  # Salida:
  #   - Lista de errores con la coordenada (fila,columna) de cada símbolo desconocido.
  defp validar_simbolos([], _simbolos, _fila, errores), do: errores

  defp validar_simbolos([fila | cola], simbolos, numero_fila, errores) do
    errores =
      # Valida la fila actual empezando en la columna 0.
      validar_simbolos_fila(fila, simbolos, numero_fila, 0, errores)

    # Continúa con las filas restantes.
    validar_simbolos(cola, simbolos, numero_fila + 1, errores)
  end

  # validar_simbolos_fila/5 (privada, recursiva)
  # Recorre las columnas de una fila comprobando que cada símbolo esté definido.
  #
  # Entradas:
  #   - Símbolos restantes de la fila, simbolos definidos, fila, columna actual, errores.
  # Proceso:
  #   - Si el símbolo no está en la tabla se agrega un error con su coordenada; luego avanza a la columna siguiente.
  # Salida:
  #   - Lista de errores acumulada.
  defp validar_simbolos_fila([], _simbolos, _fila, _columna, errores),
    do: errores

  defp validar_simbolos_fila(
         [simbolo | cola],
         simbolos,
         fila,
         columna,
         errores
       ) do
    errores =
      # El símbolo está definido: no hay error.
      if simbolo in simbolos do
        errores
      else
        [
          # Símbolo desconocido: se registra con su coordenada.
          "Símbolo '#{simbolo}' no definido en (#{fila},#{columna})."
          | errores
        ]
      end

    validar_simbolos_fila(
      cola,
      simbolos,
      fila,
      columna + 1,
      errores
    )
  end

  # validar_borde/2 (privada)
  # Comprueba que todo el borde de la matriz esté formado por X.
  #
  # Entradas:
  #   - edificio: matriz; errores: acumulador.
  # Proceso:
  #   - Con menos de 2 filas o 2 columnas el borde no es válido; si no, recorre filas y columnas recursivamente.
  # Salida:
  #   - Lista de errores (coordenadas de las casillas del borde que no son X).
  defp validar_borde([], errores), do: errores

  defp validar_borde(edificio, errores) do
    alto = length(edificio)
    ancho = length(hd(edificio))

    if alto < 2 or ancho < 2 do
      ["El edificio no tiene un borde válido." | errores]
    else
      validar_borde_filas(edificio, 0, alto, ancho, errores)
    end
  end

  # validar_borde_filas/5 (recursiva): valida cada fila con validar_borde_columnas/6 y avanza a la siguiente.
  defp validar_borde_filas([], _fila, _alto, _ancho, errores), do: errores

  defp validar_borde_filas([actual | cola], fila, alto, ancho, errores) do
    errores =
      validar_borde_columnas(actual, fila, 0, alto, ancho, errores)

    validar_borde_filas(cola, fila + 1, alto, ancho, errores)
  end

  # validar_borde_columnas/6 (recursiva): una casilla es de borde si está en la primera o última fila o columna;
  # si es de borde y no es X se agrega un error con su coordenada.
  defp validar_borde_columnas([], _fila, _col, _alto, _ancho, errores),
    do: errores

  defp validar_borde_columnas(
         [simbolo | cola],
         fila,
         columna,
         alto,
         ancho,
         errores
       ) do
    # La casilla es de borde si está en la primera/última fila o columna.
    borde =
      fila == 0 or fila == alto - 1 or
        columna == 0 or columna == ancho - 1

    errores =
      # Casilla de borde que no es X: error.
      if borde and simbolo != "X" do
        ["El borde debe ser X en (#{fila},#{columna})." | errores]
      else
        errores
      end

    validar_borde_columnas(
      cola,
      fila,
      columna + 1,
      alto,
      ancho,
      errores
    )
  end

  # --------------------------------------------------
  # BUSCAR INICIO Y META
  # --------------------------------------------------

  # buscar_inicio/1 y buscar_meta/1 (privadas)
  # Localizan las casillas S y M en la matriz.
  #
  # Entradas:
  #   - edificio: matriz.
  # Proceso:
  #   - Delegan en buscar_simbolo/4 con el símbolo "S" o "M".
  # Salida:
  #   - [fila, columna] de la primera aparición, o nil si no existe.
  defp buscar_inicio(edificio) do
    buscar_simbolo(edificio, "S", 0, 0)
  end

  defp buscar_meta(edificio) do
    buscar_simbolo(edificio, "M", 0, 0)
  end

  # buscar_simbolo/4 y buscar_simbolo_fila/4 (privadas, recursivas)
  # Búsqueda recursiva de un símbolo en la matriz.
  #
  # Entradas:
  #   - Filas restantes (o casillas restantes), símbolo buscado y la coordenada actual.
  # Proceso:
  #   - Revisa la fila actual; si no lo encuentra pasa a la siguiente (x + 1); en cada fila avanza columna a columna (y + 1).
  # Salida:
  #   - [fila, columna] o nil.
  defp buscar_simbolo([], _simbolo, _x, _y), do: nil

  defp buscar_simbolo([fila | cola], simbolo, x, _y) do
    resultado = buscar_simbolo_fila(fila, simbolo, x, 0)

    if resultado != nil do
      resultado
    else
      buscar_simbolo(cola, simbolo, x + 1, 0)
    end
  end

  defp buscar_simbolo_fila([], _simbolo, _x, _y), do: nil

  defp buscar_simbolo_fila([actual | cola], simbolo, x, y) do
    if actual == simbolo do
      [x, y]
    else
      buscar_simbolo_fila(cola, simbolo, x, y + 1)
    end
  end

  # --------------------------------------------------
  # OBTENER TERRENO DE UNA POSICIÓN
  # --------------------------------------------------

  # obtener_terreno/4 (privada)
  # Obtiene el struct %Terreno{} de una casilla.
  #
  # Entradas:
  #   - x, y: fila y columna; edificio: matriz; terrenos: lista de %Terreno{}.
  # Proceso:
  #   - Toma el símbolo de la casilla (Enum.at devuelve [] si la fila no existe) y busca su definición.
  # Salida:
  #   - El %Terreno{} correspondiente, o nil si el símbolo no está definido.
  defp obtener_terreno(x, y, edificio, terrenos) do
    # Símbolo que hay en la posición (x, y) de la matriz.
    simbolo =
      edificio
      |> Enum.at(x, [])
      |> Enum.at(y)

    Enum.find(terrenos, fn %Terreno{simbolo: actual} ->
      actual == simbolo
    end)
  end

  # --------------------------------------------------
  # RELAJACIÓN DE ENERGÍA
  # --------------------------------------------------

  # relajar/4 (privada)
  # Un paso de la relajación de energía mínima.
  #
  # Entradas:
  #   - estado: mapa {fila, columna} => costo mínimo conocido; edificio; terrenos; bateria (límite B).
  # Proceso:
  #   - Para cada casilla transitable calcula, con los costos del estado ANTERIOR, el costo de llegar por cada vecino
  #   - (costo del vecino + costo de entrada a la casilla) descartando los mayores que B, y conserva el mínimo si mejora
  #   - el valor que ya tenía. Así cada paso extiende el alcance en una casilla.
  # Salida:
  #   - Nuevo mapa de costos (igual al anterior si ya no hay mejoras).
  defp relajar(estado, edificio, terrenos, bateria) do
    alto = length(edificio)
    ancho = length(hd(edificio))

    # Todas las coordenadas {fila, columna} de la matriz.
    posiciones =
      for x <- 0..(alto - 1),
          y <- 0..(ancho - 1),
          do: {x, y}

    # El acumulado parte del estado anterior y se actualiza casilla por casilla.
    Enum.reduce(posiciones, estado, fn {x, y}, acumulado ->
      # Solo las casillas transitables pueden recibir un costo.
      case obtener_terreno(x, y, edificio, terrenos) do
        %Terreno{transitable: true, costo: costo} ->
          # Coordenadas de los cuatro vecinos, en el orden fijo de direcciones.
          vecinos =
            Enum.map(@direcciones, fn direccion ->
              mover({x, y}, direccion)
            end)

          # Costo de llegar por cada vecino: costo conocido del vecino + costo de entrada a esta casilla.
          # Se ignoran los vecinos sin costo (nil) y los costos que superan la batería.
          candidatos =
            Enum.map(vecinos, fn vecino ->
              Map.get(estado, vecino)
            end)
            |> Enum.filter(&is_integer/1)
            |> Enum.map(&(&1 + costo))
            |> Enum.filter(&(&1 <= bateria))

          # Sin candidatos no hay cambios; si hay, se toma el menor.
          case candidatos do
            [] ->
              acumulado

            _ ->
              nuevo_costo = Enum.min(candidatos)

              # Costo que la casilla ya tenía (nil si aún no era alcanzable).
              anterior = Map.get(acumulado, {x, y})

              # Se actualiza solo si la casilla era inalcanzable o el nuevo costo es menor.
              if anterior == nil or nuevo_costo < anterior do
                Map.put(acumulado, {x, y}, nuevo_costo)
              else
                acumulado
              end
          end

        _ ->
          acumulado
      end
    end)
  end

  # mover/2 (privada)
  # Calcula la casilla vecina en una dirección.
  #
  # Entradas:
  #   - {x, y}: posición actual; dirección: "arriba", "derecha", "abajo" o "izquierda".
  # Proceso:
  #   - Pattern matching sobre el texto de la dirección.
  # Salida:
  #   - Tupla {fila, columna} del vecino.
  defp mover({x, y}, "arriba"), do: {x - 1, y}
  defp mover({x, y}, "derecha"), do: {x, y + 1}
  defp mover({x, y}, "abajo"), do: {x + 1, y}
  defp mover({x, y}, "izquierda"), do: {x, y - 1}

  # expansion_energia/4 (privada)
  # Construye el Stream infinito de mapas de costo mínimo y lo consume hasta que se estabiliza.
  #
  # Entradas:
  #   - inicio: [fila, columna] de S; edificio; terrenos; bateria.
  # Proceso:
  #   - Estado 0: solo S con costo 0. Stream.iterate/2 aplica relajar/4 a cada estado para obtener el siguiente.
  #   - consumir_expansion/7 toma elementos hasta encontrar dos estados consecutivos iguales.
  # Salida:
  #   - Tupla {estado_final, indice_de_estabilizacion}; además se escribe expansion_energia.txt.
  defp expansion_energia(inicio, edificio, terrenos, bateria) do
    # Paso 0: solo la casilla S tiene costo 0 (las posiciones del mapa son tuplas {fila, columna}).
    estado_inicial = %{List.to_tuple(inicio) => 0}

    # Stream infinito y perezoso: no se calcula ningún paso hasta que se consume.
    estados =
      Stream.iterate(estado_inicial, fn estado ->
        relajar(estado, edificio, terrenos, bateria)
      end)

    # Consume el Stream hasta el primer par de estados consecutivos iguales.
    consumir_expansion(
      estados,
      nil,
      0,
      [],
      edificio,
      terrenos,
      bateria
    )
  end

  # consumir_expansion/7 (privada, recursiva)
  # Consume el Stream de relajación hasta que dos estados consecutivos sean iguales.
  #
  # Entradas:
  #   - estados (Stream), anterior (estado previo), indice, resultado (pasos ya vistos), edificio, terrenos, bateria.
  # Proceso:
  #   - Toma el estado número 'indice'; si es igual al anterior se estabilizó: escribe expansion_energia.txt.
  #   - Si no, guarda el paso y continúa con indice + 1.
  # Salida:
  #   - {estado_final, indice}: el índice es la primera posición cuyo estado repite al anterior.
  defp consumir_expansion(
         estados,
         anterior,
         indice,
         resultado,
         edificio,
         terrenos,
         bateria
       ) do
    # Obtiene (calcula) el elemento número 'indice' del Stream.
    estado = Enum.at(estados, indice)

    # Estabilización: este estado es igual al anterior.
    if anterior != nil and estado == anterior do
      File.write!(
        # Escribe los pasos distintos y el índice de estabilización.
        "expansion_energia.txt",
        generar_texto_expansion(Enum.reverse(resultado), indice)
      )

      # Devuelve el estado final y el índice en que se estabilizó.
      {estado, indice}
    else
      consumir_expansion(
        estados,
        estado,
        indice + 1,
        # Guarda el paso actual (al inicio de la lista) y sigue con el siguiente índice.
        [{indice, estado} | resultado],
        edificio,
        terrenos,
        bateria
      )
    end
  end

  # generar_texto_expansion/2 (privada)
  # Da formato de texto a los pasos de la relajación.
  #
  # Entradas:
  #   - estados: lista de {paso, mapa}; estabilizacion: índice de estabilización.
  # Proceso:
  #   - Una línea por paso con las posiciones ordenadas por fila y columna: Paso k: (f,c)=costo, ...
  # Salida:
  #   - String listo para escribir en expansion_energia.txt.
  defp generar_texto_expansion(estados, estabilizacion) do
    contenido =
      Enum.map(estados, fn {paso, estado} ->
        posiciones =
          estado
          # Ordena las posiciones por fila y columna.
          |> Enum.sort_by(fn {{x, y}, _costo} -> {x, y} end)
          |> Enum.map(fn {{x, y}, costo} ->
            "(#{x},#{y})=#{costo}"
          end)

        "Paso #{paso}: #{Enum.join(posiciones, ", ")}"
      end)

    Enum.join(contenido, "\n") <>
      "\nÍndice de estabilización: #{estabilizacion}\n"
  end

  # --------------------------------------------------
  # EXPLORACIÓN RECURSIVA DE RECORRIDOS SIMPLES
  # --------------------------------------------------

  @doc """
  Resuelve el problema una vez validados los datos: filtra con la relajación y enumera los recorridos.

  ## Entradas

    * `terreno`: lista de `%Terreno{}`.
    * `bateria`: entero positivo B.
    * `edificio`: matriz validada.

  ## Proceso

    * Localiza S y M y ejecuta la relajación de energía.
    * Si la meta no tiene costo en el estado final, informa que no es alcanzable y genera salidas sin recorrido.
    * Si es alcanzable, enumera recursivamente todos los recorridos simples con `explorar/8`.
    * Guarda el CSV y el resumen, elige el de menor energía y genera el SVG.

  ## Salida

    * Lista de `%Recorrido{}` (o el resultado de escribir el SVG cuando no hay recorrido).
    * Archivos `recorridos_rescate.csv`, `resumen_rescate.txt`, `expansion_energia.txt` y `ruta_optima.svg`.
  """
  def encontrar_recorridos(terreno, bateria, edificio) do
    # Localiza S y M en la matriz.
    inicio = buscar_inicio(edificio)
    meta = buscar_meta(edificio)

    # Relajación de energía como filtro previo (costos mínimos por posición).
    {costos, _indice} =
      expansion_energia(inicio, edificio, terreno, bateria)

    # Si la meta no tiene costo, ninguna ruta llega con energía <= B: se omite la enumeración.
    if not Map.has_key?(costos, List.to_tuple(meta)) do
      IO.puts("La meta no es alcanzable con la batería disponible.")

      # Sin recorridos: CSV solo con el encabezado y resumen negativo.
      guardar_resultados([])
      # Mapa sin ruta, con la leyenda 'sin recorrido'.
      generar_svg(edificio, terreno, nil)
    else
      # Enumeración recursiva de todos los recorridos simples S -> M. Se acumulan al inicio de la
      # lista, por eso se invierten después para conservar el orden de hallazgo.
      recorridos =
        explorar(
          inicio,
          meta,
          edificio,
          terreno,
          bateria,
          [inicio],
          0,
          []
        )
        |> Enum.reverse()

      guardar_resultados(recorridos)

      # Recorrido de menor energía; si hay empate, min_by devuelve el primero encontrado
      # (orden de exploración: arriba, derecha, abajo, izquierda).
      mejor_recorrido =
        Enum.min_by(recorridos, fn recorrido ->
          recorrido.energia
        end)

      # Muestra por pantalla el recorrido de menor energía.
      IO.inspect(mejor_recorrido, label: "Recorrido de menor energía")

      # Dibuja el mapa con ese recorrido resaltado.
      generar_svg(edificio, terreno, mejor_recorrido)

      recorridos
    end
  end

  @doc """
  Explora recursivamente (con retroceso) los recorridos simples desde una posición hasta la meta.

  ## Entradas

    * `posicion`: `[fila, columna]` actual.
    * `meta`: `[fila, columna]` de M.
    * `edificio`, `terreno`, `bateria`: datos del problema.
    * `visitadas`: lista de posiciones ya recorridas (incluye la actual).
    * `energia`: energía acumulada.
    * `recorridos`: acumulador de recorridos encontrados.

  ## Proceso

    * Si la posición es la meta, crea un `%Recorrido{}` y lo agrega al acumulador.
    * Si no, delega en `verificar_caminos/9`, que prueba las cuatro direcciones.

  ## Salida

    * Lista de `%Recorrido{}` con los recorridos encontrados hasta el momento (más reciente primero).
  """
  def explorar(
        posicion,
        meta,
        edificio,
        terreno,
        bateria,
        visitadas,
        energia,
        recorridos
      ) do
    # Caso base: se llegó a la meta; se registra el recorrido.
    if posicion == meta do
      # 'visitadas' ya contiene la ruta completa desde S.
      recorrido = %Recorrido{
        posiciones: visitadas,
        energia: energia
      }

      # Se agrega al inicio de la lista de recorridos.
      [recorrido | recorridos]
    else
      # Caso recursivo: prueba las cuatro direcciones desde la posición actual.
      verificar_caminos(
        posicion,
        meta,
        edificio,
        terreno,
        bateria,
        visitadas,
        energia,
        @direcciones,
        recorridos
      )
    end
  end

  @doc """
  Prueba las direcciones pendientes desde una posición y acumula los recorridos que llegan a la meta.

  ## Entradas

    * `posicion`, `meta`, `edificio`, `terreno`, `bateria`, `visitadas`, `energia`: igual que en `explorar/8`.
    * `direcciones`: direcciones por probar, en el orden fijo arriba, derecha, abajo, izquierda.
    * `recorridos`: acumulador.

  ## Proceso

    * Con la lista vacía devuelve el acumulador (caso base).
    * Con una dirección: calcula la casilla vecina; si no fue visitada y es transitable, y la energía no supera B, llama a `explorar/8` para ella.
    * Luego continúa con las direcciones restantes.

  ## Salida

    * Lista de `%Recorrido{}` actualizada.
  """
  def verificar_caminos(
        _posicion,
        _meta,
        _edificio,
        _terreno,
        _bateria,
        _visitadas,
        _energia,
        [],
        recorridos
      ) do
    recorridos
  end

  # Caso recursivo: procesa la primera dirección y continúa con la cola.
  def verificar_caminos(
        posicion,
        meta,
        edificio,
        terreno,
        bateria,
        visitadas,
        energia,
        [direccion | cola],
        recorridos
      ) do
    # Casilla vecina en la dirección actual. La posición se guarda como tupla para mover/2 y como lista
    # [fila, columna] en 'visitadas'.
    siguiente = mover(List.to_tuple(posicion), direccion)
    {x, y} = siguiente
    siguiente_lista = [x, y]

    nuevos_recorridos =
      # Solo se avanza si la casilla no fue visitada (recorrido simple) y es transitable.
      if siguiente_lista not in visitadas and
           verificar(x, y, edificio, terreno) do
        case obtener_terreno(x, y, edificio, terreno) do
          # Pattern matching + guarda: acepta el terreno transitable solo si la energía acumulada más su
          # costo no supera la batería. Paredes y rutas sin energía caen en el caso '_'.
          %Terreno{transitable: true, costo: costo}
          when energia + costo <= bateria ->
            # Avanza recursivamente: la nueva casilla se agrega a 'visitadas' y se suma su costo. Como las listas son
            # inmutables, al volver de la llamada 'visitadas' no cambió: el retroceso es automático.
            explorar(
              siguiente_lista,
              meta,
              edificio,
              terreno,
              bateria,
              visitadas ++ [siguiente_lista],
              energia + costo,
              recorridos
            )

          _ ->
            recorridos
        end
      else
        recorridos
      end

    # Continúa con las direcciones restantes usando los recorridos acumulados hasta ahora.
    verificar_caminos(
      posicion,
      meta,
      edificio,
      terreno,
      bateria,
      visitadas,
      energia,
      cola,
      nuevos_recorridos
    )
  end

  @doc """
  Indica si una casilla es transitable.

  ## Entradas

    * `x`, `y`: fila y columna.
    * `edificio`: matriz.
    * `terreno`: lista de `%Terreno{}`.

  ## Proceso

    * Obtiene el terreno de la casilla y comprueba con pattern matching que `transitable` sea `true`.

  ## Salida

    * `true` si la casilla existe y es transitable; `false` en caso contrario.
  """
  def verificar(x, y, edificio, terreno) do
    case obtener_terreno(x, y, edificio, terreno) do
      %Terreno{transitable: true} -> true
      _ -> false
    end
  end

  # --------------------------------------------------
  # GUARDAR CSV Y RESUMEN
  # --------------------------------------------------

  # guardar_resultados/1 (privada) - sin recorridos
  # Escribe las salidas cuando no existe ningún recorrido válido.
  #
  # Entradas:
  #   - Lista vacía de recorridos.
  # Proceso:
  #   - Escribe el CSV solo con el encabezado y un resumen negativo.
  # Salida:
  #   - recorridos_rescate.csv, resumen_rescate.txt y el mismo mensaje por pantalla.
  defp guardar_resultados([]) do
    File.write!(
      # Sin recorridos: el CSV solo contiene el encabezado.
      "recorridos_rescate.csv",
      "id;movimientos;energia;posiciones\n"
    )

    resumen = "No existe ningún recorrido válido.\n"

    File.write!("resumen_rescate.txt", resumen)
    IO.puts(resumen)
  end

  # guardar_resultados/1 (privada) - con recorridos
  # Escribe el CSV y el resumen de los recorridos encontrados.
  #
  # Entradas:
  #   - recorridos: lista de %Recorrido{} (en orden de hallazgo).
  # Proceso:
  #   - Una fila CSV por recorrido; calcula el mínimo de movimientos y de energía (criterios independientes)
  #   - y conserva todos los empates.
  # Salida:
  #   - recorridos_rescate.csv (separador ;), resumen_rescate.txt y el resumen por pantalla.
  defp guardar_resultados(recorridos) do
    # Una fila por recorrido: id;movimientos;energia;posiciones (movimientos = posiciones - 1).
    filas =
      recorridos
      |> Enum.with_index(1)
      |> Enum.map(fn {%Recorrido{posiciones: posiciones, energia: energia}, id} ->
        movimientos = length(posiciones) - 1

        posiciones_texto =
          Enum.map_join(posiciones, " -> ", fn [x, y] ->
            "(#{x},#{y})"
          end)

        "#{id};#{movimientos};#{energia};#{posiciones_texto}"
      end)

    File.write!(
      # Escribe el CSV completo: encabezado + filas.
      "recorridos_rescate.csv",
      "id;movimientos;energia;posiciones\n" <>
        Enum.join(filas, "\n") <> "\n"
    )

    # Mínimos de cada criterio (no se presupone que coincidan).
    menos_movimientos =
      recorridos
      |> Enum.map(&(length(&1.posiciones) - 1))
      |> Enum.min()

    menor_energia =
      recorridos
      |> Enum.map(& &1.energia)
      |> Enum.min()

    # Se conservan todos los recorridos empatados en cada criterio.
    mejores_movimientos =
      Enum.filter(recorridos, fn recorrido ->
        length(recorrido.posiciones) - 1 == menos_movimientos
      end)

    mejores_energias =
      Enum.filter(recorridos, fn recorrido ->
        recorrido.energia == menor_energia
      end)

    # Texto del resumen: también se escribe en resumen_rescate.txt y se muestra por pantalla.
    resumen = """
    Total de recorridos: #{length(recorridos)}

    Menor cantidad de movimientos: #{menos_movimientos}
    Recorridos que cumplen:
    #{formatear_recorridos(mejores_movimientos)}

    Menor consumo de energía: #{menor_energia}
    Recorridos que cumplen:
    #{formatear_recorridos(mejores_energias)}
    """

    File.write!("resumen_rescate.txt", resumen)
    IO.puts(resumen)
  end

  # formatear_recorridos/1 (privada)
  # Da formato de texto a una lista de recorridos.
  #
  # Entradas:
  #   - recorridos: lista de %Recorrido{}.
  # Proceso:
  #   - Cada recorrido se convierte en '(f,c) -> (f,c) -> ...' y se une con saltos de línea.
  # Salida:
  #   - String con un recorrido por línea.
  defp formatear_recorridos(recorridos) do
    recorridos
    |> Enum.map(fn recorrido ->
      Enum.map_join(recorrido.posiciones, " -> ", fn [x, y] ->
        "(#{x},#{y})"
      end)
    end)
    |> Enum.join("\n")
  end

  # --------------------------------------------------
  # GENERACIÓN DEL SVG
  # --------------------------------------------------

  # generar_svg/3 (privada)
  # Dibuja el edificio y el recorrido de menor energía en ruta_optima.svg.
  #
  # Entradas:
  #   - edificio: matriz; terrenos: lista de %Terreno{}; recorrido: %Recorrido{} o nil.
  # Proceso:
  #   - Cada casilla es un cuadrado de 40 x 40 px con color según su símbolo y el nombre del terreno (escapado para XML).
  #   - Con recorrido dibuja una polilínea roja por los centros de las casillas; con nil escribe la leyenda 'sin recorrido'.
  # Salida:
  #   - Archivo ruta_optima.svg.
  defp generar_svg(edificio, terrenos, recorrido) do
    # Cada casilla mide 40 x 40 píxeles.
    tamano = 40
    alto = length(edificio)
    ancho = length(hd(edificio))

    # Color de relleno por símbolo; los símbolos sin color usan blanco.
    colores = %{
      "X" => "#333333",
      "." => "#eeeeee",
      "L" => "#987044",
      "S" => "#65b96c",
      "M" => "#e5c44d"
    }

    # Un rectángulo (fondo) y un texto (nombre del terreno) por cada casilla.
    casillas =
      edificio
      |> Enum.with_index()
      |> Enum.map(fn {fila, x} ->
        fila
        |> Enum.with_index()
        |> Enum.map(fn {simbolo, y} ->
          color = Map.get(colores, simbolo, "#ffffff")

          # Nombre del terreno, tomado de terrenos.csv, para rotular la casilla.
          texto =
            case Enum.find(terrenos, &(&1.simbolo == simbolo)) do
              nil -> ""
              terreno -> terreno.nombre
            end

          """
          <rect x="#{y * tamano}" y="#{x * tamano}"
            width="#{tamano}" height="#{tamano}"
            fill="#{color}" stroke="#333333"/>
          <text x="#{y * tamano + 20}" y="#{x * tamano + 24}"
            text-anchor="middle" font-size="12">#{escapar_xml(texto)}</text>
          """
        end)
      end)
      |> List.flatten()
      |> Enum.join("\n")

    # Sin recorrido: leyenda de texto. Con recorrido: polilínea roja que une los centros de las casillas.
    linea_ruta =
      case recorrido do
        nil ->
          """
          <text x="10" y="#{alto * tamano + 25}"
            font-size="16">sin recorrido</text>
          """

        %Recorrido{posiciones: posiciones} ->
          # Centro de cada casilla: x = columna * 40 + 20, y = fila * 40 + 20.
          puntos =
            Enum.map_join(posiciones, " ", fn [x, y] ->
              "#{y * tamano + 20},#{x * tamano + 20}"
            end)

          """
          <polyline points="#{puntos}"
            fill="none" stroke="#ff0000"
            stroke-width="5" stroke-linejoin="round"/>
          """
      end

    # Documento SVG completo (casillas + ruta).
    svg = """
    <?xml version="1.0" encoding="UTF-8"?>
    <svg xmlns="http://www.w3.org/2000/svg"
      width="#{ancho * tamano}"
      height="#{alto * tamano + 35}"
      viewBox="0 0 #{ancho * tamano} #{alto * tamano + 35}">
      #{casillas}
      #{linea_ruta}
    </svg>
    """

    # Escribe el archivo SVG en el directorio de trabajo.
    File.write!("ruta_optima.svg", svg)
  end

  # escapar_xml/1 (privada)
  # Escapa los caracteres especiales de XML para poder insertar texto en el SVG.
  #
  # Entradas:
  #   - texto: string.
  # Proceso:
  #   - Reemplaza & < > " y ' por sus entidades (&amp; primero, para no escapar dos veces).
  # Salida:
  #   - String seguro para XML.
  defp escapar_xml(texto) do
    texto
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end

# Punto de entrada: al ejecutar 'elixir recorrido_rescate.exs' se llama a main/0.
Recorrido_Rescate.main()
