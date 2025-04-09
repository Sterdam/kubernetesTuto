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
