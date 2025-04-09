#!/bin/bash

echo "Démarrage du stress test combiné (CPU, mémoire, I/O, réseau)..."

# Détermine le nombre de CPU
NUM_CPU=$(nproc)
echo "Nombre de CPU détectés: $NUM_CPU"

# Récupération de la mémoire totale en MB
TOTAL_MEM=$(free -m | grep Mem | awk '{print $2}')
echo "Mémoire totale détectée: $TOTAL_MEM MB"

# Calcule 70% de la mémoire disponible pour le stress
STRESS_MEM=$((TOTAL_MEM * 70 / 100))
echo "Stressage de $STRESS_MEM MB de mémoire (70% du total)"

# Stress combiné
stress-ng --cpu $NUM_CPU --cpu-method all \
          --vm 2 --vm-bytes ${STRESS_MEM}M --vm-keep \
          --io 2 --hdd 1 --hdd-bytes 1G \
          --timeout 600s --metrics-brief &

# ID du processus stress-ng
STRESS_PID=$!

# Génération de trafic réseau en parallèle
for i in {1..500}; do
  curl -s https://www.google.com > /dev/null &
  if [ $((i % 50)) -eq 0 ]; then
    echo "Requêtes réseau générées: $i"
    sleep 2
  fi
done

# Attente que le stress-ng se termine
wait $STRESS_PID

echo "Test de stress combiné terminé."
