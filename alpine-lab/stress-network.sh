#!/bin/bash

echo "Démarrage du stress test réseau..."

# Génération de trafic réseau
for i in {1..1000}; do
  curl -s https://www.google.com > /dev/null &
  if [ $((i % 50)) -eq 0 ]; then
    echo "Requêtes réseau générées: $i"
    sleep 1
  fi
done

# On attend que tous les processus curl se terminent
wait

echo "Test de stress réseau terminé."
