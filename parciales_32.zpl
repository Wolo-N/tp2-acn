# ============================================================================
# MODELO PARTE 3 - MAXIMIZAR DISPERSI�N TEMPORAL
# ============================================================================
# OBJETIVO PRIORITARIO: Maximizar dispersi�n ponderada por estudiantes en com�n
#
# Estrategia:
# - Priorizar agendar parciales con MAYOR cantidad de estudiantes en com�n
#   lo M�S DISPERSOS posible en el tiempo
# - NO es necesario agendar todos los parciales
# - La m�trica es: suma de w[p1,p2] * distancia[p1,p2]
#   donde w[p1,p2] = cantidad de estudiantes que toman ambos parciales
#
# Simplificaciones para eficiencia:
# - Usar variable dia[p] en vez de x[p,d,h] (ignorar hora espec�fica)
# - Mapear d�as a �ndices secuenciales: 1�1, 2�2, ..., 12�9
# - Linearizar distancia con variables auxiliares
# ============================================================================

# ----------------------------------------------------------------------------
# CONJUNTOS
# ----------------------------------------------------------------------------
set P := { read "cursos.dat" as "<1s>" };                       # Parciales
set D := { 1, 2, 3, 4, 5, 9, 10, 11, 12 };                     # D�as h�biles
set H := { 9, 12, 15, 18 };                                     # Horarios

# Pares de parciales con estudiantes en com�n (incompatibilidades)
set E := { read "estudiantes-en-comun.dat" as "<1s,2s>" };

# ----------------------------------------------------------------------------
# PAR�METROS
# ----------------------------------------------------------------------------
param capacidad := 75;

# Aulas requeridas por cada parcial
param aulas[P] := read "cursos.dat" as "<1s> 2n";

# Peso = cantidad de estudiantes en com�n entre dos parciales
param w[E] := read "estudiantes-en-comun.dat" as "<1s,2s> 3n";

# Mapeo de d�a real a �ndice secuencial (para distancias uniformes)
# D�a:    1  2  3  4  5  9  10 11 12
# �ndice: 1  2  3  4  5  6  7  8  9
param indice[D] := <1> 1, <2> 2, <3> 3, <4> 4, <5> 5,
                   <9> 6, <10> 7, <11> 8, <12> 9;

# Constante grande para Big-M
param M := 100;

# ----------------------------------------------------------------------------
# VARIABLES
# ----------------------------------------------------------------------------

# x[p,d,h] = 1 si parcial p se asigna en d�a d, hora h
var x[P * D * H] binary;

# y[p] = 1 si parcial p est� asignado (en alg�n d�a/hora)
var y[P] binary;

# idx[p] = �ndice secuencial del d�a asignado a parcial p
#          (0 si no asignado, 1-9 si asignado)
var idx[P] integer >= 0 <= 9;

# distancia[p1,p2] = |idx[p1] - idx[p2]| si ambos asignados, 0 si alguno no asignado
var distancia[E] integer >= 0 <= 8;

# ----------------------------------------------------------------------------
# FUNCI�N OBJETIVO
# ----------------------------------------------------------------------------
# Maximizar: suma de (peso � distancia) para todos los pares
# Esto prioriza dispersar parciales con muchos estudiantes en com�n
# ----------------------------------------------------------------------------

maximize dispersion_total:
  sum <p1,p2> in E: w[p1,p2] * distancia[p1,p2];

# ----------------------------------------------------------------------------
# RESTRICCIONES
# ----------------------------------------------------------------------------

# (R1) Asignaci�n �nica por parcial
# Si un parcial est� asignado (y[p]=1), debe estar en exactamente un slot
subto asignacion_unica:
  forall <p> in P:
    sum <d,h> in D * H: x[p,d,h] == y[p];

# (R2) Incompatibilidades en el mismo slot
# Dos parciales con estudiantes en com�n NO pueden estar en el mismo slot
subto incompatibilidades:
  forall <p1,p2> in E:
    forall <d,h> in D * H:
      x[p1,d,h] + x[p2,d,h] <= 1;

# (R3) Capacidad de aulas
# Total de aulas requeridas en un slot no puede exceder capacidad
subto capacidad_aulas:
  forall <d,h> in D * H:
    sum <p> in P: aulas[p] * x[p,d,h] <= capacidad;

# (R4) Linking idx[p] con d�a asignado
# Si p est� en d�a d, entonces idx[p] = indice[d]
# Si p no est� asignado, idx[p] = 0
subto linking_idx:
  forall <p> in P:
    idx[p] == sum <d,h> in D * H: indice[d] * x[p,d,h];

# ----------------------------------------------------------------------------
# (R5) Linearizaci�n de distancia = |idx[p1] - idx[p2]|
# ----------------------------------------------------------------------------
# Necesitamos:
# - distancia = 0 si alguno de los dos parciales NO est� asignado
# - distancia = |idx[p1] - idx[p2]| si ambos est�n asignados
#
# Usando Big-M:
# - Si y[p1]=0 o y[p2]=0, forzar distancia=0
# - Si y[p1]=1 y y[p2]=1, calcular |idx[p1] - idx[p2]|
# ----------------------------------------------------------------------------

# Si p1 no asignado, distancia debe ser 0
subto distancia_zero_si_p1_no_asignado:
  forall <p1,p2> in E:
    distancia[p1,p2] <= M * y[p1];

# Si p2 no asignado, distancia debe ser 0
subto distancia_zero_si_p2_no_asignado:
  forall <p1,p2> in E:
    distancia[p1,p2] <= M * y[p2];

# Si ambos asignados: distancia >= idx[p1] - idx[p2]
# Si alguno no asignado: restricci�n se relaja (Big-M)
subto distancia_abs_1:
  forall <p1,p2> in E:
    distancia[p1,p2] >= idx[p1] - idx[p2] - M * (2 - y[p1] - y[p2]);

# Si ambos asignados: distancia >= idx[p2] - idx[p1]
# Si alguno no asignado: restricci�n se relaja (Big-M)
subto distancia_abs_2:
  forall <p1,p2> in E:
    distancia[p1,p2] >= idx[p2] - idx[p1] - M * (2 - y[p1] - y[p2]);

# ============================================================================
# NOTAS SOBRE EL MODELO
# ============================================================================
#
# 1. DIFERENCIA CON MODELOS ANTERIORES:
#    - Modelos 1-2: Maximizan cantidad de parciales asignados
#    - Modelo 3: Maximiza SOLO dispersi�n ponderada
#    - Resultado: Puede no asignar todos los parciales si eso mejora dispersi�n
#
# 2. PRIORIDAD DE ESTUDIANTES:
#    - w[p1,p2] = cantidad de estudiantes que toman ambos parciales
#    - Maximizar sum(w * distancia) prioriza dispersar parciales con m�s
#      estudiantes en com�n
#    - Ejemplo: 100 estudiantes tomando P1 y P2 � peso 100
#                10 estudiantes tomando P3 y P4 � peso 10
#                El modelo preferir� separar P1-P2 que P3-P4
#
# 3. DISTANCIAS:
#    - Usamos �ndice secuencial (1-9) para tratar todos los d�as uniformemente
#    - Distancia m�xima posible = 8 (d�a 1 a d�a 12)
#    - d�as 1-5 son consecutivos (distancias 1-4 entre ellos)
#    - d�as 9-12 son consecutivos (distancias 1-3 entre ellos)
#    - d�a 5 a d�a 9: distancia 1 (en �ndice secuencial)
#
# 4. SIMPLIFICACI�N:
#    - No usamos variable z[p,d] como en modelos anteriores
#    - Derivamos idx[p] directamente de x[p,d,h]
#    - Esto reduce variables: 12,534 en vez de 232,966
#
# 5. EXPECTATIVA:
#    - El solver deber�a usar d�as 1,2,3,4,5,9,10,11,12 distribuidamente
#    - Parciales con muchos estudiantes en com�n deber�an estar muy separados
#    - Algunos parciales pueden quedar sin asignar si no caben sin violar
#      restricciones de incompatibilidad/capacidad
# ============================================================================