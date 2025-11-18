# ============================================================================
# MODELO DE ASIGNACIÓN DE PARCIALES - ZIMPL
# ============================================================================
# Problema: Asignar parciales a slots (día, hora) maximizando cantidad asignada
# Restricciones: incompatibilidades, capacidad de aulas
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
