#!/bin/bash

echo "Démarrage du stress test mémoire..."

# Récupération de la mémoire totale en MB
TOTAL_MEM=$(free -m | grep Mem | awk '{print $2}')
echo "Mémoire totale détectée: $TOTAL_MEM MB"

# Calcule 80% de la mémoire disponible
STRESS_MEM=$((TOTAL_MEM * 80 / 100))
echo "Stressage de $STRESS_MEM MB de mémoire (80% du total)"

# Stress mémoire
stress-ng --vm 2 --vm-bytes ${STRESS_MEM}M --vm-keep --timeout 300s --metrics-brief

echo "Test de stress mémoire terminé."
