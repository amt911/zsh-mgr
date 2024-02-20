#!/bin/bash

# Definir los datos de la tabla
datos=(
  "Nombre1 Valor1"
  "Nombre2 Valor2"
  "Nombre3 Valor3"
  "Nombre4 Valor4"
)

# Imprimir encabezados
printf "%-20s %-20s\n" "Columna1" "Columna2"

# Imprimir filas
local fila
for fila in "${datos[@]}"; do
  printf "%-20s %-20s\n" $fila
done
unset fila


# Función para imprimir una fila de la tabla
imprimir_fila() {
    local fila="$1"
    echo "+-----------------+-----------------+"
    echo "| ${fila// /                 } |"
}

# Imprimir encabezados
echo "+-----------------+-----------------+"
echo "|     Columna1    |     Columna2    |"
imprimir_fila "Valor1           Valor2"
imprimir_fila "Valor3           Valor4"
imprimir_fila "Valor5           Valor6"
echo "+-----------------+-----------------+"

# Función para imprimir una fila de la tabla
imprimir_fila2() {
    local fila="$1"
    echo "├─────────────────┼─────────────────┤"
    echo "│ $fila │"
}

# Imprimir encabezados
echo "┌─────────────────┬─────────────────┐"
echo "│     Columna1    │     Columna2    │"
imprimir_fila2 "Valor1          │          Valor2"
imprimir_fila2 "Valor3          │          Valor4"
imprimir_fila2 "Valor5          │          Valor6"
echo "└─────────────────┴─────────────────"

# ┌─┬┐  ╔═╦╗  ╓─╥╖  ╒═╤╕
# │ ││  ║ ║║  ║ ║║  │ ││
# ├─┼┤  ╠═╬╣  ╟─╫╢  ╞═╪╡
# └─┴┘  ╚═╩╝  ╙─╨╜  ╘═╧╛
# ┌───────────────────┐
# │  ╔═══╗ Some Text  │▒
# │  ╚═╦═╝ in the box │▒
# ╞═╤══╩══╤═══════════╡▒
# │ ├──┬──┤           │▒
# │ └──┴──┘           │▒
# └───────────────────┘▒
#  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒

p(){
  declare -r p="perro"

  echo "perro"
}

p

echo "p: $p"