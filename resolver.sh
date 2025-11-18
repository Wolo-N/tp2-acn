#!/bin/bash
# Script para resolver modelos ZIMPL con SCIP y generar reportes

# Verificar que se pasó un argumento
if [ $# -eq 0 ]; then
    echo "Uso: ./resolver.sh <archivo.zpl>"
    echo "Ejemplo: ./resolver.sh parciales.zpl"
    exit 1
fi

ARCHIVO_ZPL=$1
NOMBRE_BASE="${ARCHIVO_ZPL%.zpl}"

echo "========================================="
echo "Resolviendo: $ARCHIVO_ZPL"
echo "========================================="

# Compilar con ZIMPL
echo ""
echo "[1/3] Compilando con ZIMPL..."
./SCIPI/bin/zimpl "$ARCHIVO_ZPL"

if [ $? -ne 0 ]; then
    echo "Error al compilar con ZIMPL"
    exit 1
fi

# Resolver con SCIP
echo ""
echo "[2/3] Resolviendo con SCIP..."
./SCIPI/bin/scip -f "${NOMBRE_BASE}.lp" 2>&1 | python3 parsear_solucion.py > "resultado_${NOMBRE_BASE}.txt"

if [ $? -ne 0 ]; then
    echo "Error al resolver con SCIP"
    exit 1
fi

# Mostrar resultado
echo ""
echo "[3/3] Resultado guardado en: resultado_${NOMBRE_BASE}.txt"
echo ""
echo "========================================="
echo "Vista previa del resultado:"
echo "========================================="
head -40 "resultado_${NOMBRE_BASE}.txt"
echo ""
echo "Ver resultado completo: cat resultado_${NOMBRE_BASE}.txt"
