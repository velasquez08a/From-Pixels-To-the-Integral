-- Practice I - From Pixels to the Integral: Area under a curve
-- ST0244 - Programming Paradigms - EAFIT University
-- Solución funcional en Haskell.
--
-- Transformación implementada:
--   imagen binaria (PBM P4) -> bytes -> bits -> píxeles -> f(x) -> M -> área

module Main where

import qualified Data.ByteString as BS
import Data.Bits (testBit)
import Data.Word (Word8)
import Data.Char (chr)
import Data.List (nub)
import Control.Monad (unless, forM_)
import Text.Printf (printf)
import System.IO (hSetEncoding, stdout, utf8)

-- ==========================================================
-- Tipo de datos: imagen PBM P4 ya decodificada
-- ==========================================================

data ImagenPBM = ImagenPBM
  { ancho        :: Int
  , alto         :: Int
  , bytesPorFila :: Int
  , datos        :: BS.ByteString
  }

-- ==========================================================
-- 1. LECTURA DEL ARCHIVO PBM P4 (binario, sin conversión manual)
-- ==========================================================

leerArchivoPBM :: FilePath -> IO BS.ByteString
leerArchivoPBM = BS.readFile

leerToken :: BS.ByteString -> (String, BS.ByteString)
leerToken bs0 =
  let bs1 = saltarEspaciosYComentarios bs0
      (tokenBytes, resto) = BS.span (not . esEspacio) bs1
  in (map (chr . fromIntegral) (BS.unpack tokenBytes), resto)

saltarEspaciosYComentarios :: BS.ByteString -> BS.ByteString
saltarEspaciosYComentarios bs
  | BS.null bs                = bs
  | esEspacio (BS.head bs)    = saltarEspaciosYComentarios (BS.drop 1 bs)
  | BS.head bs == 35          = saltarEspaciosYComentarios (BS.dropWhile (/= 10) bs)
  | otherwise                 = bs

esEspacio :: Word8 -> Bool
esEspacio w = w == 32 || w == 9 || w == 10 || w == 13

procesarCabecera :: BS.ByteString -> (String, Int, Int, BS.ByteString)
procesarCabecera bs =
  let (magic, resto1)   = leerToken bs
      (anchoStr, resto2) = leerToken resto1
      (altoStr, resto3)  = leerToken resto2
      datosImg           = BS.drop 1 resto3
  in (magic, read anchoStr, read altoStr, datosImg)

bytesPorFilaDe :: Int -> Int
bytesPorFilaDe w = (w + 7) `div` 8

cargarPBM :: FilePath -> IO ImagenPBM
cargarPBM ruta = do
  bytes <- leerArchivoPBM ruta
  unless (not (BS.null bytes)) $
    error ("Archivo vacío o no encontrado: " ++ ruta)
  let (magic, w, h, datosImg) = procesarCabecera bytes
  unless (magic == "P4") $
    error ("Formato inesperado (" ++ magic ++ "); se esperaba P4.")
  unless (w > 0 && h > 0) $
    error "Dimensiones inválidas: ancho y alto deben ser positivos."
  let bpf = bytesPorFilaDe w
  unless (BS.length datosImg >= bpf * h) $
    error "Datos binarios insuficientes para las dimensiones declaradas."
  return ImagenPBM { ancho = w, alto = h, bytesPorFila = bpf, datos = datosImg }

-- ==========================================================
-- 2. ACCESO A PÍXELES INDIVIDUALES
-- ==========================================================

esPixelNegro :: ImagenPBM -> Int -> Int -> Bool
esPixelNegro img x y
  | x < 0 || x >= ancho img || y < 0 || y >= alto img =
      error (printf "Coordenada fuera de rango: (%d, %d)" x y)
  | otherwise = testBit byte posicionBit
  where
    indiceByte  = y * bytesPorFila img + x `div` 8
    posicionBit = 7 - (x `mod` 8)
    byte        = BS.index (datos img) indiceByte

-- ==========================================================
-- 3. FUNCIÓN f(x): PÍXELES NEGROS CONSECUTIVOS DESDE ABAJO
-- ==========================================================

f :: ImagenPBM -> Int -> Int
f img x = length (takeWhile (esPixelNegro img x) filasDesdeAbajo)
  where
    filasDesdeAbajo = [alto img - 1, alto img - 2 .. 0]

-- ==========================================================
-- 4. CONSTRUCCIÓN DE M Y CÁLCULO DEL ÁREA (SUMA DE RIEMANN)
-- ==========================================================

construirM :: ImagenPBM -> [Int]
construirM img = map (f img) [0 .. ancho img - 1]

calcularArea :: [Int] -> Int
calcularArea = sum

-- ==========================================================
-- 5. VALORES DE MUESTRA (mínimo 10 posiciones distribuidas)
-- ==========================================================

muestras :: Int -> Int -> [Int] -> [(Int, Int)]
muestras n w m = [ (x, m !! x) | x <- posiciones ]
  where
    posiciones
      | n <= 1    = [0]
      | otherwise = nub [ round (fromIntegral i * fromIntegral (w - 1)
                                  / fromIntegral (n - 1) :: Double)
                        | i <- [0 .. n - 1] ]

-- ==========================================================
-- 6. VISUALIZACIÓN DE ALTA RESOLUCIÓN (SUAVE CON SUBPÍXELES)
-- ==========================================================

anchoTerminal, altoTerminal :: Int
anchoTerminal = 120
altoTerminal  = 25

bloquesSubpixel :: String
bloquesSubpixel = "  ▂▃▄▅▆▇█"

compactarM :: Int -> [Int] -> [Double]
compactarM nCols m = map promedioBloque (tomarBloques tam m)
  where
    n   = length m
    tam = max 1 (n `div` max 1 nCols)
    promedioBloque bloque = fromIntegral (sum bloque) / fromIntegral (length bloque)

tomarBloques :: Int -> [a] -> [[a]]
tomarBloques _ [] = []
tomarBloques tam xs =
  let (b, resto) = splitAt tam xs
  in if null resto then [b] else b : tomarBloques tam resto

dibujarCurva :: [Int] -> IO ()
dibujarCurva m = do
  let compacta   = compactarM anchoTerminal m
      maxAltura  = maximum (1 : compacta)
      subpixels  = map (\h -> h / maxAltura * fromIntegral (altoTerminal * 8)) compacta
  
  forM_ [altoTerminal, altoTerminal - 1 .. 1] $ \fila -> do
    let renderCol sp =
          let minSp = fromIntegral ((fila - 1) * 8)
              maxSp = fromIntegral (fila * 8)
          in if sp >= maxSp
             then '█'
             else if sp <= minSp
                  then ' '
                  else let idx = round (sp - minSp)
                       in bloquesSubpixel !! min 8 (max 0 idx)
    putStrLn [ renderCol sp | sp <- subpixels ]

-- ==========================================================
-- 7. VISUALIZACIÓN DE LA FUNCIÓN DE ALTURAS M[x] = f(x)
-- ==========================================================

nivelesBloque :: String
nivelesBloque = " ▁▂▃▄▅▆▇█"

dibujarSparklineM :: [Int] -> IO ()
dibujarSparklineM m = putStrLn [ nivelesBloque !! nivel h | h <- compacta ]
  where
    compacta  = compactarM anchoTerminal m
    maxAltura = maximum (1 : compacta)
    nNiveles  = length nivelesBloque - 1
    nivel h   = round (h / maxAltura * fromIntegral nNiveles)

-- ==========================================================
-- PROGRAMA PRINCIPAL
-- ==========================================================

rutaPBM :: FilePath
rutaPBM = "curva_binaria_P4.pbm"

main :: IO ()
main = do
  hSetEncoding stdout utf8
  img <- cargarPBM rutaPBM

  putStrLn "=============================================="
  putStrLn " PRACTICE I - FROM PIXELS TO THE INTEGRAL"
  putStrLn " Paradigma: Programación funcional (Haskell)"
  putStrLn "=============================================="
  printf "Imagen: %d x %d pixeles (bytes por fila = %d)\n\n"
         (ancho img) (alto img) (bytesPorFila img)

  let m = construirM img

  putStrLn "Curva original (imagen -> bits -> pixeles -> f(x)):"
  dibujarCurva m
  putStrLn ""

  putStrLn "Funcion de alturas M[x] = f(x):"
  dibujarSparklineM m
  putStrLn ""

  putStrLn "Valores de muestra x_i -> f(x_i):"
  forM_ (muestras 10 (ancho img) m) $ \(x, fx) ->
    printf "  x = %-6d -> f(x) = %d pixeles\n" x fx
  putStrLn ""

  let area = calcularArea m
  putStrLn "Cada columna tiene base Dx = 1 pixel"
  putStrLn "Area = suma de f(x) = sum(M)"
  printf "AREA TOTAL = %d pixeles cuadrados\n" area