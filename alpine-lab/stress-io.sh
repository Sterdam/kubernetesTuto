#!/bin/bash

echo "Démarrage du stress test I/O..."

# Création d'un répertoire temporaire pour les tests I/O
mkdir -p /tmp/stress-io-test

# Stress I/O avec 4 workers et 2GB d'écritures par worker
stress-ng --io 4 --hdd 2 --hdd-bytes 2G --timeout 300s --metrics-brief

# Nettoyage
rm -rf /tmp/stress-io-test

echo "Test de stress I/O terminé."
