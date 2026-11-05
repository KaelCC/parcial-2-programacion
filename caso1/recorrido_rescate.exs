defmodule Terreno do
  defstruct simbolo: "", nombre: "", transitable: false, costo: 0
end

defmodule Recorrido do
  defstruct posiciones: [], energia: 0
end

defmodule Recorrido_Rescate do
  # Orden fijo para explorar y desempatar
  @direcciones ["arriba", "derecha", "abajo", "izquierda"]

  def main() do
    ruta_edificio = Path.join(__DIR__, "edificio.txt")
    ruta_terreno = Path.join(__DIR__, "terrenos.csv")
    ruta_bateria = Path.join(__DIR__, "bateria.txt")

    edificio =
      ruta_edificio
      |> File.stream!()
      |> Stream.map(fn linea ->
        linea |> String.trim() |> String.split()
      end)
      |> Enum.to_list()

    lineas_terreno =
      ruta_terreno
      |> File.stream!()
      |> Stream.map(&String.trim/1)
      |> Enum.to_list()
      |> Enum.reject(&(&1 == ""))

    lineas_bateria =
      ruta_bateria
      |> File.stream!()
      |> Stream.map(&String.trim/1)
      |> Enum.to_list()
      |> Enum.reject(&(&1 == ""))

    {terreno, errores_terreno} = cargar_terrenos(lineas_terreno)
    {bateria, errores_bateria} = cargar_bateria(lineas_bateria)

    errores =
      validar_edificio(edificio, terreno) ++
        errores_terreno ++ errores_bateria

    File.write!(
      "validacion_edificio.txt",
      if errores == [] do
        "Edificio válido. No se encontraron errores.\n"
      else
        Enum.join(errores, "\n")
      end
    )

    if errores != [] do
      IO.puts("Se encontraron errores en la validación:")
      Enum.each(errores, &IO.puts/1)
    else
      IO.puts("Validación correcta.")

      encontrar_recorridos(terreno, bateria, edificio)
    end
  end

  # --------------------------------------------------
  # LECTURA DE TERRENOS
  # --------------------------------------------------

  defp cargar_terrenos(lineas) do
    cargar_terrenos(lineas, 1, [], [])
  end

  defp cargar_terrenos([], _linea, terrenos, errores) do
    {Enum.reverse(terrenos), Enum.reverse(errores)}
  end

  defp cargar_terrenos([linea | cola], numero, terrenos, errores) do
    partes = String.split(String.trim(linea), ",")

    case partes do
      [simbolo, nombre, transitable, costo] ->
        case {transitable, Integer.parse(costo)} do
          {"si", {valor, ""}} when valor >= 0 ->
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

          {"no", {valor, ""}} when valor >= 0 ->
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
              ["Línea #{numero}: registro de terreno inválido." | errores]
            )
        end

      _ ->
        cargar_terrenos(
          cola,
          numero + 1,
          terrenos,
          ["Línea #{numero}: cantidad incorrecta de columnas." | errores]
        )
    end
  end

  # --------------------------------------------------
  # LECTURA DE BATERÍA
  # --------------------------------------------------

  defp cargar_bateria(lineas) do
    case lineas do
      [linea] ->
        case Integer.parse(String.trim(linea)) do
          {valor, ""} when valor > 0 ->
            {valor, []}

          _ ->
            {0, ["Batería: debe ser un entero positivo."]}
        end

      _ ->
        {0, ["Batería: debe existir una sola línea con el presupuesto."]}
    end
  end

  # --------------------------------------------------
  # VALIDACIÓN DEL EDIFICIO
  # --------------------------------------------------

  defp validar_edificio(edificio, terrenos) do
    errores = []

    errores =
      if edificio == [] or Enum.all?(edificio, &(&1 == [])) do
        ["El edificio está vacío." | errores]
      else
        errores
      end

    anchos = Enum.map(edificio, &length/1)

    errores =
      if length(Enum.uniq(anchos)) > 1 do
        ["El edificio no es rectangular." | errores]
      else
        errores
      end

    simbolos = Enum.map(terrenos, & &1.simbolo)

    errores =
      if length(simbolos) != length(Enum.uniq(simbolos)) do
        ["Existen símbolos repetidos en terrenos.csv." | errores]
      else
        errores
      end

    errores =
      if Enum.count(simbolos, &(&1 == "S")) != 1 do
        ["terrenos.csv debe definir S exactamente una vez." | errores]
      else
        errores
      end

    errores =
      if Enum.count(simbolos, &(&1 == "M")) != 1 do
        ["terrenos.csv debe definir M exactamente una vez." | errores]
      else
        errores
      end

    errores = validar_simbolos(edificio, simbolos, 0, errores)
    errores = validar_borde(edificio, errores)

    Enum.reverse(errores)
  end

  defp validar_simbolos([], _simbolos, _fila, errores), do: errores

  defp validar_simbolos([fila | cola], simbolos, numero_fila, errores) do
    errores =
      validar_simbolos_fila(fila, simbolos, numero_fila, 0, errores)

    validar_simbolos(cola, simbolos, numero_fila + 1, errores)
  end

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
      if simbolo in simbolos do
        errores
      else
        [
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

  defp validar_borde_filas([], _fila, _alto, _ancho, errores), do: errores

  defp validar_borde_filas([actual | cola], fila, alto, ancho, errores) do
    errores =
      validar_borde_columnas(actual, fila, 0, alto, ancho, errores)

    validar_borde_filas(cola, fila + 1, alto, ancho, errores)
  end

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
    borde =
      fila == 0 or fila == alto - 1 or
        columna == 0 or columna == ancho - 1

    errores =
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

  defp buscar_inicio(edificio) do
    buscar_simbolo(edificio, "S", 0, 0)
  end

  defp buscar_meta(edificio) do
    buscar_simbolo(edificio, "M", 0, 0)
  end

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

  defp obtener_terreno(x, y, edificio, terrenos) do
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

  defp relajar(estado, edificio, terrenos, bateria) do
    alto = length(edificio)
    ancho = length(hd(edificio))

    posiciones =
      for x <- 0..(alto - 1),
          y <- 0..(ancho - 1),
          do: {x, y}

    Enum.reduce(posiciones, estado, fn {x, y}, acumulado ->
      case obtener_terreno(x, y, edificio, terrenos) do
        %Terreno{transitable: true, costo: costo} ->
          vecinos =
            Enum.map(@direcciones, fn direccion ->
              mover({x, y}, direccion)
            end)

          candidatos =
            Enum.map(vecinos, fn vecino ->
              Map.get(estado, vecino)
            end)
            |> Enum.filter(&is_integer/1)
            |> Enum.map(&(&1 + costo))
            |> Enum.filter(&(&1 <= bateria))

          case candidatos do
            [] ->
              acumulado

            _ ->
              nuevo_costo = Enum.min(candidatos)

              anterior = Map.get(acumulado, {x, y})

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

  defp mover({x, y}, "arriba"), do: {x - 1, y}
  defp mover({x, y}, "derecha"), do: {x, y + 1}
  defp mover({x, y}, "abajo"), do: {x + 1, y}
  defp mover({x, y}, "izquierda"), do: {x, y - 1}

  defp expansion_energia(inicio, edificio, terrenos, bateria) do
    estado_inicial = %{List.to_tuple(inicio) => 0}

    estados =
      Stream.iterate(estado_inicial, fn estado ->
        relajar(estado, edificio, terrenos, bateria)
      end)

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

  defp consumir_expansion(
         estados,
         anterior,
         indice,
         resultado,
         edificio,
         terrenos,
         bateria
       ) do
    estado = Enum.at(estados, indice)

    if anterior != nil and estado == anterior do
      File.write!(
        "expansion_energia.txt",
        generar_texto_expansion(Enum.reverse(resultado), indice)
      )

      {estado, indice}
    else
      consumir_expansion(
        estados,
        estado,
        indice + 1,
        [{indice, estado} | resultado],
        edificio,
        terrenos,
        bateria
      )
    end
  end

  defp generar_texto_expansion(estados, estabilizacion) do
    contenido =
      Enum.map(estados, fn {paso, estado} ->
        posiciones =
          estado
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

  def encontrar_recorridos(terreno, bateria, edificio) do
    inicio = buscar_inicio(edificio)
    meta = buscar_meta(edificio)

    {costos, _indice} =
      expansion_energia(inicio, edificio, terreno, bateria)

    if not Map.has_key?(costos, List.to_tuple(meta)) do
      IO.puts("La meta no es alcanzable con la batería disponible.")

      guardar_resultados([])
      generar_svg(edificio, terreno, nil)
    else
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

      mejor_recorrido =
        Enum.min_by(recorridos, fn recorrido ->
          recorrido.energia
        end)

      IO.inspect(mejor_recorrido, label: "Recorrido de menor energía")

      generar_svg(edificio, terreno, mejor_recorrido)

      recorridos
    end
  end

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
    if posicion == meta do
      recorrido = %Recorrido{
        posiciones: visitadas,
        energia: energia
      }

      [recorrido | recorridos]
    else
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
    siguiente = mover(List.to_tuple(posicion), direccion)
    {x, y} = siguiente
    siguiente_lista = [x, y]

    nuevos_recorridos =
      if siguiente_lista not in visitadas and
           verificar(x, y, edificio, terreno) do
        case obtener_terreno(x, y, edificio, terreno) do
          %Terreno{transitable: true, costo: costo}
          when energia + costo <= bateria ->
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

  def verificar(x, y, edificio, terreno) do
    case obtener_terreno(x, y, edificio, terreno) do
      %Terreno{transitable: true} -> true
      _ -> false
    end
  end

  # --------------------------------------------------
  # GUARDAR CSV Y RESUMEN
  # --------------------------------------------------

  defp guardar_resultados([]) do
    File.write!(
      "recorridos_rescate.csv",
      "id;movimientos;energia;posiciones\n"
    )

    resumen = "No existe ningún recorrido válido.\n"

    File.write!("resumen_rescate.txt", resumen)
    IO.puts(resumen)
  end

  defp guardar_resultados(recorridos) do
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
      "recorridos_rescate.csv",
      "id;movimientos;energia;posiciones\n" <>
        Enum.join(filas, "\n") <> "\n"
    )

    menos_movimientos =
      recorridos
      |> Enum.map(&(length(&1.posiciones) - 1))
      |> Enum.min()

    menor_energia =
      recorridos
      |> Enum.map(& &1.energia)
      |> Enum.min()

    mejores_movimientos =
      Enum.filter(recorridos, fn recorrido ->
        length(recorrido.posiciones) - 1 == menos_movimientos
      end)

    mejores_energias =
      Enum.filter(recorridos, fn recorrido ->
        recorrido.energia == menor_energia
      end)

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

  defp generar_svg(edificio, terrenos, recorrido) do
    tamano = 40
    alto = length(edificio)
    ancho = length(hd(edificio))

    colores = %{
      "X" => "#333333",
      "." => "#eeeeee",
      "L" => "#987044",
      "S" => "#65b96c",
      "M" => "#e5c44d"
    }

    casillas =
      edificio
      |> Enum.with_index()
      |> Enum.map(fn {fila, x} ->
        fila
        |> Enum.with_index()
        |> Enum.map(fn {simbolo, y} ->
          color = Map.get(colores, simbolo, "#ffffff")

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

    linea_ruta =
      case recorrido do
        nil ->
          """
          <text x="10" y="#{alto * tamano + 25}"
            font-size="16">sin recorrido</text>
          """

        %Recorrido{posiciones: posiciones} ->
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

    File.write!("ruta_optima.svg", svg)
  end

  defp escapar_xml(texto) do
    texto
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end

Recorrido_Rescate.main()
