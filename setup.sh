#!/bin/bash

# Script pour créer tous les fichiers nécessaires au projet MicroK8s stress test

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher l'état de création des fichiers
create_file() {
    local file_path=$1
    local file_content=$2
    
    echo -e "${BLUE}Création du fichier: $file_path${NC}"
    mkdir -p "$(dirname "$file_path")"
    
    # Écrire le contenu dans le fichier sans l'exécuter
    cat > "$file_path" << 'EOF'
$file_content
EOF
    
    # Remplacer la variable file_content dans le fichier
    sed -i "s|\\\$file_content|$file_content|g" "$file_path"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Fichier créé avec succès: $file_path${NC}"
    else
        echo -e "${RED}✗ Erreur lors de la création du fichier: $file_path${NC}"
    fi
}

# Créer les répertoires de base s'ils n'existent pas
echo -e "${YELLOW}Création des répertoires de base...${NC}"
mkdir -p ~/microk8s-stress-test/alpine-lab
mkdir -p ~/microk8s-stress-test/observer

# 1. Fichiers dans alpine-lab/

# 1.1 Dockerfile pour le conteneur lab
cat > ~/microk8s-stress-test/alpine-lab/Dockerfile << 'EOF'
FROM alpine:latest

# Installation des outils de base et des outils de stress
RUN apk update && apk add --no-cache \
    stress-ng \
    curl \
    wget \
    htop \
    procps \
    bash \
    coreutils \
    util-linux \
    python3 \
    py3-pip

# Création d'un répertoire pour les scripts de stress
WORKDIR /stress-scripts

# Copie des scripts de stress
COPY stress-cpu.sh /stress-scripts/
COPY stress-memory.sh /stress-scripts/
COPY stress-io.sh /stress-scripts/
COPY stress-network.sh /stress-scripts/
COPY stress-all.sh /stress-scripts/

# Rendre les scripts exécutables
RUN chmod +x /stress-scripts/*.sh

# Exposition d'un port pour le monitoring
EXPOSE 8080

# Commande par défaut (juste pour garder le conteneur en vie)
CMD ["tail", "-f", "/dev/null"]
EOF
echo -e "${GREEN}✓ Fichier créé avec succès: ~/microk8s-stress-test/alpine-lab/Dockerfile${NC}"

# 1.2 script-cpu.sh
cat > ~/microk8s-stress-test/alpine-lab/stress-cpu.sh << 'EOF'
#!/bin/bash

echo "Démarrage du stress test CPU..."
echo "Utilisation de stress-ng pour stresser tous les CPU disponibles"

# Détermine le nombre de CPU
NUM_CPU=$(nproc)
echo "Nombre de CPU détectés: $NUM_CPU"

# Stress CPU
stress-ng --cpu $NUM_CPU --cpu-method all --timeout 300s --metrics-brief

echo "Test de stress CPU terminé."
EOF
echo -e "${GREEN}✓ Fichier créé avec succès: ~/microk8s-stress-test/alpine-lab/stress-cpu.sh${NC}"

# 1.3 script-memory.sh
cat > ~/microk8s-stress-test/alpine-lab/stress-memory.sh << 'EOF'
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
EOF
echo -e "${GREEN}✓ Fichier créé avec succès: ~/microk8s-stress-test/alpine-lab/stress-memory.sh${NC}"

# 1.4 script-io.sh
cat > ~/microk8s-stress-test/alpine-lab/stress-io.sh << 'EOF'
#!/bin/bash

echo "Démarrage du stress test I/O..."

# Création d'un répertoire temporaire pour les tests I/O
mkdir -p /tmp/stress-io-test

# Stress I/O avec 4 workers et 2GB d'écritures par worker
stress-ng --io 4 --hdd 2 --hdd-bytes 2G --timeout 300s --metrics-brief

# Nettoyage
rm -rf /tmp/stress-io-test

echo "Test de stress I/O terminé."
EOF
echo -e "${GREEN}✓ Fichier créé avec succès: ~/microk8s-stress-test/alpine-lab/stress-io.sh${NC}"

# 1.5 script-network.sh
cat > ~/microk8s-stress-test/alpine-lab/stress-network.sh << 'EOF'
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
EOF
echo -e "${GREEN}✓ Fichier créé avec succès: ~/microk8s-stress-test/alpine-lab/stress-network.sh${NC}"

# 1.6 script-all.sh
cat > ~/microk8s-stress-test/alpine-lab/stress-all.sh << 'EOF'
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
EOF
echo -e "${GREEN}✓ Fichier créé avec succès: ~/microk8s-stress-test/alpine-lab/stress-all.sh${NC}"

# 2. Fichiers dans observer/

# 2.1 Dockerfile pour l'observateur
cat > ~/microk8s-stress-test/observer/Dockerfile << 'EOF'
FROM ubuntu:latest

# Installation des outils de monitoring
RUN apt-get update && apt-get install -y \
    prometheus \
    prometheus-node-exporter \
    curl \
    wget \
    htop \
    iftop \
    net-tools \
    python3 \
    python3-pip \
    vim \
    jq \
    dnsutils \
    iputils-ping \
    iproute2 \
    grafana \
    openssh-client

# Installation des dépendances Python pour les scripts d'observation
RUN pip3 install \
    requests \
    pandas \
    matplotlib \
    prometheus-client \
    kubernetes

# Création d'un répertoire pour les scripts d'observation
WORKDIR /monitoring-scripts

# Copie des scripts d'observation
COPY monitor.py /monitoring-scripts/
COPY prometheus.yml /etc/prometheus/
COPY grafana-dashboard.json /var/lib/grafana/dashboards/

# Exposition des ports pour Prometheus et Grafana
EXPOSE 9090 3000

# Commande de démarrage qui lance Prometheus et Grafana
CMD service prometheus start && service grafana-server start && tail -f /dev/null
EOF
echo -e "${GREEN}✓ Fichier créé avec succès: ~/microk8s-stress-test/observer/Dockerfile${NC}"

# 2.2 monitor.py
cat > ~/microk8s-stress-test/observer/monitor.py << 'EOF'
#!/usr/bin/env python3

import time
import requests
import json
import matplotlib.pyplot as plt
import pandas as pd
from datetime import datetime
from prometheus_client.parser import text_string_to_metric_families
from kubernetes import client, config

# Configuration pour accéder à l'API Kubernetes
try:
    config.load_incluster_config()  # Quand le script est exécuté dans un Pod
except:
    config.load_kube_config()  # Pour les tests locaux

v1 = client.CoreV1Api()

# Fonction pour récupérer les métriques Prometheus
def get_prometheus_metrics(prometheus_url="http://localhost:9090"):
    try:
        # Récupérer les métriques pour le CPU
        cpu_query = 'sum(rate(container_cpu_usage_seconds_total{pod=~"alpine-lab.*"}[5m])) by (pod)'
        cpu_response = requests.get(f"{prometheus_url}/api/v1/query", params={"query": cpu_query})
        
        # Récupérer les métriques pour la mémoire
        mem_query = 'sum(container_memory_usage_bytes{pod=~"alpine-lab.*"}) by (pod)'
        mem_response = requests.get(f"{prometheus_url}/api/v1/query", params={"query": mem_query})
        
        # Récupérer les métriques pour le réseau
        net_query = 'sum(rate(container_network_receive_bytes_total{pod=~"alpine-lab.*"}[5m])) by (pod)'
        net_response = requests.get(f"{prometheus_url}/api/v1/query", params={"query": net_query})
        
        # Récupérer les métriques pour les I/O disque
        io_query = 'sum(rate(container_fs_writes_bytes_total{pod=~"alpine-lab.*"}[5m])) by (pod)'
        io_response = requests.get(f"{prometheus_url}/api/v1/query", params={"query": io_query})
        
        # Formater et retourner les résultats
        results = {
            "cpu": cpu_response.json(),
            "memory": mem_response.json(),
            "network": net_response.json(),
            "disk_io": io_response.json(),
            "timestamp": datetime.now().isoformat()
        }
        
        return results
    except Exception as e:
        print(f"Erreur lors de la récupération des métriques Prometheus: {e}")
        return None

# Fonction pour récupérer les informations du Pod via l'API Kubernetes
def get_pod_info(pod_name_prefix="alpine-lab"):
    try:
        pods = v1.list_pod_for_all_namespaces(watch=False)
        lab_pods = [pod for pod in pods.items if pod.metadata.name.startswith(pod_name_prefix)]
        
        pod_info = []
        for pod in lab_pods:
            pod_data = {
                "name": pod.metadata.name,
                "namespace": pod.metadata.namespace,
                "status": pod.status.phase,
                "host_ip": pod.status.host_ip,
                "pod_ip": pod.status.pod_ip,
                "creation_timestamp": pod.metadata.creation_timestamp.isoformat(),
                "containers": []
            }
            
            for container in pod.spec.containers:
                container_data = {
                    "name": container.name,
                    "image": container.image,
                    "resources": {}
                }
                
                if container.resources:
                    if container.resources.limits:
                        container_data["resources"]["limits"] = container.resources.limits
                    if container.resources.requests:
                        container_data["resources"]["requests"] = container.resources.requests
                
                pod_data["containers"].append(container_data)
            
            pod_info.append(pod_data)
        
        return pod_info
    except Exception as e:
        print(f"Erreur lors de la récupération des informations du Pod: {e}")
        return None

# Fonction principale pour le monitoring
def monitor_alpine_lab(interval=30, prometheus_url="http://localhost:9090"):
    print(f"Démarrage du monitoring de alpine-lab avec un intervalle de {interval} secondes...")
    
    metrics_history = []
    
    try:
        while True:
            print(f"\n=== Collecte des données à {datetime.now().isoformat()} ===")
            
            # Récupérer les métriques et les informations du Pod
            prometheus_metrics = get_prometheus_metrics(prometheus_url)
            pod_info = get_pod_info()
            
            # Sauvegarder les métriques
            if prometheus_metrics:
                metrics_history.append(prometheus_metrics)
                
                # Afficher un résumé des métriques
                for metric_type, data in prometheus_metrics.items():
                    if metric_type != "timestamp":
                        print(f"{metric_type.upper()}: {json.dumps(data, indent=2)}")
            
            # Afficher les informations du Pod
            if pod_info:
                print("\nINFORMATIONS DU POD:")
                for pod in pod_info:
                    print(f"  - {pod['name']} ({pod['status']})")
                    print(f"    Namespace: {pod['namespace']}")
                    print(f"    IP: {pod['pod_ip']}")
                    
                    for container in pod["containers"]:
                        print(f"    Container: {container['name']} ({container['image']})")
                        if "resources" in container and container["resources"]:
                            print(f"      Resources: {json.dumps(container['resources'], indent=6)}")
            
            # Sauvegarder les métriques dans un fichier JSON toutes les 10 itérations
            if len(metrics_history) % 10 == 0:
                with open(f"/monitoring-scripts/metrics_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json", "w") as f:
                    json.dump(metrics_history[-10:], f, indent=2)
            
            time.sleep(interval)
    
    except KeyboardInterrupt:
        print("\nMonitoring interrompu par l'utilisateur.")
        
        # Sauvegarder toutes les métriques collectées
        with open(f"/monitoring-scripts/all_metrics_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json", "w") as f:
            json.dump(metrics_history, f, indent=2)
        
        # Générer des graphiques
        generate_metrics_graphs(metrics_history)

# Fonction pour générer des graphiques à partir des métriques collectées
def generate_metrics_graphs(metrics_history):
    if not metrics_history:
        print("Aucune métrique à tracer.")
        return
    
    # Préparer les données
    timestamps = [m["timestamp"] for m in metrics_history]
    
    # Créer une figure avec plusieurs sous-graphiques
    fig, axs = plt.subplots(2, 2, figsize=(15, 10))
    
    # Graphique CPU
    cpu_values = []
    for m in metrics_history:
        if "cpu" in m and "data" in m["cpu"] and "result" in m["cpu"]["data"]:
            for result in m["cpu"]["data"]["result"]:
                if "value" in result and len(result["value"]) > 1:
                    cpu_values.append(float(result["value"][1]))
                else:
                    cpu_values.append(0)
        else:
            cpu_values.append(0)
    
    axs[0, 0].plot(range(len(cpu_values)), cpu_values)
    axs[0, 0].set_title("Utilisation CPU")
    axs[0, 0].set_xlabel("Échantillons")
    axs[0, 0].set_ylabel("CPU (cores)")
    axs[0, 0].grid(True)
    
    # Graphique mémoire
    mem_values = []
    for m in metrics_history:
        if "memory" in m and "data" in m["memory"] and "result" in m["memory"]["data"]:
            for result in m["memory"]["data"]["result"]:
                if "value" in result and len(result["value"]) > 1:
                    # Convertir en MB
                    mem_values.append(float(result["value"][1]) / (1024 * 1024))
                else:
                    mem_values.append(0)
        else:
            mem_values.append(0)
    
    axs[0, 1].plot(range(len(mem_values)), mem_values)
    axs[0, 1].set_title("Utilisation mémoire")
    axs[0, 1].set_xlabel("Échantillons")
    axs[0, 1].set_ylabel("Mémoire (MB)")
    axs[0, 1].grid(True)
    
    # Graphique réseau
    net_values = []
    for m in metrics_history:
        if "network" in m and "data" in m["network"] and "result" in m["network"]["data"]:
            for result in m["network"]["data"]["result"]:
                if "value" in result and len(result["value"]) > 1:
                    # Convertir en KB/s
                    net_values.append(float(result["value"][1]) / 1024)
                else:
                    net_values.append(0)
        else:
            net_values.append(0)
    
    axs[1, 0].plot(range(len(net_values)), net_values)
    axs[1, 0].set_title("Trafic réseau entrant")
    axs[1, 0].set_xlabel("Échantillons")
    axs[1, 0].set_ylabel("Trafic (KB/s)")
    axs[1, 0].grid(True)
    
    # Graphique I/O disque
    io_values = []
    for m in metrics_history:
        if "disk_io" in m and "data" in m["disk_io"] and "result" in m["disk_io"]["data"]:
            for result in m["disk_io"]["data"]["result"]:
                if "value" in result and len(result["value"]) > 1:
                    # Convertir en KB/s
                    io_values.append(float(result["value"][1]) / 1024)
                else:
                    io_values.append(0)
        else:
            io_values.append(0)
    
    axs[1, 1].plot(range(len(io_values)), io_values)
    axs[1, 1].set_title("I/O disque")
    axs[1, 1].set_xlabel("Échantillons")
    axs[1, 1].set_ylabel("I/O (KB/s)")
    axs[1, 1].grid(True)
    
    # Ajuster la mise en page et sauvegarder
    plt.tight_layout()
    plt.savefig("/monitoring-scripts/metrics_graphs.png")
    print("Graphiques des métriques générés et sauvegardés dans '/monitoring-scripts/metrics_graphs.png'")

if __name__ == "__main__":
    monitor_alpine_lab(interval=30)
EOF
echo -e "${GREEN}✓ Fichier créé avec succès: ~/microk8s-stress-test/observer/monitor.py${NC}"

# 2.3 prometheus.yml
cat > ~/microk8s-stress-test/observer/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: "kubernetes-pods"
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: kubernetes_pod_name

  - job_name: "kubernetes-nodes"
    kubernetes_sd_configs:
      - role: node
    relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)
      - target_label: __address__
        replacement: kubernetes.default.svc:443
      - source_labels: [__meta_kubernetes_node_name]
        regex: (.+)
        target_label: __metrics_path__
        replacement: /api/v1/nodes/${1}/proxy/metrics/cadvisor

  - job_name: "kubernetes-apiserver"
    kubernetes_sd_configs:
      - role: endpoints
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      insecure_skip_verify: true
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    relabel_configs:
      - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
        action: keep
        regex: default;kubernetes;https
EOF
echo -e "${GREEN}✓ Fichier créé avec succès: ~/microk8s-stress-test/observer/prometheus.yml${NC}"

# 2.4 grafana-dashboard.json
cat > ~/microk8s-stress-test/observer/grafana-dashboard.json << 'EOF'
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": "-- Grafana --",
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "id": 1,
  "links": [],
  "panels": [
    {
      "aliasColors": {},
      "bars": false,
      "dashLength": 10,
      "dashes": false,
      "datasource": "Prometheus",
      "fill": 1,
      "fillGradient": 0,
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 0
      },
      "hiddenSeries": false,
      "id": 2,
      "legend": {
        "avg": false,
        "current": false,
        "max": false,
        "min": false,
        "show": true,
        "total": false,
        "values": false
      },
      "lines": true,
      "linewidth": 1,
      "nullPointMode": "null",
      "options": {
        "dataLinks": []
      },
      "percentage": false,
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": false,
      "targets": [
        {
          "expr": "sum(rate(container_cpu_usage_seconds_total{pod=~\"alpine-lab.*\"}[5m])) by (pod)",
          "interval": "",
          "legendFormat": "{{pod}}",
          "refId": "A"
        }
      ],
      "thresholds": [],
      "timeFrom": null,
      "timeRegions": [],
      "timeShift": null,
      "title": "CPU Usage",
      "tooltip": {
        "shared": true,
        "sort": 0,
        "value_type": "individual"
      },
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "time",
        "name": null,
        "show": true,
        "values": []
      },
      "yaxes": [
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    },
    {
      "aliasColors": {},
      "bars": false,
      "dashLength": 10,
      "dashes": false,
      "datasource": "Prometheus",
      "fill": 1,
      "fillGradient": 0,
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 0
      },
      "hiddenSeries": false,
      "id": 4,
      "legend": {
        "avg": false,
        "current": false,
        "max": false,
        "min": false,
        "show": true,
        "total": false,
        "values": false
      },
      "lines": true,
      "linewidth": 1,
      "nullPointMode": "null",
      "options": {
        "dataLinks": []
      },
      "percentage": false,
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": false,
      "targets": [
        {
          "expr": "sum(container_memory_usage_bytes{pod=~\"alpine-lab.*\"}) by (pod)",
          "interval": "",
          "legendFormat": "{{pod}}",
          "refId": "A"
        }
      ],
      "thresholds": [],
      "timeFrom": null,
      "timeRegions": [],
      "timeShift": null,
      "title": "Memory Usage",
      "tooltip": {
        "shared": true,
        "sort": 0,
        "value_type": "individual"
      },
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "time",
        "name": null,
        "show": true,
        "values": []
      },
      "yaxes": [
        {
          "format": "bytes",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    }
  ],
  "refresh": "10s",
  "schemaVersion": 22,
  "style": "dark",
  "tags": [],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-1h",
    "to": "now"
  },
  "timepicker": {
    "refresh_intervals": [
      "5s",
      "10s",
      "30s",
      "1m",
      "5m",
      "15m",
      "30m",
      "1h",
      "2h",
      "1d"
    ]
  },
  "timezone": "",
  "title": "Alpine Lab Monitoring",
  "uid": "alpinelab",
  "variables": {
    "list": []
  },
  "version": 1
}
EOF
echo -e "${GREEN}✓ Fichier créé avec succès: ~/microk8s-stress-test/observer/grafana-dashboard.json${NC}"

# 3. Fichiers de configuration K8s

# 3.1 rbac-config.yaml
cat > ~/microk8s-stress-test/rbac-config.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: observer-account
  namespace: stress-test
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: observer-role
rules:
- apiGroups: [""]
  resources: ["nodes", "nodes/proxy", "services", "endpoints", "pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["extensions"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["configmaps", "namespaces"]
  verbs: ["get"]
- apiGroups: ["metrics.k8s.io"]
  resources: ["pods", "nodes"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: observer-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: observer-role
subjects:
- kind: ServiceAccount
  name: observer-account
  namespace: stress-test
EOF
echo -e "${GREEN}✓ Fichier créé avec succès: ~/microk8s-stress-test/rbac-config.yaml${NC}"

# 3.2 alpine-lab-deployment.yaml
cat > ~/microk8s-stress-test/alpine-lab-deployment.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: stress-test
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alpine-lab
  namespace: stress-test
  labels:
    app: alpine-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: alpine-lab
  template:
    metadata:
      labels:
        app: alpine-lab
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
    spec:
      containers:
      - name: alpine-lab
        image: localhost:32000/alpine-lab:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
        resources:
          limits:
            cpu: "2"
            memory: "2Gi"
          requests:
            cpu: "500m"
            memory: "500Mi"
        volumeMounts:
        - name: stress-scripts-volume
          mountPath: /stress-scripts
      volumes:
      - name: stress-scripts-volume
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: alpine-lab
  namespace: stress-test
spec:
  selector:
    app: alpine-lab
  ports:
  - port: 8080
    targetPort: 8080
  type: ClusterIP
EOF
echo -e "${GREEN}✓ Fichier créé avec succès: ~/microk8s-stress-test/alpine-lab-deployment.yaml${NC}"

# 3.3 observer-deployment.yaml
cat > ~/microk8s-stress-test/observer-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: observer
  namespace: stress-test
  labels:
    app: observer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: observer
  template:
    metadata:
      labels:
        app: observer
    spec:
      containers:
      - name: observer
        image: localhost:32000/observer:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 9090
          name: prometheus
        - containerPort: 3000
          name: grafana
        volumeMounts:
        - name: monitoring-scripts-volume
          mountPath: /monitoring-scripts
        - name: prometheus-config-volume
          mountPath: /etc/prometheus/prometheus.yml
          subPath: prometheus.yml
      volumes:
      - name: monitoring-scripts-volume
        emptyDir: {}
      - name: prometheus-config-volume
        configMap:
          name: prometheus-config
---
apiVersion: v1
kind: Service
metadata:
  name: observer
  namespace: stress-test
spec:
  selector:
    app: observer
  ports:
  - port: 9090
    targetPort: 9090
    name: prometheus
  - port: 3000
    targetPort: 3000
    name: grafana
  type: NodePort
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: stress-test
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s

    scrape_configs:
      - job_name: "kubernetes-pods"
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
            action: replace
            regex: ([^:]+)(?::\d+)?;(\d+)
            replacement: $1:$2
            target_label: __address__
          - action: labelmap
            regex: __meta_kubernetes_pod_label_(.+)
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: kubernetes_namespace
          - source_labels: [__meta_kubernetes_pod_name]
            action: replace
            target_label: kubernetes_pod_name

      - job_name: "kubernetes-nodes"
        kubernetes_sd_configs:
          - role: node
        relabel_configs:
          - action: labelmap
            regex: __meta_kubernetes_node_label_(.+)
          - target_label: __address__
            replacement: kubernetes.default.svc:443
          - source_labels: [__meta_kubernetes_node_name]
            regex: (.+)
            target_label: __metrics_path__
            replacement: /api/v1/nodes/${1}/proxy/metrics/cadvisor
EOF
echo -e "${GREEN}✓ Fichier créé avec succès: ~/microk8s-stress-test/observer-deployment.yaml${NC}"

# Rendre les scripts exécutables
echo -e "${YELLOW}Rendre les scripts exécutables...${NC}"
chmod +x ~/microk8s-stress-test/alpine-lab/stress-*.sh
chmod +x ~/microk8s-stress-test/observer/monitor.py

echo -e "${GREEN}Tous les fichiers ont été créés avec succès !${NC}"
echo -e "${YELLOW}Étapes suivantes :${NC}"
echo -e "1. Créer le namespace Kubernetes : ${BLUE}kubectl create namespace stress-test${NC}"
echo -e "2. Construire les images Docker : ${BLUE}cd ~/microk8s-stress-test/alpine-lab && docker build -t localhost:32000/alpine-lab:latest .${NC}"
echo -e "3. Puis : ${BLUE}cd ~/microk8s-stress-test/observer && docker build -t localhost:32000/observer:latest .${NC}"
echo -e "4. Déployer les configurations RBAC : ${BLUE}kubectl apply -f ~/microk8s-stress-test/rbac-config.yaml${NC}"
echo -e "5. Déployer les applications : ${BLUE}kubectl apply -f ~/microk8s-stress-test/alpine-lab-deployment.yaml -f ~/microk8s-stress-test/observer-deployment.yaml${NC}"
