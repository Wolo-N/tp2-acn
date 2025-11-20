#!/usr/bin/env python3
"""
Análisis de dispersión temporal de parciales para estudiantes.

Calcula métricas de dispersión basadas en:
- Distancia mínima, máxima y promedio entre parciales para pares con estudiantes en común
- Distribución de distancias
- Score total de dispersión (suma de w[p1,p2] * distancia[p1,p2])
"""

import sys
import re
from collections import defaultdict

def leer_estudiantes_comun():
    """Lee estudiantes-en-comun.dat y retorna dict {(p1,p2): peso}"""
    pares = {}
    with open('estudiantes-en-comun.dat', 'r') as f:
        for line in f:
            parts = line.strip().split('\t')
            if len(parts) >= 3:
                p1, p2, peso = parts[0], parts[1], int(parts[2])
                # Guardar ambas direcciones
                pares[(p1, p2)] = peso
                pares[(p2, p1)] = peso
    return pares

def leer_solucion_scip(filename):
    """
    Lee un archivo de resultados parseados y extrae la asignación de parciales.
    Retorna: dict {parcial: (dia, hora)}
    """
    asignacion = {}

    with open(filename, 'r') as f:
        en_seccion_slots = False
        for line in f:
            line = line.strip()

            # Detectar inicio de sección de slots
            if 'ASIGNACIÓN DE PARCIALES POR SLOT' in line:
                en_seccion_slots = True
                continue

            # Detectar fin de sección de slots
            if en_seccion_slots and ('---' in line or 'Total asignados' in line or line == ''):
                if 'Total asignados' in line or (line == '' and asignacion):
                    break
                continue

            # Saltar cabecera
            if en_seccion_slots and ('Día' in line or 'Hora' in line):
                continue

            # Parsear líneas de asignación
            if en_seccion_slots:
                # Formato: "Día    Hora   Cantidad   Aulas    Parciales"
                # Ejemplo: "1      9      23         67       P0, P6, P7, ..."
                match = re.match(r'(\d+)\s+(\d+)\s+\d+\s+\d+\s+(.+)', line)
                if match:
                    dia = int(match.group(1))
                    hora = int(match.group(2))
                    parciales_str = match.group(3)

                    # Parsear lista de parciales
                    parciales = [p.strip() for p in parciales_str.split(',')]

                    for parcial in parciales:
                        if parcial:  # Evitar strings vacíos
                            asignacion[parcial] = (dia, hora)

    return asignacion

# Mapeo de día a índice secuencial (para calcular distancias reales)
DIAS = [1, 2, 3, 4, 5, 9, 10, 11, 12]
DIA_A_INDICE = {dia: idx for idx, dia in enumerate(DIAS)}

def calcular_distancia(dia1, dia2):
    """Calcula la distancia secuencial entre dos días"""
    if dia1 not in DIA_A_INDICE or dia2 not in DIA_A_INDICE:
        return None
    return abs(DIA_A_INDICE[dia1] - DIA_A_INDICE[dia2])

def analizar_dispersion(asignacion, pares):
    """
    Calcula estadísticas de dispersión.

    Args:
        asignacion: dict {parcial: (dia, hora)}
        pares: dict {(p1, p2): peso}

    Returns:
        dict con estadísticas
    """
    distancias = []
    distancias_ponderadas = []
    score_total = 0
    pares_mismo_dia = 0
    pares_dias_consecutivos = 0
    pares_dias_lejanos = 0  # distancia >= 5

    # Distribución de distancias
    dist_histogram = defaultdict(int)

    # Analizar cada par de parciales con estudiantes en común
    for (p1, p2), peso in pares.items():
        # Evitar contar el mismo par dos veces
        if p1 >= p2:
            continue

        # Verificar que ambos parciales estén asignados
        if p1 not in asignacion or p2 not in asignacion:
            continue

        dia1, hora1 = asignacion[p1]
        dia2, hora2 = asignacion[p2]

        # Calcular distancia en días
        dist = calcular_distancia(dia1, dia2)

        if dist is not None:
            distancias.append(dist)
            distancias_ponderadas.extend([dist] * peso)  # Ponderar por cantidad de estudiantes
            score_total += peso * dist
            dist_histogram[dist] += 1

            # Categorizar
            if dist == 0:
                pares_mismo_dia += 1
            elif dist == 1:
                pares_dias_consecutivos += 1
            elif dist >= 5:
                pares_dias_lejanos += 1

    # Calcular estadísticas
    n_pares = len(distancias)

    if n_pares == 0:
        return {
            'error': 'No se encontraron pares de parciales asignados',
            'n_pares': 0
        }

    return {
        'n_pares': n_pares,
        'n_estudiantes_afectados': sum(pares.values()) // 2,  # Dividir por 2 porque guardamos ambas direcciones
        'distancia_min': min(distancias),
        'distancia_max': max(distancias),
        'distancia_promedio': sum(distancias) / len(distancias),
        'distancia_promedio_ponderada': sum(distancias_ponderadas) / len(distancias_ponderadas),
        'score_total': score_total,
        'pares_mismo_dia': pares_mismo_dia,
        'pares_dias_consecutivos': pares_dias_consecutivos,
        'pares_dias_lejanos': pares_dias_lejanos,
        'distribucion': dict(sorted(dist_histogram.items()))
    }

def imprimir_estadisticas(nombre, stats):
    """Imprime estadísticas de forma legible"""
    print(f"\n{'='*70}")
    print(f"ESTADÍSTICAS DE DISPERSIÓN: {nombre}")
    print(f"{'='*70}")

    if 'error' in stats:
        print(f"Error: {stats['error']}")
        return

    print(f"\nPares analizados: {stats['n_pares']}")
    print(f"Total estudiantes afectados: {stats['n_estudiantes_afectados']}")
    print(f"\nDISTANCIAS (en días):")
    print(f"  Mínima:             {stats['distancia_min']}")
    print(f"  Máxima:             {stats['distancia_max']}")
    print(f"  Promedio:           {stats['distancia_promedio']:.2f}")
    print(f"  Promedio ponderado: {stats['distancia_promedio_ponderada']:.2f}")
    print(f"\nSCORE TOTAL DE DISPERSIÓN: {stats['score_total']}")
    print(f"  (suma de peso × distancia para todos los pares)")
    print(f"\nCATEGORÍAS:")
    print(f"  Pares mismo día (dist=0):      {stats['pares_mismo_dia']:4d} ({100*stats['pares_mismo_dia']/stats['n_pares']:5.1f}%)")
    print(f"  Pares días consecutivos (d=1): {stats['pares_dias_consecutivos']:4d} ({100*stats['pares_dias_consecutivos']/stats['n_pares']:5.1f}%)")
    print(f"  Pares días lejanos (dist≥5):   {stats['pares_dias_lejanos']:4d} ({100*stats['pares_dias_lejanos']/stats['n_pares']:5.1f}%)")

    print(f"\nDISTRIBUCIÓN DE DISTANCIAS:")
    print(f"  Distancia  |  Cantidad de pares  |  Porcentaje")
    print(f"  {'-'*50}")
    for dist in sorted(stats['distribucion'].keys()):
        count = stats['distribucion'][dist]
        pct = 100 * count / stats['n_pares']
        print(f"      {dist:2d}     |        {count:4d}        |    {pct:5.1f}%")

def main():
    if len(sys.argv) < 2:
        print("Uso: python3 analizar_dispersion.py <archivo_resultado> [archivo2] [archivo3] ...")
        print("\nEjemplo:")
        print("  python3 analizar_dispersion.py resultado_parciales2.txt")
        print("  python3 analizar_dispersion.py resultado_parciales*.txt")
        sys.exit(1)

    # Leer datos de estudiantes en común
    print("Leyendo estudiantes-en-comun.dat...")
    pares = leer_estudiantes_comun()
    print(f"Total de pares con estudiantes en común: {len(pares)//2}")

    # Analizar cada archivo de resultados
    for filename in sys.argv[1:]:
        try:
            print(f"\n\nProcesando {filename}...")
            asignacion = leer_solucion_scip(filename)

            if not asignacion:
                print(f"⚠️  No se encontró asignación en {filename}")
                continue

            print(f"Parciales asignados: {len(asignacion)}")

            stats = analizar_dispersion(asignacion, pares)
            imprimir_estadisticas(filename, stats)

        except FileNotFoundError:
            print(f"⚠️  Archivo no encontrado: {filename}")
        except Exception as e:
            print(f"❌ Error procesando {filename}: {e}")
            import traceback
            traceback.print_exc()

if __name__ == '__main__':
    main()
