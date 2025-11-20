# ============================================================================
# MODELO PARTE 3 - MAXIMIZAR DISPERSIÓN TEMPORAL
# ============================================================================
# OBJETIVO PRIORITARIO: Maximizar dispersión ponderada por estudiantes en común
#
# Estrategia:
# - Priorizar agendar parciales con MAYOR cantidad de estudiantes en común
#   lo MÁS DISPERSOS posible en el tiempo
# - NO es necesario agendar todos los parciales
# - La métrica es: suma de w[p1,p2] * distancia[p1,p2]
#   donde w[p1,p2] = cantidad de estudiantes que toman ambos parciales
#
# Simplificaciones para eficiencia:
# - Usar variable dia[p] en vez de x[p,d,h] (ignorar hora específica)
# - Mapear días a índices secuenciales: 1’1, 2’2, ..., 12’9
# - Linearizar distancia con variables auxiliares
# ============================================================================

# ----------------------------------------------------------------------------
# CONJUNTOS
# ----------------------------------------------------------------------------
set P := { read "cursos.dat" as "<1s>" };                       # Parciales
set D := { 1, 2, 3, 4, 5, 9, 10, 11, 12 };                     # Días hábiles
set H := { 9, 12, 15, 18 };                                     # Horarios

# Pares de parciales con estudiantes en común (incompatibilidades)
set E := { read "estudiantes-en-comun.dat" as "<1s,2s>" };

# ----------------------------------------------------------------------------
# PARÁMETROS
# ----------------------------------------------------------------------------
param capacidad := 75;

# Aulas requeridas por cada parcial
param aulas[P] := read "cursos.dat" as "<1s> 2n";

# Peso = cantidad de estudiantes en común entre dos parciales
param w[E] := read "estudiantes-en-comun.dat" as "<1s,2s> 3n";

# Mapeo de día real a índice secuencial (para distancias uniformes)
# Día:    1  2  3  4  5  9  10 11 12
# Índice: 1  2  3  4  5  6  7  8  9
param indice[D] := <1> 1, <2> 2, <3> 3, <4> 4, <5> 5,
                   <9> 6, <10> 7, <11> 8, <12> 9;

# Constante grande para Big-M
param M := 100;

# ----------------------------------------------------------------------------
# VARIABLES
# ----------------------------------------------------------------------------

# x[p,d,h] = 1 si parcial p se asigna en día d, hora h
var x[P * D * H] binary;

# y[p] = 1 si parcial p está asignado (en algún día/hora)
var y[P] binary;

# idx[p] = índice secuencial del día asignado a parcial p
#          (0 si no asignado, 1-9 si asignado)
var idx[P] integer >= 0 <= 9;

# distancia[p1,p2] = |idx[p1] - idx[p2]| si ambos asignados, 0 si alguno no asignado
var distancia[E] integer >= 0 <= 8;

# ----------------------------------------------------------------------------
# FUNCIÓN OBJETIVO
# ----------------------------------------------------------------------------
# Maximizar: suma de (peso × distancia) para todos los pares
# Esto prioriza dispersar parciales con muchos estudiantes en común
# ----------------------------------------------------------------------------

maximize dispersion_total:
  sum <p1,p2> in E: w[p1,p2] * distancia[p1,p2];

# ----------------------------------------------------------------------------
# RESTRICCIONES
# ----------------------------------------------------------------------------

# (R1) Asignación única por parcial
# Si un parcial está asignado (y[p]=1), debe estar en exactamente un slot
subto asignacion_unica:
  forall <p> in P:
    sum <d,h> in D * H: x[p,d,h] == y[p];

# (R2) Incompatibilidades en el mismo slot
# Dos parciales con estudiantes en común NO pueden estar en el mismo slot
subto incompatibilidades:
  forall <p1,p2> in E:
    forall <d,h> in D * H:
      x[p1,d,h] + x[p2,d,h] <= 1;

# (R3) Capacidad de aulas
# Total de aulas requeridas en un slot no puede exceder capacidad
subto capacidad_aulas:
  forall <d,h> in D * H:
    sum <p> in P: aulas[p] * x[p,d,h] <= capacidad;

# (R4) Linking idx[p] con día asignado
# Si p está en día d, entonces idx[p] = indice[d]
# Si p no está asignado, idx[p] = 0
subto linking_idx:
  forall <p> in P:
    idx[p] == sum <d,h> in D * H: indice[d] * x[p,d,h];

# ----------------------------------------------------------------------------
# (R5) Linearización de distancia = |idx[p1] - idx[p2]|
# ----------------------------------------------------------------------------
# Necesitamos:
# - distancia = 0 si alguno de los dos parciales NO está asignado
# - distancia = |idx[p1] - idx[p2]| si ambos están asignados
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
# Si alguno no asignado: restricción se relaja (Big-M)
subto distancia_abs_1:
  forall <p1,p2> in E:
    distancia[p1,p2] >= idx[p1] - idx[p2] - M * (2 - y[p1] - y[p2]);

# Si ambos asignados: distancia >= idx[p2] - idx[p1]
# Si alguno no asignado: restricción se relaja (Big-M)
subto distancia_abs_2:
  forall <p1,p2> in E:
    distancia[p1,p2] >= idx[p2] - idx[p1] - M * (2 - y[p1] - y[p2]);

# ============================================================================
# NOTAS SOBRE EL MODELO
# ============================================================================
#
# 1. DIFERENCIA CON MODELOS ANTERIORES:
#    - Modelos 1-2: Maximizan cantidad de parciales asignados
#    - Modelo 3: Maximiza SOLO dispersión ponderada
#    - Resultado: Puede no asignar todos los parciales si eso mejora dispersión
#
# 2. PRIORIDAD DE ESTUDIANTES:
#    - w[p1,p2] = cantidad de estudiantes que toman ambos parciales
#    - Maximizar sum(w * distancia) prioriza dispersar parciales con más
#      estudiantes en común
#    - Ejemplo: 100 estudiantes tomando P1 y P2 ’ peso 100
#                10 estudiantes tomando P3 y P4 ’ peso 10
#                El modelo preferirá separar P1-P2 que P3-P4
#
# 3. DISTANCIAS:
#    - Usamos índice secuencial (1-9) para tratar todos los días uniformemente
#    - Distancia máxima posible = 8 (día 1 a día 12)
#    - días 1-5 son consecutivos (distancias 1-4 entre ellos)
#    - días 9-12 son consecutivos (distancias 1-3 entre ellos)
#    - día 5 a día 9: distancia 1 (en índice secuencial)
#
# 4. SIMPLIFICACIÓN:
#    - No usamos variable z[p,d] como en modelos anteriores
#    - Derivamos idx[p] directamente de x[p,d,h]
#    - Esto reduce variables: 12,534 en vez de 232,966
#
# 5. EXPECTATIVA:
#    - El solver debería usar días 1,2,3,4,5,9,10,11,12 distribuidamente
#    - Parciales con muchos estudiantes en común deberían estar muy separados
#    - Algunos parciales pueden quedar sin asignar si no caben sin violar
#      restricciones de incompatibilidad/capacidad
# ============================================================================
