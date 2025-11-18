#!/usr/bin/env python3
"""
Parser de solución de SCIP para el problema de asignación de parciales
"""

import re
import sys
from collections import defaultdict

def parsear_solucion_scip(salida_texto):
    """Parsea la salida de SCIP y extrae la asignación de parciales"""

    # Buscar la sección de solución primal
    inicio = salida_texto.find("primal solution (original space):")
    if inicio == -1:
        print("No se encontró solución en la salida")
        return None

    # Buscar el valor objetivo
    obj_match = re.search(r'objective value:\s+(\d+)', salida_texto[inicio:])
    if obj_match:
        valor_objetivo = int(obj_match.group(1))
        print(f"\n{'='*70}")
        print(f"SOLUCIÓN ÓPTIMA ENCONTRADA")
        print(f"{'='*70}")
        print(f"\nParciales asignados: {valor_objetivo} de 208 ({valor_objetivo/208*100:.1f}%)")
        print(f"\n{'='*70}\n")

    # Extraer asignaciones x[P,D,H] = 1
    asignaciones = []
    patron = r'x\$([P\d]+)#(\d+)#(\d+)\s+1'

    for match in re.finditer(patron, salida_texto[inicio:]):
        parcial = match.group(1)
        dia = int(match.group(2))
        hora = int(match.group(3))
        asignaciones.append((parcial, dia, hora))

    return asignaciones, valor_objetivo

def leer_aulas_requeridas():
    """Lee el archivo cursos.dat para obtener las aulas requeridas por cada parcial"""
    aulas = {}
    try:
        with open('cursos.dat', 'r') as f:
            for line in f:
                parts = line.strip().split('\t')
                if len(parts) == 2:
                    parcial = parts[0]
                    num_aulas = int(parts[1])
                    aulas[parcial] = num_aulas
    except FileNotFoundError:
        print("Advertencia: No se encontró cursos.dat, no se mostrarán las aulas")
    return aulas

def generar_reporte(asignaciones, valor_objetivo):
    """Genera un reporte organizado por día y hora"""

    # Leer aulas requeridas
    aulas_requeridas = leer_aulas_requeridas()

    # Organizar por slot (día, hora)
    slots = defaultdict(list)
    for parcial, dia, hora in asignaciones:
        slots[(dia, hora)].append(parcial)

    # Días y horas disponibles
    dias = [1, 2, 3, 4, 5, 9, 10, 11, 12]
    horas = [9, 12, 15, 18]

    print("ASIGNACIÓN DE PARCIALES POR SLOT\n")
    print(f"{'Día':<6} {'Hora':<6} {'Cantidad':<10} {'Aulas':<8} {'Parciales'}")
    print(f"{'-'*80}")

    total_asignados = 0
    for dia in dias:
        for hora in horas:
            parciales_slot = slots.get((dia, hora), [])
            if parciales_slot:
                # Calcular total de aulas usadas en este slot
                total_aulas = sum(aulas_requeridas.get(p, 0) for p in parciales_slot)

                parciales_str = ', '.join(sorted(parciales_slot, key=lambda x: int(x[1:])))
                print(f"{dia:<6} {hora:<6} {len(parciales_slot):<10} {total_aulas:<8} {parciales_str}")
                total_asignados += len(parciales_slot)

    print(f"{'-'*70}")
    print(f"Total asignados: {total_asignados}")

    # Estadísticas por día
    print(f"\n{'='*70}")
    print("ESTADÍSTICAS POR DÍA\n")
    print(f"{'Día':<10} {'Parciales asignados'}")
    print(f"{'-'*30}")

    for dia in dias:
        total_dia = sum(len(slots.get((dia, hora), [])) for hora in horas)
        if total_dia > 0:
            print(f"{dia:<10} {total_dia}")

    # Estadísticas por horario
    print(f"\n{'='*70}")
    print("ESTADÍSTICAS POR HORARIO\n")
    print(f"{'Hora':<10} {'Parciales asignados'}")
    print(f"{'-'*30}")

    for hora in horas:
        total_hora = sum(len(slots.get((dia, hora), [])) for dia in dias)
        if total_hora > 0:
            print(f"{hora:<10} {total_hora}")

if __name__ == "__main__":
    # Leer salida de SCIP desde stdin o archivo
    if len(sys.argv) > 1:
        with open(sys.argv[1], 'r') as f:
            salida = f.read()
    else:
        salida = sys.stdin.read()

    resultado = parsear_solucion_scip(salida)
    if resultado:
        asignaciones, valor_objetivo = resultado
        generar_reporte(asignaciones, valor_objetivo)
