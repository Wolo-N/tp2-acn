#!/bin/bash
# Analiza la dispersión de los top pares en una solución

if [ $# -eq 0 ]; then
    echo "Uso: ./analizar_top_pares.sh <archivo_resultado>"
    exit 1
fi

RESULTADO=$1

python3 << 'EOF'
import sys

# Leer archivo de resultado desde argumento
resultado_file = sys.argv[1] if len(sys.argv) > 1 else 'resultado_parciales3_top.txt'

# Parsear asignación
asignacion = {}
with open(resultado_file) as f:
    en_seccion = False
    for line in f:
        if 'ASIGNACIÓN DE PARCIALES POR SLOT' in line:
            en_seccion = True
            continue
        if en_seccion and 'Total asignados' in line:
            break
        if en_seccion and line.strip():
            parts = line.strip().split()
            if parts and parts[0].isdigit():
                dia = int(parts[0])
                if len(parts) >= 5:
                    parciales_str = ' '.join(parts[4:])
                    parciales = [p.strip(',') for p in parciales_str.split()]
                    for p in parciales:
                        if p.startswith('P'):
                            asignacion[p] = dia

# Parciales críticos
criticos = ['P38', 'P50', 'P94', 'P149', 'P186']

# Top 20 pares por peso
top_pares = [
    ('P38', 'P94', 479),
    ('P38', 'P149', 434),
    ('P94', 'P149', 409),
    ('P38', 'P186', 401),
    ('P50', 'P94', 399),
    ('P50', 'P149', 398),
    ('P50', 'P186', 386),
    ('P94', 'P186', 376),
    ('P38', 'P50', 370),
    ('P149', 'P186', 329),
    ('P64', 'P117', 245),
    ('P117', 'P124', 227),
    ('P64', 'P124', 183),
    ('P19', 'P137', 166),
    ('P67', 'P71', 163),
    ('P19', 'P181', 163),
    ('P94', 'P193', 162),
    ('P137', 'P181', 161),
    ('P50', 'P193', 156),
    ('P104', 'P137', 153)
]

# Mapeo día a índice
dia_a_idx = {1:1, 2:2, 3:3, 4:4, 5:5, 9:6, 10:7, 11:8, 12:9}

print('=' * 80)
print(f'ANÁLISIS DE DISPERSIÓN: {resultado_file}')
print('=' * 80)
print()

# 1. Asignación de parciales críticos
print('1. ASIGNACIÓN DE PARCIALES CRÍTICOS (P38, P50, P94, P149, P186)')
print('-' * 80)
for p in criticos:
    if p in asignacion:
        dia = asignacion[p]
        idx = dia_a_idx[dia]
        print(f'   {p:6s} → Día {dia:2d} (índice secuencial {idx})')
    else:
        print(f'   {p:6s} → ❌ NO ASIGNADO')
print()

# 2. Distancias entre top pares
print('2. DISTANCIAS ENTRE TOP 20 PARES (por peso de estudiantes)')
print('-' * 80)
print(f"{'#':>3s}  {'P1':>6s}  {'P2':>6s}  {'Peso':>5s}  {'Día1':>4s}  {'Día2':>4s}  {'Dist':>4s}  {'Status'}")
print('-' * 80)

distancias = []
for i, (p1, p2, peso) in enumerate(top_pares, 1):
    if p1 in asignacion and p2 in asignacion:
        d1, d2 = asignacion[p1], asignacion[p2]
        idx1, idx2 = dia_a_idx[d1], dia_a_idx[d2]
        dist = abs(idx1 - idx2)
        distancias.append(dist)

        # Clasificar
        if dist == 0:
            status = '❌ MISMO DÍA'
        elif dist <= 2:
            status = '⚠️  Cercano'
        elif dist >= 5:
            status = '✅ Disperso'
        else:
            status = '➖ Moderado'

        print(f'{i:3d}  {p1:>6s}  {p2:>6s}  {peso:5d}  {d1:4d}  {d2:4d}  {dist:4d}  {status}')
    else:
        print(f'{i:3d}  {p1:>6s}  {p2:>6s}  {peso:5d}  {"N/A":>4s}  {"N/A":>4s}  {"N/A":>4s}  ❌ No asignado')

print()

# 3. Estadísticas resumidas
if distancias:
    print('3. ESTADÍSTICAS DE DISPERSIÓN (TOP 20 PARES)')
    print('-' * 80)
    print(f'   Distancia mínima:  {min(distancias)}')
    print(f'   Distancia máxima:  {max(distancias)}')
    print(f'   Distancia promedio: {sum(distancias)/len(distancias):.2f}')
    print()
    print(f'   Pares mismo día (dist=0):    {distancias.count(0):2d} ({100*distancias.count(0)/len(distancias):5.1f}%)')
    print(f'   Pares cercanos (dist≤2):     {sum(1 for d in distancias if d <= 2):2d} ({100*sum(1 for d in distancias if d <= 2)/len(distancias):5.1f}%)')
    print(f'   Pares dispersos (dist≥5):    {sum(1 for d in distancias if d >= 5):2d} ({100*sum(1 for d in distancias if d >= 5)/len(distancias):5.1f}%)')
    print()

    # Score ponderado
    score = sum(peso * dist for (p1, p2, peso), dist in zip(top_pares, distancias))
    print(f'   Score ponderado (suma peso×dist): {score:,}')
    print()

# 4. Análisis de uso de días
print('4. USO DE DÍAS (distribución de 208 parciales)')
print('-' * 80)
dias_usados = {}
for p, d in asignacion.items():
    dias_usados[d] = dias_usados.get(d, 0) + 1

for dia in [1,2,3,4,5,9,10,11,12]:
    count = dias_usados.get(dia, 0)
    bar = '█' * (count // 2)
    print(f'   Día {dia:2d}: {count:3d} parciales  {bar}')

print()
print('=' * 80)

EOF

python3 -c "import sys; exec(open(__file__).read())" "$RESULTADO"
