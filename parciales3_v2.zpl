# ============================================================================
# MODELO PARTE 3 - MAXIMIZAR DISPERSIÓN TEMPORAL (CORREGIDO)
# ============================================================================
# - Índices de días reparados: los días 9..12 quedan realmente "lejanos" respecto
#   de 1..5 para que el solver tenga incentivo real a usarlos.
# - Linealización exacta de |idx[p1] - idx[p2]|.
# - M elegido en función del rango de índices.
# ============================================================================

# ----------------------------------------------------------------------------
# SETS
# ----------------------------------------------------------------------------
set P := { read "cursos.dat" as "<1s>" };                       # Parciales
set D := { 1, 2, 3, 4, 5, 9, 10, 11, 12 };                     # Días hábiles
set H := { 9, 12, 15, 18 };                                     # Horarios

# Pares con estudiantes en común (lista tal cual está en el .dat)
set E := { read "estudiantes-en-comun.dat" as "<1s,2s>" };

# ----------------------------------------------------------------------------
# PARÁMETROS
# ----------------------------------------------------------------------------
param capacidad := 75;

# Aulas requeridas por cada parcial
param aulas[P] := read "cursos.dat" as "<1s> 2n";

# Peso = cantidad de estudiantes en común entre dos parciales
param w[E] := read "estudiantes-en-comun.dat" as "<1s,2s> 3n";

# ---------------------------
# Indice de días: mapear días reales a un eje con salto entre 5 y 9
# ---------------------------
# Elegimos un salto suficiente para que 9..12 queden efectivamente lejos.
# Por ejemplo: 1..5 => 1..5, 9..12 => 20..23  (gap = 15)
param indice[D] := <1> 1, <2> 2, <3> 3, <4> 4, <5> 5,
                   <9> 20, <10> 21, <11> 22, <12> 23;

# Máximo índice posible (para acotar variables)
param MAX_IDX := 23;

# Big-M: suficientemente mayor que la distancia máxima posible (23-1=22)
# Elegí M=100 como valor numérico pequeño pero seguro.
param M := 100;

# ----------------------------------------------------------------------------
# VARIABLES
# ----------------------------------------------------------------------------

# x[p,d,h] = 1 si parcial p se asigna en día d, hora h
var x[P * D * H] binary;

# y[p] = 1 si parcial p está asignado (en algún día/hora)
var y[P] binary;

# idx[p] = índice del día asignado a p (0 si no asignado; 1..MAX_IDX si asignado)
var idx[P] integer >= 0 <= MAX_IDX;

# t[p1,p2] = idx[p1] - idx[p2]  (puede ser negativo)
var t[E] integer >= -MAX_IDX <= MAX_IDX;

# distancia[p1,p2] = |t[p1,p2]| cuando ambos asignados, 0 si alguno no asignado
var distancia[E] integer >= 0 <= MAX_IDX;

# ----------------------------------------------------------------------------
# FUNCIÓN OBJETIVO
# ----------------------------------------------------------------------------

maximize dispersion_total:
  sum <p1,p2> in E: w[p1,p2] * distancia[p1,p2];

# ----------------------------------------------------------------------------
# RESTRICCIONES
# ----------------------------------------------------------------------------

# (R1) Asignación única: si y[p]=1 debe estar exactamente en un slot (día+hora)
subto asignacion_unica:
  forall <p> in P:
    sum <d,h> in D * H: x[p,d,h] == y[p];

# (R2) Incompatibilidades: pares con estudiantes en común no en el mismo slot
subto incompatibilidades:
  forall <p1,p2> in E:
    forall <d,h> in D * H:
      x[p1,d,h] + x[p2,d,h] <= 1;

# (R3) Capacidad de aulas por slot
subto capacidad_aulas:
  forall <d,h> in D * H:
    sum <p> in P: aulas[p] * x[p,d,h] <= capacidad;

# (R4) Linking idx[p] con día asignado: idx = indice[d] si x[p,d,h]=1
#     (si no asignado, idx queda 0)
subto linking_idx:
  forall <p> in P:
    idx[p] == sum <d,h> in D * H: indice[d] * x[p,d,h];

# (R5) Definición de t = idx[p1] - idx[p2]
subto definir_t:
  forall <p1,p2> in E:
    t[p1,p2] == idx[p1] - idx[p2];

# (R6) Si alguno no asignado => distancia debe ser 0
#      distancia <= M * y[p1]; distancia <= M * y[p2]
subto distancia_cero_si_no_asignado_1:
  forall <p1,p2> in E:
    distancia[p1,p2] <= M * y[p1];

subto distancia_cero_si_no_asignado_2:
  forall <p1,p2> in E:
    distancia[p1,p2] <= M * y[p2];

# (R7) Igualdad absoluta usando t: cuando ambos asignados, distancia == |t|
#      Linealizamos con 4 desigualdades que encajan cuando y[p1]=y[p2]=1
#  - distancia >=  t - M*(2 - y1 - y2)
#  - distancia >= -t - M*(2 - y1 - y2)
#  - distancia <=  t + M*(2 - y1 - y2)
#  - distancia <= -t + M*(2 - y1 - y2)
subto distancia_ge_t_pos:
  forall <p1,p2> in E:
    distancia[p1,p2] >= t[p1,p2] - M * (2 - y[p1] - y[p2]);

subto distancia_ge_t_neg:
  forall <p1,p2> in E:
    distancia[p1,p2] >= -t[p1,p2] - M * (2 - y[p1] - y[p2]);

subto distancia_le_t_pos:
  forall <p1,p2> in E:
    distancia[p1,p2] <= t[p1,p2] + M * (2 - y[p1] - y[p2]);

subto distancia_le_t_neg:
  forall <p1,p2> in E:
    distancia[p1,p2] <= -t[p1,p2] + M * (2 - y[p1] - y[p2]);

# ----------------------------------------------------------------------------
# NOTAS / SUGERENCIAS
# ----------------------------------------------------------------------------
# - Con el mapping de indice con gap (20..23) los días 9..12 generan
#   distancias reales grandes respecto a 1..5; el solver tendrá incentivo
#   real a usar esos días si eso aumenta la suma ponderada w*distancia.
#
# - M se fijó en 100; con idx en [0..23] la distancia máxima es 22.
#   M=100 es seguro y no demasiado grande (mejor que 10000).
#
# - Si querés reducir cantidad de variables, podés filtrar E por peso:
#     set E2 := { <p,q> in E | w[p,q] >= WMIN };
#   y sustituir E por E2 en las variables/constraints de distancia/t.
#
# - Si necesitás que el modelo maximice primero #de parciales asignados
#   y luego dispersion (lexicográfico), puedo volver a añadir esa
#   prioridad (M * sum y[p] + dispersion). Actualmente el modelo
#   maximiza SOLO dispersión ponderada (como tu enunciado 3).
# ============================================================================