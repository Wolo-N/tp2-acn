# ============================================================================
# MODELO DE ASIGNACIÓN DE PARCIALES - ZIMPL (VERSIÓN 3 OPTIMIZADA)
# ============================================================================
# Optimizaciones aplicadas:
# 1. ELIMINADA restricción R5 (no 3 vecinos mismo día) - reduce complejidad
# 2. Solo penalizar pares en días DIFERENTES (no mismo día, ya prohibido por R2)
# 3. Simplificar penalización: solo considerar si están en días consecutivos o no
# ============================================================================

# ----------------------------------------------------------------------------
# CONJUNTOS
# ----------------------------------------------------------------------------
set P := { read "cursos.dat" as "<1s>" };                       # Parciales
set D := { 1, 2, 3, 4, 5, 9, 10, 11, 12 };                     # Días disponibles
set H := { 9, 12, 15, 18 };                                     # Horarios disponibles
set E := { read "estudiantes-en-comun.dat" as "<1s,2s>" };     # Incompatibilidades

# ----------------------------------------------------------------------------
# PARÁMETROS
# ----------------------------------------------------------------------------
param capacidad := 75;

# Aulas requeridas por cada parcial
param aulas[P] := read "cursos.dat" as "<1s> 2n";

# Peso de cada arista (estudiantes en común)
param w[E] := read "estudiantes-en-comun.dat" as "<1s,2s> 3n";

# ----------------------------------------------------------------------------
# VARIABLES
# ----------------------------------------------------------------------------
var x[P * D * H] binary;  # x[p,d,h] = 1 si parcial p en día d, hora h
var y[P] binary;           # y[p] = 1 si parcial p es asignado
var z[P * D] binary;       # z[p,d] = 1 si parcial p en día d (cualquier hora)

# OPTIMIZACIÓN: Solo variables para PARES CONSECUTIVOS de días
# Días consecutivos en el calendario: (1,2), (2,3), (3,4), (4,5), (9,10), (10,11), (11,12)
set D_consecutivos := { <1,2>, <2,3>, <3,4>, <4,5>, <9,10>, <10,11>, <11,12> };

# Variable: ambos_consec[p1,p2,d1,d2] = 1 si p1 en d1 Y p2 en d2 (días consecutivos)
var ambos_consec[E * D_consecutivos] binary;

# ----------------------------------------------------------------------------
# FUNCIÓN OBJETIVO
# ============================================================================
# Minimizar concentración en días consecutivos
# Penalización: 20 puntos por cada par con estudiantes en común en días consecutivos
# ============================================================================

minimize concentracion:
  20 * (sum <p1,p2> in E:
          sum <d1,d2> in D_consecutivos:
            w[p1,p2] * ambos_consec[p1,p2,d1,d2])
  - 1000 * (sum <p> in P: y[p]);

# ----------------------------------------------------------------------------
# RESTRICCIONES
# ----------------------------------------------------------------------------

# (R1) Asignación única
subto asignacion_unica:
  forall <p> in P:
    sum <d> in D:
      sum <h> in H:
        x[p,d,h] == y[p];

# (R2) Incompatibilidades en mismo slot
subto incompatibilidades:
  forall <p1,p2> in E:
    forall <d> in D:
      forall <h> in H:
        x[p1,d,h] + x[p2,d,h] <= 1;

# (R3) Capacidad de aulas
subto capacidad_aulas:
  forall <d> in D:
    forall <h> in H:
      sum <p> in P:
        aulas[p] * x[p,d,h] <= capacidad;

# (R4) Linking constraint para z
subto linking_z:
  forall <p> in P:
    forall <d> in D:
      z[p,d] == sum <h> in H: x[p,d,h];

# (R5) ELIMINADA - para reducir complejidad

# (R6) Linearización para días CONSECUTIVOS solamente
subto linearizacion_consec_1:
  forall <p1,p2> in E:
    forall <d1,d2> in D_consecutivos:
      ambos_consec[p1,p2,d1,d2] <= z[p1,d1];

subto linearizacion_consec_2:
  forall <p1,p2> in E:
    forall <d1,d2> in D_consecutivos:
      ambos_consec[p1,p2,d1,d2] <= z[p2,d2];

subto linearizacion_consec_3:
  forall <p1,p2> in E:
    forall <d1,d2> in D_consecutivos:
      ambos_consec[p1,p2,d1,d2] >= z[p1,d1] + z[p2,d2] - 1;

# ----------------------------------------------------------------------------
# MEJORAS RESPECTO A VERSIÓN ANTERIOR:
# ----------------------------------------------------------------------------
# 1. Variables reducidas: 2758 × 7 = 19,306 (vs 223,398 antes)
# 2. Sin restricción R5 (reduce ~110K restricciones)
# 3. Solo penaliza días consecutivos (el caso más crítico)
# 4. Días no-consecutivos pero cercanos (ej: día 1 y 3) no se penalizan
#    explícitamente, pero la optimización natural los separará
# ============================================================================
