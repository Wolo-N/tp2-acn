# ============================================================================
# MODELO DE ASIGNACIÓN DE PARCIALES - ZIMPL (VERSIÓN 3)
# ============================================================================
# Problema: Asignar parciales maximizando dispersión temporal
#
# FUNCIÓN OBJETIVO:
# Maximizar la dispersión de parciales entre estudiantes, evitando que tengan
# todos sus parciales concentrados en pocas fechas consecutivas.
#
# ESTRATEGIA CON INFORMACIÓN LIMITADA:
# Como solo conocemos estudiantes en común entre PARES de parciales, usamos
# una función objetivo que penaliza cuando dos parciales con estudiantes en
# común están muy cerca en el tiempo. La penalización es proporcional a:
#   - Número de estudiantes en común (peso w_pq)
#   - Distancia temporal entre los parciales (menor distancia = mayor penalización)
#
# FUNCIÓN OBJETIVO:
#   Minimizar: Σ w_pq × penalización_temporal(p,q)
#              (p,q)∈E
#
# donde penalización_temporal se define como el inverso de la distancia en días
# entre los parciales (parciales más cercanos = mayor penalización)
# ============================================================================

# ----------------------------------------------------------------------------
# CONJUNTOS
# ----------------------------------------------------------------------------
set P := { read "cursos.dat" as "<1s>" };                       # Parciales (P0-P207)
set D := { 1, 2, 3, 4, 5, 9, 10, 11, 12 };                     # Días disponibles
set H := { 9, 12, 15, 18 };                                     # Horarios disponibles
set E := { read "estudiantes-en-comun.dat" as "<1s,2s>" };     # Incompatibilidades

# ----------------------------------------------------------------------------
# PARÁMETROS
# ----------------------------------------------------------------------------
param capacidad := 75;  # Capacidad de aulas por slot

# Aulas requeridas por cada parcial
param aulas[P] := read "cursos.dat" as "<1s> 2n";

# Peso de cada arista (estudiantes en común)
param w[E] := read "estudiantes-en-comun.dat" as "<1s,2s> 3n";

# Parámetro de penalización por cercanía temporal
# Penalización mayor cuando los días están más cerca
# Formula: si d1 == d2 → 100, sino → 20 / |d1-d2|
param penalizacion[<d1,d2> in D * D] :=
  if d1 == d2 then 100
  else if d1 < d2 then 20 / (d2 - d1)
  else 20 / (d1 - d2) end end;

# ----------------------------------------------------------------------------
# VARIABLES
# ----------------------------------------------------------------------------
# x[p,d,h] = 1 si el parcial p se asigna al día d y hora h
var x[P * D * H] binary;

# y[p] = 1 si el parcial p es asignado
var y[P] binary;

# z[p,d] = 1 si el parcial p es asignado en el día d (cualquier hora)
var z[P * D] binary;

# Variable auxiliar que indica si p1 está en d1 Y p2 está en d2 simultáneamente
# Usada para linearizar el producto z[p1,d1] * z[p2,d2]
var ambos[E * D * D] binary;

# ----------------------------------------------------------------------------
# FUNCIÓN OBJETIVO
# ============================================================================
# OBJETIVO MULTICRITERIO (enfoque lexicográfico):
# 1° Prioridad: Maximizar parciales asignados (agregamos gran peso)
# 2° Prioridad: Minimizar concentración temporal (dispersar parciales)
#
# Función objetivo = 1000 * parciales_asignados - costo_temporal
# ============================================================================

minimize concentracion:
  sum <p1,p2> in E:
    sum <d1> in D:
      sum <d2> in D:
        w[p1,p2] * penalizacion[d1,d2] * ambos[p1,p2,d1,d2]
  - 1000 * (sum <p> in P: y[p]);

# ----------------------------------------------------------------------------
# RESTRICCIONES
# ----------------------------------------------------------------------------

# (R1) Asignación única: cada parcial se asigna a lo sumo un slot
subto asignacion_unica:
  forall <p> in P:
    sum <d> in D:
      sum <h> in H:
        x[p,d,h] == y[p];

# (R2) Incompatibilidades: parciales incompatibles no pueden estar en el mismo slot
subto incompatibilidades:
  forall <p1,p2> in E:
    forall <d> in D:
      forall <h> in H:
        x[p1,d,h] + x[p2,d,h] <= 1;

# (R3) Capacidad de aulas: no exceder capacidad por slot
subto capacidad_aulas:
  forall <d> in D:
    forall <h> in H:
      sum <p> in P:
        aulas[p] * x[p,d,h] <= capacidad;

# (R4) Linking constraint: z[p,d] = 1 si p está asignado en día d
subto linking_z:
  forall <p> in P:
    forall <d> in D:
      z[p,d] == sum <h> in H: x[p,d,h];



# (R6) NUEVA: Linearización del producto z[p1,d1] * z[p2,d2]
# ambos[p1,p2,d1,d2] = 1 ssi z[p1,d1] = 1 Y z[p2,d2] = 1
subto linearizacion_ambos_1:
  forall <p1,p2> in E:
    forall <d1> in D:
      forall <d2> in D:
        ambos[p1,p2,d1,d2] <= z[p1,d1];

subto linearizacion_ambos_2:
  forall <p1,p2> in E:
    forall <d1> in D:
      forall <d2> in D:
        ambos[p1,p2,d1,d2] <= z[p2,d2];

subto linearizacion_ambos_3:
  forall <p1,p2> in E:
    forall <d1> in D:
      forall <d2> in D:
        ambos[p1,p2,d1,d2] >= z[p1,d1] + z[p2,d2] - 1;

# ----------------------------------------------------------------------------
# NOTAS SOBRE LA FUNCIÓN OBJETIVO:
# ----------------------------------------------------------------------------
# 1. Maximizamos dispersión PENALIZANDO concentración temporal
# 2. La penalización es mayor cuando:
#    - Hay muchos estudiantes en común (peso w_pq alto)
#    - Los parciales están en días cercanos (penalización[d1,d2] alta)
# 3. El peso 1000 asegura que primero se maximice la cantidad de parciales
#    asignados, y luego se dispersen temporalmente
# 4. Con información limitada (solo pares), esta es una aproximación razonable:
#    dispersar parciales con estudiantes en común dispersa indirectamente
#    los parciales de cada estudiante individual
# ============================================================================
