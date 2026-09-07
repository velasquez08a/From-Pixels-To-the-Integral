# Practice I - From Pixels to the Integral

ST0244 - Programación de Paradigmas · School of Applied Sciences and Engineering · EAFIT University
Docente: Alexander Narváez Berrío (anarvae1@eafit.edu.co) · Ago 2026

## Integrantes

- Juanita Santa Bedoya
- Andrés Julián Velásquez

## Descripción

El profesor entrega una imagen binaria en formato **PBM P4** (`curva_binaria_P4.pbm`) que representa
una región bajo una curva. Este repositorio resuelve el mismo problema matemático con dos paradigmas
distintos:

- **Haskell** (programación funcional)
- **Prolog** (programación lógica/declarativa)

Ambos programas leen el mismo archivo directamente en binario, calculan el área bajo la curva y
producen **exactamente el mismo resultado**: ese número es la comprobación de que ambos paradigmas
están describiendo el mismo problema.

## Objetivo

Explorar cómo un mismo problema matemático —encontrar el área bajo una curva discreta a partir de una
imagen— se expresa de maneras distintas según el paradigma de programación:

- En Haskell, como una **transformación de datos**: `dominio -> alturas -> área`.
- En Prolog, como una **colección de relaciones**: `f(X,Y) -> todos los Y que satisfacen f -> área`.

## Interpretación matemática

Para cada posición horizontal `x` de la imagen se recorre la columna correspondiente **desde la fila
inferior hacia arriba**, contando píxeles negros consecutivos hasta encontrar el primer píxel blanco:

```
f(x) = cantidad de píxeles negros consecutivos desde la parte inferior de la columna x
```

Con esos valores se construye el vector de alturas:

```
M = [f(0), f(1), f(2), ..., f(n-1)]
```

Como cada columna tiene base `Δx = 1 píxel`, cada `f(x)` es la altura de un rectángulo de una suma de
Riemann con `Δx = 1`. El área total es entonces:

```
A = Σ f(x)   para x = 0 .. n-1
A = sum(M)
```

El resultado se expresa en **píxeles cuadrados**.

## PBM P4

PBM P4 es un formato **binario** (no de texto). Su estructura es:

```
P4
<ancho> <alto>
<datos binarios de píxeles>
```

- Puede haber comentarios (`# ...`) y espacios/saltos de línea entre los tokens de la cabecera.
- Tras el token del alto hay **exactamente un** carácter de separación antes de que empiecen los datos.
- Los píxeles están **compactados en bits**: un byte contiene hasta 8 píxeles, con el bit `1`
  representando negro y el bit más significativo como el primer píxel del byte.
- Si el ancho no es múltiplo de 8, la última posición de cada byte de fila queda como **padding** y no
  se consulta nunca.

Para el píxel `(x, y)`:

```
bytesPorFila = ceil(ancho / 8)
índiceByte   = y * bytesPorFila + x div 8
posiciónBit  = 7 - (x mod 8)
negro        = bit(byte, posiciónBit) == 1
```

`y = 0` es la primera fila almacenada en el archivo (la fila superior de la imagen); por eso `f(x)`
empieza a contar desde `y = alto - 1` (la fila inferior) y sube.

## Haskell

La solución en `Haskell/Main.hs` está organizada en funciones puras y pequeñas: lectura de bytes,
separación de cabecera y datos, acceso a bits/píxeles, `f`, construcción de `M` y cálculo del área.
La idea funcional central son dos líneas:

```haskell
m    = map (f img) [0 .. ancho img - 1]  -- M es la aplicación de f a todo el dominio
area = sum m                              -- el área es la suma de Riemann (Δx = 1)
```

No hay bucles imperativos: se usan `map`, `sum`, `takeWhile`, listas por comprensión y recursión donde
corresponde (por ejemplo, en el parser de la cabecera).

## Prolog

La solución en `Prolog/main.pl` describe el problema como relaciones, no como procedimientos. La
relación central es:

```prolog
f(X, ArrayDatos, Alto, BytesPorFila, Altura)
```

que se lee como *"Altura es la altura asociada a la columna X en esta imagen"*. La lista `M` se obtiene
preguntándole a Prolog **todos** los valores que satisfacen esa relación:

```prolog
findall(Altura, (between(0, MaxX, X), f(X, ArrayDatos, Alto, BytesPorFila, Altura)), M),
sum_list(M, Area).
```

Los datos binarios se convierten en un término compuesto (`v(Byte0, Byte1, ...)`) para poder acceder a
cualquier byte con `arg/3` en tiempo prácticamente constante, en vez de recorrer una lista con `nth0/3`
en cada consulta de píxel.

## Visualización

Ambos programas dividen `M` en bloques de columnas y **promedian** cada bloque antes de dibujar nada,
para caber en una terminal razonable. **Esta reducción es únicamente visual**: el área siempre se
calcula sobre la lista `M` completa (una entrada por cada columna real de la imagen), antes de
compactar nada para mostrarla en pantalla. Cada implementación usa su propio estilo de dibujo:

- **Haskell** dibuja la curva con una rejilla de 120x25 usando bloques Unicode con resolución de
  "sub-píxel" (`▂▃▄▅▆▇█`): cada fila de terminal se divide en 8 niveles internos, así que una columna
  puede llenar parcialmente una fila con un bloque intermedio en vez de solo lleno/vacío, dando una
  curva más suave.
- **Prolog** dibuja la curva con una rejilla de 80x20 usando solo el carácter ASCII `#`, y la función
  de alturas con una rampa de densidad en caracteres ASCII (`.:-=+*#%@`).

> **Nota:** la versión de Haskell usa caracteres Unicode y cambia el encoding de la salida con
> `hSetEncoding stdout utf8`. Si al ejecutarlo en Windows aparecen símbolos rotos o un error de
> codificación en la consola, cambia esos caracteres por ASCII simple (por ejemplo `#` y
> `.:-=+*#%@`, como ya hace la versión de Prolog) y quita esa línea de `hSetEncoding`; el resultado
> numérico no cambia.

## Ejecución de Haskell

Requiere **GHC** (recomendado 9.4 o superior). Este programa busca `curva_binaria_P4.pbm` en el
**directorio desde el que se ejecuta**, así que se debe compilar y correr **desde la raíz del
repositorio** (donde está el `.pbm`), no desde dentro de la carpeta `Haskell/`:

```bash
ghc -O2 -o Haskell/main Haskell/Main.hs
./Haskell/main
```

En Windows (PowerShell), igual, parado en la raíz del repositorio:

```powershell
ghc -O2 -o Haskell\main.exe Haskell\Main.hs
.\Haskell\main.exe
```

## Ejecución de Prolog

Requiere **SWI-Prolog** (recomendado 9.0 o superior).

```bash
cd Prolog
swipl -q -g main -t halt main.pl
```

A diferencia de Haskell, este programa sí funciona ejecutándose **desde la carpeta `Prolog/`**: al
cargar el archivo detecta automáticamente en qué carpeta está guardado `main.pl` y busca el `.pbm` ahí
mismo y en la carpeta superior (`../curva_binaria_P4.pbm`), que es donde vive en este repositorio.

El programa se ejecuta con este único comando (carga el archivo, corre `main` automáticamente y cierra
al terminar), y al final espera a que se presione **ENTER** antes de cerrar la ventana, para que toda
la salida quede visible en pantalla al grabar el video.

**Nota para Windows:** si `swipl` no se reconoce en la terminal, usa la ruta completa al ejecutable:

```powershell
& "C:\Program Files\swipl\bin\swipl.exe" -q -g main -t halt main.pl
```

## Resultado

Ejecutado con el archivo `curva_binaria_P4.pbm` real entregado por el profesor:

```
Imagen: 567 x 319 píxeles (bytes por fila = 71)

Valores de muestra:
  x = 0    -> f(x) = 224 píxeles
  x = 63   -> f(x) = 239 píxeles
  x = 126  -> f(x) = 227 píxeles
  x = 189  -> f(x) = 225 píxeles
  x = 252  -> f(x) = 238 píxeles
  x = 314  -> f(x) = 229 píxeles
  x = 377  -> f(x) = 176 píxeles
  x = 440  -> f(x) = 113 píxeles
  x = 503  -> f(x) = 97  píxeles
  x = 566  -> f(x) = 145 píxeles

Área (Haskell) = 108660 píxeles cuadrados
Área (Prolog)  = 108660 píxeles cuadrados
```

Las dos implementaciones producen exactamente la misma área (108660 píxeles cuadrados) y los mismos
valores de muestra. Este número coincide además con el que obtiene el programa de referencia en C++
del profesor para esta misma imagen (Figura 1 de la guía), lo cual confirma que la lectura del PBM P4,
el acceso a bits y el cálculo de `f(x)` son correctos.

## Comparación de paradigmas

| | Haskell (funcional) | Prolog (lógico/declarativo) |
|---|---|---|
| Pregunta que responde | "¿Qué transformación lleva del dominio al resultado?" | "¿Qué relación deben cumplir X, la imagen y su altura?" |
| Flujo conceptual | `dominio -> alturas -> área` | `relaciones -> valores que satisfacen f(X) -> área` |
| Construcción de M | `map f [0 .. ancho-1]` | `findall(Altura, f(X,...,Altura), M)` |
| Cálculo del área | `sum M` | `sum_list(M, Area)` |
| Estilo | Se define **cómo** transformar los datos paso a paso mediante funciones puras. | Se define **qué** debe cumplirse, y Prolog busca todos los valores que lo satisfacen. |

En ambos casos el archivo PBM se lee directamente en binario y `f(x)` está definida sobre los mismos
bits; la diferencia está en cómo se expresa la construcción de `M` y el recorrido del dominio.
