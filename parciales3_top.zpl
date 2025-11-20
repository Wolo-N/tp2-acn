# ============================================================================
# MODELO PARTE 3 - ENFOQUE EN TOP PARES CON MÁS ESTUDIANTES
# ============================================================================
# ESTRATEGIA:
# - Identificar los pares con mayor peso (más estudiantes en común)
# - Priorizar FUERTEMENTE la dispersión de estos pares críticos
# - Usar función objetivo con pesos exponenciales para top pares
#
# PARES CRÍTICOS (top 10 por peso):
# 1. P38-P94:   479 estudiantes
# 2. P38-P149:  434 estudiantes
# 3. P94-P149:  409 estudiantes
# 4. P38-P186:  401 estudiantes
# 5. P50-P94:   399 estudiantes
# 6. P50-P149:  398 estudiantes
# 7. P50-P186:  386 estudiantes
# 8. P94-P186:  376 estudiantes
# 9. P38-P50:   370 estudiantes
# 10. P149-P186: 329 estudiantes
#
# Parciales críticos: P38, P50, P94, P149, P186
# ============================================================================

# ----------------------------------------------------------------------------
# CONJUNTOS
# ----------------------------------------------------------------------------
set P := { read "cursos.dat" as "<1s>" };
set D := { 1, 2, 3, 4, 5, 9, 10, 11, 12 };
set H := { 9, 12, 15, 18 };
set E := { read "estudiantes-en-comun.dat" as "<1s,2s>" };

# Parciales críticos (involucrados en top pares)
set P_criticos := { "P38", "P50", "P94", "P149", "P186" };

# Top 10 pares más críticos
set E_top := {
    <"P38", "P94">, <"P38", "P149">, <"P94", "P149">, <"P38", "P186">,
    <"P50", "P94">, <"P50", "P149">, <"P50", "P186">, <"P94", "P186">,
    <"P38", "P50">, <"P149", "P186">
};

# ----------------------------------------------------------------------------
# PARÁMETROS
# ----------------------------------------------------------------------------
param capacidad := 75;
param aulas[P] := read "cursos.dat" as "<1s> 2n";
param w[E] := read "estudiantes-en-comun.dat" as "<1s,2s> 3n";

# Mapeo de día a índice con GAP GRANDE entre semanas
# Días 1-5 → índices 1-5 (primera semana)
# Días 9-12 → índices 20-23 (segunda semana, gap=15)
# Esto crea incentivo real para usar días 9-12
param indice[D] := <1> 1, <2> 2, <3> 3, <4> 4, <5> 5,
                   <9> 20, <10> 21, <11> 22, <12> 23;

param MAX_IDX := 23;
param M := 100;

# Factor de peso para top pares (multiplicador)
param top_factor := 10;  # Los top pares valen 10x más

# ----------------------------------------------------------------------------
# VARIABLES
# ----------------------------------------------------------------------------
var x[P * D * H] binary;
var y[P] binary;
var idx[P] integer >= 0 <= MAX_IDX;
var t[E] integer >= -MAX_IDX <= MAX_IDX;
var distancia[E] integer >= 0 <= MAX_IDX;

# ----------------------------------------------------------------------------
# FUNCIÓN OBJETIVO
# ----------------------------------------------------------------------------
# Maximizar dispersión con PRIORIDAD ABSOLUTA en top pares
# Los top pares tienen peso multiplicado por top_factor
# ----------------------------------------------------------------------------

maximize dispersion_ponderada:
  # Dispersión normal para todos los pares
  sum <p1,p2> in E: w[p1,p2] * distancia[p1,p2]

  # BONUS extra para top pares (se cuentan top_factor veces más)
  + top_factor * sum <p1,p2> in E_top: w[p1,p2] * distancia[p1,p2];

# ----------------------------------------------------------------------------
# RESTRICCIONES
# ----------------------------------------------------------------------------

# (R1) Asignación única
subto asignacion_unica:
  forall <p> in P:
    sum <d,h> in D * H: x[p,d,h] == y[p];

# (R2) Incompatibilidades en mismo slot
subto incompatibilidades:
  forall <p1,p2> in E:
    forall <d,h> in D * H:
      x[p1,d,h] + x[p2,d,h] <= 1;

# (R3) Capacidad de aulas
subto capacidad_aulas:
  forall <d,h> in D * H:
    sum <p> in P: aulas[p] * x[p,d,h] <= capacidad;

# (R4) Linking idx
subto linking_idx:
  forall <p> in P:
    idx[p] == sum <d,h> in D * H: indice[d] * x[p,d,h];

# (R5) REQUISITO CRÍTICO: Los 5 parciales críticos DEBEN ser asignados
# Esto asegura que podemos dispersarlos
subto parciales_criticos_obligatorios:
  forall <p> in P_criticos:
    y[p] == 1;

# (R6) Definición de t = idx[p1] - idx[p2]
subto definir_t:
  forall <p1,p2> in E:
    t[p1,p2] == idx[p1] - idx[p2];

# (R7) Si alguno no asignado => distancia debe ser 0
subto distancia_zero_si_no_asignado_1:
  forall <p1,p2> in E:
    distancia[p1,p2] <= M * y[p1];

subto distancia_zero_si_no_asignado_2:
  forall <p1,p2> in E:
    distancia[p1,p2] <= M * y[p2];

# (R8) Linearización exacta de |t| con 4 desigualdades
# Cuando ambos asignados (y[p1]=y[p2]=1): distancia = |t|
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

# (R9) DISPERSIÓN MÍNIMA para top pares
# Con índices con gap, distancia mínima 15 asegura diferentes semanas
# Distancia 15 = un parcial en día 5 (idx=5), otro en día 9 (idx=20)
subto distancia_minima_top_pares:
  forall <p1,p2> in E_top:
    distancia[p1,p2] >= 15;

# ============================================================================
# CARACTERÍSTICAS CLAVE DEL MODELO
# ============================================================================
#
# 1. PARCIALES CRÍTICOS OBLIGATORIOS (R5):
#    - P38, P50, P94, P149, P186 DEBEN asignarse
#    - Esto garantiza que podemos optimizar su dispersión
#
# 2. DISTANCIA MÍNIMA GARANTIZADA (R9):
#    - Top 10 pares deben tener distancia >= 15
#    - Con índices con gap (1-5, 20-23), distancia 15 significa:
#      * Un parcial en semana 1 (días 1-5, idx 1-5)
#      * Otro parcial en semana 2 (días 9-12, idx 20-23)
#      * Ejemplo: P38 día 5 (idx=5), P94 día 9 (idx=20) → dist=15 ✓
#    - Esto FUERZA que top pares estén en semanas diferentes
#
# 3. PESO EXPONENCIAL EN OBJETIVO:
#    - Top pares cuentan (1 + top_factor) = 11 veces en objetivo
#    - Con gap en índices, las distancias son MUCHO mayores:
#      * Ejemplo: P38 día 1 (idx=1), P94 día 9 (idx=20) → dist=19
#      * Contribución normal: 479 × 19 = 9,101
#      * Contribución top: 10 × 479 × 19 = 91,010
#      * TOTAL: 100,111 puntos ← MASIVO incentivo
#    - Esto hace que el solver priorice absolutamente estos pares
#
# 4. GAP EN ÍNDICES (CLAVE):
#    - Días 1-5 → índices 1-5
#    - Días 9-12 → índices 20-23 (gap de 15)
#    - Esto crea incentivo numérico real para usar días 9-12
#    - Sin el gap, días 9-12 parecían "cercanos" a días 1-5
#
# 5. EXPECTATIVA DE SOLUCIÓN:
#    - Los 5 parciales críticos distribuidos en ambas semanas
#    - Ejemplo óptimo:
#      * P38, P50 → semana 1 (días 1-5)
#      * P94, P149, P186 → semana 2 (días 9-12)
#    - Distancias entre top pares: mínimo 15, máximo 22
#    - Score total esperado: ~500,000+ (vs 10,610 anterior)
# ============================================================================
