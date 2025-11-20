###############################################################################
# PARCIALES - MODELO SIMPLE (funcional y rápido)
# - Trabaja por día (sin horas).
# - Filtra aristas por peso >= WMIN (tratamos primero aristas de mayor conflicto).
# - Usa z[p1,p2,d1,d2] para linearizar contribución w * distancia.
# - Índices de días con gap entre 5 y 9 para que 9..12 sean realmente lejanos.
###############################################################################

# -----------------------------------------------------------------------------
# SETS
# -----------------------------------------------------------------------------
set P  := { read "cursos.dat" as "<1s>" };                      # parciales
set D  := { 1,2,3,4,5,9,10,11,12 };                             # días
set H  := { 9,12,15,18 };                                       # horarios (solo para contar slots)
set E  := { read "estudiantes-en-comun.dat" as "<1s,2s>" };     # pares (p,q) con peso en archivo

# -----------------------------------------------------------------------------
# PARAMETERS
# -----------------------------------------------------------------------------
param capacidad := 75;                                           # aulas por horario
param aulas[P] := read "cursos.dat" as "<1s> 2n";                # aulas requeridas por parcial
param w[E] := read "estudiantes-en-comun.dat" as "<1s,2s> 3n";  # peso (estudiantes en comun)

# mapeo de días a índices con gap
param indice[D] := <1> 1, <2> 2, <3> 3, <4> 4, <5> 5,
                   <9> 20, <10> 21, <11> 22, <12> 23;

# capacidad diaria (sumamos horas para no modelar horas)
param SLOTS_PER_DAY := card(H);              # 4
param CAP_DIARIA := capacidad * SLOTS_PER_DAY;

# filtro de aristas por peso (ajustar WMIN para velocidad)
# El modelo solo considerará las aristas en E2.
param WMIN := 100;                              # por defecto 5 — subilo para hacerlo más rápido
set E2 := { <p,q> in E | w[p,q] >= WMIN };

# -----------------------------------------------------------------------------
# VARIABLES
# -----------------------------------------------------------------------------
# x[p,d] = 1 si parcial p se asigna al día d
var x[P * D] binary;

# y[p] = 1 si parcial p está asignado a algún día
var y[P] binary;

# z[p1,p2,d1,d2] = 1 si p1 está en d1 AND p2 está en d2 (solo para pares en E2)
var z[E2 * D * D] binary;

# -----------------------------------------------------------------------------
# OBJETIVO: MAXIMIZAR DISPERSIÓN PONDERADA por w * distancia
# -----------------------------------------------------------------------------
maximize dispersion_total:
  sum <p1,p2> in E2:
    sum <d1,d2> in D * D:
      w[p1,p2] * abs(indice[d1] - indice[d2]) * z[p1,p2,d1,d2];

# -----------------------------------------------------------------------------
# RESTRICCIONES
# -----------------------------------------------------------------------------

# (R1) asignacion_unica: cada parcial asignado a lo sumo a un día
subto asignacion_unica:
  forall <p> in P:
    sum <d> in D: x[p,d] <= 1;

# (R2) vinculo y: y[p] = 1 si existe asignacion
subto linking_y:
  forall <p> in P:
    sum <d> in D: x[p,d] == y[p];

# (R3) capacidad_diaria: aulas totales en un día no superan CAP_DIARIA
subto capacidad_diaria:
  forall <d> in D:
    sum <p> in P: aulas[p] * x[p,d] <= CAP_DIARIA;

# (R4) incompatibilidades SIMPLE (si querés estricta por slot, esto es relaxada)
#      (Opcional: esta restriccion impide que pares con estudiantes en comun
#       queden en el mismo día si w muy alto — la podes comentar si no la queres)
subto incompat_same_day:
  forall <p1,p2> in E:
    forall <d> in D:
      x[p1,d] + x[p2,d] <= 1;

# (R5) Definición de z (linearización): z <= x[p1,d1], z <= x[p2,d2], z >= x[p1,d1] + x[p2,d2] -1
subto z_upper1:
  forall <p1,p2> in E2:
    forall <d1,d2> in D * D:
      z[p1,p2,d1,d2] <= x[p1,d1];

subto z_upper2:
  forall <p1,p2> in E2:
    forall <d1,d2> in D * D:
      z[p1,p2,d1,d2] <= x[p2,d2];

subto z_lower:
  forall <p1,p2> in E2:
    forall <d1,d2> in D * D:
      z[p1,p2,d1,d2] >= x[p1,d1] + x[p2,d2] - 1;

# (R6) Simetría/redundancia: si querés reducir tamaño, fijá orden en E2
# Nota: E2 debe contener cada par una sola vez (p<q). ZIMPL lo leerá tal cual.
# Si E contiene ambas direcciones, podés filtrar externamente o con una constricción.

# -----------------------------------------------------------------------------
# SUGERENCIAS PARA CORRER RÁPIDO
# -----------------------------------------------------------------------------
# 1) Empezá con WMIN grande (ej. 50 o 100) para que E2 sea pequeño y veas comportamiento.
# 2) Si querés forzar que modelos prioricen asignar parciales (antes que dispersar),
#    podés convertir objetivo en lexicográfico: primero max sum y[p], luego dispersion.
# 3) Si querés velocidad, comentar la restricción incompat_same_day (R4) y validar
#    resultados luego con una verificación separada.
#
# -----------------------------------------------------------------------------
# FIN
# -----------------------------------------------------------------------------