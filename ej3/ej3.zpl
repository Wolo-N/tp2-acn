# ============================================================================
# MODELO SIMPLIFICADO - Solo días consecutivos
# ============================================================================

# CONJUNTOS
set P := { read "cursos.dat" as "<1s>" };
set D := { 1, 2, 3, 4, 5, 9, 10, 11, 12 };
set H := { 9, 12, 15, 18 };
set E := { read "estudiantes-en-comun.dat" as "<1s,2s>" };

# Solo pares consecutivos
set DC := { <1,2>, <2,3>, <3,4>, <4,5>, <9,10>, <10,11>, <11,12> };

# PARÁMETROS
param capacidad := 75;
param aulas[P] := read "cursos.dat" as "<1s> 2n";
param w[E] := read "estudiantes-en-comun.dat" as "<1s,2s> 3n";

# VARIABLES
var x[P * D * H] binary;
var y[P] binary;
var z[P * D] binary;
var ambos_consec[E * DC] binary;  # Solo pares consecutivos

# OBJETIVO
minimize concentracion:
  20 * sum <p1,p2> in E:
         sum <d1,d2> in DC:
           w[p1,p2] * ambos_consec[p1,p2,d1,d2]
  - 10000 * sum <p> in P: y[p];

# RESTRICCIONES
subto asignacion_unica:
  forall <p> in P:
    sum <d,h> in D * H: x[p,d,h] == y[p];

subto incompatibilidades:
  forall <p1,p2> in E:
    forall <d,h> in D * H:
      x[p1,d,h] + x[p2,d,h] <= 1;

subto capacidad_aulas:
  forall <d,h> in D * H:
    sum <p> in P: aulas[p] * x[p,d,h] <= capacidad;

subto linking_z:
  forall <p,d> in P * D:
    z[p,d] == sum <h> in H: x[p,d,h];

# Linearización solo para consecutivos
subto lin1:
  forall <p1,p2> in E:
    forall <d1,d2> in DC:
      ambos_consec[p1,p2,d1,d2] <= z[p1,d1];

subto lin2:
  forall <p1,p2> in E:
    forall <d1,d2> in DC:
      ambos_consec[p1,p2,d1,d2] <= z[p2,d2];

subto lin3:
  forall <p1,p2> in E:
    forall <d1,d2> in DC:
      ambos_consec[p1,p2,d1,d2] >= z[p1,d1] + z[p2,d2] - 1;