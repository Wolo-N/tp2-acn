#!/bin/bash

# ============================================================================
# SOLVER AUTOMÁTICO PARA MODELOS ZIMPL
# ============================================================================
# Uso: ./solver.sh <archivo.zpl>
# Ejemplo: ./solver.sh parciales2.zpl
# ============================================================================

# Verificar que se pasó un archivo como argumento
if [ $# -eq 0 ]; then
    echo "Error: Debes proporcionar un archivo .zpl"
    echo "Uso: ./solver.sh <archivo.zpl>"
    exit 1
fi

# Obtener el archivo .zpl
ZPL_FILE=$1

# Verificar que el archivo existe
if [ ! -f "$ZPL_FILE" ]; then
    echo "Error: El archivo $ZPL_FILE no existe"
    exit 1
fi

# Extraer el nombre base (sin extensión)
BASE_NAME=$(basename "$ZPL_FILE" .zpl)

# Definir nombres de archivos derivados
LP_FILE="${BASE_NAME}.lp"
SALIDA_SCIP="${BASE_NAME}_salida.txt"
REPORTE="${BASE_NAME}_reporte.txt"

echo "============================================================"
echo "🚀 INICIANDO PROCESO DE OPTIMIZACIÓN"
echo "============================================================"
echo "Archivo fuente: $ZPL_FILE"
echo "Archivo LP:     $LP_FILE"
echo "Salida SCIP:    $SALIDA_SCIP"
echo "Reporte final:  $REPORTE"
echo ""

# ============================================================
# PASO 1 — Compilar modelo ZIMPL a .lp
# ============================================================
echo "📝 PASO 1: Compilando ZIMPL → LP..."
zimpl "$ZPL_FILE"

if [ ! -f "$LP_FILE" ]; then
    echo "❌ Error: No se generó el archivo $LP_FILE"
    exit 1
fi
echo "✅ Compilación exitosa: $LP_FILE generado"
echo ""

# ============================================================
# PASO 2 — Resolver con SCIP y guardar salida
# ============================================================
echo "🔍 PASO 2: Ejecutando SCIP..."
scip -f "$LP_FILE" > "$SALIDA_SCIP"
echo "✅ SCIP finalizado, salida guardada en $SALIDA_SCIP"
echo ""

# ============================================================
# PASO 3 — Verificar que existe solución
# ============================================================
echo "🔎 PASO 3: Verificando solución..."
if grep -q "primal solution" "$SALIDA_SCIP"; then
    echo "✅ Solución encontrada"
    grep "primal solution" "$SALIDA_SCIP" | head -1
else
    echo "⚠️  No se encontró 'primal solution' en la salida"
    echo "Revisa $SALIDA_SCIP para más detalles"
fi
echo ""

# ============================================================
# PASO 4 — Parsear solución
# ============================================================
echo "📊 PASO 4: Generando reporte..."
if [ -f "parsear_solucion.py" ]; then
    python3 parsear_solucion.py "$SALIDA_SCIP" > "$REPORTE"
    echo "✅ Reporte generado: $REPORTE"
else
    echo "⚠️  No se encontró parsear_solucion.py, saltando paso de parseo"
    REPORTE="$SALIDA_SCIP"
fi
echo ""

# ============================================================
# PASO 5 — Mostrar resultado
# ============================================================
echo "============================================================"
echo "📄 RESULTADO FINAL"
echo "============================================================"
cat "$REPORTE"
echo ""
echo "============================================================"
echo "✨ PROCESO COMPLETADO"
echo "============================================================"
echo "Archivos generados:"
echo "  - $LP_FILE"
echo "  - $SALIDA_SCIP"
echo "  - $REPORTE"