# ============================================================================
# MODELO DE ASIGNACIÓN DE PARCIALES - ZIMPL (VERSIÓN 2)
# ============================================================================
# Problema: Asignar parciales a slots (día, hora) maximizando cantidad asignada
# Restricciones:
#   - Incompatibilidades (no pueden estar en el mismo slot)
#   - Capacidad de aulas por slot
#   - NUEVA: Ningún estudiante rinde 3 parciales el mismo día
#            (no puede haber 3 vértices vecinos en G programados el mismo día)
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

# ----------------------------------------------------------------------------
# VARIABLES
# ----------------------------------------------------------------------------
# x[p,d,h] = 1 si el parcial p se asigna al día d y hora h
var x[P * D * H] binary;

# y[p] = 1 si el parcial p es asignado
var y[P] binary;

# z[p,d] = 1 si el parcial p es asignado en el día d (cualquier hora)
var z[P * D] binary;

# ----------------------------------------------------------------------------
# FUNCIÓN OBJETIVO
# ----------------------------------------------------------------------------
# Maximizar la cantidad de parciales asignados
maximize parciales_asignados: sum <p> in P: y[p];

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

# (R5) NUEVA RESTRICCIÓN: No puede haber 3 parciales vecinos (incompatibles) el mismo día
# Para cada tripla de parciales (p1,p2,p3) donde p1-p2, p2-p3, y p1-p3 son incompatibles,
# no pueden estar los 3 en el mismo día
subto no_tres_vecinos_mismo_dia:
  forall <p1,p2> in E:
    forall <p3> in P with <p1,p3> in E and <p2,p3> in E:
      forall <d> in D:
        z[p1,d] + z[p2,d] + z[p3,d] <= 2;

# ----------------------------------------------------------------------------
# NOTA: Las variables x, y, z son binarias por definición
# ----------------------------------------------------------------------------
