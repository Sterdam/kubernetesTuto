#!/bin/bash

echo "Démarrage du stress test CPU..."
echo "Utilisation de stress-ng pour stresser tous les CPU disponibles"

# Détermine le nombre de CPU
NUM_CPU=$(nproc)
echo "Nombre de CPU détectés: $NUM_CPU"

# Stress CPU
stress-ng --cpu $NUM_CPU --cpu-method all --timeout 300s --metrics-brief

echo "Test de stress CPU terminé."
